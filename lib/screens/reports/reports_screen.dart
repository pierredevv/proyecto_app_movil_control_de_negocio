import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';

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
      context.read<DashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151924),
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
              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
          : RefreshIndicator(
              color: const Color(0xFF4ECDC4),
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
                  ).animate().fade(duration: 400.ms, delay: 100.ms),
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
                                  color: Color(0xFFA0A8C1), fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(delay: 200.ms)
                  else
                    ...provider.recentTransactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final t = entry.value;

                      final isSale = t.type.name == 'sale';
                      final iconData =
                          isSale ? Icons.arrow_outward : Icons.south_west;
                      final iconColor = isSale
                          ? const Color(0xFF51CF66)
                          : const Color(0xFFFF6B6B);
                      final titleText = isSale ? 'Venta' : 'Compra / Gasto';

                      Widget tile = _AnimatedTransactionTile(
                        iconData: iconData,
                        iconColor: iconColor,
                        titleText: titleText,
                        dateText:
                            DateFormat('dd MMM yyyy • HH:mm').format(t.date),
                        amount: t.totalAmount,
                        isPositive: isSale,
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
                    color: Color(0xFF6B7494),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Balance Display
                Text(
                  '\$${provider.netBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: isPositive
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFFFF6B6B),
                    shadows: [
                      Shadow(
                        color: (isPositive
                                ? const Color(0xFF4ECDC4)
                                : const Color(0xFFFF6B6B))
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                ),
                const Text(
                  'Balance Neto',
                  style: TextStyle(color: Color(0xFFA0A8C1), fontSize: 14),
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
                    _buildMetricCol(
                      label: 'Ventas',
                      value: provider.totalSalesToday,
                      color: const Color(0xFF51CF66),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    _buildMetricCol(
                      label: 'Compras',
                      value: provider.totalPurchasesToday,
                      color: const Color(0xFFFF6B6B),
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
      {required String label, required double value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFA0A8C1), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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

  const _AnimatedTransactionTile({
    required this.iconData,
    required this.iconColor,
    required this.titleText,
    required this.dateText,
    required this.amount,
    required this.isPositive,
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
      onTapUp: (_) => setState(() => _isPressed = false),
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
                            color: Color(0xFFA0A8C1),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.isPositive ? '+' : '-'}\$${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: widget.isPositive
                          ? const Color(0xFF51CF66)
                          : const Color(0xFFFF6B6B),
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
