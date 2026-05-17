import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/business_profile.dart';
import '../../utils/number_to_words.dart';

/// Generates a thermal-printer receipt directly as ESC/POS bytes.
///
/// The output mirrors the PDF template from [PdfGeneratorService] exactly:
///   logo (optional) → FACTURA header → business data → divider →
///   customer block → divider → items table → divider →
///   totals (bold) → amount-in-words → divider → legal text → QR → cut
///
/// Architecture rationale
/// ──────────────────────
/// Converting a PDF to a raster image consumes 100–200 MB of RAM on cheap
/// Android devices and produces corrupted / blank output when the GC
/// interrupts the byte stream mid-transfer.
/// This service bypasses that pipeline entirely: ~2–10 KB of ESC/POS commands.
class EscPosReceiptService {
  /// Returns the complete ESC/POS byte stream for [transaction].
  /// [widthMm] must match the physical printer paper width (58 or 80 mm).
  Future<Uint8List> buildReceipt(
    Transaction transaction,
    BusinessProfile profile, {
    double widthMm = 58,
  }) async {
    final capProfile = await CapabilityProfile.load();
    final generator = Generator(
      widthMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
      capProfile,
    );

    // 58 mm → 32 chars/line; 80 mm → 48 chars/line
    final lineWidth = widthMm == 58 ? 32 : 48;
    final sep = '=' * lineWidth;
    final thinSep = '-' * lineWidth;

    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a', 'es_BO');
    final dateStr = dateFormat.format(transaction.date);

    // ── Sanitize all user-supplied strings ───────────────────────────────
    // ESC/POS code pages are 8-bit; anything above U+00FF (emoji, CJK, …)
    // throws "Invalid argument: Contains invalid characters".
    final bizName   = _s(profile.businessName).toUpperCase();
    final bizBranch = _s(profile.branchNumber);
    final bizPos    = _s(profile.posNumber);
    final bizZone   = _s(profile.zone);
    final bizAddr   = _s(profile.address.isNotEmpty
        ? profile.address
        : profile.streetNumber);
    final bizPhone  = _s(profile.phone);
    final bizCity   = _s(profile.city.isNotEmpty ? profile.city : 'Santa Cruz');
    final bizNit    = _s(profile.nit);
    final bizPrefix = _s(profile.invoicePrefix);
    final bizFooter = _s(profile.invoiceFooter);

    String entityName = 'S/N';
    String ciNit = 'NO NIT';
    if (transaction is Sale) {
      entityName = _s(transaction.customerName?.trim().isNotEmpty == true
          ? transaction.customerName!
          : 'S/N');
      ciNit = _s(transaction.clientCiNit?.trim().isNotEmpty == true
          ? transaction.clientCiNit!
          : 'NO NIT');
    } else if (transaction is Purchase) {
      entityName = _s(transaction.supplierName?.trim().isNotEmpty == true
          ? transaction.supplierName!
          : 'S/N');
    }

    final invoiceNum =
        '$bizPrefix-${transaction.id?.toString().padLeft(4, '0') ?? '0000'}';
    final authCode = '${bizPrefix}AUTHCODE';

    List<int> bytes = [];
    bytes += generator.reset();

    // ── 1. Logo ───────────────────────────────────────────────────────────
    if (profile.printLogoOnThermal &&
        profile.logoPath != null &&
        profile.logoPath!.isNotEmpty) {
      final logoFile = File(profile.logoPath!);
      if (await logoFile.exists()) {
        try {
          final rawBytes = await logoFile.readAsBytes();
          final decoded = img.decodeImage(rawBytes);
          if (decoded != null) {
            // Resize to max 160 px wide, keeping aspect ratio
            final logoW = widthMm == 58 ? 160 : 240;
            final scaled = img.copyResize(decoded,
                width: logoW, interpolation: img.Interpolation.average);
            // Flatten onto white (same fix as the rasterization pipeline)
            final flat = img.Image(
                width: scaled.width, height: scaled.height, numChannels: 4);
            img.fill(flat, color: img.ColorRgba8(255, 255, 255, 255));
            img.compositeImage(flat, scaled);
            final gray = img.grayscale(flat);
            final contrasted = img.adjustColor(gray, contrast: 1.8);
            bytes += generator.imageRaster(contrasted,
                align: PosAlign.center);
            // Convert PDF logoSpacing (0-40) to thermal feed lines (0-4 max)
            final feedLines = (profile.logoSpacing / 10).round().clamp(0, 4);
            if (feedLines > 0) {
              bytes += generator.feed(feedLines);
            }
          }
        } catch (e) {
          // Logo failed — continue without it rather than crashing
        }
      }
    }

    // ── 2. Header — matches PDF exactly ───────────────────────────────────
    bytes += generator.text(
      'FACTURA',
      styles: const PosStyles(
          bold: true, align: PosAlign.center, height: PosTextSize.size2),
    );
    bytes += generator.text(
      'CON DERECHO A CREDITO FISCAL',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.text(
      bizName,
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.text(
      'SUCURSAL NO. $bizBranch',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Punto de Venta No. $bizPos',
      styles: const PosStyles(align: PosAlign.center),
    );
    if (bizZone.isNotEmpty || bizAddr.isNotEmpty) {
      bytes += generator.text(
        'ZONA: $bizZone, CALLE: $bizAddr',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (bizPhone.isNotEmpty) {
      bytes += generator.text(
        'Telefono: $bizPhone',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.text(
      bizCity,
      styles: const PosStyles(align: PosAlign.center),
    );
    if (profile.showNitOnInvoice && bizNit.isNotEmpty) {
      bytes += generator.text(
        'NIT: $bizNit',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      );
    }
    bytes += generator.text(
      'NRO. FACTURA: $invoiceNum',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.text(
      'COD. AUTORIZACION: $authCode',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(sep);

    // ── 3. Customer block ─────────────────────────────────────────────────
    bytes += generator.text('NOMBRE/RAZON SOCIAL: $entityName');
    bytes += generator.text('NIT/CI: $ciNit');
    bytes += generator.text('FECHA DE EMISION: $dateStr');

    bytes += generator.text(thinSep);

    // ── 4. Items table ────────────────────────────────────────────────────
    if (widthMm == 58) {
      // 32-char layout: name + total on row 1, qty × unit on row 2
      bytes += generator.row([
        PosColumn(
            text: 'DESCRIPCION',
            width: 8,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'TOTAL',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    } else {
      // 48-char layout: 4 columns
      bytes += generator.row([
        PosColumn(
            text: 'CANT.',
            width: 2,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'DESCRIPCION',
            width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'P.UNIT.',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(
            text: 'TOTAL',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    }
    bytes += generator.text(thinSep);

    for (final item in transaction.items) {
      final qty = item.quantity;
      final qtyStr =
          '${qty.toStringAsFixed(qty == qty.truncate() ? 0 : 2)} ${_s(item.saleUnit)}';
      final totalStr = 'Bs.${item.subtotal.toStringAsFixed(2)}';
      final unitStr  = 'Bs.${item.unitPrice.toStringAsFixed(2)}';
      final nameMaxLen = widthMm == 58 ? 20 : 28;
      final rawName = _s(item.productName);
      final name = rawName.length > nameMaxLen
          ? '${rawName.substring(0, nameMaxLen - 1)}.'
          : rawName;

      if (widthMm == 58) {
        bytes += generator.row([
          PosColumn(text: name, width: 8),
          PosColumn(
              text: totalStr,
              width: 4,
              styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
        bytes += generator.text('  $qtyStr x $unitStr');
      } else {
        bytes += generator.row([
          PosColumn(text: qtyStr, width: 2),
          PosColumn(text: name, width: 6),
          PosColumn(
              text: unitStr,
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: totalStr,
              width: 2,
              styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
    }
    bytes += generator.text(sep);

    // ── 5. Totals (bold) — matches PDF exactly ────────────────────────────
    final grossAmount = transaction.totalAmount - transaction.adjustmentAmount;

    if (transaction.adjustmentAmount != 0) {
      bytes += generator.row([
        PosColumn(
            text: 'SUBTOTAL:',
            width: 8,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Bs.${grossAmount.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(
            text: 'DESCUENTO:',
            width: 8,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Bs.${transaction.adjustmentAmount.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          text: 'TOTAL A PAGAR:',
          width: 8,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Bs.${transaction.totalAmount.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    if (transaction is Sale) {
      final change = transaction.amountTendered > transaction.totalAmount
          ? transaction.amountTendered - transaction.totalAmount
          : 0.0;
      bytes += generator.row([
        PosColumn(
            text: 'EFECTIVO:',
            width: 8,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Bs.${transaction.amountTendered.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(
            text: 'CAMBIO:',
            width: 8,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Bs.${change.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          text: 'IMPORTE BASE CF:',
          width: 8,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Bs.${transaction.totalAmount.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    bytes += generator.text(sep);

    // ── 6. Amount in words ────────────────────────────────────────────────
    final words = _s(
      NumberToWords.toLiteral(transaction.totalAmount, currency: 'Bolivianos')
          .replaceAll('SON: ', ''),
    );
    bytes += generator.text(
      'SON: $words',
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(thinSep);

    // ── 7. Legal text — matches PDF exactly ──────────────────────────────
    bytes += generator.text(
      '"ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'PAIS. EL USO ILICITO DE ESTA SERA',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'SANCIONADO DE ACUERDO A LEY"',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Ley N 453: El proveedor debera suministrar',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'el servicio sin discriminacion.',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(1);

    // ── 8. QR code ────────────────────────────────────────────────────────
    final qrData =
        '$bizNit|${transaction.id}|${transaction.date.toIso8601String()}'
        '|${transaction.totalAmount.toStringAsFixed(2)}|$ciNit|$authCode';
    bytes += generator.qrcode(qrData, size: QRSize.size4);
    bytes += generator.feed(1);

    // ── 9. Footer ─────────────────────────────────────────────────────────
    bytes += generator.text(
      'Doc: FFA/000-${transaction.id?.toString().padLeft(6, '0') ?? '000000'}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'SistemaVentas - v1.0',
      styles: const PosStyles(align: PosAlign.center),
    );
    if (bizFooter.isNotEmpty) {
      bytes += generator.feed(1);
      bytes += generator.text(
        bizFooter,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    // Many portable 58mm printers don't have an auto-cutter.
    // We feed just enough to pass the tear bar to avoid wasting paper.
    bytes += generator.feed(2);
    // Cut command can cause extra feeds on some cheap printers if not supported,
    // but usually it's ignored if hardware doesn't support it.
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  /// Strips characters outside the Latin-1 range (U+0000–U+00FF).
  ///
  /// ESC/POS code pages are 8-bit. Characters above U+00FF (emoji, CJK, …)
  /// cause esc_pos_utils_plus to throw "Invalid argument: Contains invalid
  /// characters". Keeping ≤ U+00FF preserves Spanish letters (á, é, ñ, ü, ¡).
  static String _s(String text) =>
      String.fromCharCodes(text.runes.where((r) => r <= 0xFF));
}
