import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import 'business_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    if (!settingsProvider.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = settingsProvider.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BUSINESS PROFILE SECTION
          _SectionTitle('Perfil del Negocio', theme: theme),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.store, color: Colors.blue),
              title: const Text('Editar Perfil y Facturación'),
              subtitle: Text(profile.businessName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BusinessProfileScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // APPEARANCE SECTION
          _SectionTitle('Apariencia', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Oscuro'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {themeProvider.themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  themeProvider.setThemeMode(newSelection.first);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // TEXT SIZE SECTION
          _SectionTitle('Tamaño de Texto', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<double>(
                segments: const [
                  ButtonSegment<double>(
                    value: 0.85,
                    label: Text('Pequeño'),
                    icon: Icon(Icons.text_decrease),
                  ),
                  ButtonSegment<double>(
                    value: 1.0,
                    label: Text('Normal'),
                    icon: Icon(Icons.text_format),
                  ),
                  ButtonSegment<double>(
                    value: 1.15,
                    label: Text('Grande'),
                    icon: Icon(Icons.text_increase),
                  ),
                ],
                selected: {settingsProvider.textScale},
                onSelectionChanged: (Set<double> newSelection) {
                  settingsProvider.setTextScale(newSelection.first);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // POS & INVENTORY BEHAVIOR
          _SectionTitle('Comportamiento POS e Inventario', theme: theme),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Confirmar antes de vaciar carrito'),
                  secondary: const Icon(Icons.delete_sweep),
                  value: profile.confirmClearCart,
                  onChanged: (v) {
                    settingsProvider
                        .updateProfile(profile.copyWith(confirmClearCart: v));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Limpiar carrito tras venta exitosa'),
                  secondary: const Icon(Icons.shopping_cart_checkout),
                  value: profile.autoClearCartAfterSale,
                  onChanged: (v) {
                    settingsProvider.updateProfile(
                        profile.copyWith(autoClearCartAfterSale: v));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Mostrar pdts sin stock en POS'),
                  secondary: const Icon(Icons.visibility_off),
                  value: profile.showOutOfStockInPOS,
                  onChanged: (v) {
                    settingsProvider.updateProfile(
                        profile.copyWith(showOutOfStockInPOS: v));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Alertas por stock bajo'),
                  secondary: const Icon(Icons.notifications_active),
                  value: profile.lowStockAlertsEnabled,
                  onChanged: (v) {
                    settingsProvider.updateProfile(
                        profile.copyWith(lowStockAlertsEnabled: v));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionTitle(this.title, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
