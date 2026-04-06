import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

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
      final records = await _db.getEntityLedgers(widget.entityType, widget.entityId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Estado de Cuenta Completo'),
        backgroundColor: const Color(0xFF1E2432),
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
        color: const Color(0xFF1E2432),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            widget.entityType == 'CUSTOMER' ? Icons.person : Icons.local_shipping,
            color: widget.entityType == 'CUSTOMER' ? AppTheme.blueIcon : Colors.orangeAccent,
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
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
        final date = DateTime.fromMillisecondsSinceEpoch(item['date']);
        final debit = (item['debit_amount'] as num).toDouble();
        final credit = (item['credit_amount'] as num).toDouble();
        final balance = (item['materialized_running_balance'] as num).toDouble();
        final type = item['transaction_source_type'];
        final isCustomer = widget.entityType == 'CUSTOMER';

        // Styling logic based on transaction type and entity type
        IconData icon;
        Color color;
        String amountText;

        // In accounting: DEBIT increases Customer Debt but decreases Supplier Debt
        if (type == 'INVOICE' || type == 'PURCHASE') {
          icon = Icons.receipt_long;
          color = AppTheme.redAccent;
          amountText = isCustomer ? '+ Bs. ${debit.toStringAsFixed(2)}' : '+ Bs. ${credit.toStringAsFixed(2)}';
        } else {
           icon = Icons.payment;
           color = AppTheme.greenAccent;
           amountText = isCustomer ? '- Bs. ${credit.toStringAsFixed(2)}' : '- Bs. ${debit.toStringAsFixed(2)}';
        }

        return Card(
          color: const Color(0xFF1E2432),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['note'] ?? 'Transacción',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(date),
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amountText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Saldo: Bs. ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
