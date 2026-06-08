import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import '../models/business_profile.dart';
import '../utils/number_to_words.dart';
import '../utils/currency_helper.dart';

class PdfGeneratorService {
  Future<Uint8List> generateInvoice(Transaction transaction, BusinessProfile profile,
      {String? ciNit, String? customClientName}) async {
    
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Load logo if the profile has one and the toggle is on.
    pw.MemoryImage? logoImage;
    if (profile.showLogoOnInvoice &&
        profile.logoPath != null &&
        profile.logoPath!.isNotEmpty) {
      final logoFile = File(profile.logoPath!);
      if (await logoFile.exists()) {
        logoImage = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }
    
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a', CurrencyHelper.locale);
    
    // Determine CI/NIT and Entity Name
    String entityName = customClientName ?? (transaction is Sale ? transaction.customerName : (transaction is Purchase ? transaction.supplierName : null)) ?? "S/N";
    String effectiveCiNit = ciNit ?? (transaction is Sale ? transaction.clientCiNit : null) ?? "NO NIT";
    
    if (effectiveCiNit.trim().isEmpty) effectiveCiNit = "NO NIT";
    if (entityName.trim().isEmpty) entityName = "S/N";

    // QR Data formulation (SIN Standard simulation)
    final String qrJsonString = 
        "${profile.nit}|${transaction.id}|${transaction.date.toIso8601String()}|${transaction.totalAmount.toStringAsFixed(2)}|$effectiveCiNit|${profile.invoicePrefix}AUTHCODE";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo (only when enabled and file exists)
              if (logoImage != null) ...[
                pw.Image(logoImage, width: 80, height: 80, fit: pw.BoxFit.contain),
                pw.SizedBox(height: profile.logoSpacing),
              ],

              // Header
              pw.Text('FACTURA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('CON DERECHO A CRÉDITO FISCAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text(profile.businessName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text('SUCURSAL NO. ${profile.branchNumber}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Punto de Venta No. ${profile.posNumber}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('ZONA: ${profile.zone}, CALLE: ${profile.address.isNotEmpty ? profile.address : profile.streetNumber}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
              if (profile.phone.isNotEmpty)
                pw.Text('Teléfono: ${profile.phone}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('SANTA CRUZ', style: const pw.TextStyle(fontSize: 10)),
              
              if (profile.showNitOnInvoice && profile.nit.isNotEmpty)
                pw.Text('NIT: ${profile.nit}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              
              pw.Text('NRO. FACTURA: ${profile.invoicePrefix}-${transaction.id?.toString().padLeft(4, '0')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('CÓD. AUTORIZACIÓN: ${profile.invoicePrefix}AUTHCODE', style: const pw.TextStyle(fontSize: 10)),
              
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              
              // Customer Info
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(text: pw.TextSpan(text: 'NOMBRE/RAZÓN SOCIAL: ', style: const pw.TextStyle(fontSize: 10), children: [pw.TextSpan(text: entityName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))])),
                    pw.RichText(text: pw.TextSpan(text: 'NIT/CI: ', style: const pw.TextStyle(fontSize: 10), children: [pw.TextSpan(text: effectiveCiNit, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))])),
                    pw.RichText(text: pw.TextSpan(text: 'FECHA DE EMISIÓN: ', style: const pw.TextStyle(fontSize: 10), children: [pw.TextSpan(text: dateFormat.format(transaction.date), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))])),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),

              // Items Table
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey, width: 0.5, style: pw.BorderStyle.dashed),
                ),
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 8),
                // N7 FIX: Removed DCTO column (always 0.00) to maximize width on 80mm thermal paper
                headers: ['CANT.', 'DESCRIPCIÓN', 'P.UNIT.', 'TOTAL'],
                data: transaction.items.map((item) {
                  return [
                    '${item.quantity.toStringAsFixed(2)} ${item.saleUnit}',
                    '${item.productId} - ${item.productName}',
                    item.unitPrice.toStringAsFixed(2),
                    item.subtotal.toStringAsFixed(2),
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // C3 FIX: grossAmount = totalAmount - adjustmentAmount
                    // adjustmentAmount is negative for discounts, so this recovers pre-discount total
                    pw.Builder(builder: (context) {
                      final grossAmount = transaction.totalAmount - transaction.adjustmentAmount;
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.RichText(text: pw.TextSpan(text: 'SUBTOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), children: [pw.TextSpan(text: CurrencyHelper.simple(grossAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.normal))])),
                          if (transaction.adjustmentAmount != 0)
                            pw.RichText(text: pw.TextSpan(text: 'DESCUENTO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), children: [pw.TextSpan(text: CurrencyHelper.simple(transaction.adjustmentAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.normal))])),
                          pw.RichText(text: pw.TextSpan(text: 'TOTAL A PAGAR: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), children: [pw.TextSpan(text: CurrencyHelper.simple(transaction.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.normal))])),
                        ],
                      );
                    }),
                    
                    if (transaction is Sale) ...[
                      pw.RichText(text: pw.TextSpan(text: 'EFECTIVO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), children: [pw.TextSpan(text: CurrencyHelper.simple(transaction.amountTendered), style: pw.TextStyle(fontWeight: pw.FontWeight.normal))])),
                      pw.RichText(text: pw.TextSpan(text: 'CAMBIO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), children: [pw.TextSpan(text: CurrencyHelper.simple((transaction.amountTendered > transaction.totalAmount ? transaction.amountTendered - transaction.totalAmount : 0.0)), style: pw.TextStyle(fontWeight: pw.FontWeight.normal))])),
                    ],
                    pw.RichText(text: pw.TextSpan(text: 'IMPORTE BASE CRÉDITO FISCAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), children: [pw.TextSpan(text: CurrencyHelper.simple(transaction.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.normal))])),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Amount in words
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'SON: ${NumberToWords.toLiteral(transaction.totalAmount, currency: profile.currencyName).replaceAll('SON: ', '')}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),

              // Legal Text
              pw.Text(
                '"ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL\nPAÍS. EL USO ILÍCITO DE ÉSTA SERÁ\nSANCIONADO DE ACUERDO A LEY"',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Ley N° 453: El proveedor deberá suministrar el servicio sin discriminación, con respeto, calidez y trato cordial a los usuarios y consumidores.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Este documento es la Representación Gráfica de un Documento Fiscal Digital emitido en una modalidad de facturación en línea.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),

              pw.SizedBox(height: 12),

              // QR Code
              pw.Container(
                height: 80,
                width: 80,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrJsonString,
                  drawText: false,
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Text('Doc: FFA/000-${transaction.id?.toString().padLeft(6, '0') ?? "000000"}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('SistemaVentas - v1.0', style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
