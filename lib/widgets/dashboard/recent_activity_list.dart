import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';
import '../../screens/history/transaction_history_screen.dart';
import '../../screens/sales/sale_detail_screen.dart';
import '../../screens/purchases/purchase_details_screen.dart';
import '../../screens/customers/customer_ledger_screen.dart';

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
                if (t.status == 'PARTIAL') {
                  typeLabel = 'VENTA · PARCIAL';
                } else if (t.status == 'CREDIT') {
                  typeLabel = 'VENTA · CRÉDITO';
                } else {
                  typeLabel = 'VENTA';
                }
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
    
    Color accentColor;
    if (isSale) {
      if (transaction.status == 'PARTIAL') {
        accentColor = const Color(0xFFF59F00); // orange
      } else if (transaction.status == 'CREDIT') {
        accentColor = Colors.blueAccent;
      } else {
        accentColor = AppTheme.greenAccent;
      }
    } else {
      accentColor = AppTheme.redAccent;
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final heroTag = '${transaction.type.name}_${transaction.id}_icon';
        if (isSale && transaction is Sale) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaleDetailScreen(
                sale: transaction,
                heroTag: heroTag,
              ),
            ),
          );
        } else if (transaction is Purchase) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseDetailsScreen(
                purchase: transaction,
                heroTag: heroTag,
              ),
            ),
          );
        } else if (transaction is Expense || transaction is Payment) {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: Text(transaction is Expense
                          ? 'Detalle de Gasto'
                          : 'Detalle de Pago'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Monto: Bs. ${transaction.totalAmount.toStringAsFixed(2)}'),
                          Text(
                              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}'),
                          if (transaction is Expense)
                            Text('Descripción: ${transaction.description}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TransactionHistoryScreen()));
                          },
                          child: const Text('Ir al Historial'),
                        )
                      ]));
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
                          Hero(
                            tag:
                                '${transaction.type.name}_${transaction.id}_icon',
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          accentColor.withValues(alpha: 0.3)),
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
                          if (isSale && transaction is Sale && (transaction.status == 'PARTIAL' || transaction.status == 'CREDIT'))
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pagado: Bs. ${transaction.amountPaid.toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11)),
                                Text('Pendiente: Bs. ${transaction.pendingAmount.toStringAsFixed(2)}', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ]
                            ))
                          else
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
                      
                      // Row 4: Collect Installment Button
                      if (isSale && transaction is Sale && (transaction.status == 'PARTIAL' || transaction.status == 'CREDIT') && transaction.customerId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CustomerLedgerScreen(
                                      customerId: transaction.customerId!,
                                      customerName: transaction.customerName ?? 'Cliente',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.payment_rounded, size: 16, color: accentColor),
                              label: Text('Cobrar Cuota', style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: accentColor.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
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
