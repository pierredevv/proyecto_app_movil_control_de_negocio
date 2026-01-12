import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../providers/customer_provider.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final int customerId;

  const CustomerHistoryScreen({super.key, required this.customerId});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Transaction>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<Transaction>> _fetchHistory() async {
    return await _db.getCustomerHistory(widget.customerId);
  }

  Future<void> _showPaymentDialog() async {
    final controller = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Monto del Pago (Bs.)',
            prefixText: 'Bs. ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldSave == true && controller.text.isNotEmpty) {
      final amount = double.tryParse(controller.text);
      if (amount != null && amount > 0) {
        if (!mounted) return;
        try {
          await context
              .read<CustomerProvider>()
              .addPayment(widget.customerId, amount);
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pago registrado exitosamente')),
          );
          // Refresh history
          setState(() {
            _historyFuture = _fetchHistory();
          });
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Transacciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(),
        icon: const Icon(Icons.payment),
        label: const Text('Registrar Pago'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Transaction>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final transactions = snapshot.data ?? [];
          if (transactions.isEmpty) {
            return const Center(child: Text('Sin transacciones registradas.'));
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];

              if (transaction is Sale) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag, color: Colors.blue),
                    title: const Text(
                      'Venta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(DateFormat('dd MMM yyyy, HH:mm')
                        .format(transaction.date)),
                    trailing: Text(
                      'Bs. ${transaction.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ),
                );
              } else if (transaction is Payment) {
                return Card(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: ListTile(
                    leading: const Icon(Icons.payment, color: Colors.green),
                    title: const Text(
                      'Pago Recibido',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    subtitle: Text(DateFormat('dd MMM yyyy, HH:mm')
                        .format(transaction.date)),
                    trailing: Text(
                      '- Bs. ${transaction.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
