import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../widgets/inventory/product_list_item.dart';
import 'product_form_screen.dart';
import 'stock_adjustment_screen.dart';
import 'inventory_filter_panel.dart';
import '../../widgets/common/skeleton_list.dart';
import '../notifications/notifications_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../import/import_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadProducts();
      // Ensure specific categories are loaded if not already
      context.read<SupplierProvider>().loadSuppliers();
      // Update notifications for the badge
      context.read<NotificationProvider>().checkLowStock();
      context.read<NotificationProvider>().checkOverdueSales();
    });

    _searchController.addListener(() {
      setState(() {
        _isSearching = _searchController.text.isNotEmpty;
      });
      context.read<InventoryProvider>().setSearchQuery(_searchController.text);
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildHeader(context),
      floatingActionButton: _buildFAB(context),
      body: Stack(
        children: [
          // Background Pattern
          // Background Gradient & Blobs
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          const Color(0xFFF8FAFC),
                          const Color(0xFFE2E8F0),
                          const Color(0xFFF1F5F9),
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2)
                    .withValues(alpha: 0.1), // Primary Blue
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444)
                    .withValues(alpha: 0.1), // Secondary Red
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Pattern Overlay (Optional, keeping it subtle on top)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.03 : 0.02,
              child: Image.asset(
                'assets/images/pattern.png',
                repeat: ImageRepeat.repeat,
                color: isDark ? Colors.white : Colors.black,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Main Content
          Column(
            children: [
              // Spacer for AppBar since extendBodyBehindAppBar is true
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),

              _buildSearchBar(context),

              _buildActiveFilters(context),

              if (!provider.isLoading)
                _buildCategoryTabs(
                    context, provider.categories, provider.selectedCategoryId),

              Expanded(
                child: provider.isLoading
                    ? const SkeletonList()
                    : provider.filteredProducts.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 80, left: 16, right: 16),
                            itemCount: provider.filteredProducts.length +
                                (provider.hasMore ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              if (index == provider.filteredProducts.length) {
                                return provider.hasMore
                                    ? const Center(
                                        child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ))
                                    : const SizedBox(height: 80);
                              }
                              final product = provider.filteredProducts[index];
                              return ProductListItem(
                                product: product,
                                categoryName: _getCategoryName(
                                    provider.categories, product.categoryId),
                                onEdit: () => _navigateToForm(context, product),
                                onDelete: () =>
                                    _confirmDelete(context, product),
                                onAdjustStock: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: product)),
                                ).then((_) {
                                  if (context.mounted) {
                                    context.read<InventoryProvider>().loadProducts(reset: true);
                                  }
                                }),
                              ).animate().fadeIn(duration: 400.ms).slideY(
                                    begin: 0.1,
                                    end: 0,
                                    delay: (50 * (index % 10)).ms,
                                  );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final activeFilters = inventoryProvider.activeFilterCount;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Inventario',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined,
                  color: Colors.white, size: 24),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white, size: 24),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const InventoryFilterPanel(),
                );
              },
            ),
            if (activeFilters > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeFilters',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF), // White 15% opacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x1AFFFFFF), // White 10% opacity
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // Black 10% opacity
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glass blur
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              hintStyle: const TextStyle(
                  color: Color(0xFF6B7494),
                  fontSize: 16,
                  fontWeight: FontWeight.normal),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 12),
                child: Icon(Icons.search, color: Color(0xFFA0A8C1), size: 24),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 52, minHeight: 24),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilters(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final chips = <Widget>[];

    // Sort
    if (provider.currentSort != SortOption.nameAsc) {
      String label = '';
      switch (provider.currentSort) {
        case SortOption.stockAsc:
          label = 'Stock Asc';
          break;
        case SortOption.priceAsc:
          label = 'Precio Asc';
          break;
        case SortOption.priceDesc:
          label = 'Precio Desc';
          break;
        default:
          break;
      }
      chips.add(_buildFilterChip(label, () => provider.removeFilter('sort')));
    }

    // Categories
    for (var catId in provider.selectedCategories) {
      final cat = provider.categories.firstWhere((c) => c.id == catId,
          orElse: () => Category(id: -1, name: '?'));
      chips.add(_buildFilterChip(
          cat.name, () => provider.removeFilter('category', catId)));
    }

    // Stock Status
    for (var status in provider.selectedStockStatuses) {
      String label = '';
      switch (status) {
        case StockStatus.sufficient:
          label = 'Stock Suficiente';
          break;
        case StockStatus.moderate:
          label = 'Stock Moderado';
          break;
        case StockStatus.critical:
          label = 'Stock Crítico';
          break;
      }
      chips.add(_buildFilterChip(
          label, () => provider.removeFilter('stockStatus', status)));
    }

    // Price Range (Simple indicator)
    if (provider.priceRange != null) {
      chips.add(_buildFilterChip(
          '\$${provider.priceRange!.start.round()} - \$${provider.priceRange!.end.round()}',
          () => provider.removeFilter('price')));
    }

    // Stock Range
    if (provider.stockRange != null) {
      chips.add(_buildFilterChip(
          'Stock: ${provider.stockRange!.start.round()} - ${provider.stockRange!.end.round()}',
          () => provider.removeFilter('stock')));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    // Using a glassmorphism style for filter chips too for consistency
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding:
                const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 4),
                // Larger Hit Target for Close Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.close, size: 16, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(
      BuildContext context, List<Category> categories, int? selectedId) {
    return Container(
      height: 60, // Increased height for underlines
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : categories[index - 1];
          final isSelected =
              isAll ? selectedId == null : selectedId == category!.id;

          return GestureDetector(
            onTap: () {
              context
                  .read<InventoryProvider>()
                  .setCategoryFilter(isAll ? null : category!.id);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0x26FFFFFF) // White 15%
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0x1AFFFFFF), width: 1.5)
                          : Border.all(
                              color: const Color(0x1AFFFFFF), width: 1),
                      boxShadow: isSelected
                          ? [
                              const BoxShadow(
                                color: Color(0x334A90E2), // Blue 20%
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: BackdropFilter(
                      filter: isSelected
                          ? ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8)
                          : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Text(
                        isAll ? 'Todos' : category!.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFA0A8C1),
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      height: 3,
                      width: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2), // Blue underline
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A90E2).withValues(alpha: 0.05),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.inventory_2_outlined,
                  size: 100, color: Colors.grey.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),
            const Text(
              'No hay productos en inventario',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Agrega productos para comenzar a gestionar tu inventario',
              style: TextStyle(color: Color(0xFFA0A8C1), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D4A90E2), // Blue 30%
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _navigateToForm(context, null),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Agregar primer producto',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: const Color(0xFFFF6B6B),
      foregroundColor: Colors.white,
      activeBackgroundColor: Colors.grey.shade800,
      activeForegroundColor: Colors.white,
      visible: true,
      closeManually: false,
      curve: Curves.bounceIn,
      overlayColor: Colors.black,
      overlayOpacity: 0.6,
      elevation: 12,
      shape: const CircleBorder(),
      children: [
        SpeedDialChild(
          child: const Icon(Icons.edit_document, color: Colors.white),
          backgroundColor: const Color(0xFF4A90E2), // Blue
          label: 'Agregar Manual',
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black87),
          onTap: () => _navigateToForm(context, null),
        ),
        SpeedDialChild(
          child: const Icon(Icons.cloud_upload, color: Colors.white),
          backgroundColor: const Color(0xFF10B981), // Green
          label: 'Importar Excel/CSV',
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black87),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportScreen()),
            ).then((_) {
              if (context.mounted) {
                context.read<InventoryProvider>().loadProducts(reset: true);
              }
            });
          },
        ),
      ],
    );
  }

  String _getCategoryName(List<Category> categories, int? id) {
    if (id == null) return 'Sin Categoría';
    return categories
        .firstWhere((c) => c.id == id,
            orElse: () => Category(id: -1, name: 'Desconocido'))
        .name;
  }

  void _navigateToForm(BuildContext context, Product? product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<InventoryProvider>().loadProducts(reset: true);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Eliminar "${product.name}" del inventario?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<InventoryProvider>().deleteProduct(product.id!);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<InventoryProvider>().loadProducts();
    }
  }
}

// End of ProductListScreen class.
// _ProductListItem extracted to lib/widgets/inventory/product_list_item.dart
