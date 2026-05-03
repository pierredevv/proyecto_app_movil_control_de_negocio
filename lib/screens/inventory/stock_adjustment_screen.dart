import 'dart:ui' as ui;
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
  // UX #6: Optional unit cost for entry adjustments to enable WAC recalculation
  final TextEditingController _unitCostController = TextEditingController();

  String _selectedReason = 'Vencimiento';
  bool _isAddition =
      false; // false = subtraction (Loss/Expiration), true = addition (Correction)
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
    _unitCostController.dispose();
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
          content: Text(
              'Error: El stock resultante sería negativo (${_newStockSalesUnits.toStringAsFixed(2)} ${widget.product.saleUnit})'),
          backgroundColor: AppTheme.redAccent,
        ),
      );
      return;
    }

    // UX #6: Parse optional unit cost for WAC recalculation on entry adjustments
    final double? unitCost = _isAddition && _unitCostController.text.isNotEmpty
        ? (double.tryParse(_unitCostController.text) ?? 0.0) > 0
            ? double.tryParse(_unitCostController.text)
            : null
        : null;

    setState(() => _isLoading = true);

    try {
      await context.read<InventoryProvider>().adjustStock(
            widget.product.id!,
            _deltaBaseUnits,
            _selectedReason,
            note: _noteController.text.isNotEmpty ? _noteController.text : null,
            unitCost: unitCost,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ajuste de stock confirmado (${_isAddition ? "+" : "-"}${qty.toStringAsFixed(2)} ${widget.product.saleUnit})'),
            backgroundColor: AppTheme.greenAccent,
          ),
        );
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ajuste de Stock',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // N6 NOTE: This gradient is intentionally hardcoded dark (glassmorphism design language).
          // The scaffoldBackgroundColor (set above) only affects the Scaffold layer beneath.
          // If light theme support is added, conditionally show this gradient only in dark mode:
          //   if (Theme.of(context).brightness == Brightness.dark) ...
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A)
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                      blurRadius: 100,
                      spreadRadius: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Product Info Glass Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1.5),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Stock Actual:',
                                          style:
                                              TextStyle(color: Colors.white70)),
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
                                  if (_selectedReason == 'Vencimiento' ||
                                      _selectedReason == 'Pérdida') {
                                    _selectedReason = 'Corrección';
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _isAddition
                                        ? AppTheme.greenAccent.withAlpha(50)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isAddition
                                          ? AppTheme.greenAccent
                                          : Colors.white
                                              .withValues(alpha: 0.08),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.add_circle_outline,
                                          color: _isAddition
                                              ? AppTheme.greenAccent
                                              : Colors.white54),
                                      const SizedBox(height: 4),
                                      Text('Entrada',
                                          style: TextStyle(
                                              color: _isAddition
                                                  ? AppTheme.greenAccent
                                                  : Colors.white54,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isAddition = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: !_isAddition
                                        ? AppTheme.redAccent.withAlpha(50)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !_isAddition
                                          ? AppTheme.redAccent
                                          : Colors.white
                                              .withValues(alpha: 0.08),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.remove_circle_outline,
                                          color: !_isAddition
                                              ? AppTheme.redAccent
                                              : Colors.white54),
                                      const SizedBox(height: 4),
                                      Text('Salida',
                                          style: TextStyle(
                                              color: !_isAddition
                                                  ? AppTheme.redAccent
                                                  : Colors.white54,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Quantity Field
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: TextField(
                              controller: _quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText:
                                    'Cantidad a ${_isAddition ? "sumar" : "restar"} (${widget.product.saleUnit})',
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF4A90E2), width: 1.5),
                                ),
                                prefixIcon: Icon(
                                    _isAddition ? Icons.add : Icons.remove,
                                    color: Colors.white54),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // UX #6: Optional unit cost field for entry adjustments
                        if (_isAddition) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: TextField(
                                controller: _unitCostController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                                decoration: InputDecoration(
                                  labelText:
                                      'Costo Unitario (Bs.) — Opcional (recalcula CMPp)',
                                  labelStyle: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                  hintText:
                                      'Dejar vacío para mantener CMPp actual',
                                  hintStyle: const TextStyle(
                                      color: Colors.white30, fontSize: 13),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppTheme.greenAccent
                                            .withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppTheme.greenAccent,
                                        width: 1.5),
                                  ),
                                  prefixIcon: const Icon(Icons.attach_money,
                                      color: Colors.white54),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Reason Dropdown
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedReason,
                              dropdownColor: const Color(0xFF2E384D),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Motivo del Ajuste',
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF4A90E2), width: 1.5),
                                ),
                              ),
                              items: _reasons
                                  .map((r) => DropdownMenuItem(
                                      value: r, child: Text(r)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedReason = val);
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Note Field
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: TextField(
                              controller: _noteController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Nota (Opcional)',
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF4A90E2), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Preview Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: previewColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: previewColor.withAlpha(50)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Stock Final Resultante:',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)),
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
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A90E2), Color(0xFF50A7EA)],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _submitAdjustment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirmar Ajuste',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
