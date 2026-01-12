import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class FinancialSummary extends StatelessWidget {
  const FinancialSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FinancialCard(
            label: 'Ventas de Hoy',
            amount: 'Bs. ${provider.totalSalesToday.toStringAsFixed(2)}',
            icon: Icons.arrow_upward,
            color: AppTheme.emerald,
            bgColor: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFD1FAE5),
          ),
          const SizedBox(width: 12),
          _FinancialCard(
            label: 'Compras de Hoy',
            amount: 'Bs. ${provider.totalPurchasesToday.toStringAsFixed(2)}',
            icon: Icons.arrow_downward,
            color: AppTheme.primary,
            bgColor: const Color(0xFFFFF1F2),
            borderColor: const Color(0xFFFFE4E6),
          ),
          const SizedBox(width: 12),
          _FinancialCard(
            label: 'Balance Diario',
            amount: 'Bs. ${provider.netBalance.toStringAsFixed(2)}',
            icon: provider.netBalance >= 0
                ? Icons.trending_up
                : Icons.trending_down,
            color: provider.netBalance >= 0 ? Colors.blue : Colors.orange,
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
          ),
        ],
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;

  // Hack for simpler color passing
  final Color colorMain;

  const _FinancialCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    Color? color,
  }) : colorMain = color ?? Colors.green;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Adjust colors for dark mode
    final bg = isDark ? colorMain.withValues(alpha: 0.1) : bgColor;
    final border = isDark ? colorMain.withValues(alpha: 0.2) : borderColor;
    final text = isDark ? colorMain.withValues(alpha: 0.8) : colorMain;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: text),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
