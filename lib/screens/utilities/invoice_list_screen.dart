import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import 'print_preview_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final DatabaseService _db = DatabaseService();
  final Color moduleColor = const Color(0xFF9B51E0); // Purple UI

  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final allTransactions = await _db.getTransactions(limit: 100);

      // Filter only Sales and Purchases for invoicing/receipts
      final filtered = allTransactions.where((t) {
        return t.type == TransactionType.sale ||
            t.type == TransactionType.purchase;
      }).toList();

      setState(() {
        _transactions = filtered;
      });
    } catch (e) {
      debugPrint('Error loading transactions for prints: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassCard({required Widget child, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Imprimir Facturas',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: moduleColor))
          : _transactions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: moduleColor,
                  onRefresh: _loadTransactions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      final isSale = t.type == TransactionType.sale;

                      String entityName = 'Consumidor Final';
                      if (t is Sale &&
                          t.customerName != null &&
                          t.customerName!.isNotEmpty) {
                        entityName = t.customerName!;
                      } else if (t is Purchase &&
                          t.supplierName != null &&
                          t.supplierName!.isNotEmpty) {
                        entityName = t.supplierName!;
                      }

                      return _buildGlassCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PrintPreviewScreen(transaction: t),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSale
                                    ? const Color(0xFF00C48C)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFFFF6B6B)
                                        .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSale
                                      ? const Color(0xFF00C48C)
                                          .withValues(alpha: 0.20)
                                      : const Color(0xFFFF6B6B)
                                          .withValues(alpha: 0.20),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isSale
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isSale
                                    ? const Color(0xFF00C48C)
                                    : const Color(0xFFFF6B6B),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSale
                                        ? 'Venta a $entityName'
                                        : 'Compra a $entityName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy - HH:mm')
                                        .format(t.date),
                                    style: const TextStyle(
                                        color: Color(0xFFA0A8C1), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${t.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.print,
                                    color: Color(0xFF6B7494), size: 18),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: moduleColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long,
                size: 60, color: moduleColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin Registros',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay ventas ni compras para imprimir.',
            style: TextStyle(color: Color(0xFFA0A8C1), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
