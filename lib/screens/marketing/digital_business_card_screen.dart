import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/settings_provider.dart';
import 'dart:ui' as ui;
import '../../theme/app_theme.dart';

class DigitalBusinessCardScreen extends StatelessWidget {
  const DigitalBusinessCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<SettingsProvider>().profile;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Tarjeta de Presentación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
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
            top: 100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.blueIcon.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.blueIcon.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Digital Business Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5),
                            ],
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppTheme.blueIcon,
                                child: Text(
                                  profile.businessName.isNotEmpty ? profile.businessName[0].toUpperCase() : 'N',
                                  style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                profile.businessName.isNotEmpty ? profile.businessName : 'Mi Negocio',
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Contáctanos para más información',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              _buildContactRow(Icons.phone, profile.phone.isNotEmpty ? profile.phone : '+591 00000000'),
                              const SizedBox(height: 16),
                              _buildContactRow(Icons.email, profile.email.isNotEmpty ? profile.email : 'correo@ejemplo.com'),
                              const SizedBox(height: 16),
                              _buildContactRow(Icons.location_on, profile.address.isNotEmpty ? profile.address : 'Dirección no definida'),
                              
                              const SizedBox(height: 32),
                              // QR Code Section
                              if (profile.phone.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: 'https://wa.me/${profile.phone.replaceAll(RegExp(r'\D'), '')}',
                                    version: QrVersions.auto,
                                    size: 120.0,
                                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Escanea para Whatsapp',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: [AppTheme.blueIcon, Color(0xFF50A7EA)]),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // This could use screenshot and share_plus to actually share
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Función de compartir estará disponible pronto.')),
                          );
                        },
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text('Compartir Tarjeta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
