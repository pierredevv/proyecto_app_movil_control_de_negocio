import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui' as ui;
import 'digital_business_card_screen.dart';
import 'whatsapp_catalog_screen.dart';
import '../../theme/app_theme.dart';

class MarketingHubScreen extends StatelessWidget {
  const MarketingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Crece tu Negocio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient & Blobs
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surfaceDeep, AppTheme.surfaceSlate, AppTheme.surfaceDeep],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF8C52FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8C52FF).withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Herramientas de Marketing',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Usa estas herramientas para llegar a más clientes y aumentar tus ventas.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildMarketingCard(
                    context: context,
                    title: 'Tarjeta de Presentación Digital',
                    description: 'Crea y comparte tu tarjeta de negocios con diseño profesional.',
                    icon: Icons.contact_mail,
                    color: AppTheme.blueIcon,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalBusinessCardScreen()));
                    },
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),

                  const SizedBox(height: 16),

                  _buildMarketingCard(
                    context: context,
                    title: 'Exportar Catálogo Whatsapp',
                    description: 'Genera un catálogo en texto de tus productos para compartir rápidamente.',
                    icon: Icons.storefront,
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsAppCatalogScreen()));
                    },
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketingCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
