import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/import_provider.dart';
import '../../models/import_result.dart';
import '../../theme/app_theme.dart';

class ImportPreviewScreen extends StatelessWidget {
  const ImportPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final importProvider = context.watch<ImportProvider>();
    final result = importProvider.parseResult;

    // Safety check - shouldn't happen if routing is correct
    if (result == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
            child: Text('No hay datos parseados.',
                style: TextStyle(color: Colors.white))),
      );
    }

    final totalRows = result.rows.length;
    final selectedCount = totalRows - importProvider.deselectedRows.length;
    final isInserting = importProvider.step == ImportStep.inserting;
    final isDone = importProvider.step == ImportStep.done;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Vista Previa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isDone
          ? _buildSuccessView(context, importProvider)
          : Column(
              children: [
                // Info Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E293B), // Slate 800
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat(
                          'Filas Válidas', '\$totalRows', Colors.white),
                      _buildHeaderStat(
                          'A Importar', '\$selectedCount', AppTheme.primary),
                      if (result.errors.isNotEmpty)
                        _buildHeaderStat('Errores', '${result.errors.length}',
                            Colors.redAccent),
                    ],
                  ),
                ),

                // Lista de Productos
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: totalRows,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final row = result.rows[index];
                      final isSelected = importProvider.isRowSelected(index);
                      return _buildProductRow(
                          context, row, index, isSelected, importProvider);
                    },
                  ),
                ),

                // Bottom Bar Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: SafeArea(
                    child: isInserting
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary))
                        : Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.05),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancelar',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: selectedCount > 0
                                      ? () => importProvider.confirmImport()
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: AppTheme.primary,
                                    disabledBackgroundColor:
                                        Colors.grey.withValues(alpha: 0.3),
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(12))),
                                  ),
                                  child: const Text(
                                    'Importar \$selectedCount',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductRow(BuildContext context, ProductImportRow row, int index,
      bool isSelected, ImportProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.5)
              : const Color(0x1AFFFFFF),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) => provider.toggleRowSelection(index),
            activeColor: AppTheme.primary,
            checkColor: Colors.white,
            title: Text(
              row.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                decoration: isSelected
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildChip(
                          row.barcode.isEmpty ? 'Sin código' : row.barcode,
                          const Color(0xFF6B7494)),
                      const SizedBox(width: 8),
                      _buildChip('Bs. ${row.price.toStringAsFixed(2)}',
                          const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Conversión Stock View
                  if (row.unitsPerSaleUnit > 1)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Se multiplicará x${row.unitsPerSaleUnit.toStringAsFixed(0)} (Empaque: ${row.packagingInfo}) → Total: ${row.stockBase.toStringAsFixed(0)} unid base',
                              style: const TextStyle(
                                  color: Color(0xFFF59E0B), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Stock Base: ${row.stockBase.toStringAsFixed(0)} ${row.saleUnit}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context, ImportProvider provider) {
    final stats =
        provider.insertResult ?? {'inserted': 0, 'updated': 0, 'errors': 0};

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF10B981), size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Importación Completada!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildStatRow('Nuevos Agregados',
                      stats['inserted'].toString(), const Color(0xFF10B981)),
                  const Divider(color: Colors.white10, height: 24),
                  _buildStatRow('Existentes Actualizados',
                      stats['updated'].toString(), const Color(0xFF4A90E2)),
                  if ((stats['errors'] ?? 0) > 0) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildStatRow('Errores (Omitidos)',
                        stats['errors'].toString(), Colors.redAccent),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  provider.reset();
                  // Regresa al primer tab/pantalla principal
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Ir al Inventario',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        Text(val,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
