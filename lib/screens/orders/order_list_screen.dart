import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/glass_transaction_card.dart';
import '../../widgets/common/skeleton_list.dart';
import '../../utils/whatsapp_helper.dart';
import 'order_details_screen.dart';
import '../purchases/purchase_form_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/common/glass_dialog.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  // Removed SingleTickerProviderStateMixin
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<Order> _allOrders = [];
  List<Order> _pendingOrders = [];
  List<Order> _confirmedOrders = [];

  // 0: Pendientes, 1: Confirmados, 2: Todos
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getOrders();
      if (mounted) {
        setState(() {
          _allOrders = data;
          _pendingOrders =
              data.where((o) => o.status.toUpperCase() == 'PENDING').toList();
          _confirmedOrders =
              data.where((o) => o.status.toUpperCase() == 'CONFIRMED').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar pedidos: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(Order order, String newStatus) async {
    try {
      await _db.updateOrderStatus(order.id!, newStatus);
      if (newStatus == 'RECEIVED' && mounted) {
        await context.read<InventoryProvider>().loadProducts(reset: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Pedido actualizado a $newStatus'),
              backgroundColor: Colors.green),
        );
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Pedidos Realizados',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Transparent for gradient
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Container(
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
        child: Stack(
          children: [
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
                    BoxShadow(color: const Color(0xFF4A90E2).withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 20),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildGlassTabBar(isDark),
                  Expanded(
                    child: _isLoading
                        ? const SkeletonList()
                        : _buildCurrentList(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Only show FAB if NOT in Pending/Confirmed empty states (optional, but usually good to keep)
      // User request said CTA Button on Pending Empty State, so we might want to hide main FAB or keep it?
      // "Do NOT show on Confirmed Orders" refers to the CTA inside the empty state.
      // We will keep the main FAB as "Standard" access.
      floatingActionButton: _shouldShowFab()
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const PurchaseFormScreen(initialIsOrder: true)),
                );
                if (result == true) {
                  _loadOrders();
                }
              },
              backgroundColor: const Color(0xFFEF5350),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nuevo Pedido',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  bool _shouldShowFab() {
    // 0: Pendientes, 1: Confirmados, 2: Todos
    if (_selectedTab == 1) return false; // Never show on Confirmed
    if (_selectedTab == 0 && _pendingOrders.isEmpty) {
      return false; // Hide on Pending if empty (CTA shown)
    }
    return true; // Show on All, or Pending (if not empty)
  }

  Widget _buildGlassTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTabButton('Pendientes', 0, isDark),
            const SizedBox(width: 12),
            _buildTabButton('Confirmados', 1, isDark),
            const SizedBox(width: 12),
            _buildTabButton('Todos', 2, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index, bool isDark) {
    final isSelected = _selectedTab == index;

    // Active Styles (Glass) matching History Screen
    final bgColor = isSelected
        ? (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;

    final borderColor = isSelected
        ? (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;

    final textColor = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFFA0A8C1) : Colors.grey);

    final fontWeight = isSelected ? FontWeight.w600 : FontWeight.w400;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 2),
            Text(text,
                style: TextStyle(
                    color: textColor, fontWeight: fontWeight, fontSize: 15)),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                          blurRadius: 8)
                    ]),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentList(bool isDark) {
    List<Order> currentOrders;
    String statusContext;

    switch (_selectedTab) {
      case 0:
        currentOrders = _pendingOrders;
        statusContext = 'PENDING';
        break;
      case 1:
        currentOrders = _confirmedOrders;
        statusContext = 'CONFIRMED';
        break;
      default:
        currentOrders = _allOrders;
        statusContext = 'ALL';
    }

    if (currentOrders.isEmpty) {
      return _buildEmptyState(statusContext);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: currentOrders.length,
      itemBuilder: (context, index) {
        final order = currentOrders[index];

        // Determine visual properties based on status
        Color borderColor;
        Color statusColor;
        switch (order.status.toUpperCase()) {
          case 'PENDING':
            borderColor = Colors.amber;
            statusColor = Colors.orange;
            break;
          case 'CONFIRMED':
            borderColor = Colors.green;
            statusColor = Colors.blue;
            break;
          default:
            borderColor = Colors.grey.withValues(alpha: 0.2);
            statusColor = Colors.grey;
        }

        return GlassTransactionCard(
          title: order.supplierName ?? 'Proveedor General',
          subtitle:
              '${DateFormat('dd/MM/yyyy').format(order.date)} • ${order.items.length} items',
          amount: order.totalAmount,
          status: order.status,
          color: statusColor,
          icon: Icons.local_shipping_outlined,
          isOrder: true,
          borderColor: order.status == 'RECEIVED' ? null : borderColor,
          actionButtons: _buildActionButtons(order, isDark),
          heroTag: 'order_${order.id}_icon',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(order: order),
              ),
            ).then((_) => _loadOrders());
          },
        ).animate().fadeIn(duration: 400.ms).slideY(
              begin: 0.1,
              end: 0,
              delay: (50 * index).ms,
            );
      },
    );
  }

  Widget _buildEmptyState(String statusContext) {
    Color mainColor;
    IconData icon;
    String title;
    String subtitle;
    bool showCta;

    // Default values
    mainColor = Colors.grey;
    icon = Icons.inventory_2_outlined;
    title = 'No hay pedidos';
    subtitle = 'Aquí aparecerán tus pedidos.';
    showCta = false;

    if (statusContext == 'PENDING') {
      mainColor = const Color(0xFFFFB74D); // Yellow/Orange
      icon = Icons.pending_actions;
      title = 'No hay pedidos pendientes';
      subtitle = 'Los pedidos que envíes a proveedores aparecerán aquí';
      showCta = true;
    } else if (statusContext == 'CONFIRMED') {
      mainColor = const Color(0xFF66BB6A); // Green
      icon = Icons.check_circle_outline;
      title = 'No hay pedidos confirmados';
      subtitle =
          'Cuando un proveedor confirme tu pedido, lo verás en esta sección';
      showCta = false;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Large icon in a colored circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: mainColor.withValues(alpha: 0.1), // 10% opacity
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: mainColor, // 100% opacity
            ),
          ),
          const SizedBox(height: 32),
          // 2. Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // 3. Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Color(0xFFA0A8C1), // #A0A8C1
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showCta) ...[
            const SizedBox(height: 32),
            // 4. CTA Button (Only on Pending)
            Container(
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEF5350), // Red 400
                    Color(0xFFD32F2F), // Red 700
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4DEF5350),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PurchaseFormScreen(initialIsOrder: true)),
                    );
                    if (result == true) {
                      _loadOrders();
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, color: Colors.white),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Crear Primer Pedido',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildActionButtons(Order order, bool isDark) {
    final status = order.status.toUpperCase();
    if (status == 'RECEIVED' || status == 'CANCELLED') {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Forward via WhatsApp
        TextButton.icon(
          onPressed: () {
            final message = WhatsAppHelper.generateOrderMessage(order);
            // TODO: Get real phone number from supplier if available
            WhatsAppHelper.launchWhatsApp('59100000000', message);
          },
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Enviar'),
          style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.tealAccent : Colors.teal),
        ),
        const SizedBox(width: 8),

        // Confirm
        if (status == 'PENDING')
          ElevatedButton.icon(
            onPressed: () => _updateStatus(order, 'CONFIRMED'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

        // Mark Received
        if (status == 'CONFIRMED')
          ElevatedButton.icon(
            onPressed: () => _showReceiveConfirmation(order),
            icon: const Icon(Icons.inventory, size: 18),
            label: const Text('Recibir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
      ],
    );
  }

  void _showReceiveConfirmation(Order order) {
    showGlassDialog(
      context: context,
      title: 'Recibir Pedido',
      content: const Text(
          '¿Marcar este pedido como RECIBIDO?\nEsto actualizará el inventario con los productos del pedido.',
          style: TextStyle(color: Colors.white70, fontSize: 16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFFA0A8C1))),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50A7EA)],
            ),
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(order, 'RECEIVED');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar Recepción', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
