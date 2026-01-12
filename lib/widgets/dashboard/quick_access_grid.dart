import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/navigation_provider.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<_QuickAccessItem> items = [
      _QuickAccessItem(
        icon: Icons.add_business, // Changed icon for variety
        label: 'Nueva Venta',
        color: Colors.blue,
        onTap: () {
          // Trigger the global FAB action or navigate
          // For now, maybe just toast or print
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Use el botón + flotante')),
          );
        },
      ),
      _QuickAccessItem(
        icon: Icons.inventory_2_outlined,
        label: 'Productos',
        color: Colors.orange,
        onTap: () {
          context
              .read<NavigationProvider>()
              .setIndex(2); // Index of ProductList
        },
      ),
      _QuickAccessItem(
        icon: Icons.people_outline,
        label: 'Clientes',
        color: Colors.purple,
        onTap: () {
          context
              .read<NavigationProvider>()
              .setIndex(3); // Index of CustomerList
        },
      ),
      _QuickAccessItem(
        icon: Icons.history_edu,
        label: 'Compras',
        color: Colors.green,
        onTap: () {
          context
              .read<NavigationProvider>()
              .setIndex(1); // Index of PurchaseList
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Accesos Rápidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Ver Todo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.3),
                          width: 1,
                        )),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
