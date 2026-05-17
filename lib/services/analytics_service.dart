import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'database_service.dart';
import 'logger_service.dart';

class ProductPerformance {
  final int productId;
  final String productName;
  final double quantitySold;
  final double totalRevenue;
  final double currentStock;

  ProductPerformance({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.currentStock,
  });
}

class CustomerPerformance {
  final int customerId;
  final String customerName;
  final int totalVisits;
  final double totalSpent;

  CustomerPerformance({
    required this.customerId,
    required this.customerName,
    required this.totalVisits,
    required this.totalSpent,
  });
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Returns the top-selling products by volume.
  Future<List<ProductPerformance>> getTopSellingProducts({int limit = 10}) async {
    try {
      final db = await DatabaseService().database;
      final result = await db.rawQuery('''
        SELECT p.id, p.name, SUM(ti.quantity) as total_qty, SUM(ti.subtotal) as total_revenue, p.stock
        FROM transaction_items ti
        JOIN transactions t ON ti.transaction_id = t.id
        JOIN products p ON ti.product_id = p.id
        WHERE t.type = 'sale' AND t.status = 'COMPLETED'
        GROUP BY p.id
        ORDER BY total_qty DESC
        LIMIT ?
      ''', [limit]);

      return result.map((row) => ProductPerformance(
            productId: row['id'] as int,
            productName: row['name'] as String,
            quantitySold: (row['total_qty'] as num?)?.toDouble() ?? 0.0,
            totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
            currentStock: (row['stock'] as num?)?.toDouble() ?? 0.0,
          )).toList();
    } catch (e, stackTrace) {
      LoggerService().e('Analytics', 'Error calculating top products', e, stackTrace);
      return [];
    }
  }

  /// Returns products with the lowest sales but highest stock (Dead stock).
  Future<List<ProductPerformance>> getDeadStock({int limit = 10}) async {
    try {
      final db = await DatabaseService().database;
      final result = await db.rawQuery('''
        SELECT p.id, p.name, COALESCE(sales.total_qty, 0) as total_qty, COALESCE(sales.total_rev, 0) as total_revenue, p.stock
        FROM products p
        LEFT JOIN (
          SELECT ti.product_id, SUM(ti.quantity) as total_qty, SUM(ti.subtotal) as total_rev
          FROM transaction_items ti
          JOIN transactions t ON ti.transaction_id = t.id
          WHERE t.type = 'sale' AND t.status = 'COMPLETED'
          GROUP BY ti.product_id
        ) sales ON p.id = sales.product_id
        WHERE p.is_active = 1
        ORDER BY total_qty ASC, p.stock DESC
        LIMIT ?
      ''', [limit]);

      return result.map((row) => ProductPerformance(
            productId: row['id'] as int,
            productName: row['name'] as String,
            quantitySold: (row['total_qty'] as num?)?.toDouble() ?? 0.0,
            totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
            currentStock: (row['stock'] as num?)?.toDouble() ?? 0.0,
          )).toList();
    } catch (e, stackTrace) {
      LoggerService().e('Analytics', 'Error calculating dead stock', e, stackTrace);
      return [];
    }
  }

