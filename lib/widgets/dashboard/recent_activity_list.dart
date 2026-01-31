import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';
import '../../screens/history/transaction_history_screen.dart';

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
      {required String name,
      required String date,
      required String type,
      required String number,
      required String total,
      required bool isSale,
      required int delay}) {
    final accentColor = isSale ? AppTheme.greenAccent : AppTheme.redAccent;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF242B3D).withValues(alpha: 0.5)
            : Colors.white, // White card in light mode
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
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
            padding: const EdgeInsets.fromLTRB(
                20, 16, 16, 16), // Extra left padding for border
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
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      number,
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                      'Total - ', // or just Total, design says "Total - Bs..." but alignment seems to imply label is small
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      total,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: Duration(milliseconds: 800 + delay))
        .slideX(begin: -0.1, end: 0);
  }
}
