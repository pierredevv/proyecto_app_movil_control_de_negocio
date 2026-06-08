import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../utils/currency_helper.dart';

// ---------------------------------------------------------------------------
// DATA TRANSFER OBJECTS (passed to isolates — no DB handles)
// ---------------------------------------------------------------------------

class SalesReportData {
  final DateTime startDate;
  final DateTime endDate;
  final String businessName;
  final Map<String, dynamic> metrics; // from getSalesReportByDateRange
  final List<Map<String, dynamic>> transactions; // simplified sale list

  SalesReportData({
    required this.startDate,
    required this.endDate,
    required this.businessName,
    required this.metrics,
    this.transactions = const [],
  });
}

class InventoryReportData {
  final String businessName;
  final List<InventoryItem> items;
  final double totalValue;

  InventoryReportData({
    required this.businessName,
    required this.items,
    required this.totalValue,
  });
}

class InventoryItem {
  final String name;
  final String category;
  final double stock;
  final String saleUnit;
  final double wac;
  final double value;

  InventoryItem({
    required this.name,
    required this.category,
    required this.stock,
    required this.saleUnit,
    required this.wac,
    required this.value,
  });
}

class AgingReportData {
  final String businessName;
  final String entityType; // 'CUSTOMER' or 'SUPPLIER'
  final List<Map<String, dynamic>> report;
  final double totalPending;

  AgingReportData({
    required this.businessName,
    required this.entityType,
    required this.report,
    required this.totalPending,
  });
}

class CashRegisterCloseData {
  final String businessName;
  final DateTime openDate;
  final DateTime closeDate;
  final double openingBalance;
  final double closingBalance;
  final double expectedBalance;
  final double difference;
  final Map<String, dynamic> cashSummary;
  final String? notes;

  CashRegisterCloseData({
    required this.businessName,
    required this.openDate,
    required this.closeDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.expectedBalance,
    required this.difference,
    required this.cashSummary,
    this.notes,
  });
}

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

class ReportExportService {
  static final ReportExportService _instance = ReportExportService._internal();
  factory ReportExportService() => _instance;
  ReportExportService._internal();

  // ── SALES REPORT ──────────────────────────────────────────────────────────

  Future<Uint8List> exportSalesReportPdf(SalesReportData data) async {
    return compute(_generateSalesPdfIsolate, data);
  }

  Future<Uint8List> exportSalesReportExcel(SalesReportData data) async {
    return compute(_generateSalesExcelIsolate, data);
  }

  // ── INVENTORY REPORT ──────────────────────────────────────────────────────

  Future<Uint8List> exportInventoryReportPdf(
      List<Product> products, double totalValue, String businessName) async {
    final items = products
        .map((p) {
          final effectiveWac = p.weightedAverageCost > 0
              ? p.weightedAverageCost
              : p.cost / (p.unitsPerSaleUnit > 0 ? p.unitsPerSaleUnit : 1);
          return InventoryItem(
            name: p.name,
            category: '', // Category name to be resolved by caller if needed
            stock: p.stock,
            saleUnit: p.saleUnit,
            wac: effectiveWac,
            value: p.stock * effectiveWac,
          );
        })
        .toList();
    final data = InventoryReportData(
        businessName: businessName, items: items, totalValue: totalValue);
    return compute(_generateInventoryPdfIsolate, data);
  }

  Future<Uint8List> exportInventoryReportExcel(
      List<Product> products, double totalValue, String businessName) async {
    final items = products
        .map((p) {
          final effectiveWac = p.weightedAverageCost > 0
              ? p.weightedAverageCost
              : p.cost / (p.unitsPerSaleUnit > 0 ? p.unitsPerSaleUnit : 1);
          return InventoryItem(
            name: p.name,
            category: '',
            stock: p.stock,
            saleUnit: p.saleUnit,
            wac: effectiveWac,
            value: p.stock * effectiveWac,
          );
        })
        .toList();
    final data = InventoryReportData(
        businessName: businessName, items: items, totalValue: totalValue);
    return compute(_generateInventoryExcelIsolate, data);
  }

  // ── AGING REPORT ──────────────────────────────────────────────────────────

  Future<Uint8List> exportAgingReportPdf(AgingReportData data) async {
    return compute(_generateAgingPdfIsolate, data);
  }

  Future<Uint8List> exportAgingReportExcel(AgingReportData data) async {
    return compute(_generateAgingExcelIsolate, data);
  }

  // ── CASH REGISTER CLOSE ───────────────────────────────────────────────────

  Future<Uint8List> exportCashRegisterClosePdf(
      CashRegisterCloseData data) async {
    return compute(_generateCashClosePdfIsolate, data);
  }
}

