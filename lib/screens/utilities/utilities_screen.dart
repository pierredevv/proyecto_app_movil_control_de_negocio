import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../backup_manager_screen.dart';
import 'notepad_screen.dart';
import 'margin_calculator_screen.dart';
import 'invoice_list_screen.dart';

class UtilitiesScreen extends StatelessWidget {
  const UtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Utilidades',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HERRAMIENTAS',
                  style: TextStyle(
                    color: Color(0xFF6B7494),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '6 Utilidades Disponibles',
                  style: TextStyle(
                    color: Color(0xFFA0A8C1),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _buildUtilityCard(
            context,
            title: 'Gestión de Respaldos',
            subtitle: 'Importar y exportar base de datos',
            icon: Icons.cloud_upload,
            color: const Color(0xFF4A90E2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupManagerScreen()),
              );
            },
          ),
          _buildUtilityCard(
            context,
            title: 'Calculadora de Margen',
            subtitle:
                'Ingresa costo y precio de venta, calcula margen automáticamente, porcentaje, ganancia neta y precio sugerido.',
            icon: Icons.calculate,
            color: const Color(0xFFF5A623),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MarginCalculatorScreen()),
              );
            },
          ),
          _buildUtilityCard(
            context,
            title: 'Calculadora Rápida',
            subtitle: 'Herramienta integrada para estimaciones rápidas.',
            icon: Icons.calculate_outlined,
            color: const Color(0xFFF5A623),
            onTap: () async {
              if (Platform.isAndroid) {
                const intent = AndroidIntent(
                  action: 'android.intent.action.MAIN',
                  category: 'android.intent.category.APP_CALCULATOR',
                  flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                );
                try {
                  await intent.launch();
                } catch (e) {
                  if (!context.mounted) return;
                  _showErrorSnackBar(
                      context, 'No se encontró la calculadora nativa.');
                }
              } else if (Platform.isIOS) {
                final Uri calcScheme = Uri.parse('calshow://');
                if (await canLaunchUrl(calcScheme)) {
                  await launchUrl(calcScheme);
                } else {
                  if (!context.mounted) return;
                  _showErrorSnackBar(
                      context, 'No se pudo abrir la calculadora.');
                }
              } else {
                if (!context.mounted) return;
                _showErrorSnackBar(context,
                    'Calculadora nativa no soportada en esta plataforma.');
              }
            },
          ),
          _buildUtilityCard(
            context,
            title: 'Haz crecer tu negocio',
            subtitle: 'Mensajes personalizados de WhatsApp para pedidos.',
            icon: Icons.trending_up,
            color: const Color(0xFF9B51E0),
            onTap: () => _showComingSoon(context),
          ),
          _buildUtilityCard(
            context,
            title: 'Imprimir Facturas',
            subtitle: 'Compras, ventas',
            icon: Icons.print,
            color: const Color(0xFF9B51E0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoiceListScreen()),
              );
            },
          ),
          _buildUtilityCard(
            context,
            title: 'Notas de Negocio Rápidas',
            subtitle:
                'Bloc de notas simple con persistencia local. Para anotar recordatorios, pedidos verbales e ideas rápidas sin salir de la app.',
            icon: Icons.notes,
            color: const Color(0xFF9B51E0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotepadScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.construction, color: Colors.white),
            SizedBox(width: 12),
            Text('Próximamente', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF9B51E0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildUtilityCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: color.withValues(alpha: 0.20),
                                  width: 1),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFA0A8C1),
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_ios,
                              color: Color(0xFF6B7494), size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
