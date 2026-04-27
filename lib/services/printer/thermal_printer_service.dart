
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

  Future<Uint8List> rasterizePdfForThermal(Uint8List pdfBytes, {double widthMm = 80}) async {
    try {
      // Rasterize to image (scale for better quality)
      final pageImage = await Printing.raster(
        pdfBytes,
        pages: [0],
        dpi: 300,
      ).first;

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        order: img.ChannelOrder.rgba,
      );

      // Resize to thermal printer width (8px/mm ≈ 203 DPI)
      final targetWidthPx = (widthMm * 8).round();
      final resized = img.copyResize(image, width: targetWidthPx);

      // Generate ESC/POS commands for the image
      final profile = await CapabilityProfile.load();
      final generator = Generator(widthMm == 80 ? PaperSize.mm80 : PaperSize.mm58, profile);
      
      List<int> bytes = [];
      bytes += generator.reset();
      bytes += generator.imageRaster(resized); // Handles monochrome thresholding internally
      bytes += generator.feed(2);
      bytes += generator.cut();

      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Error rasterizing PDF: $e');
      return Uint8List(0);
    }
  }

  Future<bool> printPdf(Uint8List pdfBytes, {double widthMm = 80}) async {
    if (!_isConnected) return false;
    final escPosBytes = await rasterizePdfForThermal(pdfBytes, widthMm: widthMm);
    if (escPosBytes.isEmpty) return false;
    return await _connection.sendImage(escPosBytes);
  }
}
