import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Content
          Consumer<DashboardProvider>(
            builder: (context, provider, child) {
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Ventas Últimos 7 Días',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);

    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 0,
      ),
      color: theme.scaffoldBackgroundColor
          .withValues(alpha: 0.95), // Slight opacity for scroll behind
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Gestión de Negocio',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none,
                    color: theme.colorScheme.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: theme.colorScheme.onSurface),
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
