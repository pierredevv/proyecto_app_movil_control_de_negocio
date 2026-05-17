import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/import_provider.dart';
import '../../theme/app_theme.dart';
import 'import_preview_screen.dart';

class ImportMappingScreen extends StatefulWidget {
  const ImportMappingScreen({super.key});

  @override
  State<ImportMappingScreen> createState() => _ImportMappingScreenState();
}

class _ImportMappingScreenState extends State<ImportMappingScreen> {
  final Map<String, String?> _currentMapping = {};

  static const Map<String, String> _systemFields = {
    'name': 'Nombre del Producto (*)',
    'barcode': 'Código de Barras / SKU',
    'cost': 'Precio de Costo',
    'price': 'Precio de Venta',
    'stock': 'Stock Inicial',
    'category': 'Categoría',
    'saleUnit': 'Tipo de Unidad (Caja, etc)',
    'unitsPerPkg': 'Cantidad por Paquete',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final result = context.read<ImportProvider>().parseResult;
      if (result != null) {
        setState(() {
          for (final key in _systemFields.keys) {
            _currentMapping[key] = result.columnMapping[key];
          }
        });
      }
    });
  }

  Future<void> _applyAndContinue() async {
    final provider = context.read<ImportProvider>();
    final result = provider.parseResult;
    if (result == null) return;

    if (_currentMapping['name'] == null || _currentMapping['name']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe asignar una columna para el Nombre del Producto')),
      );
      return;
    }

    final Map<String, int> explicitMapping = {};
    for (final entry in _currentMapping.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        final idx = result.rawHeaders.indexOf(entry.value!);
        if (idx != -1) {
          explicitMapping[entry.key] = idx;
        }
      }
    }

    await provider.applyMappingAndPreview(explicitMapping);

    if (provider.step == ImportStep.preview && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ImportPreviewScreen()),
      );
    } else if (provider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ImportProvider>();
    final result = provider.parseResult;

    if (result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final rawHeaders = result.rawHeaders.where((h) => h.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Mapeo de Columnas', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: const Text(
              'Hemos detectado las siguientes columnas en tu archivo. '
              'Verifica y ajusta a qué campo del sistema corresponde cada una.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _systemFields.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final key = _systemFields.keys.elementAt(index);
                final label = _systemFields[key]!;
                final isRequired = key == 'name';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRequired && _currentMapping[key] == null
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isRequired ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF1E293B),
                            value: rawHeaders.contains(_currentMapping[key])
                                ? _currentMapping[key]
                                : null,
                            hint: const Text('No asignar (Omitir)', style: TextStyle(color: Colors.white38)),
                            style: const TextStyle(color: Colors.white),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No asignar (Omitir)', style: TextStyle(color: Colors.white54)),
                              ),
                              ...rawHeaders.map((header) {
                                return DropdownMenuItem<String>(
                                  value: header,
                                  child: Text(header),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _currentMapping[key] = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración Regional (Precios)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool?>(
                        title: const Text('Auto-Detectar', style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: null,
                        // ignore: deprecated_member_use
                        groupValue: provider.useCommaAsDecimal,
                        // ignore: deprecated_member_use
                        onChanged: (val) => provider.setUseCommaAsDecimal(val),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primary,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool?>(
                        title: const Text('Punto (1.000.50)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: false,
                        // ignore: deprecated_member_use
                        groupValue: provider.useCommaAsDecimal,
                        // ignore: deprecated_member_use
                        onChanged: (val) => provider.setUseCommaAsDecimal(val),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primary,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool?>(
                        title: const Text('Coma (1.000,50)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: true,
                        // ignore: deprecated_member_use
                        groupValue: provider.useCommaAsDecimal,
                        // ignore: deprecated_member_use
                        onChanged: (val) => provider.setUseCommaAsDecimal(val),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: provider.step == ImportStep.parsing ? null : _applyAndContinue,
                child: provider.step == ImportStep.parsing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continuar a la Vista Previa',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
