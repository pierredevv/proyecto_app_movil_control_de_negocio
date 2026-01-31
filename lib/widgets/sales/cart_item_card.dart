import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/invoice_item.dart';
import '../../theme/app_theme.dart';

class CartItemCard extends StatefulWidget {
  final InvoiceItem item;
  final ValueChanged<double> onUpdateQty;
  final VoidCallback onRemove;
  final int index; // For staggered animation

  const CartItemCard({
    super.key,
    required this.item,
    required this.onUpdateQty,
    required this.onRemove,
    required this.index,
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

  @override
  Widget build(BuildContext context) {
    // If deleting, animate out. Else animate in on mount.

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2C3246).withValues(alpha: 0.9),
            const Color(0xFF2C3246).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bs. ${widget.item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Subtotal',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // Controls
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Qty Row
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: widget.item.quantity > 1
                        ? () => widget.onUpdateQty(widget.item.quantity - 1)
                        : null, // Disabled if 1
                    isActive: widget.item.quantity > 1,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${widget.item.quantity % 1 == 0 ? widget.item.quantity.toInt() : widget.item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
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
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => widget.onUpdateQty(widget.item.quantity + 1),
                    isActive: true,
                  ),
                  const SizedBox(width: 8),
                  _DeleteButton(onTap: _handleDelete),
                ],
              ),
              const SizedBox(height: 8),
              // Subtotal
              Text(
                'Bs. ${widget.item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
