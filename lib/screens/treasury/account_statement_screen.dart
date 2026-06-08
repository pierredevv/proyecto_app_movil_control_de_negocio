import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../sales/sale_detail_screen.dart';
import '../purchases/purchase_details_screen.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_helper.dart';

class AccountStatementScreen extends StatefulWidget {
  final int entityId;
  final String entityName;
  final String entityType; // 'CUSTOMER' or 'SUPPLIER'

  const AccountStatementScreen({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.entityType,
  });

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _ledgers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedgers();
  }

  Future<void> _loadLedgers() async {
    setState(() => _isLoading = true);
    try {
      final records =
          await _db.getEntityLedgers(widget.entityType, widget.entityId);
      if (mounted) {
        setState(() {
          _ledgers = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading statements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// Uses the existing [DatabaseService.getTransactionById] method (O(1) by PK)
  /// to load the full Sale or Purchase and navigate to its detail screen.
  /// Only called for INVOICE and PURCHASE ledger source types.
  Future<void> _navigateToTransactionDetail(Map<String, dynamic> item) async {
    final type = item['transaction_source_type'] as String? ?? '';
    final refId = item['transaction_reference_id'] as int?;

    if (refId == null) return;

    setState(() => _isLoading = true);

    try {
      // getTransactionById does a single PK lookup — very efficient
      final transaction = await _db.getTransactionById(refId);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (transaction == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se encontró la transacción #$refId'),
          ),
        );
        return;
      }

      if (type == 'INVOICE' && transaction is Sale) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleDetailScreen(sale: transaction),
          ),
        );
      } else if (type == 'PURCHASE' && transaction is Purchase) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseDetailsScreen(purchase: transaction),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el detalle: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Estado de Cuenta Completo'),
        backgroundColor: AppTheme.cardDark,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ledgers.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay registros históricos',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : _buildTimeline(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            widget.entityType == 'CUSTOMER'
                ? Icons.person
                : Icons.local_shipping,
            color: widget.entityType == 'CUSTOMER'
                ? AppTheme.blueIcon
                : Colors.orangeAccent,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entityName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.entityType == 'CUSTOMER' ? 'Cliente' : 'Proveedor',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ledgers.length,
      itemBuilder: (context, index) {
        final item = _ledgers[index];
        final date =
            DateTime.fromMillisecondsSinceEpoch(item['date'] as int);
        final debit = (item['debit_amount'] as num).toDouble();
        final credit = (item['credit_amount'] as num).toDouble();
        final balance =
            (item['materialized_running_balance'] as num).toDouble();
        final type = item['transaction_source_type'] as String? ?? '';
        final isCustomer = widget.entityType == 'CUSTOMER';

        // INVOICE = venta facturada (Cliente); PURCHASE = compra al proveedor
        final bool isTappable = type == 'INVOICE' || type == 'PURCHASE';

        IconData icon;
        Color color;
        String amountText;

        if (isTappable) {
          // Originating transaction — increases debt
          icon = Icons.receipt_long;
          color = AppTheme.redAccent;
          amountText = isCustomer
              ? '+ ${CurrencyHelper.simple(debit)}'
              : '+ ${CurrencyHelper.simple(credit)}';
        } else {
          // Payment / credit — reduces debt
          icon = Icons.payment;
          color = AppTheme.greenAccent;
          amountText = isCustomer
              ? '- ${CurrencyHelper.simple(credit)}'
              : '- ${CurrencyHelper.simple(debit)}';
        }

        return Card(
          color: AppTheme.cardDark,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // Only INVOICE / PURCHASE entries navigate to a detail screen
            onTap: isTappable
                ? () => _navigateToTransactionDetail(item)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ── Icon ────────────────────────────────────────────────
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 16),

                  // ── Text block ──────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['note'] ?? 'Transacción',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Chevron indicates tap is available
                            if (isTappable)
                              const Icon(Icons.chevron_right,
                                  color: Colors.white38, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Amounts ─────────────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountText,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saldo: ${CurrencyHelper.simple(balance)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
