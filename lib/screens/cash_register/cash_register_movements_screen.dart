import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';
import '../sales/sale_detail_screen.dart';
import '../purchases/purchase_details_screen.dart';
import '../orders/order_details_screen.dart';
import '../../widgets/responsive_layout.dart';

class CashRegisterMovementsScreen extends StatefulWidget {
  final DateTime openDate;
  final DateTime closeDate;
  final int registerId;
  final double openingBalance;
  final double expectedBalance;

  const CashRegisterMovementsScreen({
    super.key,
    required this.openDate,
    required this.closeDate,
    required this.registerId,
    required this.openingBalance,
    required this.expectedBalance,
  });

  @override
  State<CashRegisterMovementsScreen> createState() =>
      _CashRegisterMovementsScreenState();
}

class _CashRegisterMovementsScreenState
    extends State<CashRegisterMovementsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseService();
      final transactions = await db.getTransactionsByDateRange(
        widget.openDate,
        widget.closeDate,
      );
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar movimientos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Transaction> get _filteredTransactions {
    if (_filterType == null) return _transactions;
    return _transactions.where((t) {
      switch (_filterType) {
        case 'sale':
          return t.type == TransactionType.sale;
        case 'purchase':
          return t.type == TransactionType.purchase;
        case 'expense':
          return t.type == TransactionType.expense;
        case 'payment':
          return t.type == TransactionType.payment;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, dynamic> get _summary {
    double totalSales = 0;
    int salesCount = 0;
    double totalPurchases = 0;
    int purchasesCount = 0;
    double totalExpenses = 0;
    int expensesCount = 0;
    double totalPaymentsIn = 0;
    double totalPaymentsOut = 0;
    int paymentsCount = 0;

    for (var t in _transactions) {
      if (t.status == 'VOIDED') continue;
      switch (t.type) {
        case TransactionType.sale:
          final sale = t as Sale;
          totalSales += sale.totalAmount;
          salesCount++;
          break;
        case TransactionType.purchase:
          totalPurchases += t.totalAmount;
          purchasesCount++;
          break;
        case TransactionType.expense:
          totalExpenses += t.totalAmount;
          expensesCount++;
          break;
        case TransactionType.payment:
          final payment = t as Payment;
          paymentsCount++;
          if (payment.entityType == 'SUPPLIER') {
            totalPaymentsOut += payment.totalAmount;
          } else {
            totalPaymentsIn += payment.totalAmount;
          }
          break;
        case TransactionType.order:
          break;
      }
    }

    return {
      'totalSales': totalSales,
      'salesCount': salesCount,
      'totalPurchases': totalPurchases,
      'purchasesCount': purchasesCount,
      'totalExpenses': totalExpenses,
      'expensesCount': expensesCount,
      'totalPaymentsIn': totalPaymentsIn,
      'totalPaymentsOut': totalPaymentsOut,
      'paymentsCount': paymentsCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = CurrencyHelper.formatter;
    final timeFmt = DateFormat('dd MMM yyyy, HH:mm', CurrencyHelper.locale);
    final detailFmt = DateFormat('dd/MM/yyyy HH:mm', CurrencyHelper.locale);

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
                _buildHeader(context, isDark, timeFmt),
                const SizedBox(height: 16),
                _buildSummaryCards(isDark, fmt),
                const SizedBox(height: 16),
                _buildFilterChips(isDark),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? _buildSkeletonLoader(isDark)
                      : _filteredTransactions.isEmpty
                          ? _buildEmptyState(isDark)
                          : BoundedDesktopWrapper(
                              child: RefreshIndicator(
                                onRefresh: _loadTransactions,
                                color: AppTheme.redAccent,
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  itemCount: _filteredTransactions.length,
                                  itemBuilder: (context, index) {
                                    final t = _filteredTransactions[index];
                                    return _buildTransactionCard(
                                      t, isDark, fmt, detailFmt,
                                    ).animate().fadeIn(
                                        duration: 300.ms,
                                        delay: ((30 * index).clamp(0, 300)).ms);
                                  },
                                ),
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

  Widget _buildHeader(BuildContext context, bool isDark, DateFormat timeFmt) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.textSecondary : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
                    child: Icon(Icons.arrow_back, color: textColor, size: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movimientos Turno #${widget.registerId}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${timeFmt.format(widget.openDate)} — ${timeFmt.format(widget.closeDate)}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark, NumberFormat fmt) {
    final summary = _summary;
    final cardBg =
        isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.15) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.10)
        : Colors.grey.withValues(alpha: 0.2);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.textTertiary : (Colors.grey[600] ?? Colors.grey);

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSummaryCard(
            'Ventas',
            '${summary['salesCount']}',
            fmt.format(summary['totalSales']),
            AppTheme.greenAccent,
            Icons.point_of_sale,
            cardBg, cardBorder, textColor, subColor,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Compras',
            '${summary['purchasesCount']}',
            fmt.format(summary['totalPurchases']),
            AppTheme.redAccent,
            Icons.inventory_2,
            cardBg, cardBorder, textColor, subColor,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Gastos',
            '${summary['expensesCount']}',
            fmt.format(summary['totalExpenses']),
            AppTheme.warning,
            Icons.money_off,
            cardBg, cardBorder, textColor, subColor,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Pagos',
            '${summary['paymentsCount']}',
            'E: ${fmt.format(summary['totalPaymentsIn'])}\nS: ${fmt.format(summary['totalPaymentsOut'])}',
            AppTheme.blueIcon,
            Icons.payment,
            cardBg, cardBorder, textColor, subColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    String amount,
    Color color,
    IconData icon,
    Color cardBg,
    Color cardBorder,
    Color textColor,
    Color subColor,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count trans.',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(null, 'Todos'),
          const SizedBox(width: 8),
          _buildChip('sale', 'Ventas'),
          const SizedBox(width: 8),
          _buildChip('purchase', 'Compras'),
          const SizedBox(width: 8),
          _buildChip('expense', 'Gastos'),
          const SizedBox(width: 8),
          _buildChip('payment', 'Pagos'),
        ],
      ),
    );
  }

  Widget _buildChip(String? type, String label) {
    final isActive = _filterType == type;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.15)
              : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : (isDark ? Colors.white70 : Colors.grey[600]),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1200.ms, color: isDark ? Colors.white10 : Colors.black12);
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark ? Colors.white54 : Colors.black38;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: textColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No hay movimientos en este turno',
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    Transaction t,
    bool isDark,
    NumberFormat fmt,
    DateFormat detailFmt,
  ) {
    final cardBg =
        isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.15) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.10)
        : Colors.grey.withValues(alpha: 0.2);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.textTertiary : Colors.grey[600];
    final isVoided = t.status == 'VOIDED';

    IconData icon;
    Color iconColor;
    String typeLabel;
    String entityName;
    bool isPositive = false;

    switch (t.type) {
      case TransactionType.sale:
        final sale = t as Sale;
        icon = Icons.point_of_sale;
        iconColor = isVoided ? Colors.grey : AppTheme.greenAccent;
        typeLabel = sale.status == 'VOIDED'
            ? 'VENTA ANULADA'
            : sale.status == 'CREDIT'
                ? 'VENTA CRÉDITO'
                : sale.status == 'PARTIAL'
                    ? 'VENTA PARCIAL'
                    : 'VENTA';
        entityName = sale.customerName ?? 'Cliente General';
        isPositive = !isVoided;
        break;
      case TransactionType.purchase:
        final purchase = t as Purchase;
        icon = Icons.inventory_2;
        iconColor = isVoided ? Colors.grey : AppTheme.redAccent;
        typeLabel = purchase.status == 'VOIDED'
            ? 'COMPRA ANULADA'
            : purchase.status == 'CREDIT'
                ? 'COMPRA CRÉDITO'
                : purchase.status == 'PARTIAL'
                    ? 'COMPRA PARCIAL'
                    : 'COMPRA';
        entityName = purchase.supplierName ?? 'Proveedor General';
        isPositive = false;
        break;
      case TransactionType.expense:
        icon = Icons.money_off;
        iconColor = isVoided ? Colors.grey : AppTheme.warning;
        typeLabel = isVoided ? 'GASTO ANULADO' : 'GASTO';
        entityName = (t as Expense).description;
        isPositive = false;
        break;
      case TransactionType.payment:
        final payment = t as Payment;
        icon = Icons.payment;
        iconColor = isVoided ? Colors.grey : AppTheme.blueIcon;
        typeLabel = isVoided ? 'PAGO ANULADO' : 'PAGO';
        entityName = payment.entityType == 'SUPPLIER'
            ? 'Pago a Proveedor'
            : 'Abono de Cliente';
        isPositive = payment.entityType != 'SUPPLIER';
        break;
      case TransactionType.order:
        icon = Icons.shopping_bag_outlined;
        iconColor = isVoided ? Colors.grey : const Color(0xFF8C52FF);
        typeLabel = 'PEDIDO';
        entityName = (t as Order).supplierName ?? 'Proveedor General';
        isPositive = false;
        break;
    }

    final amountStr = fmt.format(t.totalAmount);
    final dateStr = detailFmt.format(t.date);
    final amountColor = isVoided
        ? Colors.grey
        : isPositive
            ? AppTheme.greenAccent
            : AppTheme.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isVoided ? cardBg.withValues(alpha: 0.5) : cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVoided
              ? Colors.red.withValues(alpha: 0.2)
              : cardBorder,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToDetail(t),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '#${t.id}',
                            style: TextStyle(
                              color: subColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entityName,
                        style: TextStyle(
                          color: isVoided ? Colors.grey : textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPositive ? '+' : '-'} $amountStr',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVoided) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ANULADA',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(Transaction t) {
    if (t is Sale) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SaleDetailScreen(sale: t),
        ),
      ).then((_) {
        if (mounted) _loadTransactions();
      });
    } else if (t is Purchase) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseDetailsScreen(purchase: t),
        ),
      ).then((_) {
        if (mounted) _loadTransactions();
      });
    } else if (t is Order) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(order: t),
        ),
      ).then((_) {
        if (mounted) _loadTransactions();
      });
    }
  }
}
