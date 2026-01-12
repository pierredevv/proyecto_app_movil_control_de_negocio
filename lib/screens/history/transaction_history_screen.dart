import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final DatabaseService _db = DatabaseService();

  // Filters
  DateTimeRange? _dateRange;
  String? _selectedType; // null = all
  bool _isLoading = false;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTransactions(
        limit: 100,
        type: _selectedType,
        startDate: _dateRange?.start.millisecondsSinceEpoch,
        endDate: _dateRange?.end.millisecondsSinceEpoch,
      );
      if (mounted) {
        setState(() {
          _transactions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        // Ensure strictly inclusive for entire days
        _dateRange = DateTimeRange(
            start: DateTime(
                picked.start.year, picked.start.month, picked.start.day),
            end: DateTime(
                picked.end.year, picked.end.month, picked.end.day, 23, 59, 59));
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Transacciones'),
        actions: [
          IconButton(
            icon: Icon(
                _dateRange == null ? Icons.date_range : Icons.event_available),
            onPressed: _pickDateRange,
            tooltip: 'Filtrar por Fecha',
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _dateRange = null);
                _loadData();
              },
              tooltip: 'Limpiar Fecha',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(
                  label: 'Todos',
                  isSelected: _selectedType == null,
                  onSelected: () {
                    setState(() => _selectedType = null);
                    _loadData();
                  },
                ),
                _FilterChip(
                  label: 'Ventas',
                  isSelected: _selectedType == 'sale',
                  onSelected: () {
                    setState(() => _selectedType = 'sale');
                    _loadData();
                  },
                ),
                _FilterChip(
                  label: 'Compras',
                  isSelected: _selectedType == 'purchase',
                  onSelected: () {
                    setState(() => _selectedType = 'purchase');
                    _loadData();
                  },
                ),
                _FilterChip(
                  label: 'Gastos',
                  isSelected: _selectedType == 'expense',
                  onSelected: () {
                    setState(() => _selectedType = 'expense');
                    _loadData();
                  },
                ),
                _FilterChip(
                  label: 'Pagos',
                  isSelected: _selectedType == 'payment',
                  onSelected: () {
                    setState(() => _selectedType = 'payment');
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No se encontraron registros',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    return _TransactionTile(transaction: t);
                  },
                ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primary : null,
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String title;
    String subtitle = DateFormat('dd MMM, HH:mm').format(transaction.date);
    String amountPrefix = '';

    // Determine Logic based on Type
    switch (transaction.type) {
      case TransactionType.sale:
        icon = Icons.arrow_upward;
        color = const Color(0xFF047857); // Green
        title = (transaction as Sale).customerName ?? 'Venta General';
        amountPrefix = '+';
        break;
      case TransactionType.purchase:
        icon = Icons.arrow_downward;
        color = AppTheme.primary; // Blue
        title = (transaction as Purchase).supplierName ?? 'Compra';
        amountPrefix = '-';
        break;
      case TransactionType.expense:
        icon = Icons.money_off;
        color = Colors.redAccent;
        title = (transaction as Expense).description;
        amountPrefix = '-';
        break;
      case TransactionType.payment:
        icon = Icons.attach_money;
        color = const Color(0xFF047857);
        // Payment usually means customer paid debt => Income for us
        // Wait, Payment in our system logic (from Phase 8.1): "Decreases Customer Debt", logs as "Payment".
        // It is money IN.
        title = 'Pago Cliente';
        amountPrefix = '+';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(
          '$amountPrefix Bs. ${transaction.totalAmount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }
}
