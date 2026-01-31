import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/common/custom_bottom_nav.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'purchases/purchase_list_screen.dart';
import 'inventory/product_list_screen.dart';
import 'sales/sales_screen.dart';
import 'menu_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentIndex = navigationProvider.currentIndex;

    final List<Widget> pages = [
      const DashboardScreen(),
      const PurchaseListScreen(),
      const ProductListScreen(),
      const MenuScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: currentIndex,
        onTap: (index) => navigationProvider.setIndex(index),
      ),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(top: 30),
        child: FloatingActionButton(
          heroTag: 'main_fab',
          backgroundColor: AppTheme.primary,
          elevation: 4,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SalesScreen()),
            );
          },
          shape: const CircleBorder(),
          child: const Icon(Icons.add_shopping_cart,
              color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
