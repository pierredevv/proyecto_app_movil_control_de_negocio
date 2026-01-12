import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/backup_service.dart';
import '../customers/customer_list_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú'),
      ),
      body: ListView(
        children: [
          _MenuSection(
            title: 'Gestión',
            children: [
              _MenuTile(
                icon: Icons.people,
                title: 'Clientes',
                subtitle: 'Gestionar clientes y deudas',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CustomerListScreen()),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.history,
                title: 'Historial de Transacciones',
                subtitle: 'Ver ventas y compras',
                onTap: () {
                  // Navigate to history via provider or direct push
                  // Since we are changing tabs, maybe push is better for specific screen
                  // But let's assume we'll create a dedicated screen for it.
                  // For now, let's use the provider to switch to tab 1 (Purchases) as placeholder
                  // OR push the new TransactionHistoryScreen once created.
                  // context.read<NavigationProvider>().setIndex(1);
                  // TODO: Connect to TransactionHistoryScreen
                },
              ),
            ],
          ),
          _MenuSection(
            title: 'Sistema',
            children: [
              _MenuTile(
                icon: Icons.backup,
                title: 'Respaldo de Datos',
                subtitle: 'Exportar base de datos a archivo JSON',
                onTap: () async {
                  try {
                    await BackupService.createAndShareBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Respaldo generado exitosamente')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              _MenuTile(
                icon: Icons.settings,
                title: 'Configuración',
                subtitle: 'Opciones de la aplicación',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MenuSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
