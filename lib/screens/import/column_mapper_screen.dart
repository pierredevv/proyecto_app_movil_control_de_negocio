import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'import_preview_screen.dart';

/// Note: In a fully robust system, if `detectColumns` fails (missing 'name'),
/// we would route the user here instead of throwing an Exception.
/// This screen allows manual mapping of headers.
/// For this implementation phase, it acts as a placeholder/future enhancement
/// to explicitly define un-detected mappings visually.
class ColumnMapperScreen extends StatefulWidget {
  final List<String> availableHeaders;

  const ColumnMapperScreen({
    super.key,
    required this.availableHeaders,
  });

  @override
  State<ColumnMapperScreen> createState() => _ColumnMapperScreenState();
}

class _ColumnMapperScreenState extends State<ColumnMapperScreen> {
  // Required mapping: name
  String? selectedNameCol;
  String? selectedBarcodeCol;
  String? selectedPriceCol;
  String? selectedCostCol;
  String? selectedStockCol;
  String? selectedCategoryCol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Mapear Columnas',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No pudimos detectar automáticamente algunas columnas importantes. Por favor selecciona a qué columna corresponde cada dato.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildMappingRow('Nombre del Producto *', selectedNameCol,
                        (v) => setState(() => selectedNameCol = v)),
                    _buildMappingRow('Código de Barras', selectedBarcodeCol,
                        (v) => setState(() => selectedBarcodeCol = v)),
                    _buildMappingRow('Precio Venta', selectedPriceCol,
                        (v) => setState(() => selectedPriceCol = v)),
                    _buildMappingRow('Precio Costo', selectedCostCol,
                        (v) => setState(() => selectedCostCol = v)),
                    _buildMappingRow('Stock', selectedStockCol,
                        (v) => setState(() => selectedStockCol = v)),
                    _buildMappingRow('Categoría', selectedCategoryCol,
                        (v) => setState(() => selectedCategoryCol = v)),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedNameCol != null
                      ? () {
                          // Logic to re-process explicitly matching columns overrides.
                          // Provider mapping ...
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ImportPreviewScreen()),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continuar a Vista Previa',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMappingRow(
      String label, String? currentValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                hint: const Text('Omitir',
                    style: TextStyle(color: Colors.white38)),
                dropdownColor: const Color(0xFF1E293B),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('Omitir',
                          style: TextStyle(color: Colors.white38))),
                  ...widget.availableHeaders
                      .map((h) => DropdownMenuItem(value: h, child: Text(h))),
                ],
                onChanged: onChanged,
              ),
            ),
          )
        ],
      ),
    );
  }
}
