import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction_model.dart';

class PdfGeneratorService {
  Future<Uint8List> generateInvoice(Sale sale) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
        symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_BO');

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
                child: pw.Text('MI NEGOCIO',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ),
              pw.Center(child: pw.Text('NIT: 123456789')),
              pw.Center(child: pw.Text('Dirección: Av. Principal #123')),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Sale Info
              pw.Text('Nro. Venta: #${sale.id}'),
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
              pw.Center(
                  child: pw.Text('¡Gracias por su compra!',
                      style: const pw.TextStyle(fontSize: 10))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
