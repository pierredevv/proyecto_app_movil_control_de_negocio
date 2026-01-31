import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProductSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const ProductSearchBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white70),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Buscar o escanear...',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary, // Turquoise
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
