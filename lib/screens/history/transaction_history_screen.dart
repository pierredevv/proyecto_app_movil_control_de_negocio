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

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final DatabaseService _db = DatabaseService();

  // Filters
  DateTimeRange? _dateRange;
  String? _selectedType; // null = all
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

    // Background Gradient logic can be handled by Scaffold background or a Container
    // The user requested Glassmorphism which implies a dark/colorful background.
    // If we are in Light mode, we need to ensure contrast.

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Pattern (Optional)
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
                // 1. Custom Header
                _buildHeader(context, isDark),

                const SizedBox(height: 20),

                // 2. Filter Tabs
                _GlassFilterTabs(
                  selectedType: _selectedType,
                  onChanged: _onTabChanged,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // 3. Transactions List
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
    // Determine subtitle
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
              // Back Button
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
                      fontSize:
                          20, // Reduced slightly to fit better with back button
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
          // Glass Calendar Icon
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

    // Customize based on filter
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
          // CTA Button (Glass + gradient)
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
                    ? () {
                        Navigator.pop(context); // Go back to dashboard/POS
                      }
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
          _buildTab(null, 'Todos'),
          const SizedBox(width: 12),
          _buildTab('sale', 'Ventas'),
          const SizedBox(width: 12),
          _buildTab('purchase', 'Compras'),
          const SizedBox(width: 12),
          _buildTab('expense', 'Gastos'),
          const SizedBox(width: 12),
          _buildTab('payment', 'Pagos'),
        ],
      ),
    );
  }

  Widget _buildTab(String? type, String label) {
    final bool isActive = selectedType == type;

    // Active Styles (Glass)
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
            // Spacer to center text vertically accounting for underline
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

class _GlassTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool isDark;

  const _GlassTransactionCard(
      {required this.transaction, required this.isDark});

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
    }
  }

  Future<void> _handlePrint(BuildContext context) async {
    if (transaction is! Sale) return;

    final sale = transaction as Sale;

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPreviewScreen(transaction: sale),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al abrir la vista previa: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showOptions(BuildContext context) {
    // Only support options for Sale for now, or adapt helper
    // The design shows "Cancel", "Duplicate", etc.
    // For now we wire up what we have.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionOptionsBottomSheet(
        onEdit: () {
          // TODO: Navigate to Edit screen or POS with loaded data
        },
        onCancel: () {
          // TODO: Implement cancel logic
        },
        onSharePdf: () => _handlePrint(context), // Reuse print logic
        onDuplicate: () {
          // TODO: Implement duplicate logic
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Data Parsing
    String typeLabel = '';
    IconData typeIcon = Icons.help_outline;
    Color typeColor = Colors.grey;
    String name = '';
    String dateStr = DateFormat('MMM dd, HH:mm').format(transaction.date);
    double amount = transaction.totalAmount;
    String amountStr = 'Bs. ${amount.toStringAsFixed(2)}';
    bool isPositive = false;

    switch (transaction.type) {
      case TransactionType.purchase:
        typeLabel = 'COMPRA';
        typeIcon = Icons.inventory_2; // Use distinct icon for purchase
        typeColor = const Color(0xFFFF6B6B); // Red
        name = (transaction as Purchase).supplierName ?? 'Proveedor General';
        isPositive = false;
        break;
      case TransactionType.sale:
        typeLabel = 'VENTA';
        typeIcon = Icons.attach_money;
        typeColor = const Color(0xFF51CF66); // Green
        name = (transaction as Sale).customerName ?? 'Cliente General';
        isPositive = true;
        break;
      case TransactionType.expense:
        typeLabel = 'GASTO';
        typeIcon = Icons.money_off;
        typeColor = const Color(0xFFFFA94D); // Yellow
        name = (transaction as Expense).description;
        isPositive = false;
        break;
      case TransactionType.payment:
        typeLabel = 'PAGO';
        typeIcon = Icons.payment;
        typeColor = const Color(0xFF4A90E2); // Blue
        name = 'Abono de Cliente';
        isPositive = true; // Payments are money IN
        break;
      case TransactionType.order:
        typeLabel = 'PEDIDO';
        typeIcon = Icons.shopping_bag_outlined; // Or another suitable icon
        typeColor = const Color(0xFF8C52FF); // Purple or another distinct color
        name = (transaction as Order).supplierName ??
            'Proveedor General'; // Orders have suppliers
        isPositive =
            false; // Orders are typically not direct money in/out until fulfilled
        break;
    }

    final heroTag = '${transaction.type.name}_${transaction.id}_icon';

    final amountColor =
        isPositive ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B);
    final prefix = isPositive ? '+' : '-';

    // 2. Styles
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
                  // Left Border Indicator
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
                        // Row 1: Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Badge
                            Row(
                              children: [
                                Hero(
                                  tag: heroTag,
                                  child: Icon(typeIcon,
                                      size: 18, color: secondaryGray),
                                ),
                                const SizedBox(width: 6),
                                Text('$typeLabel • #${transaction.id}',
                                    style: const TextStyle(
                                        color: secondaryGray,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            // Actions
                            Row(
                              children: [
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

                        // Row 2: Name
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Row 3: Date
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: subtitleColor,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Separator
                        Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2)),

                        const SizedBox(height: 12),

                        // Row 4: Amount
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
                        )
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
}
