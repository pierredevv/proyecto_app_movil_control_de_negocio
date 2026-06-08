import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/transaction_model.dart';
import '../sales/sale_detail_screen.dart';
import '../purchases/purchase_details_screen.dart';
import 'aging_report_screen.dart';
import 'sales_period_report_screen.dart';
import 'valued_inventory_report_screen.dart';
import 'advanced_analytics_screen.dart';
import '../../theme/app_theme.dart';
import '../orders/order_details_screen.dart';
import '../../utils/currency_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DashboardProvider>();
      if (provider.recentTransactions.isEmpty) {
        provider.loadDashboardData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        title: const Text(
          'Reportes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.greenIcon))
          : RefreshIndicator(
              color: AppTheme.greenIcon,
              backgroundColor: const Color(0xFF1E2433),
              onRefresh: () async => await provider.loadDashboardData(),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _AnimatedSummaryCard(provider: provider)
                      .animate()
                      .fade(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, delay: 50.ms),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AgingReportScreen()),
                            );
                          },
                          icon: const Icon(Icons.assessment, size: 18),
                          label: const Text('Antigüedad\nde Deuda', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.cardDark,
                            foregroundColor: AppTheme.blueIcon,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color:
                                      AppTheme.blueIcon.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SalesPeriodReportScreen()),
                            );
                          },
                          icon: const Icon(Icons.trending_up, size: 18),
                          label: const Text('Ventas por\nPeriodo', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.cardDark,
                            foregroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color:
                                      AppTheme.success.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 75.ms),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ValuedInventoryReportScreen()),
                      );
                    },
                    icon: const Icon(Icons.inventory_2),
                    label: const Text('Reporte de Inventario Valorado'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.cardDark,
                      foregroundColor: AppTheme.blueIcon,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color:
                                AppTheme.blueIcon.withValues(alpha: 0.3)),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 100.ms),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdvancedAnalyticsScreen()),
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('Analítica Avanzada y Data Mining'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.cardDark,
                      foregroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 110.ms),
                  const SizedBox(height: 24),
                  const AnimatedOpacity(
                    opacity: 1.0,
                    duration: Duration(milliseconds: 300),
                    child: Text(
                      'Actividad Reciente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 125.ms),
                  const SizedBox(height: 12),
                  if (provider.recentTransactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Icon(Icons.history,
                                size: 64,
                                color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay transacciones aún',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(delay: 200.ms)
                  else
                    ...provider.recentTransactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final t = entry.value;

                      // N2 FIX: Supplier payments are outflows — only customer payments are inflows
                      bool isPositive;
                      if (t is Payment) {
                        isPositive = t.entityType != 'SUPPLIER';
                      } else {
                        isPositive = t.type.name == 'sale';
                      }
                      final iconData =
                          isPositive ? Icons.arrow_outward : Icons.south_west;
                      final iconColor = isPositive
                          ? AppTheme.success
                          : AppTheme.redAccent;
                      
                      String titleText = 'Transacción';
                      if (t is Sale) {
                        titleText = 'Venta';
                      } else if (t is Purchase) {
                        titleText = 'Compra';
                      } else if (t is Expense) {
                        titleText = 'Gasto';
                      } else if (t is Payment) {
                        titleText = 'Pago';
                      } else if (t is Order) {
                        titleText = 'Pedido';
                      }

                      Widget tile = _AnimatedTransactionTile(
                        iconData: iconData,
                        iconColor: iconColor,
                        titleText: titleText,
                        dateText:
                            DateFormat('dd MMM yyyy • HH:mm').format(t.date),
                        amount: t.totalAmount,
                        isPositive: isPositive,
                        onTap: () {
                          if (t is Sale) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: t)));
                          } else if (t is Purchase) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseDetailsScreen(purchase: t)));
                          } else if (t is Order) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: t)));
                          } else if (t is Expense || t is Payment) {
                            showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                        title: Text(t is Expense
                                            ? 'Detalle de Gasto'
                                            : 'Detalle de Pago'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Monto: ${CurrencyHelper.simple(t.totalAmount)}'),
                                            Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}'),
                                            if (t is Expense)
                                              Text('Descripción: ${t.description}'),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Cerrar')),
                                        ]));
                          }
                        },
                      );

                      if (index < 8) {
                        return tile
                            .animate()
                            .fade(
                                duration: 300.ms,
                                delay: (150 + (index * 50)).ms)
                            .slideY(
                                begin: 0.1,
                                end: 0,
                                delay: (150 + (index * 50)).ms);
                      }
                      return tile;
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class _AnimatedSummaryCard extends StatelessWidget {
  final DashboardProvider provider;

  const _AnimatedSummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isPositive = provider.netBalance >= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  'RESUMEN DEL DÍA',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Balance Display
                Text(
                  CurrencyHelper.simple(provider.netBalance),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: isPositive
                        ? AppTheme.greenIcon
                        : AppTheme.redAccent,
                    shadows: [
                      Shadow(
                        color: (isPositive
                                ? AppTheme.greenIcon
                                : AppTheme.redAccent)
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                ),
                const Text(
                  'Balance Neto (base caja)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),

                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 24),

                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // UX #3 FIX: Show accrual sales with a sub-label clarifying it includes A/R
                    Expanded(
                      child: _buildMetricCol(
                        label: 'Ventas',
                        sublabel: '(incl. crédito)',
                        value: provider.totalSalesToday,
                        color: AppTheme.success,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    // UX #3 FIX: Show cash received separately from accrual sales
                    Expanded(
                      child: _buildMetricCol(
                        label: 'Cobrado',
                        sublabel: '(efectivo hoy)',
                        value: provider.cashInToday,
                        color: AppTheme.greenIcon,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    Expanded(
                      child: _buildMetricCol(
                        label: 'Compras',
                        sublabel: '',
                        value: provider.totalPurchasesToday,
                        color: AppTheme.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(
      {required String label, String sublabel = '', required double value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyHelper.simple(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        if (sublabel.isNotEmpty)
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
          ),
      ],
    );
  }
}

class _AnimatedTransactionTile extends StatefulWidget {
  final IconData iconData;
  final Color iconColor;
  final String titleText;
  final String dateText;
  final double amount;
  final bool isPositive;
  final VoidCallback onTap;

  const _AnimatedTransactionTile({
    required this.iconData,
    required this.iconColor,
    required this.titleText,
    required this.dateText,
    required this.amount,
    required this.isPositive,
    required this.onTap,
  });

  @override
  State<_AnimatedTransactionTile> createState() =>
      _AnimatedTransactionTileState();
}

class _AnimatedTransactionTileState extends State<_AnimatedTransactionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _isPressed ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.iconData,
                        color: widget.iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.dateText,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.isPositive ? '+' : '-'}${CurrencyHelper.simple(widget.amount)}',
                    style: TextStyle(
                      color: widget.isPositive
                          ? AppTheme.success
                          : AppTheme.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
