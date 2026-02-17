import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';
import '../../screens/history/transaction_history_screen.dart';
import '../../screens/sales/sale_detail_screen.dart';

class RecentActivityList extends StatelessWidget {
  final List<Transaction> transactions;

  const RecentActivityList({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actividad Reciente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TransactionHistoryScreen()),
                  );
                },
                child: const Text(
                  'Ver Todo',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Transaction List
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No hay actividad reciente',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final t = entry.value;

              String name = 'Transacción';
              String typeLabel = 'OTRO';
              bool isSale = false;

              if (t is Sale) {
                name = t.customerName ?? 'Cliente Ocasional';
                typeLabel = 'VENTA';
                isSale = true;
              } else if (t is Purchase) {
                name = t.supplierName ?? 'Proveedor Ocasional';
                typeLabel = 'COMPRA';
              } else if (t is Expense) {
                name = t.description;
                typeLabel = 'GASTO';
              } else if (t is Payment) {
                name = 'Pago de Deuda';
                typeLabel = 'PAGO';
              }

              final currencyFormat = NumberFormat.currency(
                  symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');

              return _buildTransactionCard(
                context,
                transaction: t, // Pass full object
                name: name,
                date: DateFormat('dd/MM HH:mm').format(t.date),
                type: typeLabel,
                number: '#${t.id}',
                total: currencyFormat.format(t.totalAmount),
                isSale: isSale,
                delay: index * 100,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context,
      {required Transaction transaction,
      required String name,
      required String date,
      required String type,
      required String number,
      required String total,
      required bool isSale,
      required int delay}) {
    final accentColor = isSale ? AppTheme.greenAccent : AppTheme.redAccent;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (isSale && transaction is Sale) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  SaleDetailScreen(sale: transaction),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve)); // Slide from right

                var offsetAnimation = animation.drive(tween);
                var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeIn),
                );

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 350),
              reverseTransitionDuration: const Duration(milliseconds: 350),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        // Glassmorphism Decoration
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0x26FFFFFF) // White 15% opacity
              : Colors
                  .white, // Keep white for light mode or adapt? usually glass is used on dark
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0x1AFFFFFF) // White 10% opacity
                : Colors.black.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Stack(
              children: [
                // Side Border
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(color: accentColor),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name and Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[200]
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Row 2: Badge and Number
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            number,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Row 3: Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(child: Container()), // Spacer
                          Text(
                            'Total - ',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          Hero(
                            tag:
                                'transaction-${number.replaceAll("#", "")}-total',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                total,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms, delay: Duration(milliseconds: 800 + delay))
          .slideX(begin: -0.1, end: 0),
    );
  }
}
