import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/transaction_model.dart';
import 'dart:ui';
import '../sales/sale_detail_screen.dart';
import '../utilities/print_preview_screen.dart';
import '../../widgets/transactions/transaction_options_sheet.dart';
import '../purchases/purchase_details_screen.dart';
import '../orders/order_details_screen.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/sale_unit_option.dart';
import '../../providers/cart_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../customers/customer_ledger_screen.dart';

import '../purchases/purchase_form_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final DatabaseService _db = DatabaseService();

  DateTimeRange? _dateRange;
  String? _selectedType;
  bool _isLoading = false;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTransactions(
        limit: 100,
        type: _selectedType,
        startDate: _dateRange?.start.millisecondsSinceEpoch,
        endDate: _dateRange?.end.millisecondsSinceEpoch,
      );
      if (mounted) {
        setState(() {
          _transactions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _voidTransaction(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Transacción'),
        content: Text(
            '¿Estás seguro de que deseas anular esta ${t.type == TransactionType.sale ? 'Venta' : 'Compra'} por Bs. ${t.totalAmount.toStringAsFixed(2)}?\n\nEl inventario y el balance del cliente/proveedor se revertirán.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Sí, Anular', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      if (t.type == TransactionType.sale) {
        await _db.deleteSale(t.id!);
      } else if (t.type == TransactionType.purchase ||
          t.type == TransactionType.order) {
        await _db.deletePurchase(t.id!);
      } else if (t.type == TransactionType.expense) {
        await _db.deleteExpense(t.id!);
      } else if (t.type == TransactionType.payment) {
        await _db.deletePayment(t.id!);
      } else {
        throw Exception('No soportado para este tipo de transacción');
      }

      if (mounted) {
        context.read<DashboardProvider>().loadDashboardData();
        context.read<InventoryProvider>().loadProducts(reset: true);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Transacción anulada exitosamente'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al anular: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _duplicateTransaction(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicar Transacción'),
        content: Text(
            '¿Deseas duplicar esta ${t.type == TransactionType.sale ? 'Venta' : 'Compra'}?\n\nSe cargarán los productos en el carrito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Duplicar',
                style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    await _loadToCartAndNavigate(t);
  }

  Future<void> _loadToCartAndNavigate(Transaction t) async {
    if (t.type == TransactionType.sale) {
      final cart = context.read<CartProvider>();
      final inventory = context.read<InventoryProvider>();

      cart.clearCart();

      if ((t as Sale).customerId != null) {
        try {
          final db = await _db.database;
          final results = await db
              .query('customers', where: 'id = ?', whereArgs: [t.customerId]);
          if (results.isNotEmpty) {
            cart.setCustomer(Customer.fromMap(results.first));
          }
        } catch (e) {
          // ignore
        }
      }

      for (var i in t.items) {
        final productMatch =
            inventory.products.where((p) => p.id == i.productId).firstOrNull;
        if (productMatch != null) {
          final option = SaleUnitOption(
            label: '${i.productName} (${i.saleUnit})',
            unitCode: i.saleUnit,
            unitsPerSaleUnit: i.unitsPerSaleUnit,
            price: i.unitPrice,
          );
          try {
            cart.addToCart(productMatch, option: option, qty: i.quantity);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Sin stock para ${productMatch.name}'),
                    backgroundColor: Colors.orange),
              );
            }
            cart.clearCart();
            return;
          }
        }
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (t.type == TransactionType.purchase ||
        t.type == TransactionType.order) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseFormScreen(
            initialTransactionToDuplicate: t,
          ),
        ),
      ).then((_) {
        if (mounted) _loadData();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Duplicado no soportado para este tipo de transacción')),
        );
      }
    }
  }

  Future<void> _editTransaction(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Transacción'),
        content: const Text(
            'Para mantener la consistencia contable, la edición anula la transacción actual y la envía al carrito.\n\n¿Deseas continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Editar',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      if (t.type == TransactionType.sale) {
        await _db.deleteSale(t.id!);
      } else if (t.type == TransactionType.purchase ||
          t.type == TransactionType.order) {
        await _db.deletePurchase(t.id!);
      } else {
        throw Exception('No soportado para este tipo de transacción');
      }

      if (t.type != TransactionType.expense &&
          t.type != TransactionType.payment) {
        await _loadToCartAndNavigate(t);
      }

      if (mounted) {
        context.read<DashboardProvider>().loadDashboardData();
        context.read<InventoryProvider>().loadProducts(reset: true);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No se pudo inicializar la edición: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = DateTimeRange(
            start: DateTime(
                picked.start.year, picked.start.month, picked.start.day),
            end: DateTime(
                picked.end.year, picked.end.month, picked.end.day, 23, 59, 59));
      });
      _loadData();
    }
  }

  void _onTabChanged(String? type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.03 : 0.02,
              child: Image.asset(
                'assets/images/pattern.png',
                repeat: ImageRepeat.repeat,
                color: isDark ? Colors.white : Colors.black,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isDark),
                const SizedBox(height: 20),
                _GlassFilterTabs(
                  selectedType: _selectedType,
                  onChanged: _onTabChanged,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? _buildSkeletonLoader(isDark)
                      : _transactions.isEmpty
                          ? _buildEmptyState(context, isDark)
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: const Color(0xFFFF6B6B),
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: _transactions.length,
                                itemBuilder: (context, index) {
                                  final t = _transactions[index];
                                  return _GlassTransactionCard(
                                    transaction: t,
                                    isDark: isDark,
                                    onVoid: () => _voidTransaction(t),
                                    onDuplicate: () => _duplicateTransaction(t),
                                    onEdit: () => _editTransaction(t),
                                  ).animate().fadeIn(duration: 300.ms).slideY(
                                      begin: 0.2,
                                      end: 0,
                                      curve: Curves.easeOut,
                                      delay: ((50 * index).clamp(0, 500)).ms);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final count = _transactions.length;
    final dateStr = _dateRange != null
        ? '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}'
        : DateFormat('MMMM yyyy').format(DateTime.now());

    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? const Color(0xFFA0A8C1) : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Center(
                        child:
                            Icon(Icons.arrow_back, color: textColor, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial Transacciones',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count registros • $dateStr',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Center(
                    child:
                        Icon(Icons.calendar_today, color: textColor, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1200.ms, color: isDark ? Colors.white10 : Colors.black12);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    IconData icon;
    String message;
    String ctaLabel;

    if (_selectedType == 'sale') {
      icon = Icons.point_of_sale;
      message = 'No se encontraron ventas';
      ctaLabel = 'Realizar Venta';
    } else if (_selectedType == 'purchase') {
      icon = Icons.inventory_2;
      message = 'No se encontraron compras';
      ctaLabel = 'Registrar Compra';
    } else if (_selectedType == 'expense') {
      icon = Icons.money_off;
      message = 'No hay gastos registrados';
      ctaLabel = 'Registrar Gasto';
    } else {
      icon = Icons.history_edu;
      message = 'No hay movimientos';
      ctaLabel = 'Actualizar';
    }

    final textColor = isDark ? Colors.white70 : Colors.black54;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: textColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: textColor, fontSize: 16)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _selectedType == 'sale'
                    ? () => Navigator.pop(context)
                    : _loadData,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(ctaLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Tabs
// ─────────────────────────────────────────────────────────────────────────────

class _GlassFilterTabs extends StatelessWidget {
  final String? selectedType;
  final Function(String?) onChanged;
  final bool isDark;

  const _GlassFilterTabs(
      {required this.selectedType,
      required this.onChanged,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTab(type: null, label: 'Todos'),
          const SizedBox(width: 12),
          _buildTab(type: 'sale', label: 'Ventas'),
          const SizedBox(width: 12),
          _buildTab(type: 'purchase', label: 'Compras'),
          const SizedBox(width: 12),
          _buildTab(type: 'expense', label: 'Gastos'),
          const SizedBox(width: 12),
          _buildTab(type: 'payment', label: 'Pagos'),
        ],
      ),
    );
  }

  Widget _buildTab({String? type, required String label}) {
    final bool isActive = selectedType == type;

    final bgColor = isActive
        ? (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;

    final borderColor = isActive
        ? (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;

    final textColor = isActive
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFFA0A8C1) : Colors.grey);

    final fontWeight = isActive ? FontWeight.w600 : FontWeight.w400;

    return GestureDetector(
      onTap: () => onChanged(type),
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
            Text(label,
                style: TextStyle(
                    color: textColor, fontWeight: fontWeight, fontSize: 15)),
            if (isActive) ...[
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Card  — Vyapar-style payment info for PARTIAL/CREDIT
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool isDark;
  final VoidCallback onVoid;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  const _GlassTransactionCard({
    required this.transaction,
    required this.isDark,
    required this.onVoid,
    required this.onDuplicate,
    required this.onEdit,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _typeColor() {
    if (transaction is Sale) {
      final sale = transaction as Sale;
      switch (sale.status.toUpperCase()) {
        case 'PARTIAL':
          return const Color(0xFFF59F00);
        case 'CREDIT':
          return const Color(0xFF4A90E2);
        case 'VOIDED':
          return const Color(0xFF6B7494);
        default:
          return const Color(0xFF51CF66);
      }
    }
    switch (transaction.type) {
      case TransactionType.purchase:
        return const Color(0xFFFF6B6B);
      case TransactionType.expense:
        return const Color(0xFFFFA94D);
      case TransactionType.payment:
        return const Color(0xFF4A90E2);
      case TransactionType.order:
        return const Color(0xFF8C52FF);
      default:
        return const Color(0xFF51CF66);
    }
  }

  String _typeLabel() {
    if (transaction is Sale) {
      final sale = transaction as Sale;
      switch (sale.status.toUpperCase()) {
        case 'PARTIAL':
          return 'VENTA · PARCIAL';
        case 'CREDIT':
          return 'VENTA · CRÉDITO';
        case 'VOIDED':
          return 'VENTA · ANULADA';
        default:
          return 'VENTA';
      }
    }
    switch (transaction.type) {
      case TransactionType.purchase:
        return 'COMPRA';
      case TransactionType.expense:
        return 'GASTO';
      case TransactionType.payment:
        return 'PAGO';
      case TransactionType.order:
        return 'PEDIDO';
      default:
        return 'OTRO';
    }
  }

  bool get _isPendingSale =>
      transaction is Sale &&
      (transaction.status == 'PARTIAL' || transaction.status == 'CREDIT');

  void _navigateToDetail(BuildContext context, String heroTag) {
    if (transaction is Sale) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SaleDetailScreen(
            sale: transaction as Sale,
            heroTag: heroTag,
          ),
        ),
      );
    } else if (transaction is Purchase) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseDetailsScreen(
            purchase: transaction as Purchase,
            heroTag: heroTag,
          ),
        ),
      );
    } else if (transaction is Order) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(
            order: transaction as Order,
            heroTag: heroTag,
          ),
        ),
      );
    } else if (transaction is Expense || transaction is Payment) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(transaction is Expense
                      ? 'Detalle de Gasto'
                      : 'Detalle de Pago'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Monto: Bs. ${transaction.totalAmount.toStringAsFixed(2)}'),
                      Text(
                          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}'),
                      if (transaction is Expense)
                        Text(
                            'Descripción: ${(transaction as Expense).description}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar')),
                  ]));
    }
  }

  Future<void> _handlePrint(BuildContext context) async {
    final sale = transaction as Sale;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(transaction: sale),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionOptionsBottomSheet(
        isVoided: transaction.status == 'VOIDED',
        showDuplicate: transaction.type != TransactionType.expense &&
            transaction.type != TransactionType.payment,
        showSharePdf: transaction.type == TransactionType.sale,
        onEdit: () => onEdit(),
        onCancel: () {
          if (transaction.status == 'VOIDED') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Esta transacción ya está anulada')),
            );
            return;
          }
          onVoid();
        },
        onSharePdf: () => _handlePrint(context),
        onDuplicate: () => onDuplicate(),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor();
    final heroTag = '${transaction.type.name}_${transaction.id}_icon';

    String name;
    bool isPositive = false;

    switch (transaction.type) {
      case TransactionType.purchase:
        name = (transaction as Purchase).supplierName ?? 'Proveedor General';
        isPositive = false;
        break;
      case TransactionType.sale:
        name = (transaction as Sale).customerName ?? 'Cliente General';
        isPositive = true;
        break;
      case TransactionType.expense:
        name = (transaction as Expense).description;
        isPositive = false;
        break;
      case TransactionType.payment:
        name = 'Abono de Cliente';
        isPositive = true;
        break;
      case TransactionType.order:
        name = (transaction as Order).supplierName ?? 'Proveedor General';
        isPositive = false;
        break;
    }

    final dateStr = DateFormat('MMM dd, HH:mm').format(transaction.date);
    final amountStr = 'Bs. ${transaction.totalAmount.toStringAsFixed(2)}';
    final prefix = isPositive ? '+' : '-';
    final amountColor =
        isPositive ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B);

    final cardBg =
        isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.15) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.10)
        : Colors.grey.withValues(alpha: 0.2);
    final shadowColor = isDark
        ? const Color(0xFF000000).withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.05);

    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? const Color(0xFF6B7494) : Colors.grey[600];
    const secondaryGray = Color(0xFFA0A8C1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: shadowColor, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToDetail(context, heroTag),
              child: Stack(
                children: [
                  // Left color indicator
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(color: typeColor),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: type badge + actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: heroTag,
                                  child: Icon(_iconFor(transaction.type),
                                      size: 18, color: secondaryGray),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_typeLabel()} • #${transaction.id}',
                                  style: const TextStyle(
                                      color: secondaryGray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (transaction.type == TransactionType.sale)
                                  IconButton(
                                    icon: const Icon(Icons.print,
                                        size: 22, color: Color(0xFFFF6B6B)),
                                    onPressed: () => _handlePrint(context),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert,
                                      size: 22, color: secondaryGray),
                                  onPressed: () => _showOptions(context),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Row 2: customer/supplier name
                        Text(name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            )),

                        const SizedBox(height: 4),

                        // Row 3: date
                        Text(dateStr,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor,
                            )),

                        const SizedBox(height: 12),

                        Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2)),

                        const SizedBox(height: 12),

                        // ── Payment breakdown (PARTIAL/CREDIT) ────────────
                        if (_isPendingSale) ...[
                          _buildPaymentBreakdown(
                            context,
                            sale: transaction as Sale,
                            typeColor: typeColor,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Row 4: total amount
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$prefix $amountStr',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: amountColor,
                            ),
                          ),
                        ),

                        // ── Cobrar button (PARTIAL/CREDIT with customer) ──
                        if (_isPendingSale &&
                            (transaction as Sale).customerId != null) ...[
                          const SizedBox(height: 12),
                          _buildCobrarButton(context,
                              sale: transaction as Sale, typeColor: typeColor),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
  }

  IconData _iconFor(TransactionType type) {
    switch (type) {
      case TransactionType.sale:
        return Icons.attach_money;
      case TransactionType.purchase:
        return Icons.inventory_2;
      case TransactionType.expense:
        return Icons.money_off;
      case TransactionType.payment:
        return Icons.payment;
      case TransactionType.order:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _buildPaymentBreakdown(
    BuildContext context, {
    required Sale sale,
    required Color typeColor,
    required bool isDark,
  }) {
    final fmt = NumberFormat.currency(
        symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');
    final paidColor = const Color(0xFF51CF66);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: typeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Pagado
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAGADO',
                    style: TextStyle(
                        color: paidColor.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(fmt.format(sale.amountPaid),
                    style: TextStyle(
                        color: paidColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
              width: 1, height: 34, color: typeColor.withValues(alpha: 0.25)),
          const SizedBox(width: 12),
          // Pendiente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.status == 'CREDIT' ? 'CRÉDITO TOTAL' : 'PENDIENTE',
                    style: TextStyle(
                        color: typeColor.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(fmt.format(sale.pendingAmount),
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Due date
          if (sale.paymentDueDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _isOverdue(sale.paymentDueDate!)
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.15)
                    : typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Icon(
                    _isOverdue(sale.paymentDueDate!)
                        ? Icons.warning_amber_rounded
                        : Icons.calendar_today,
                    size: 12,
                    color: _isOverdue(sale.paymentDueDate!)
                        ? const Color(0xFFFF6B6B)
                        : typeColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd/MM').format(sale.paymentDueDate!),
                    style: TextStyle(
                      color: _isOverdue(sale.paymentDueDate!)
                          ? const Color(0xFFFF6B6B)
                          : typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isOverdue(DateTime dueDate) => DateTime.now().isAfter(dueDate);

  Widget _buildCobrarButton(BuildContext context,
      {required Sale sale, required Color typeColor}) {
    return GestureDetector(
      onTap: () {
        // Close the current options if open, then navigate
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerLedgerScreen(
              customerId: sale.customerId!,
              customerName: sale.customerName ?? 'Cliente',
            ),
          ),
        );
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: typeColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_rounded, color: typeColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Cobrar cuota de este cliente',
              style: TextStyle(
                color: typeColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, color: typeColor, size: 12),
          ],
        ),
      ),
    );
  }
}
