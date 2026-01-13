import 'package:flutter/material.dart';
import '../backup_manager_screen.dart';

class UtilitiesScreen extends StatelessWidget {
  const UtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilidades')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUtilityCard(
            context,
            title: 'Gestión de Respaldos',
            subtitle: 'Importar y exportar base de datos',
            icon: Icons.backup,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupManagerScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildUtilityCard(
            context,
            title: 'Calculadora Rápida',
            subtitle: 'Herramienta simple para cálculos',
            icon: Icons.calculate,
            color: Colors.orange,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
        onTap: onTap,
      ),
    );
  }
}
