import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Providers
import '../providers/settings_provider.dart';
import '../providers/notification_provider.dart';

// Screens
import 'customers/customer_list_screen.dart';
import 'suppliers/supplier_list_screen.dart';
import 'expenses/expense_form_screen.dart';
import 'history/transaction_history_screen.dart';
import 'purchases/purchase_list_screen.dart';
import 'orders/order_list_screen.dart';
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    // Check for low stock notifications when menu loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().checkLowStock();
      context.read<NotificationProvider>().checkOverdueSales();
    });
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'Desconocida');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Using a base scaffold layout. It's assumed the parent scaffold or app handles the global background.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient & Blobs
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          const Color(0xFFF8FAFC),
                          const Color(0xFFE2E8F0),
                          const Color(0xFFF1F5F9),
                        ],
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
                color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context)
                      .animate()
                      .fade(duration: 300.ms)
                      .slideY(begin: -0.2, end: 0, duration: 300.ms),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'MI NEGOCIO',
                    items: [
                      _MenuItemData(
                        icon: Icons.account_balance_wallet,
                        title: 'Ventas',
                        color: const Color(0xFF4A90E2), // Blue
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const TransactionHistoryScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.shopping_cart,
                        title: 'Compras',
                        color: const Color(0xFF9B51E0), // Purple
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PurchaseListScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.local_shipping_outlined,
                        title: 'Pedidos',
                        color: const Color(0xFFF5A623), // Orange
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const OrderListScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.people,
                        title: 'Clientes',
                        color: const Color(0xFF4ECDC4), // Turquoise
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CustomerListScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.local_shipping,
                        title: 'Proveedores',
                        color: const Color(0xFFFFA94D), // Yellow
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SupplierListScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.inventory,
                        title: 'Gestión de Inventario',
                        color: const Color(0xFFFF6B9D), // Magenta
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProductListScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.bar_chart,
                        title: 'Reportes',
                        color: const Color(0xFFFF6B6B), // Red
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReportsScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.receipt_long,
                        title: 'Gastos',
                        color: const Color(0xFFFF8A65), // Coral
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ExpenseFormScreen())),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms, delay: 50.ms).slideY(
                      begin: 0.1, end: 0, duration: 300.ms, delay: 50.ms),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: 'FUNCIONALIDADES IMPORTANTES',
                    items: [
                      _MenuItemData(
                        icon: Icons.sync,
                        title: 'Sincronización y Compartir',
                        color: const Color(0xFF4A90E2),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Próximamente: Sincronización con Supabase')),
                          );
                        },
                      ),
                      _MenuItemData(
                        icon: Icons.cloud_upload,
                        title: 'Respaldo de Datos',
                        color: const Color(0xFF4ECDC4),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BackupManagerScreen())),
                      ),
                      _MenuItemData(
                        icon: Icons.build,
                        title: 'Utilidades',
                        color: const Color(0xFFF5A623),
                        isNew: true,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UtilitiesScreen())),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms, delay: 100.ms).slideY(
                      begin: 0.1, end: 0, duration: 300.ms, delay: 100.ms),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: 'OTROS',
                    items: [
                      _MenuItemData(
                        icon: Icons.settings,
                        title: 'Configuración',
                        color: const Color(0xFFA0A8C1),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen())),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms, delay: 150.ms).slideY(
                      begin: 0.1, end: 0, duration: 300.ms, delay: 150.ms),
                  const SizedBox(height: 32),
                  _buildFooter(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final profile = settingsProvider.profile;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12), // Slightly more opaque
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.10), // Glassmorphism avatar
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child:
                        profile.logoPath != null && profile.logoPath!.isNotEmpty
                            ? Image.file(
                                File(profile.logoPath!),
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                    Icons.store,
                                    color: Colors.white,
                                    size: 28),
                              )
                            : const Icon(Icons.store,
                                color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.businessName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Business Management',
                      style: TextStyle(color: Color(0xFFA0A8C1), fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Notifications
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined,
                        color: Colors.white, size: 24),
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
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Settings
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<_MenuItemData> items}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF), // Exactly 10% opacity Hex
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0x14FFFFFF), width: 1.5), // 8% opacity Hex
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFA0A8C1), // Secondary color
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...items.asMap().entries.map((entry) {
                  int index = entry.key;
                  _MenuItemData item = entry.value;
                  bool isLast = index == items.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _MenuItemWidget(item: item),
                      ),
                      if (!isLast)
                        Container(
                          height: 1,
                          color: Colors.white
                              .withValues(alpha: 0.05), // 5% Soft Separator
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          'APP VERSION',
          style: TextStyle(
            color: Color(0xFF6B7494),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _appVersion.isNotEmpty ? _appVersion : '...',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Política de Privacidad',
            style: TextStyle(
              color: Color(0xFF4A90E2),
              fontSize: 14,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF4A90E2),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isNew;

  _MenuItemData({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isNew = false,
  });
}

class _MenuItemWidget extends StatefulWidget {
  final _MenuItemData item;
  const _MenuItemWidget({required this.item});

  @override
  State<_MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) =>
      setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.item.onTap();
  }

  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        child: Row(
          children: [
            // Icon Area
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.item.color
                    .withValues(alpha: 0.20), // 20% visible circle
                shape: BoxShape.circle,
              ),
              child: Icon(widget.item.icon, color: widget.item.color, size: 24),
            ),

            const SizedBox(width: 16),

            // Text Area
            Expanded(
              child: Text(
                widget.item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),

            // Badges & Chevron
            if (widget.item.isNew)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8A65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NUEVO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFF6B7494), size: 20),
          ],
        ),
      ),
    );
  }
}