// ===========================================================================
// ISOLATE FUNCTIONS (top-level — cannot access class state)
// ===========================================================================

final _fmt = CurrencyHelper.formatter;
final _dateFmt = DateFormat('dd/MM/yyyy');
final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

// ── SALES PDF ───────────────────────────────────────────────────────────────

Future<Uint8List> _generateSalesPdfIsolate(SalesReportData data) async {
  final pdf = pw.Document();
  final m = data.metrics;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (ctx) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(data.businessName,
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              '${_dateFmt.format(data.startDate)} — ${_dateFmt.format(data.endDate)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ]),
        pw.Divider(),
        pw.SizedBox(height: 8),
      ]),
      build: (ctx) => [
        pw.Header(
            level: 0,
            child: pw.Text('Reporte de Ventas por Período',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold))),

        // Summary metrics
        pw.Row(children: [
          _pdfMetricBox('Total Ventas', _fmt.format(m['total_sales'] ?? 0)),
          _pdfMetricBox('Transacciones', '${m['transaction_count'] ?? 0}'),
          _pdfMetricBox('Ticket Promedio', _fmt.format(m['avg_ticket'] ?? 0)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _pdfMetricBox('Ganancia Bruta', _fmt.format(m['gross_profit'] ?? 0)),
          _pdfMetricBox(
              'Margen Bruto',
              '${(m['gross_margin_pct'] as num? ?? 0).toStringAsFixed(1)}%'),
          _pdfMetricBox('Productos Vendidos',
              '${(m['total_sale_units_sold'] as num? ?? 0).toStringAsFixed(0)} uds'),
        ]),
        pw.SizedBox(height: 16),

        // Unit breakdown
        if ((m['unit_breakdown'] as List?)?.isNotEmpty == true) ...[
          pw.Text('Desglose por Unidad de Venta',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            context: ctx,
            data: <List<String>>[
              ['Tipo', 'Cantidad'],
              ...(m['unit_breakdown'] as List).map((u) => [
                    u['sale_unit']?.toString() ?? 'UNI',
                    (u['quantity'] as num?)?.toStringAsFixed(2) ?? '0',
                  ]),
            ],
          ),
          pw.SizedBox(height: 16),
        ],

        // Top products
        if ((m['top_products'] as List?)?.isNotEmpty == true) ...[
          pw.Text('Top 5 Productos',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            context: ctx,
            data: <List<String>>[
              ['Producto', 'Cantidad', 'Ingresos'],
              ...(m['top_products'] as List).map((p) => [
                    p['product_name']?.toString() ?? '',
                    '${(p['total_qty'] as num?)?.toStringAsFixed(2) ?? '0'} ${p['sale_unit'] ?? ''}',
                    _fmt.format(p['total_revenue'] ?? 0),
                  ]),
            ],
          ),
        ],

        // Transaction list
        if (data.transactions.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Detalle de Transacciones',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            context: ctx,
            headerStyle:
                pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            data: <List<String>>[
              ['#', 'Fecha', 'Cliente', 'Total', 'Estado'],
              ...data.transactions.map((t) => [
                    '${t['id'] ?? ''}',
                    t['date'] ?? '',
                    t['customer'] ?? 'Ocasional',
                    _fmt.format(t['total'] ?? 0),
                    t['status'] ?? '',
                  ]),
            ],
          ),
        ],
      ],
    ),
  );

  return pdf.save();
}

