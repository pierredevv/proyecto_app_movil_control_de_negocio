import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/inventory_provider.dart';
import '../../services/report_export_service.dart';
import '../../services/snackbar_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';

class ValuedInventoryReportScreen extends StatefulWidget {
  const ValuedInventoryReportScreen({super.key});

  @override
  State<ValuedInventoryReportScreen> createState() =>
      _ValuedInventoryReportScreenState();
}

class _ValuedInventoryReportScreenState
    extends State<ValuedInventoryReportScreen> {
  bool _isExporting = false;

  Future<void> _exportReport(bool isPdf) async {
    setState(() => _isExporting = true);
    try {
      final inventory = context.read<InventoryProvider>();
      final products =
          inventory.products.where((p) => p.stock > 0).toList()
            ..sort((a, b) {
              final valA = a.stock * (a.weightedAverageCost > 0 ? a.weightedAverageCost : (a.cost / (a.unitsPerSaleUnit > 0 ? a.unitsPerSaleUnit : 1)));
              final valB = b.stock * (b.weightedAverageCost > 0 ? b.weightedAverageCost : (b.cost / (b.unitsPerSaleUnit > 0 ? b.unitsPerSaleUnit : 1)));
              return valB.compareTo(valA);
            });
      final totalValue = products.fold(
          0.0, (sum, p) => sum + (p.stock * (p.weightedAverageCost > 0 ? p.weightedAverageCost : (p.cost / (p.unitsPerSaleUnit > 0 ? p.unitsPerSaleUnit : 1)))));

      final exportService = ReportExportService();
      final bytes = isPdf
          ? await exportService.exportInventoryReportPdf(
              products, totalValue, 'Inventario Valorado')
          : await exportService.exportInventoryReportExcel(
              products, totalValue, 'Inventario Valorado');

      final dir = await getTemporaryDirectory();
      final ext = isPdf ? 'pdf' : 'xlsx';
      final file = File('${dir.path}/inventario_valorado.$ext');
      await file.writeAsBytes(bytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Inventario Valorado',
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
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Force a UI update if the products change
    final inventory = context.watch<InventoryProvider>();
    final products = inventory.products;

    // Filter out products with 0 stock to avoid clutter, or keep them? Usually kept to be transparent, or filtered if requested. Let's keep stock > 0 for valued inventory.
    final valuedProducts = products.where((p) => p.stock > 0).toList()
      ..sort((a, b) {
        final valA = a.stock * (a.weightedAverageCost > 0 ? a.weightedAverageCost : (a.cost / (a.unitsPerSaleUnit > 0 ? a.unitsPerSaleUnit : 1)));
        final valB = b.stock * (b.weightedAverageCost > 0 ? b.weightedAverageCost : (b.cost / (b.unitsPerSaleUnit > 0 ? b.unitsPerSaleUnit : 1)));
        return valB.compareTo(valA);
      });

    final totalCapital = valuedProducts.fold(
        0.0, (sum, p) => sum + (p.stock * (p.weightedAverageCost > 0 ? p.weightedAverageCost : (p.cost / (p.unitsPerSaleUnit > 0 ? p.unitsPerSaleUnit : 1)))));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Inventario Valorado'),
        backgroundColor: theme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: _isExporting ? null : () => _exportReport(true),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Exportar Excel',
            onPressed: _isExporting ? null : () => _exportReport(false),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Summary Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Text('Capital Total Invertido',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(CurrencyHelper.simple(totalCapital),
                          style: const TextStyle(
                              color: AppTheme.blueIcon,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('${valuedProducts.length} Productos con Stock',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.54))),
                    ],
                  ),
                ),
              ),

              // List
              Expanded(
                child: valuedProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 64,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            Text(
                                'No hay productos en inventario con stock mayor a 0.',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.54))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await context.read<InventoryProvider>().loadProducts();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: valuedProducts.length,
                          itemBuilder: (context, index) {
                            final p = valuedProducts[index];
                            final value = p.stock * (p.weightedAverageCost > 0 ? p.weightedAverageCost : (p.cost / (p.unitsPerSaleUnit > 0 ? p.unitsPerSaleUnit : 1)));

                            return Card(
                              color: theme.cardColor,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                        image: (p.imagePath != null &&
                                                p.imagePath!.isNotEmpty)
                                            ? DecorationImage(
                                                image: FileImage(
                                                    File(p.imagePath!)),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (p.imagePath != null &&
                                              p.imagePath!.isNotEmpty)
                                          ? null
                                          : Center(
                                              child: Text(
                                                p.name.isNotEmpty
                                                    ? p.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name,
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text(
                                              'Stock: ${p.stock.toStringAsFixed(1)} ${p.saleUnit} | Costo WAC: ${CurrencyHelper.simple(p.weightedAverageCost)}',
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.54),
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text('Valor Total',
                                            style: TextStyle(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.54),
                                                fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(
                                            CurrencyHelper.simple(value),
                                            style: const TextStyle(
                                                color: AppTheme.blueIcon,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
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
}
