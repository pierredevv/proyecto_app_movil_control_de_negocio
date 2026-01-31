import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class SalesHeader extends StatelessWidget {
  final int cartItemCount;
  final VoidCallback onClearCart;

  const SalesHeader({
    super.key,
    required this.cartItemCount,
    required this.onClearCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: Colors.transparent, // Uses background of Scaffold
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios,
                color: theme.colorScheme.onSurface, size: 20),
          ),
          Expanded(
            child: Text(
              'Punto de Venta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.shopping_cart,
                  color: theme.colorScheme.onSurface, size: 28),
              if (cartItemCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cartItemCount > 9 ? '9+' : cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                      .animate(key: ValueKey(cartItemCount))
                      .scale(
                        duration: 400.ms,
                        begin: const Offset(1, 1),
                        end: const Offset(1.3, 1.3),
                      )
                      .then()
                      .scale(
                        duration: 400.ms,
                        begin: const Offset(1.3, 1.3),
                        end: const Offset(1, 1),
                      ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onClearCart,
            icon: Icon(Icons.delete,
                color: theme.colorScheme.onSurface, size: 28),
            tooltip: 'Vaciar Carrito',
          ),
        ],
      ),
    );
  }
}
