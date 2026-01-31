import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/customers/customer_list_screen.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accesos Rápidos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAccessItem(
                context,
                icon: Icons.add,
                label: 'Venta Nueva',
                color: AppTheme.blueIcon,
                delay: 0,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SalesScreen()),
                  );
                },
              ),
              _buildQuickAccessItem(
                context,
                icon: Icons.qr_code,
                label: 'Productos',
                color: AppTheme.yellowIcon,
                delay: 100,
                onTap: () {
                  // Switch to Inventory Tab (Index 2)
                  context.read<NavigationProvider>().setIndex(2);
                },
              ),
              _buildQuickAccessItem(
                context,
                icon: Icons.people,
                label: 'Clientes',
                color: AppTheme.purpleIcon,
                delay: 200,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CustomerListScreen()),
                  );
                },
              ),
              _buildQuickAccessItem(
                context,
                icon: Icons.shopping_cart,
                label: 'Compras',
                color: AppTheme.greenIcon,
                delay: 300,
                onTap: () {
                  // Switch to Purchases Tab (Index 1)
                  context.read<NavigationProvider>().setIndex(1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required int delay,
      required VoidCallback onTap}) {
    return Column(
      children: [
        _AnimatedScaleButton(
          color: color,
          icon: icon,
          onTap: onTap,
        ).animate().scale(
            duration: 300.ms,
            delay: Duration(milliseconds: 600 + delay),
            curve: Curves.easeOutBack),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _AnimatedScaleButton extends StatefulWidget {
  final Color color;
  final IconData icon;

  final VoidCallback onTap;

  const _AnimatedScaleButton(
      {required this.color, required this.icon, required this.onTap});

  @override
  State<_AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<_AnimatedScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
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
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
