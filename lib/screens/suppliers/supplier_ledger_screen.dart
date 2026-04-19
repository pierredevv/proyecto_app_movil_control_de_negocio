import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../providers/supplier_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/glass_transaction_card.dart';
import 'package:intl/intl.dart';
import '../treasury/supplier_payment_screen.dart';
import '../treasury/account_statement_screen.dart';
import '../../main.dart'; // To access routeObserver
import '../../widgets/common/glass_dialog.dart';

class SupplierLedgerScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierLedgerScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierLedgerScreen> createState() => _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends State<SupplierLedgerScreen> with WidgetsBindingObserver, RouteAware {
  final DatabaseService _db = DatabaseService();
  List<Purchase> _pendingPurchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLedger();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) {
      _loadLedger();
      context.read<SupplierProvider>().loadSuppliers();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        _loadLedger();
        context.read<SupplierProvider>().loadSuppliers();
      }
    }
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final history = await _db.getSupplierHistory(widget.supplierId);
      // Filter only pending purchases (PARTIAL or CREDIT)
      _pendingPurchases = history
          .whereType<Purchase>()
          .where((p) => p.status == 'PARTIAL' || p.status == 'CREDIT')
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando cuentas por pagar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReceivePaymentDialog(Purchase purchase) async {
    final controller =
        TextEditingController(text: purchase.pendingAmount.toStringAsFixed(2));
    String selectedMethod = 'EFECTIVO';

    final result = await showGlassDialog<Map<String, dynamic>>(
      context: context,
      title: 'Pagar cuota',
      content: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Compra #${purchase.id} - Saldo a pagar: Bs. ${purchase.pendingAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monto a pagar (Bs.)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4A90E2))),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedMethod,
              dropdownColor: const Color(0xFF2E384D),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Método de Pago',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4A90E2))),
              ),
              items: ['EFECTIVO', 'QR', 'TRANSFERENCIA'].map((m) {
                return DropdownMenuItem(value: m, child: Text(m));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedMethod = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFFA0A8C1))),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF50A7EA)]),
          ),
          child: ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0 && val <= purchase.pendingAmount + 0.01) {
                Navigator.pop(context, {'amount': val, 'method': selectedMethod});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Monto inválido')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        await _db.receiveSupplierPayment(purchase.id!, result['amount'],
            note: 'Pago de cuota a proveedor', paymentMethod: result['method']);
        
        if (!mounted) return;

        // We also need to reload the supplier debt globally
        if (mounted) {
          await context.read<SupplierProvider>().loadSuppliers();
        }
        await _loadLedger();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get real-time debt
    final suppliers = context.watch<SupplierProvider>().suppliers;
    final idx = suppliers.indexWhere((s) => s.id == widget.supplierId);
    final totalDebt = idx >= 0 ? suppliers[idx].totalDebt : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.payment),
        label: const Text('Pago Global'),
        backgroundColor: const Color(0xFF4A90E2), // Corporate Blue
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupplierPaymentScreen(initialSupplierId: widget.supplierId),
            ),
          );
          if (!mounted || !context.mounted) return;
          _loadLedger();
          context.read<SupplierProvider>().loadSuppliers();
        },
      ),
      appBar: AppBar(
        title: Text('Cuentas por Pagar: ${widget.supplierName}'),
        backgroundColor: const Color(0xFF1E2432),
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.redAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.redAccent.withAlpha(50)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Deuda Total:',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('Bs. ${totalDebt.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.redAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountStatementScreen(
                        entityId: widget.supplierId,
                        entityName: widget.supplierName,
                        entityType: 'SUPPLIER',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 20),
                label: const Text('Ver Estado de Cuenta Completo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pendingPurchases.isEmpty
                    ? const Center(
                        child: Text('No hay cuentas por pagar',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _pendingPurchases.length,
                        itemBuilder: (context, index) {
                          final purchase = _pendingPurchases[index];
                          final dueDateText = purchase.paymentDueDate != null
                              ? 'Vence: ${DateFormat('dd/MM/yyyy').format(purchase.paymentDueDate!)}'
                              : 'Sin fecha de vencimiento';

                          return GlassTransactionCard(
                            title: 'Compra #${purchase.id}',
                            subtitle:
                                'Pagado: Bs. ${purchase.amountPaid.toStringAsFixed(2)} | $dueDateText',
                            amount: purchase.pendingAmount,
                            status: purchase.status,
                            color: AppTheme.redAccent,
                            icon: Icons.receipt_long,
                            actionButtons: Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A90E2),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.payment, size: 18),
                                label: const Text('Pagar Cuota'),
                                onPressed: () => _showReceivePaymentDialog(purchase),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
