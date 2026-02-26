import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/import_provider.dart';
import '../../theme/app_theme.dart';
import 'import_preview_screen.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final importProvider = context.watch<ImportProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: const Text('Importar Productos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono gigante decorativo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 60,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Título principal
                  const Text(
                    'Subir Archivo de Inventario',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Subtítulo explicativo
                  const Text(
                    'Selecciona un archivo Excel (.xlsx, .xls) o CSV con tu lista de productos. El sistema detectará automáticamente las columnas comunes (Nombre, Código, Precio, Stock, Medida).',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFFA0A8C1), // Slate 400
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Manejo de Estados
                  if (importProvider.step == ImportStep.parsing)
                    const Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text('Leyendo archivo...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  else if (importProvider.step == ImportStep.error)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            importProvider.errorMessage ?? 'Error desconocido',
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => importProvider.reset(),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white12),
                            child: const Text('Reintentar',
                                style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    )
                  else
                    // Botón principal
                    _buildUploadButton(context, importProvider),

                  const SizedBox(height: 32),

                  // Tips
                  _buildTipsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(BuildContext context, ImportProvider provider) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)], // Azul moderno
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await provider.pickAndParseFile();
            if (provider.step == ImportStep.preview && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportPreviewScreen()),
              );
            }
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Seleccionar Archivo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF), // White 10%
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)), // White 5%
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Consejos:',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipRow(
              'La primera fila debe contener los nombres de las columnas.'),
          _buildTipRow('Solo la columna "Nombre" es obligatoria.'),
          _buildTipRow(
              'Multiplicadores como "24x300" en "Medida" se detectan solos.'),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, right: 8),
            child: Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Color(0xFFA0A8C1), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
