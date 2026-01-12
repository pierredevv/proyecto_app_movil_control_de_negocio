import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/transaction_model.dart';
import '../../screens/history/transaction_history_screen.dart';
import '../../theme/app_theme.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final transactions = provider.recentTransactions;

    if (transactions.isEmpty) {
      return const Center(child: Text('No hay transacciones recientes'));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'ACTIVIDAD RECIENTE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
                letterSpacing: 1.0,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionHistoryScreen()),
                );
              },
              child: const Text(
                'Ver historial',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        ...transactions.map((t) {
          String name = 'Desconocido';
          String badgeText = '';
          Color badgeColor = Colors.grey;
          Color badgeTextColor = Colors.black;
          String amountPrefix = '';

          if (t is Sale) {
            name = t.customerName ?? 'Público General';
            badgeText = 'Venta';
            badgeColor = const Color(0xFFD1FAE5);
            badgeTextColor = const Color(0xFF047857);
            amountPrefix = 'Bs. ';
          } else if (t is Purchase) {
            name = t.supplierName ?? 'Proveedor Desconocido';
            badgeText = 'Compra';
            badgeColor = const Color(0xFFFFF1F2);
            badgeTextColor = AppTheme.primary;
            amountPrefix = '- Bs. ';
          } else if (t is Expense) {
            name = t.description;
            badgeText = 'Gasto';
            badgeColor = const Color(0xFFFEF3C7);
            badgeTextColor = const Color(0xFFD97706);
            amountPrefix = '- Bs. ';
          } else if (t is Payment) {
            name = 'Pago de Cliente';
            badgeText = 'Pago';
            badgeColor = const Color(0xFFDBEAFE);
            badgeTextColor = const Color(0xFF1E40AF);
            amountPrefix = 'Bs. ';
          }

          return Column(
            children: [
              _TransactionCard(
                title: name,
                badgeText: badgeText,
                badgeColor: badgeColor,
                badgeTextColor: badgeTextColor,
                number: '#${t.id}',
                date: _formatDate(t.date),
                total: '$amountPrefix${t.totalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    // Simple formatter, can use intl later
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

class _TransactionCard extends StatelessWidget {
  final String title;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;
  final String number;
  final String date;
  final String total;

  const _TransactionCard({
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.number,
    required this.date,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? badgeTextColor.withValues(alpha: 0.2)
                          : badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : badgeTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _ActionButton(icon: Icons.print, onTap: () {}),
                  const SizedBox(width: 8),
                  _ActionButton(icon: Icons.share, onTap: () {}),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color:
              isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
        ),
      ),
    );
  }
}
