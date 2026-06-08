import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';

class CartTotalFooter extends StatefulWidget {
  final double total;
  final bool allowInvoiceAdjustments;
  final Function(double finalTotal) onCheckout;
  final Function(double finalTotal)? onQuickCheckout;

  const CartTotalFooter(
      {super.key, required this.total, this.allowInvoiceAdjustments = false, required this.onCheckout, this.onQuickCheckout});

  @override
  State<CartTotalFooter> createState() => _CartTotalFooterState();
}

class _CartTotalFooterState extends State<CartTotalFooter> {
  late TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(text: widget.total.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(CartTotalFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only automatically update the controller if the underlying cart total changed significantly 
    // AND the user hasn't wiped the text field entirely to type a new one
    if (oldWidget.total != widget.total) {
       _totalController.text = widget.total.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  double get _currentTotal {
    return double.tryParse(_totalController.text) ?? widget.total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3246).withValues(alpha: 0.95), // Dark footer
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Total a Cobrar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    CurrencyHelper.simple(widget.total),
                    style: TextStyle(
                      color: Colors.white, // Or Accent color
                      fontSize: widget.allowInvoiceAdjustments ? 14 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (widget.allowInvoiceAdjustments) ...[
                 const SizedBox(width: 8),
                 ConstrainedBox(
                   constraints: const BoxConstraints(maxWidth: 140),
                   child: TextField(
                      controller: _totalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(50))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                   )
                 )
              ]
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.onQuickCheckout != null) ...[
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onQuickCheckout!(_currentTotal),
                    label: const Text('Rapido'),
                    icon: const Icon(Icons.flash_on),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primary),
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 7,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onCheckout(_currentTotal),
                  label: const Text('COBRAR'),
                  icon: const Icon(Icons.payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