pw.Expanded _pdfMetricBox(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(right: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
}

// ── SALES EXCEL ─────────────────────────────────────────────────────────────

Uint8List _generateSalesExcelIsolate(SalesReportData data) {
  final excel = Excel.createExcel();
  final m = data.metrics;

  // Sheet 1: Summary
  final summary = excel['Resumen'];
  summary.appendRow([TextCellValue('Reporte de Ventas')]);
  summary.appendRow([
    TextCellValue('Período'),
    TextCellValue(
        '${_dateFmt.format(data.startDate)} — ${_dateFmt.format(data.endDate)}')
  ]);
  summary.appendRow([TextCellValue('')]);
  summary.appendRow([
    TextCellValue('Métrica'),
    TextCellValue('Valor')
  ]);
  summary.appendRow([
    TextCellValue('Total Ventas'),
    DoubleCellValue((m['total_sales'] as num?)?.toDouble() ?? 0)
  ]);
  summary.appendRow([
    TextCellValue('Transacciones'),
    IntCellValue((m['transaction_count'] as int?) ?? 0)
  ]);
  summary.appendRow([
    TextCellValue('Ticket Promedio'),
    DoubleCellValue((m['avg_ticket'] as num?)?.toDouble() ?? 0)
  ]);
  summary.appendRow([
    TextCellValue('COGS'),
    DoubleCellValue((m['total_cogs'] as num?)?.toDouble() ?? 0)
  ]);
  summary.appendRow([
    TextCellValue('Ganancia Bruta'),
    DoubleCellValue((m['gross_profit'] as num?)?.toDouble() ?? 0)
  ]);
  summary.appendRow([
    TextCellValue('Margen Bruto %'),
    DoubleCellValue((m['gross_margin_pct'] as num?)?.toDouble() ?? 0)
  ]);

  // Sheet 2: Top Products
  final prodSheet = excel['Top Productos'];
  prodSheet.appendRow([
    TextCellValue('Producto'),
    TextCellValue('Cantidad'),
    TextCellValue('Unidad'),
    TextCellValue('Ingresos')
  ]);
  for (var p in (m['top_products'] as List? ?? [])) {
    prodSheet.appendRow([
      TextCellValue(p['product_name']?.toString() ?? ''),
      DoubleCellValue((p['total_qty'] as num?)?.toDouble() ?? 0),
      TextCellValue(p['sale_unit']?.toString() ?? 'UNI'),
      DoubleCellValue((p['total_revenue'] as num?)?.toDouble() ?? 0),
    ]);
  }

  // Sheet 3: Transaction detail
  if (data.transactions.isNotEmpty) {
    final detailSheet = excel['Detalle'];
    detailSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Fecha'),
      TextCellValue('Cliente'),
      TextCellValue('Total'),
      TextCellValue('Estado')
    ]);
    for (var t in data.transactions) {
      detailSheet.appendRow([
        IntCellValue(t['id'] as int? ?? 0),
        TextCellValue(t['date']?.toString() ?? ''),
        TextCellValue(t['customer']?.toString() ?? 'Ocasional'),
        DoubleCellValue((t['total'] as num?)?.toDouble() ?? 0),
        TextCellValue(t['status']?.toString() ?? ''),
      ]);
    }
  }

  excel.delete('Sheet1');
  return Uint8List.fromList(excel.encode()!);
}

// ── INVENTORY PDF ───────────────────────────────────────────────────────────

