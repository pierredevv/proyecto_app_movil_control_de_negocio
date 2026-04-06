import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProductSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onScanTap;

  const ProductSearchBar({
    super.key, 
    required this.onTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                   Icon(Icons.search,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       'Buscar por texto o nombre...',
                       style: TextStyle(
                           color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                           fontSize: 16),
                     ),
                   ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onScanTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
