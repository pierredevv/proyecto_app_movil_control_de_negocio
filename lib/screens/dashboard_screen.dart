import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/quick_access_grid.dart';
import '../widgets/dashboard/financial_summary.dart';
import '../widgets/dashboard/recent_transactions.dart';
import '../widgets/dashboard/analytics_chart.dart';
import '../../providers/dashboard_provider.dart';

import 'customers/customer_list_screen.dart';
import 'history/transaction_history_screen.dart';
import 'backup_manager_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActionButtons(),
                SizedBox(height: 20),
                QuickAccessGrid(),
                SizedBox(height: 20),
                FinancialSummary(),
                SizedBox(height: 20),
                AnalyticsChart(),
                SizedBox(height: 20),
                RecentTransactions(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 12,
          bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                        : const Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront,
                    color: isDark ? Colors.blue[400] : Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestion de Negocio App',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Tienda Principal',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.diamond,
                color: AppTheme.primary,
                bgColor: isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                    : const Color(0xFFFEE2E2),
                onTap: () {},
              ),
              const SizedBox(width: 8),
              const _NotificationButton(),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.settings,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
                bgColor: Colors.transparent,
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.backup),
                          title: const Text('Respaldo de Datos'),
                          subtitle:
                              const Text('Exportar base de datos a archivo'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BackupManagerScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {},
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.notifications,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              size: 28,
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TransactionHistoryScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.primary.withValues(alpha: 0.1),
              foregroundColor: AppTheme.primary,
              elevation: 0,
              side: const BorderSide(color: AppTheme.primary),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Historial Ventas'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerListScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              shape: const StadiumBorder(),
              backgroundColor: Theme.of(context).cardColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Clientes'),
          ),
        ),
      ],
    );
  }
}
