import 'package:flutter/material.dart';
import 'customers/customer_list_screen.dart';
import 'suppliers/supplier_list_screen.dart';
import 'expenses/expense_form_screen.dart';
import '../theme/app_theme.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(
            context,
            icon: Icons.people,
            title: 'Clientes',
            subtitle: 'Administrar clientes y cuentas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: Icons.business,
            title: 'Proveedores',
            subtitle: 'Gestionar proveedores y pedidos',
            color: Colors.orangeAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierListScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: Icons.money_off_csred_rounded,
            title: 'Registrar Gasto',
            subtitle: 'Gastos de caja chica, transporte, etc.',
            color: Colors.redAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: Icons.backup,
            title: 'Respaldo de Datos',
            subtitle: 'Exportar base de datos a JSON',
            onTap: () {
              // Implement backup later
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente...')));
            },
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Configuración',
            subtitle: 'Ajustes de la aplicación',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente...')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      Color? color,
      required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? AppTheme.primary).withValues(alpha: 0.1),
          child: Icon(icon, color: color ?? AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
