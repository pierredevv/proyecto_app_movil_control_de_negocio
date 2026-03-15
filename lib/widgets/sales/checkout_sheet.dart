import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class CheckoutSheet extends StatefulWidget {
  final double totalAmount;

  const CheckoutSheet({super.key, required this.totalAmount});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _amountController = TextEditingController();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amountReceived {
    return double.tryParse(_amountController.text) ?? 0.0;
  }

  double get _pendingBalance {
    final pending = widget.totalAmount - _amountReceived;
    return pending > 0 ? pending : 0.0;
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = _pendingBalance > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirmar Cobro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total a cobrar:',
                  style: TextStyle(
                      fontSize: 16, color: theme.colorScheme.onSurface)),
              Text('Bs. ${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Received Field
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Monto recibido ahora (Bs.)',
              labelStyle:
                  TextStyle(color: theme.colorScheme.onSurface.withAlpha(150)),
              prefixIcon: const Icon(Icons.payments_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor:
                  theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            ),
          ),
          const SizedBox(height: 16),

          // Pending Balance
          if (isCredit) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.redAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.redAccent.withAlpha(50)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saldo Pendiente:',
                      style:
                          TextStyle(fontSize: 14, color: AppTheme.redAccent)),
                  Text('Bs. ${_pendingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.redAccent)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Due Date Selector
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: Text(
                  _dueDate == null
                      ? 'Establecer Fecha Límite (Opcional)'
                      : 'Vence: ${DateFormat('dd/MM/yyyy').format(_dueDate!)}',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.redAccent),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _selectDueDate,
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (_amountReceived < 0 ||
                        _amountReceived > widget.totalAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Monto inválido')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'amountReceived': _amountReceived,
                      'paymentDueDate': _dueDate,
                    });
                  },
                  child: Text(isCredit ? 'Cobro Parcial' : 'Cobrar Completo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
