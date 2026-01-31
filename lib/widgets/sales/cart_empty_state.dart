import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class CartEmptyState extends StatelessWidget {
  final VoidCallback onAddProducts;

  const CartEmptyState({super.key, required this.onAddProducts});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.white24,
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(
                  duration: 2000.ms,
                  begin: -4,
                  end: 4,
                  curve: Curves.easeInOut), // Levitation
          const SizedBox(height: 24),
          const Text(
            '¡Empieza a agregar productos!',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAddProducts,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Productos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.redAccent, // Coral
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
}
