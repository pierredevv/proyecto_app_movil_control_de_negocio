import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/dashboard/summary_glass_card.dart';
import '../widgets/dashboard/sales_trend_chart.dart';
import '../widgets/dashboard/quick_access_grid.dart';
import '../widgets/dashboard/recent_activity_list.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../providers/notification_provider.dart';
import '../../providers/inventory_provider.dart';
import 'reports/aging_report_screen.dart';
import '../../theme/app_theme.dart';

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
      context.read<NotificationProvider>().checkPendingSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient & Blobs
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppTheme.surfaceDeep,
                          AppTheme.surfaceSlate,
                          AppTheme.surfaceDeep,
                        ]
                      : [
                          const Color(0xFFF8FAFC),
                          const Color(0xFFE2E8F0),
                          const Color(0xFFF1F5F9),
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.blueIcon
                    .withValues(alpha: 0.1), // Primary Blue 10%
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blueIcon.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color:
                    AppTheme.redAccent.withValues(alpha: 0.08), // Coral 8%
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.redAccent.withValues(alpha: 0.15),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Content
          Consumer<DashboardProvider>(
            builder: (context, provider, child) {
              if (provider.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text('Error al cargar el resumen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(provider.errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => context.read<DashboardProvider>().loadDashboardData(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        )
                      ],
                    ),
                  ),
                );
              }

              double balancePct = 0.0;
              if (provider.totalSalesToday > 0) {
                balancePct =
                    (provider.totalSalesToday - provider.totalPurchasesToday) /
                        provider.totalSalesToday;
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await context.read<DashboardProvider>().loadDashboardData();
                  if (context.mounted) {
                    await context.read<NotificationProvider>().checkPendingSales();
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top +
                        80, // Dynamic header spacing
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

                    // ── Pending Sales Alert (Vyapar style) ──────────────
                    Consumer<NotificationProvider>(
                      builder: (context, notifProvider, child) {
                        final pendingCount = notifProvider.pendingSalesCount;
                        if (pendingCount == 0) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AgingReportScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.blueIcon
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.blueIcon
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.blueIcon
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: AppTheme.blueIcon,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tienes $pendingCount venta(s) pendiente(s) de cobro',
                                          style: const TextStyle(
                                            color: AppTheme.blueIcon,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Text(
                                          'Toca para ver el estado de la cartera',
                                          style: TextStyle(
                                              color: AppTheme.blueIcon,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: AppTheme.blueIcon),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Conditionally render Low Stock Alert
                    Consumer<InventoryProvider>(
                      builder: (context, invProvider, child) {
                        final lowStockCount =
                            invProvider.lowStockProducts.length;
                        if (lowStockCount == 0) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.redAccent
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.redAccent
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppTheme.redAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tienes $lowStockCount producto(s) con stock bajo',
                                      style: const TextStyle(
                                        color: AppTheme.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: AppTheme.redAccent),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

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
    final unreadCount = context.watch<NotificationProvider>().unreadCount;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      color: theme.scaffoldBackgroundColor
          .withValues(alpha: 0.95), // Slight opacity for scroll behind
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Gestión de Negocio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Stack(
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
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
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
