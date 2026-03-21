import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../models/transaction_model.dart';
import '../models/business_profile.dart';

class PdfGeneratorService {
  Future<Uint8List> generateInvoice(Sale sale, BusinessProfile profile) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
        symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_BO');

    pw.ImageProvider? logoImage;
    if (profile.showLogoOnInvoice &&
        profile.logoPath != null &&
        profile.logoPath!.isNotEmpty) {
      final file = File(profile.logoPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10), // Small margin for thermal paper
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        height: 50,
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Image(logoImage),
                      ),
                    pw.Text(
                      profile.businessName.toUpperCase(),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 16),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text('SUCURSAL NO. ${profile.branchNumber}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Punto de Venta No. ${profile.posNumber}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('ZONA: ${profile.zone}, ${profile.address.isNotEmpty ? profile.address : profile.streetNumber}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(profile.city.toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10)),
                    if (profile.phone.isNotEmpty)
                      pw.Text('Teléfono: ${profile.phone}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 10)),
                    if (profile.showNitOnInvoice && profile.nit.isNotEmpty)
                      pw.Text('NIT: ${profile.nit}',
                          textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Sale Info
              pw.Text(
                  'Nro. Venta: ${profile.invoicePrefix}-${sale.id?.toString().padLeft(4, '0')}'),
              pw.Text('Fecha: ${dateFormat.format(sale.date)}'),
              pw.Text('Cliente: ${sale.customerName ?? "Cliente Ocasional"}'),
              pw.Divider(),

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                      child: pw.Text('Prod.',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Text('Cant.',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 4),
                      child: pw.Text('Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items
              ...sale.items.map((item) {
                return pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName,
                              style: const pw.TextStyle(fontSize: 10)),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  '${item.quantity} ${item.saleUnit} x ${item.unitPrice.toStringAsFixed(2)}'),
                              pw.Text(item.subtotal.toStringAsFixed(2)),
                            ],
                          )
                        ]));
              }),

              pw.Divider(),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(currencyFormat.format(sale.totalAmount),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),

              pw.SizedBox(height: 20),
              if (profile.invoiceFooter.isNotEmpty)
                pw.Center(
                    child: pw.Text(profile.invoiceFooter,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
