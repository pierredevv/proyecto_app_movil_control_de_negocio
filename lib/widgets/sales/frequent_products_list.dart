import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../utils/currency_helper.dart';

class FrequentProductsList extends StatelessWidget {
  final List<Product> frequentProducts;
  final ValueChanged<Product> onProductSelect;

  const FrequentProductsList({
    super.key,
    required this.frequentProducts,
    required this.onProductSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (frequentProducts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Productos Frecuentes',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: frequentProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = frequentProducts[index];
              return _FrequentProductChip(
                product: product,
                onTap: () => onProductSelect(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FrequentProductChip extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const _FrequentProductChip({required this.product, required this.onTap});

  @override
  State<_FrequentProductChip> createState() => _FrequentProductChipState();
}

class _FrequentProductChipState extends State<_FrequentProductChip> {
  bool _isPressed = false;


  Color _getColorFor(String name) {
    // Deterministic color based on name length or hash
    final colors = [
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.pinkAccent,
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = _getColorFor(widget.product.name);

    // In light mode, use a slightly stronger alpha for visibility or darker text
    final bgAlpha = isDark ? 0.2 : 0.1;
    final borderAlpha = isDark ? 0.5 : 0.3;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: bgAlpha),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: borderAlpha)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.product.name.isNotEmpty ? widget.product.name.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.product.name,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyHelper.simple(widget.product.price),
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
