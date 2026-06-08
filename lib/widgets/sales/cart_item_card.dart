import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/invoice_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';

class CartItemCard extends StatefulWidget {
  final InvoiceItem item;
  final ValueChanged<double> onUpdateQty;
  final VoidCallback onRemove;
  final int index; // For staggered animation
  final bool canIncrement;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onUpdateQty,
    required this.onRemove,
    required this.index,
    required this.canIncrement,
  });

  @override
  State<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends State<CartItemCard>
    with SingleTickerProviderStateMixin {
  bool _isDeleting = false;

  void _handleDelete() async {
    setState(() => _isDeleting = true);
    // Wait for animation to finish then remove
    await Future.delayed(const Duration(milliseconds: 250));
    widget.onRemove();
  }

  void _showQtyEditDialog(BuildContext context) {
    final qtyController = TextEditingController(
        text: widget.item.quantity % 1 == 0
            ? widget.item.quantity.toInt().toString()
            : widget.item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar Cantidad'),
          content: TextField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(qtyController.text);
                if (val != null && val > 0) {
                  widget.onUpdateQty(val);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If deleting, animate out. Else animate in on mount.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        gradient: isDark
            ? LinearGradient(
                colors: [
                  const Color(0xFF2C3246).withValues(alpha: 0.9),
                  const Color(0xFF2C3246).withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : theme.colorScheme.outline),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyHelper.simple(widget.item.unitPrice),
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subtotal',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Controls
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Qty Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: widget.item.quantity > 0.01 // allow < 1 for decimals
                        ? () => widget.onUpdateQty((widget.item.quantity - 1).clamp(0.01, double.infinity))
                        : null,
                    isActive: widget.item.quantity > 0.01,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _showQtyEditDialog(context),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.item.quantity % 1 == 0 ? widget.item.quantity.toInt() : widget.item.quantity}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        )
                        .animate(key: ValueKey(widget.item.quantity))
                        .scale(
                            duration: 200.ms,
                            begin: const Offset(1, 1),
                            end: const Offset(1.2, 1.2))
                        .then()
                        .scale(end: const Offset(1, 1)),
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: widget.canIncrement
                        ? () => widget.onUpdateQty(widget.item.quantity + 1)
                        : null,
                    isActive: widget.canIncrement,
                  ),
                  const SizedBox(width: 8),
                  _DeleteButton(onTap: _handleDelete),
                ],
              ),
              const SizedBox(height: 8),
              // Subtotal
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyHelper.simple(widget.item.subtotal),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
                  .animate(key: ValueKey(widget.item.subtotal))
                  .scale(
                      duration: 300.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05))
                  .then()
                  .scale(end: const Offset(1, 1)),
            ],
          ),
        ],
      ),
    );

    if (_isDeleting) {
      return card
          .animate()
          .slideX(
            duration: 250.ms,
            begin: 0,
            end: 1, // Slide right
            curve: Curves.easeIn,
          )
          .fadeOut(duration: 250.ms);
    }

    // Entry animation
    return card
        .animate()
        .fadeIn(duration: 300.ms, delay: (50 * widget.index).ms)
        .slideY(begin: -0.2, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  const _QtyButton({required this.icon, this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AppTheme.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? AppTheme.primary : Colors.grey,
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.redAccent),
        ),
        child: const Icon(
          Icons.close, // Or Icons.delete
          size: 16,
          color: AppTheme.redAccent,
        ),
      ),
    );
  }
}
