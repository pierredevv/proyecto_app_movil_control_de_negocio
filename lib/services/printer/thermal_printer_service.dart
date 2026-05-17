
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'thermal_printer_connection.dart';
import 'bluetooth_printer_connection.dart';
import 'esc_pos_receipt_service.dart';
import '../../models/transaction_model.dart';
import '../../models/business_profile.dart';

class ThermalPrinterService {
  // Singleton instance
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  static ThermalPrinterService get instance => _instance;

  final ThermalPrinterConnection _connection = BluetoothPrinterConnection();
  String? _connectedAddress;
  bool _isConnected = false;

  ThermalPrinterService._internal() {
    _initConnection();
  }

  Future<void> _initConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('pref_printer_mac');
    if (savedAddress != null && savedAddress.isNotEmpty) {
      await connect(savedAddress);
    }
  }

  bool get isConnected => _isConnected;
  String? get connectedAddress => _connectedAddress;

  Future<bool> requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        final result = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();
        return result.values.every((status) => status.isGranted);
      } else {
        final result = await [
          Permission.locationWhenInUse,
          Permission.bluetooth,
        ].request();
        return result.values.every((status) => status.isGranted);
      }
    }
    return true;
  }

  Future<List<PrinterDevice>> scan() async {
    if (!await requestBluetoothPermissions()) {
      return [];
    }
    return await _connection.scan();
  }

  Future<bool> connect(String address) async {
    bool success = await _connection.connect(address);
    if (success) {
      _isConnected = true;
      _connectedAddress = address;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_printer_mac', address);
    }
    return success;
  }

  Future<void> disconnect() async {
    await _connection.disconnect();
    _isConnected = false;
    _connectedAddress = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_printer_mac');
  }


  Future<Uint8List> rasterizePdfForThermal(Uint8List pdfBytes,
      {double widthMm = 80}) async {
    try {
      final targetWidthPx = (widthMm * 8).round(); // 8 px/mm = 203 DPI target

      // ── Step 1: Rasterize ─────────────────────────────────────────────────
      // 120 DPI gives less anti-aliasing than 203 DPI.
      // Softer anti-aliasing = harder text edges = text survives monochrome
      // thresholding without turning grey and disappearing.
      final pageImage = await Printing.raster(
        pdfBytes,
        pages: [0],
        dpi: 120,
      ).first;

      // ── Step 2: Decode RGBA ───────────────────────────────────────────────
      final rgba = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        order: img.ChannelOrder.rgba,
      );

      // ── Step 3: Composite onto RGBA white canvas ──────────────────────────
      // MUST use numChannels: 4 (RGBA) for the destination canvas.
      // With numChannels: 3 (RGB), img.compositeImage cannot perform
      // alpha-blending correctly because it has no alpha channel to read
      // from the destination during the blend computation, causing the
      // transparent-black source pixels to remain dark instead of blending
      // onto white — which is why the previous attempt still had issues.
      final flat = img.Image(
        width: rgba.width,
        height: rgba.height,
        numChannels: 4,
      );
      img.fill(flat, color: img.ColorRgba8(255, 255, 255, 255));
      img.compositeImage(flat, rgba); // alpha-blend; transparent → white

      // ── Step 4: Resize with nearest-neighbor ─────────────────────────────
      // Interpolation.average blurs text edges into mid-grey.  After
      // monochrome thresholding, mid-grey → white (no ink) → text vanishes.
      // Nearest-neighbor preserves hard black/white edges.
      final resized = flat.width == targetWidthPx
          ? flat
          : img.copyResize(
              flat,
              width: targetWidthPx,
              interpolation: img.Interpolation.nearest,
            );

      // ── Step 5: Grayscale + contrast boost ────────────────────────────────
      // imageRaster() applies its own internal threshold (≈ 127 / 255).
      // Without a contrast boost, light-grey anti-aliased pixels sit just
      // above the threshold and are treated as white → text disappears.
      // Boosting contrast pushes dark greys below the threshold (→ ink)
      // and light greys above (→ no ink), producing a crisp 1-bit result.
      final grayscale = img.grayscale(resized);
      final contrasted = img.adjustColor(grayscale, contrast: 1.8);

      // ── Step 6: Build ESC/POS byte stream ────────────────────────────────
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        widthMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
        profile,
      );

      List<int> bytes = [];
      bytes += generator.reset();
      bytes += generator.imageRaster(contrasted, align: PosAlign.center);
      bytes += generator.feed(3);
      bytes += generator.cut();

      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Error rasterizando PDF para impresora térmica: $e');
      return Uint8List(0);
    }
  }

  Future<bool> printPdf(Uint8List pdfBytes, {double widthMm = 80}) async {
    if (!_isConnected) return false;
    final escPosBytes = await rasterizePdfForThermal(pdfBytes, widthMm: widthMm);
    if (escPosBytes.isEmpty) return false;
    return await _connection.sendImage(escPosBytes);
  }

  /// Prints a native ESC/POS receipt directly from [transaction] data.
  ///
  /// This is the correct path for Bluetooth thermal printing.
  /// It generates ~2–10 KB of ESC/POS text commands — no image rasterization,
  /// no PDF parsing, no RAM spikes. The GC never interrupts the byte stream.
  Future<bool> printReceipt(
    Transaction transaction,
    BusinessProfile profile, {
    double widthMm = 58,
  }) async {
    if (!_isConnected) return false;
    try {
      final bytes = await EscPosReceiptService().buildReceipt(
        transaction,
        profile,
        widthMm: widthMm,
      );
      if (bytes.isEmpty) return false;
      return await _connection.sendImage(bytes);
    } catch (e) {
      debugPrint('Error en printReceipt: $e');
      return false;
    }
  }

  /// Prints a plain-text test page — no image rasterization, no PDF, no RAM spikes.
  ///
  /// Use this to validate the full print chain (BT → ESC/POS → paper width)
  /// before committing to a full-receipt print.  If text prints correctly
  /// here, any remaining problems are isolated to the PDF-rasterization step.
  Future<bool> printTestPage({double widthMm = 58}) async {
    if (!_isConnected) return false;
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        widthMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
        profile,
      );

      final sep = widthMm == 58
          ? '================================'
          : '================================================';

      List<int> bytes = [];
      bytes += generator.reset();
      bytes += generator.text(sep,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('   PRUEBA DE IMPRESION   ',
          styles: const PosStyles(
              bold: true,
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.text(sep,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('Ancho papel : ${widthMm.toStringAsFixed(0)} mm',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Bluetooth   : OK',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('ESC/POS     : OK',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('ABCDEFGHIJKLMNOPQRSTUVWXYZ',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('abcdefghijklmnopqrstuvwxyz',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('0 1 2 3 4 5 6 7 8 9',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('Si lees esto, la impresora',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('funciona correctamente.',
          styles: const PosStyles(
              bold: true, align: PosAlign.center));
      bytes += generator.feed(3);
      bytes += generator.cut();

      return await _connection.sendImage(Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('Error en prueba de impresión: $e');
      return false;
    }
  }
}
