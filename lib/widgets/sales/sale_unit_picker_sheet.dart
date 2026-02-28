import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/sale_unit_option.dart';
import '../../utils/sale_unit_helper.dart';
import '../../theme/app_theme.dart';

class SaleUnitPickerSheet extends StatefulWidget {
  final Product product;
  final Function(SaleUnitOption, double qty) onConfirm;

  const SaleUnitPickerSheet({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  @override
  State<SaleUnitPickerSheet> createState() => _SaleUnitPickerSheetState();
}

class _SaleUnitPickerSheetState extends State<SaleUnitPickerSheet> {
  late List<SaleUnitOption> _options;
  late SaleUnitOption _selectedOption;
  double _quantity = 1.0;

  @override
  void initState() {
    super.initState();
    _options = SaleUnitHelper.getOptionsForProduct(widget.product);
    _selectedOption = _options.first; // Default to the main option
  }

  void _increaseQty() {
    final nextQtyInBaseUnits =
        (_quantity + 1) * _selectedOption.unitsPerSaleUnit;
    if (nextQtyInBaseUnits <= widget.product.stock) {
      setState(() {
        _quantity += 1.0;
      });
    }
  }

  void _decreaseQty() {
    if (_quantity > 1.0) {
      setState(() {
        _quantity -= 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock disponible: ${widget.product.stockInSaleUnits.toStringAsFixed(1)} ${widget.product.saleUnit}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Options List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final isSelected = option == _selectedOption;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = option;
                        // Reset quantity to 1 when changing option if the new unit doesn't fit the previous quantity
                        if ((_quantity * option.unitsPerSaleUnit) >
                            widget.product.stock) {
                          _quantity = 1.0;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.2)),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : (isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${option.unitsPerSaleUnit}x base',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Bs. ${option.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quantity Editor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cantidad:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _decreaseQty,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: _quantity > 1 ? AppTheme.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _quantity.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: ((_quantity + 1) *
                                    _selectedOption.unitsPerSaleUnit) <=
                                widget.product.stock
                            ? _increaseQty
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: ((_quantity + 1) *
                                    _selectedOption.unitsPerSaleUnit) <=
                                widget.product.stock
                            ? AppTheme.primary
                            : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Add Button
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(_selectedOption, _quantity);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Agregar por Bs. ${(_selectedOption.price * _quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
