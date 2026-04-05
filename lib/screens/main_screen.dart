import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/common/custom_bottom_nav.dart';
import '../widgets/common/responsive_layout.dart';
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

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, currentIndex, pages),
      tablet: _buildTabletDesktopLayout(context, currentIndex, pages, false),
      desktop: _buildTabletDesktopLayout(context, currentIndex, pages, true),
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, int currentIndex, List<Widget> pages) {
    final navigationProvider = context.read<NavigationProvider>();
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

  Widget _buildTabletDesktopLayout(BuildContext context, int currentIndex,
      List<Widget> pages, bool isDesktop) {
    final navigationProvider = context.read<NavigationProvider>();
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isDesktop,
            minExtendedWidth: 200,
            selectedIndex: currentIndex,
            onDestinationSelected: (int index) {
              navigationProvider.setIndex(index);
            },
            labelType: isDesktop
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'main_fab_desktop',
                  backgroundColor: AppTheme.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SalesScreen()),
                    );
                  },
                  child: const Icon(Icons.add_shopping_cart,
                      color: Colors.white),
                ),
                const SizedBox(height: 16),
              ],
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: Text('Compras'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Inventario'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu),
                selectedIcon: Icon(Icons.menu),
                label: Text('Menú'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}
