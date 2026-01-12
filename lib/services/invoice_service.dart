import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class InvoiceService {
  static Future<File> generateInvoice(Sale sale) async {
    final pdf = pw.Document();

    final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.date);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('DULCES PIERRE',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Ticket de Venta',
                    style: const pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Fecha: $date', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Cliente: ${sale.customerName ?? "Público General"}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cant.',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Producto',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              ...sale.items.map(
                (item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 20,
                        child: pw.Text('${item.quantity}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Expanded(
                        child: pw.Text(item.productName,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Text(item.subtotal.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Bs. ${sale.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
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

    return _saveDocument(name: 'ticket_${sale.id}.pdf', pdf: pdf);
  }

  static Future<File> _saveDocument({
    required String name,
    required pw.Document pdf,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