  /// Returns the top customers by total spent.
  Future<List<CustomerPerformance>> getTopCustomers({int limit = 10}) async {
    try {
      final db = await DatabaseService().database;
      final result = await db.rawQuery('''
        SELECT entity_id as id, entity_name as name, COUNT(id) as total_visits, SUM(total_amount) as total_spent
        FROM transactions
        WHERE type = 'sale' AND status = 'COMPLETED' AND entity_id IS NOT NULL
        GROUP BY entity_id
        ORDER BY total_spent DESC
        LIMIT ?
      ''', [limit]);

      return result.map((row) => CustomerPerformance(
            customerId: row['id'] as int,
            customerName: row['name'] as String,
            totalVisits: (row['total_visits'] as int?) ?? 0,
            totalSpent: (row['total_spent'] as num?)?.toDouble() ?? 0.0,
          )).toList();
    } catch (e, stackTrace) {
      LoggerService().e('Analytics', 'Error calculating top customers', e, stackTrace);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // EXPORT FUNCTIONS (ISOLATES)
  // ---------------------------------------------------------------------------

  /// Generates an Excel byte stream in a background isolate
  Future<Uint8List> generateExcelReport({
    required List<ProductPerformance> topProducts,
    required List<ProductPerformance> deadStock,
    required List<CustomerPerformance> topCustomers,
  }) async {
    final payload = _ReportPayload(
      topProducts: topProducts,
      deadStock: deadStock,
      topCustomers: topCustomers,
    );
    return compute(_generateExcelIsolate, payload);
  }

  /// Generates a PDF byte stream in a background isolate
  Future<Uint8List> generatePdfReport({
    required List<ProductPerformance> topProducts,
    required List<ProductPerformance> deadStock,
    required List<CustomerPerformance> topCustomers,
  }) async {
    final payload = _ReportPayload(
      topProducts: topProducts,
      deadStock: deadStock,
      topCustomers: topCustomers,
    );
    return compute(_generatePdfIsolate, payload);
  }
}

class _ReportPayload {
  final List<ProductPerformance> topProducts;
  final List<ProductPerformance> deadStock;
  final List<CustomerPerformance> topCustomers;
  _ReportPayload({
    required this.topProducts,
    required this.deadStock,
    required this.topCustomers,
  });
}

Uint8List _generateExcelIsolate(_ReportPayload payload) {
  final excel = Excel.createExcel();
  
  // 1. Top Products Sheet
  final topSheet = excel['Productos Más Vendidos'];
  topSheet.appendRow([
    TextCellValue('ID'), 
    TextCellValue('Producto'), 
    TextCellValue('Cant. Vendida'), 
    TextCellValue('Ingresos Total'), 
    TextCellValue('Stock Actual')
  ]);
  for (var p in payload.topProducts) {
    topSheet.appendRow([
      IntCellValue(p.productId),
      TextCellValue(p.productName),
      DoubleCellValue(p.quantitySold),
      DoubleCellValue(p.totalRevenue),
      DoubleCellValue(p.currentStock),
    ]);
  }

  // 2. Dead Stock Sheet
  final deadSheet = excel['Inventario Muerto'];
  deadSheet.appendRow([
    TextCellValue('ID'), 
    TextCellValue('Producto'), 
    TextCellValue('Stock Actual'), 
    TextCellValue('Cant. Vendida Histórica')
  ]);
  for (var p in payload.deadStock) {
    deadSheet.appendRow([
      IntCellValue(p.productId),
      TextCellValue(p.productName),
      DoubleCellValue(p.currentStock),
      DoubleCellValue(p.quantitySold),
    ]);
  }

  // 3. VIP Customers Sheet
  final vipSheet = excel['Clientes Frecuentes'];
  vipSheet.appendRow([
    TextCellValue('ID'), 
    TextCellValue('Cliente'), 
    TextCellValue('Total Visitas (Ventas)'), 
    TextCellValue('Total Gastado')
  ]);
  for (var c in payload.topCustomers) {
    vipSheet.appendRow([
      IntCellValue(c.customerId),
      TextCellValue(c.customerName),
      IntCellValue(c.totalVisits),
      DoubleCellValue(c.totalSpent),
    ]);
  }

  excel.delete('Sheet1'); // Remove default
  return Uint8List.fromList(excel.encode()!);
}

Future<Uint8List> _generatePdfIsolate(_ReportPayload payload) async {
  final pdf = pw.Document();

  pw.Widget buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20, bottom: 10),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text('Reporte de Análisis y Diagnóstico',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 12)),
        );
      },
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('Analítica de Negocio', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ),
        
        // 1. Top Products
        buildSectionTitle('Top 10: Productos Más Vendidos'),
        pw.TableHelper.fromTextArray(
          context: context,
          data: <List<String>>[
            <String>['Producto', 'Cant. Vendida', 'Ingresos', 'Stock'],
            ...payload.topProducts.map((p) => [
                  p.productName,
                  p.quantitySold.toStringAsFixed(2),
                  'Bs ${p.totalRevenue.toStringAsFixed(2)}',
                  p.currentStock.toStringAsFixed(2),
                ])
          ],
        ),

        // 2. VIP Customers
        buildSectionTitle('Top 10: Clientes Frecuentes (VIP)'),
        pw.TableHelper.fromTextArray(
          context: context,
          data: <List<String>>[
            <String>['Cliente', 'Total Ventas', 'Monto Gastado'],
            ...payload.topCustomers.map((c) => [
                  c.customerName,
                  c.totalVisits.toString(),
                  'Bs ${c.totalSpent.toStringAsFixed(2)}',
                ])
          ],
        ),

        // 3. Dead Stock
        buildSectionTitle('Alerta: Inventario de Lento Movimiento'),
        pw.TableHelper.fromTextArray(
          context: context,
          data: <List<String>>[
            <String>['Producto', 'Cant. Histórica Vendida', 'Stock Actual Estancado'],
            ...payload.deadStock.map((p) => [
                  p.productName,
                  p.quantitySold.toStringAsFixed(2),
                  p.currentStock.toStringAsFixed(2),
                ])
          ],
        ),
      ],
    ),
  );

  return await pdf.save();
}