Future<Uint8List> _generateInventoryPdfIsolate(
    InventoryReportData data) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (ctx) => pw.Column(children: [
        pw.Text(data.businessName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
      ]),
      build: (ctx) => [
        pw.Header(
            level: 0,
            child: pw.Text('Inventario Valorado',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold))),
        pw.Text('Capital Total: ${_fmt.format(data.totalValue)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text('${data.items.length} productos con stock'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          context: ctx,
          headerStyle:
              pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          data: <List<String>>[
            ['Producto', 'Stock', 'WAC', 'Valor Total'],
            ...data.items.map((i) => [
                  i.name,
                  '${i.stock.toStringAsFixed(1)} ${i.saleUnit}',
                  _fmt.format(i.wac),
                  _fmt.format(i.value),
                ]),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

// ── INVENTORY EXCEL ─────────────────────────────────────────────────────────

Uint8List _generateInventoryExcelIsolate(InventoryReportData data) {
  final excel = Excel.createExcel();
  final sheet = excel['Inventario Valorado'];
  sheet.appendRow([
    TextCellValue('Producto'),
    TextCellValue('Stock'),
    TextCellValue('Unidad'),
    TextCellValue('Costo WAC'),
    TextCellValue('Valor Total')
  ]);
  for (var i in data.items) {
    sheet.appendRow([
      TextCellValue(i.name),
      DoubleCellValue(i.stock),
      TextCellValue(i.saleUnit),
      DoubleCellValue(i.wac),
      DoubleCellValue(i.value),
    ]);
  }
  // Total row
  sheet.appendRow([
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue('TOTAL'),
    DoubleCellValue(data.totalValue),
  ]);
  excel.delete('Sheet1');
  return Uint8List.fromList(excel.encode()!);
}

// ── AGING PDF ───────────────────────────────────────────────────────────────

Future<Uint8List> _generateAgingPdfIsolate(AgingReportData data) async {
  final pdf = pw.Document();
  final isCustomer = data.entityType == 'CUSTOMER';
  final title =
      isCustomer ? 'Antigüedad de Deuda — Clientes' : 'Antigüedad de Deuda — Proveedores';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (ctx) => pw.Column(children: [
        pw.Text(data.businessName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
      ]),
      build: (ctx) => [
        pw.Header(
            level: 0,
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold))),
        pw.Text('Total Pendiente: ${_fmt.format(data.totalPending)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          context: ctx,
          data: <List<String>>[
            [isCustomer ? 'Cliente' : 'Proveedor', '0-30 días', '31-60 días', '+60 días', 'Total'],
            ...data.report.map((r) => [
                  r['entity_name']?.toString() ?? '',
                  _fmt.format((r['current'] as num?)?.toDouble() ?? 0),
                  _fmt.format((r['days_30_60'] as num?)?.toDouble() ?? 0),
                  _fmt.format((r['days_60_plus'] as num?)?.toDouble() ?? 0),
                  _fmt.format((r['total'] as num?)?.toDouble() ?? 0),
                ]),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

// ── AGING EXCEL ─────────────────────────────────────────────────────────────

Uint8List _generateAgingExcelIsolate(AgingReportData data) {
  final excel = Excel.createExcel();
  final isCustomer = data.entityType == 'CUSTOMER';
  final sheet = excel[isCustomer ? 'Clientes' : 'Proveedores'];
  sheet.appendRow([
    TextCellValue(isCustomer ? 'Cliente' : 'Proveedor'),
    TextCellValue('0-30 días'),
    TextCellValue('31-60 días'),
    TextCellValue('+60 días'),
    TextCellValue('Total')
  ]);
  for (var r in data.report) {
    sheet.appendRow([
      TextCellValue(r['entity_name']?.toString() ?? ''),
      DoubleCellValue((r['current'] as num?)?.toDouble() ?? 0),
      DoubleCellValue((r['days_30_60'] as num?)?.toDouble() ?? 0),
      DoubleCellValue((r['days_60_plus'] as num?)?.toDouble() ?? 0),
      DoubleCellValue((r['total'] as num?)?.toDouble() ?? 0),
    ]);
  }
  excel.delete('Sheet1');
  return Uint8List.fromList(excel.encode()!);
}

// ── CASH REGISTER CLOSE PDF ─────────────────────────────────────────────────

Future<Uint8List> _generateCashClosePdfIsolate(
    CashRegisterCloseData data) async {
  final pdf = pw.Document();
  final cs = data.cashSummary;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(data.businessName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(
              child: pw.Text('ARQUEO DE CAJA',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            _cashRow('Apertura:', _dateTimeFmt.format(data.openDate)),
            _cashRow('Cierre:', _dateTimeFmt.format(data.closeDate)),
            pw.Divider(),
            pw.SizedBox(height: 12),

            pw.Text('INGRESOS EN EFECTIVO',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _cashRow('Ventas de mostrador (cash):',
                _fmt.format(cs['cash_in_sales'] ?? 0)),
            _cashRow('Cobros a clientes:',
                _fmt.format(cs['cash_in_payments'] ?? 0)),
            _cashRow('Total Ingresos:',
                _fmt.format(cs['total_cash_in'] ?? 0),
                bold: true),

            pw.SizedBox(height: 12),
            pw.Text('EGRESOS EN EFECTIVO',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _cashRow(
                'Gastos:', _fmt.format(cs['cash_out_expenses'] ?? 0)),
            _cashRow('Pagos a proveedores:',
                _fmt.format(cs['cash_out_supplier_payments'] ?? 0)),
            _cashRow('Compras (cash):',
                _fmt.format(cs['cash_out_purchases'] ?? 0)),
            _cashRow('Total Egresos:',
                _fmt.format(cs['total_cash_out'] ?? 0),
                bold: true),

            pw.Divider(thickness: 2),
            pw.SizedBox(height: 12),
            _cashRow('Fondo Inicial:',
                _fmt.format(data.openingBalance)),
            _cashRow('Efectivo Esperado:',
                _fmt.format(data.expectedBalance),
                bold: true),
            _cashRow('Efectivo Contado:',
                _fmt.format(data.closingBalance),
                bold: true),
            pw.SizedBox(height: 8),
            _cashRow(
                data.difference >= 0 ? 'SOBRANTE:' : 'FALTANTE:',
                _fmt.format(data.difference.abs()),
                bold: true),

            if (data.notes != null && data.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Observaciones: ${data.notes}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('Ventas totales (devengado): ${_fmt.format(cs['accrual_sales_total'] ?? 0)} (${cs['accrual_sales_count'] ?? 0} transacciones)',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey)),

            pw.Spacer(),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(
                        width: 150, child: pw.Divider(thickness: 0.5)),
                    pw.Text('Firma Cajero',
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
                  pw.Column(children: [
                    pw.Container(
                        width: 150, child: pw.Divider(thickness: 0.5)),
                    pw.Text('Firma Supervisor',
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
                ]),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _cashRow(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    ),
  );
}
