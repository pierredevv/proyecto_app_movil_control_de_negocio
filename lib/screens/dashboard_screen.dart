import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/dashboard/summary_glass_card.dart';
import '../widgets/dashboard/sales_trend_chart.dart';
import '../widgets/dashboard/quick_access_grid.dart';
import '../widgets/dashboard/recent_activity_list.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: Stack(
        children: [
          // Content
          Consumer<DashboardProvider>(
            builder: (context, provider, child) {
              // Calculate percentages or use raw values
              // Logic for balance percentage could be: (Sales - Expenses - Purchases) / Sales ?
              // Or just mapping what we have.
              // For now let's use the provided fields.

              // Prevent division by zero if needed for percentage calculation
              // But SummaryGlassCard takes just values.
              // We need to calculate a "Balance Percentage" for the gauge.
              // Let's assume (Sales - Purchases) / Sales for "Profit Margin" notion,
              // or just use 0.0 if no sales.

              double balancePct = 0.0;
              if (provider.totalSalesToday > 0) {
                balancePct =
                    (provider.totalSalesToday - provider.totalPurchasesToday) /
                        provider.totalSalesToday;
              }

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top +
                      60 +
                      16, // Header height + spacing
                  bottom: 100, // Bottom nav spacing
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Today's Summary Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SummaryGlassCard(
                        salesTotal: provider.totalSalesToday,
                        purchasesTotal: provider.totalPurchasesToday,
                        balancePercentage: balancePct,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Sales Last 7 Days
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Ventas Últimos 7 Días',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SalesTrendChart(
                        weeklySales: provider
                            .weeklySales), // Ideally pass provider.weeklySales here
                    const SizedBox(height: 24),

                    // 3. Quick Access
                    const QuickAccessGrid(),
                    const SizedBox(height: 24),

                    // 4. Recent Activity
                    RecentActivityList(
                        transactions: provider.recentTransactions),
                  ],
                ),
              );
            },
          ),

          // Fixed Header
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _DashboardHeader(),
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
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 0,
      ),
      color: AppTheme.backgroundBlack.withValues(
          alpha:
              0.95), // Slight opacity for scroll behind? Or solid. Design says Fixed.
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Gestión de Negocio',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none,
                    color: AppTheme.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppTheme.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
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
