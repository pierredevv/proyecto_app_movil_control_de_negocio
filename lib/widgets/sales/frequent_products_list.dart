import 'package:flutter/material.dart';
import '../../models/product.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Productos Frecuentes',
            style: TextStyle(
              color: Colors.white,
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

  IconData _getIconFor(String name) {
    name = name.toLowerCase();
    if (name.contains('arroz') || name.contains('comida')) {
      return Icons.rice_bowl;
    }
    if (name.contains('cerveza') ||
        name.contains('drink') ||
        name.contains('bebida') ||
        name.contains('refresco')) {
      return Icons.sports_bar;
    }
    if (name.contains('chocolate') ||
        name.contains('galleta') ||
        name.contains('dulce')) {
      return Icons.cookie;
    }
    return Icons.inventory_2_outlined;
  }

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
    final icon = _getIconFor(widget.product.name);
    final color = _getColorFor(widget.product.name);

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
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.product.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, size: 16, color: Colors.white),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bs. ${widget.product.price.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
