import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final Product product;

  const StockAdjustmentScreen({super.key, required this.product});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  String _selectedReason = 'Vencimiento';
  bool _isAddition = false; // false = subtraction (Loss/Expiration), true = addition (Correction)
  bool _isLoading = false;

  final List<String> _reasons = [
    'Pérdida',
    'Vencimiento',
    'Robo',
    'Corrección',
    'Muestra / Cortesía',
    'Otro'
  ];

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _deltaBaseUnits {
    final qtyInfo = double.tryParse(_quantityController.text) ?? 0.0;
    // We adjust in Base Units, but the user is typing in Sales Units usually.
    // Assuming UI lets them type in their primary Sale Unit.
    final deltaSalesUnits = _isAddition ? qtyInfo : -qtyInfo;
    return deltaSalesUnits * widget.product.unitsPerSaleUnit;
  }

  double get _newStockBaseUnits {
    return widget.product.stock + _deltaBaseUnits;
  }
  
  double get _newStockSalesUnits {
    return _newStockBaseUnits / widget.product.unitsPerSaleUnit;
  }

  Future<void> _submitAdjustment() async {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad válida mayor a 0')),
      );
      return;
    }

    if (_newStockBaseUnits < -0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: El stock resultante sería negativo (${_newStockSalesUnits.toStringAsFixed(2)} ${widget.product.saleUnit})'),
          backgroundColor: AppTheme.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<InventoryProvider>().adjustStock(
        widget.product.id!,
        _deltaBaseUnits,
        _selectedReason,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewColor = _newStockBaseUnits < 0 
        ? AppTheme.redAccent 
        : (_isAddition ? AppTheme.greenAccent : Colors.orangeAccent);

    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        title: const Text('Ajuste de Stock'),
        backgroundColor: const Color(0xFF1E2432),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Info Glass Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x1AFFFFFF), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stock Actual:',
                                style: TextStyle(color: Colors.white70)),
                            Text(
                              '${widget.product.stockInSaleUnits.toStringAsFixed(2)} ${widget.product.saleUnit}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Toggle Entrada/Salida
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isAddition = true;
                            if (_selectedReason == 'Vencimiento' || _selectedReason == 'Pérdida') {
                              _selectedReason = 'Corrección';
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isAddition ? AppTheme.greenAccent.withAlpha(50) : const Color(0xFF1E2432),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isAddition ? AppTheme.greenAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.add_circle_outline, color: AppTheme.greenAccent),
                                SizedBox(height: 4),
                                Text('Entrada', style: TextStyle(color: AppTheme.greenAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isAddition = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: !_isAddition ? AppTheme.redAccent.withAlpha(50) : const Color(0xFF1E2432),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !_isAddition ? AppTheme.redAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.remove_circle_outline, color: AppTheme.redAccent),
                                SizedBox(height: 4),
                                Text('Salida', style: TextStyle(color: AppTheme.redAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quantity Field
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Cantidad a ${_isAddition ? "sumar" : "restar"} (${widget.product.saleUnit})',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E2432),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(_isAddition ? Icons.add : Icons.remove, color: Colors.white54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reason Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedReason,
                    dropdownColor: const Color(0xFF2E384D),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Motivo del Ajuste',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E2432),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReason = val);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Note Field
                  TextField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nota (Opcional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E2432),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: previewColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: previewColor.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stock Final Resultante:',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                        Text(
                          '${_newStockSalesUnits.toStringAsFixed(2)} ${widget.product.saleUnit}',
                          style: TextStyle(
                              color: previewColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submitAdjustment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar Ajuste', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
