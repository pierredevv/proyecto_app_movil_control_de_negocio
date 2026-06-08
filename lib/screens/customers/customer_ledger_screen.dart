import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/glass_transaction_card.dart';
import 'package:intl/intl.dart';
import '../treasury/global_payment_screen.dart';
import '../treasury/account_statement_screen.dart';
import '../../main.dart'; // To access routeObserver
import '../../widgets/common/glass_dialog.dart';
import '../sales/sale_detail_screen.dart';
import '../../utils/currency_helper.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> with WidgetsBindingObserver, RouteAware {
  final DatabaseService _db = DatabaseService();
  List<Sale> _pendingSales = [];
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
    // Called when the top route has been popped off, and the current route shows up.
    if (mounted) {
      _loadLedger();
      context.read<CustomerProvider>().loadCustomers();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        _loadLedger();
        context.read<CustomerProvider>().loadCustomers();
      }
    }
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final history = await _db.getCustomerHistory(widget.customerId);
      // Filter only pending sales (PARTIAL or CREDIT)
      _pendingSales = history
          .whereType<Sale>()
          .where((s) => s.status == 'PARTIAL' || s.status == 'CREDIT')
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando estado de cuenta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReceivePaymentDialog(Sale sale) async {
    final controller =
        TextEditingController(text: sale.pendingAmount.toStringAsFixed(2));
    String selectedMethod = 'EFECTIVO';

    final result = await showGlassDialog<Map<String, dynamic>>(
      context: context,
      title: 'Cobrar cuota',
      content: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Venta #${sale.id} - Saldo a favor: ${CurrencyHelper.simple(sale.pendingAmount)}',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monto a cobrar (${CurrencyHelper.symbol})',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.blueIcon)),
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.blueIcon)),
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
          child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [AppTheme.blueIcon, Color(0xFF50A7EA)]),
          ),
          child: ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0 && val <= sale.pendingAmount + 0.01) {
                // UX #5 FIX: warn the user if they are entering slightly more than owed (credit generated)
                if (val > sale.pendingAmount + 0.001) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'ℹ️ Se generará un crédito de ${CurrencyHelper.simple((val - sale.pendingAmount))} a favor del cliente.'),
                      backgroundColor: Colors.blue[700],
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
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
        await _db.receiveSalePayment(sale.id!, result['amount'],
            note: 'Cobro de cuota', paymentMethod: result['method']);
        
        if (!mounted) return;

        // We also need to reload the customer debt globally
        if (mounted) {
          await context.read<CustomerProvider>().loadCustomers();
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

  /// Navigates to SaleDetailScreen and refreshes ledger on return.
  Future<void> _navigateToSaleDetail(
      BuildContext context, Sale sale) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)),
    );
    if (!mounted || !context.mounted) return;
    _loadLedger();
    context.read<CustomerProvider>().loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    // Get real-time debt
    final customers = context.watch<CustomerProvider>().customers;
    final idx = customers.indexWhere((c) => c.id == widget.customerId);
    final totalDebt = idx >= 0 ? customers[idx].totalDebt : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.payment),
        label: const Text('Cobro Global'),
        backgroundColor: AppTheme.blueIcon,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GlobalPaymentScreen(initialCustomerId: widget.customerId),
            ),
          );
          if (!mounted || !context.mounted) return;
          _loadLedger();
          context.read<CustomerProvider>().loadCustomers();
        },
      ),
      appBar: AppBar(
        title: Text('Estado de Cuenta: ${widget.customerName}'),
        backgroundColor: AppTheme.cardDark,
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
              children: [
                const Flexible(
                  child: Text('Deuda Total:',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(CurrencyHelper.simple(totalDebt),
                      style: const TextStyle(
                          color: AppTheme.redAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ),
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
                        entityId: widget.customerId,
                        entityName: widget.customerName,
                        entityType: 'CUSTOMER',
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
                : _pendingSales.isEmpty
                    ? const Center(
                        child: Text('No hay deudas pendientes',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _pendingSales.length,
                        itemBuilder: (context, index) {
                          final sale = _pendingSales[index];
                          final dueDateText = sale.paymentDueDate != null
                              ? 'Vence: ${DateFormat('dd/MM/yyyy').format(sale.paymentDueDate!)}'
                              : 'Sin fecha de vencimiento';

                          return GlassTransactionCard(
                            title: 'Venta #${sale.id}',
                            subtitle:
                                'Cobrado: ${CurrencyHelper.simple(sale.amountPaid)} | $dueDateText',
                            amount: sale.pendingAmount,
                            status: sale.status,
                            color: AppTheme.primary,
                            icon: Icons.receipt_long,
                            onTap: () => _navigateToSaleDetail(context, sale),
                            actionButtons: ElevatedButton.icon(
                              onPressed: () => _showReceivePaymentDialog(sale),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('Cobrar Cuota'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E384D),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 36),
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
