import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';

class GlobalPaymentScreen extends StatefulWidget {
  final int? initialCustomerId;

  const GlobalPaymentScreen({
    super.key,
    this.initialCustomerId,
  });

  @override
  State<GlobalPaymentScreen> createState() => _GlobalPaymentScreenState();
}

class _GlobalPaymentScreenState extends State<GlobalPaymentScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  int? _selectedCustomerId;
  List<Sale> _pendingSales = [];
  final Map<int, double> _allocations = {};
  final Map<int, TextEditingController> _allocationControllers = {};
  
  bool _isLoading = false;
  String _paymentMethod = 'EFECTIVO';
  
  @override
  void initState() {
    super.initState();
    _amountController.addListener(_autoDistributeAmount);
    if (widget.initialCustomerId != null) {
      _selectedCustomerId = widget.initialCustomerId;
      _loadPendingSales();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (var controller in _allocationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPendingSales() async {
    if (_selectedCustomerId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final history = await _db.getCustomerHistory(_selectedCustomerId!);
      setState(() {
        _pendingSales = history
            .whereType<Sale>()
            .where((s) => s.status == 'PARTIAL' || s.status == 'CREDIT')
            .toList();
            
        // Setup controllers
        _allocations.clear();
        for (var controller in _allocationControllers.values) {
          controller.dispose();
        }
        _allocationControllers.clear();
        
        for (var sale in _pendingSales) {
          _allocations[sale.id!] = 0.0;
          final controller = TextEditingController(text: '0.00');
          controller.addListener(() => _onManualAllocationChange(sale.id!, controller.text));
          _allocationControllers[sale.id!] = controller;
        }
      });
      _autoDistributeAmount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar deudas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isAutoDistributing = false;

  void _autoDistributeAmount() {
    if (_isAutoDistributing || _pendingSales.isEmpty) return;
    if (_amountController.text.isEmpty) return;
    
    final totalDeposit = double.tryParse(_amountController.text) ?? 0.0;
    
    _isAutoDistributing = true;
    double remaining = totalDeposit;
    
    // Distribute FIFO (oldest first)
    for (var sale in _pendingSales) {
      if (remaining <= 0) {
        _allocations[sale.id!] = 0.0;
        _allocationControllers[sale.id!]!.text = '0.00';
        continue;
      }
      
      final allocation = (remaining >= sale.pendingAmount) ? sale.pendingAmount : remaining;
      _allocations[sale.id!] = allocation;
      _allocationControllers[sale.id!]!.text = allocation.toStringAsFixed(2);
      
      remaining -= allocation;
    }
    
    _isAutoDistributing = false;
    setState(() {});
  }

  void _onManualAllocationChange(int saleId, String val) {
    if (_isAutoDistributing) return;
    final amount = double.tryParse(val) ?? 0.0;
    _allocations[saleId] = amount;
    setState(() {}); // Rebuild to update sums
  }

  void _submitPayment() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un cliente.')));
      return;
    }

    final totalDeposit = double.tryParse(_amountController.text) ?? 0.0;
    if (totalDeposit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un monto válido.')));
      return;
    }

    double totalAllocated = _allocations.values.fold(0.0, (sum, val) => sum + val);
    
    // Add small tolerance for floating point comparisons
    if ((totalAllocated - totalDeposit).abs() > 0.01 && totalAllocated > totalDeposit) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('El monto distribuido (Bs. ${totalAllocated.toStringAsFixed(2)}) supera al depósito total.'))
       );
       return;
    }

    setState(() => _isLoading = true);
    try {
      await _db.receiveGlobalPayment(
        customerId: _selectedCustomerId!,
        totalAmount: totalDeposit,
        paymentMethod: _paymentMethod,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        allocations: _allocations,
      );

      if (mounted) {
        await context.read<CustomerProvider>().loadCustomers();
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago global registrado exitosamente.')),
      );
      Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;
    final double totalAllocated = _allocations.values.fold(0.0, (sum, val) => sum + val);
    final double totalDeposit = double.tryParse(_amountController.text) ?? 0.0;
    final double unallocated = totalDeposit - totalAllocated;

    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Registrar Pago Global'),
        backgroundColor: const Color(0xFF1E2432),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 60),
            child: Column(
              children: [
              // Header Card Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2432),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  )
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCustomerId,
                      dropdownColor: const Color(0xFF2E384D),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF151924),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: customers.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        setState(() => _selectedCustomerId = val);
                        await _loadPendingSales();
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Monto Total Recibido (Bs)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF151924),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        prefixIcon: Icon(Icons.payments, color: AppTheme.greenAccent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      dropdownColor: const Color(0xFF2E384D),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Método',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF151924),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: ['EFECTIVO', 'QR', 'TRANSFERENCIA'].map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nota (Opcional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF151924),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Unallocated Warning
              if (unallocated > 0.01)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hay Bs. ${unallocated.toStringAsFixed(2)} del depósito sin asignar a ninguna deuda. Se creará como saldo a favor en el estado de cuenta.',
                            style: const TextStyle(color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Allocations List
              _selectedCustomerId == null 
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Seleccione un cliente para ver sus deudas.', style: TextStyle(color: Colors.white54))))
                : _pendingSales.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Este cliente no tiene deudas pendientes.', style: TextStyle(color: Colors.white54))))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingSales.length,
                      itemBuilder: (context, index) {
                        final sale = _pendingSales[index];
                        final controller = _allocationControllers[sale.id!];
                        
                        return Card(
                          color: const Color(0xFF1E2432),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Venta #${sale.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('Total: Bs. ${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                      Text('Saldo Pendiente: Bs. ${sale.pendingAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: AppTheme.greenAccent, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                      labelText: 'Abono',
                                      labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                                      filled: true,
                                      fillColor: Color(0xFF151924),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              
              // Bottom Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2432),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, -4))
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _selectedCustomerId == null ? null : _submitPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Confirmar Pago (Bs. ${totalDeposit.toStringAsFixed(2)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ), // SingleChildScrollView
    );
  }
}
