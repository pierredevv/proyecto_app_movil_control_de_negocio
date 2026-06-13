// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/logger_service.dart';
import '../../theme/app_theme.dart';
import 'business_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDebugMode = false;

  @override
  void initState() {
    super.initState();
    _loadDebugSetting();
  }

  Future<void> _loadDebugSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDebugMode = prefs.getBool('enable_debug_logging') ?? false;
    });
  }

  Future<void> _toggleDebugMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_debug_logging', value);
    LoggerService().setDebugMode(value);
    setState(() {
      _isDebugMode = value;
    });
  }

  Future<void> _exportLogs() async {
    final file = await LoggerService().getLogFile();
    if (file != null && await file.exists()) {
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Registro de Diagnóstico - App Control de Negocio',
            sharePositionOrigin: box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : null,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay registros de error disponibles.')),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.logout();
  }

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
    final auth = context.watch<AuthProvider>();

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
          
          const SizedBox(height: 24),

          // SESSION SECTION
          _SectionTitle('Sesión', theme: theme),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      auth.currentUser?.displayName.isNotEmpty == true
                          ? auth.currentUser!.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(auth.currentUser?.displayName ?? 'Sin sesión'),
                  subtitle: Text(
                    '@${auth.currentUser?.username ?? ''} · '
                    '${auth.currentRoles.map((r) => r.displayName).join(", ")}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: _confirmLogout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // DIAGNOSTICS & SUPPORT SECTION
          _SectionTitle('Diagnóstico y Soporte', theme: theme),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('Exportar Registro de Errores'),
                  subtitle: const Text('Comparte el archivo .log con soporte técnico'),
                  trailing: const Icon(Icons.share),
                  onTap: _exportLogs,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Modo Depuración (Avanzado)'),
                  subtitle: const Text('Registra eventos detallados de la aplicación'),
                  secondary: const Icon(Icons.developer_mode),
                  value: _isDebugMode,
                  onChanged: _toggleDebugMode,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
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
