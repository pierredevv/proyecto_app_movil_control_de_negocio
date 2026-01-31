import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../widgets/inventory/product_list_item.dart';
import 'product_form_screen.dart';
import 'inventory_filter_panel.dart';

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
    final provider = context.watch<InventoryProvider>();
    final products = provider.filteredProducts;
    final categories = provider.categories;
    final selectedCategoryId = provider.selectedCategoryId;
    final isLoading = provider.isLoading;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: const InventoryFilterPanel(),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Fixed Header
            _buildHeader(context),

            // 2. Search Bar
            _buildSearchBar(context),

            // 2.5 Active Filters
            _buildActiveFilters(context),

            // 3. Horizontal Tabs
            if (!isLoading)
              _buildCategoryTabs(context, categories, selectedCategoryId),

            // 4. Scrollable List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(
                              top: 8, bottom: 80, left: 16, right: 16),
                          itemCount:
                              products.length + (provider.hasMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            if (index == products.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return ProductListItem(
                              product: products[index],
                              onEdit: () =>
                                  _navigateToForm(context, products[index]),
                              onDelete: () =>
                                  _confirmDelete(context, products[index]),
                              categoryName: _getCategoryName(
                                  categories, products[index].categoryId),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory_fab',
        onPressed: () => _navigateToForm(context, null),
        backgroundColor: const Color(0xFFEF4444), // Red
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final activeFilters = inventoryProvider.activeFilterCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Inventario',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none_outlined,
                        color: Theme.of(context).iconTheme.color),
                    onPressed: () {
                      // Optional: Navigate to notifications if desired
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
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.tune,
                        color: Theme.of(context).iconTheme.color),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
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
            ],
          )
        ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF1F2937))),
        deleteIcon: Icon(Icons.close,
            size: 16, color: isDark ? Colors.white70 : Colors.black54),
        onDeleted: onRemove,
        visualDensity: VisualDensity.compact,
        backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFF3F4F6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isSearching
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          hintStyle: TextStyle(
              color:
                  isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          prefixIcon: Icon(Icons.search,
              color:
                  isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
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
    );
  }

  Widget _buildCategoryTabs(
      BuildContext context, List<Category> categories, int? selectedId) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB) // Primary Blue
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                isAll ? 'Todos' : category!.name,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay productos aún',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _navigateToForm(context, null),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Agregar primer producto'),
          ),
        ],
      ),
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
