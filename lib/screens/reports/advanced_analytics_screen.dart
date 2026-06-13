import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/analytics_service.dart';
import '../../services/snackbar_service.dart';
import '../../utils/currency_helper.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  bool _isLoading = true;
  bool _isExporting = false;

  List<ProductPerformance> _topProducts = [];
  List<ProductPerformance> _deadStock = [];
  List<CustomerPerformance> _topCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final analytics = AnalyticsService();
    // Run these concurrently since they don't block the UI heavily (SQLite native thread)
    final results = await Future.wait([
      analytics.getTopSellingProducts(limit: 15),
      analytics.getDeadStock(limit: 15),
      analytics.getTopCustomers(limit: 15),
    ]);

    if (mounted) {
      setState(() {
        _topProducts = results[0] as List<ProductPerformance>;
        _deadStock = results[1] as List<ProductPerformance>;
        _topCustomers = results[2] as List<CustomerPerformance>;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportData(bool isPdf) async {
    setState(() => _isExporting = true);
    try {
      final analytics = AnalyticsService();
      final bytes = isPdf
          ? await analytics.generatePdfReport(
              topProducts: _topProducts,
              deadStock: _deadStock,
              topCustomers: _topCustomers,
            )
          : await analytics.generateExcelReport(
              topProducts: _topProducts,
              deadStock: _deadStock,
              topCustomers: _topCustomers,
            );

      final dir = await getTemporaryDirectory();
      final fileExt = isPdf ? 'pdf' : 'xlsx';
      final file = File('${dir.path}/analitica_negocio.$fileExt');
      await file.writeAsBytes(bytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        // ignore: deprecated_member_use
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Reporte de Analítica de Negocio',
            sharePositionOrigin: box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.showError('Error al exportar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analítica Avanzada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: _isLoading || _isExporting ? null : () => _exportData(true),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Exportar Excel',
            onPressed: _isLoading || _isExporting ? null : () => _exportData(false),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionHeader('🏆 Top Productos Más Vendidos', Colors.amber),
                    ..._topProducts.map((p) => _buildGlassCard(
                          child: ListTile(
                            title: Text(p.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text('Cant: ${p.displayQuantitySold.toStringAsFixed(0)} ${p.saleUnit} | Ingresos: ${CurrencyHelper.simple(p.totalRevenue)}', style: const TextStyle(color: Colors.white70)),
                            trailing: Text('Stock: ${p.displayCurrentStock.toStringAsFixed(0)} ${p.saleUnit}', style: const TextStyle(color: Colors.amber)),
                          ),
                        )),
                    if (_topProducts.isEmpty) const Text('No hay datos suficientes.', style: TextStyle(color: Colors.white70)),

                    const SizedBox(height: 24),
                    _buildSectionHeader('👑 Clientes VIP (Más Frecuentes)', Colors.blue),
                    ..._topCustomers.map((c) => _buildGlassCard(
                          child: ListTile(
                            title: Text(c.customerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text('Total Ventas: ${c.totalVisits}', style: const TextStyle(color: Colors.white70)),
                            trailing: Text('Gasto Total:\n${CurrencyHelper.simple(c.totalSpent)}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.blue)),
                          ),
                        )),
                    if (_topCustomers.isEmpty) const Text('No hay datos suficientes.', style: TextStyle(color: Colors.white70)),

                    const SizedBox(height: 24),
                    _buildSectionHeader('⚠️ Inventario Estancado (Baja rotación)', Colors.red),
                    ..._deadStock.map((p) => _buildGlassCard(
                          borderColor: Colors.red.withValues(alpha: 0.5),
                          child: ListTile(
                            title: Text(p.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            subtitle: Text('Cant. Histórica Vendida: ${p.displayQuantitySold.toStringAsFixed(0)} ${p.saleUnit}', style: const TextStyle(color: Colors.white70)),
                            trailing: Text('Stock Atrapado:\n${p.displayCurrentStock.toStringAsFixed(0)} ${p.saleUnit}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        )),
                    if (_deadStock.isEmpty) const Text('¡Excelente! No hay inventario estancado.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                if (_isExporting)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Generando reporte...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}
