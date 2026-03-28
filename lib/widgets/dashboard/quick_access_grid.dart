import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/customers/customer_list_screen.dart';
import '../../screens/suppliers/supplier_list_screen.dart';
import '../../screens/treasury/global_payment_screen.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos Rápidos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
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
                const SizedBox(width: 24),
                _buildQuickAccessItem(
                  context,
                  icon: Icons.payments,
                  label: 'Cobro Global',
                  color: AppTheme.greenAccent,
                  delay: 50,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GlobalPaymentScreen()),
                    );
                  },
                ),
                const SizedBox(width: 24),
                _buildQuickAccessItem(
                  context,
                  icon: Icons.qr_code,
                  label: 'Productos',
                  color: AppTheme.yellowIcon,
                  delay: 100,
                  onTap: () {
                    context.read<NavigationProvider>().setIndex(2);
                  },
                ),
                const SizedBox(width: 24),
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
                const SizedBox(width: 24),
                _buildQuickAccessItem(
                  context,
                  icon: Icons.storefront,
                  label: 'Proveedores',
                  color: const Color(0xFFF59F00), // AppTheme.orangeIcon basically
                  delay: 250,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SupplierListScreen()),
                    );
                  },
                ),
                const SizedBox(width: 24),
                _buildQuickAccessItem(
                  context,
                  icon: Icons.shopping_cart,
                  label: 'Compras',
                  color: AppTheme.greenIcon,
                  delay: 300,
                  onTap: () {
                    context.read<NavigationProvider>().setIndex(1);
                  },
                ),
              ],
            ),
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
    final theme = Theme.of(context);
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
          style: TextStyle(
            color: theme.colorScheme.onSurface,
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
