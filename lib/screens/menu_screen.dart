import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/notification_provider.dart';

// Screens
import 'customers/customer_list_screen.dart';
import 'suppliers/supplier_list_screen.dart';
import 'expenses/expense_form_screen.dart';
import 'history/transaction_history_screen.dart';
import 'purchases/purchase_list_screen.dart';
import 'inventory/product_list_screen.dart';
import 'reports/reports_screen.dart';
import 'utilities/utilities_screen.dart';
import 'settings/settings_screen.dart';
import 'backup_manager_screen.dart';
import 'notifications/notifications_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    // Check for low stock notifications when menu loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().checkLowStock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context), // Header with profile
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSectionCard(
                      context,
                      title: 'MI NEGOCIO',
                      items: [
                        _MenuItem(
                          icon: Icons.account_balance_wallet,
                          title: 'Ventas',
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const TransactionHistoryScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.shopping_cart,
                          title: 'Compras',
                          color: Colors.indigo,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PurchaseListScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.people,
                          title: 'Clientes',
                          color: Colors.teal,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CustomerListScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.local_shipping,
                          title: 'Proveedores',
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SupplierListScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.inventory,
                          title: 'Gestión de Inventario',
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProductListScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.bar_chart,
                          title: 'Reportes',
                          color: Colors.red,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ReportsScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.receipt_long,
                          title: 'Gastos',
                          color: Colors.deepOrange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExpenseFormScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      title: 'FUNCIONALIDADES IMPORTANTES',
                      items: [
                        _MenuItem(
                          icon: Icons.sync,
                          title: 'Sincronización y Compartir',
                          color: isDark
                              ? Colors.blueGrey.shade200
                              : Colors.blueGrey,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Próximamente: Sincronización con Supabase')),
                            );
                          },
                        ),
                        _MenuItem(
                          icon: Icons.cloud_upload,
                          title: 'Respaldo de Datos',
                          color: isDark
                              ? Colors.blueGrey.shade200
                              : Colors.blueGrey,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BackupManagerScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.build,
                          title: 'Utilidades',
                          color: isDark
                              ? Colors.blueGrey.shade200
                              : Colors.blueGrey,
                          isNew: true,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const UtilitiesScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      title: 'OTROS',
                      items: [
                        _MenuItem(
                          icon: Icons.settings,
                          title: 'Configuración',
                          color: isDark
                              ? Colors.blueGrey.shade200
                              : Colors.blueGrey,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildFooter(context), // Version and policy
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notificationProvider = context.watch<NotificationProvider>();
    final unreadCount = notificationProvider.unreadCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: theme.cardColor,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark
                ? Colors.blue.withValues(alpha: 0.2)
                : const Color(0xFFDBEAFE),
            child: const Icon(Icons.store, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pierre PB',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('Business Management',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor)),
            ],
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none,
                    color: theme.iconTheme.color),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()));
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)
                ]),
            child: Icon(Icons.settings, color: theme.iconTheme.color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context,
      {required String title, required List<_MenuItem> items}) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title,
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.hintColor,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.bold)),
          ),
          ...items.map((item) => _buildListTile(context, item)),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, _MenuItem item) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(item.icon, color: item.color, size: 22),
      title: Row(
        children: [
          Text(item.title,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500)),
          if (item.isNew) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Text('NUEVO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: theme.hintColor, size: 20),
      onTap: item.onTap,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text('APP VERSION',
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold, color: theme.hintColor)),
        Text('21.8.0',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextButton(
            onPressed: () {},
            child: const Text('Política de Privacidad',
                style: TextStyle(color: Colors.blue, fontSize: 13))),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isNew;

  _MenuItem(
      {required this.icon,
      required this.title,
      required this.color,
      required this.onTap,
      this.isNew = false});
}
