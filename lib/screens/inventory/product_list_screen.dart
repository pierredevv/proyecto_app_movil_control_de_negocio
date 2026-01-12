import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import 'product_form_screen.dart';
import 'category_manager_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load fresh data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadProducts();
      context.read<SupplierProvider>().loadSuppliers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider
    final provider = context.watch<InventoryProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final products = provider.filteredProducts;
    final categories = provider.categories;
    final selectedCategoryId = provider.selectedCategoryId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'categories') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CategoryManagerScreen()),
                );
                // Refresh categories after return
                if (context.mounted) {
                  context.read<InventoryProvider>().loadCategories();
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.category, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Gestionar Categorías'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize:
              const Size.fromHeight(110), // Increased height for chips
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<InventoryProvider>()
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    context.read<InventoryProvider>().setSearchQuery(value);
                    setState(() {});
                  },
                ),
              ),
              // Category Chips
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "All" option
                      final isSelected = selectedCategoryId == null;
                      return FilterChip(
                        label: const Text('Todos'),
                        selected: isSelected,
                        onSelected: (_) {
                          context
                              .read<InventoryProvider>()
                              .setCategoryFilter(null);
                        },
                        showCheckmark: false,
                        backgroundColor: Theme.of(context).cardColor,
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.grey[700],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal),
                      );
                    }
                    final category = categories[index - 1];
                    final isSelected = selectedCategoryId == category.id;
                    return FilterChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (_) {
                        context
                            .read<InventoryProvider>()
                            .setCategoryFilter(category.id);
                      },
                      showCheckmark: false,
                      backgroundColor: Theme.of(context).cardColor,
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                          color:
                              isSelected ? AppTheme.primary : Colors.grey[700],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Inventory Summary Card
          Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              final totalValue = provider.totalInventoryValue;
              final lowStockCount = provider.lowStockProducts.length;

              return Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                color: Theme.of(context).primaryColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valor Total Inventario',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Bs. ${totalValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          // Simple alert filter toggle logic could go here
                          // For now just showing the count
                        },
                        child: Column(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.amber, size: 24),
                            Text(
                              '$lowStockCount Alertas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isLowStock = product.stock <= product.minStock;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: InkWell(
                          onTap: () => _navigateToForm(context, product),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      if (product.barcode.isNotEmpty)
                                        Text('Code: ${product.barcode}',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      Text(
                                        'Stock: ${product.stock}',
                                        style: TextStyle(
                                          color: isLowStock
                                              ? AppTheme.primary
                                              : null,
                                          fontWeight: isLowStock
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Bs. ${product.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    if (isLowStock) ...[
                                      const SizedBox(height: 4),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.shopping_cart_checkout,
                                            color: Colors.orange),
                                        tooltip: 'Pedir a Proveedor',
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          _handleOrderAction(context, product);
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToForm(BuildContext context, Product? product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    ).then((_) {
      // Refresh list when coming back
      if (context.mounted) {
        context.read<InventoryProvider>().loadProducts();
      }
    });
  }

  void _handleOrderAction(BuildContext context, Product product) {
    if (product.supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Este producto no tiene proveedor asignado.')),
      );
      return;
    }

    final suppliers = context.read<SupplierProvider>().suppliers;

    // Better safe find
    try {
      final supplier = suppliers.firstWhere((s) => s.id == product.supplierId);
      final msg =
          "Hola ${supplier.name}, necesito hacer un pedido de ${product.name}. Mi stock actual es: ${product.stock}.";
      if (supplier.phone != null) {
        context.read<SupplierProvider>().sendWhatsApp(supplier.phone!, msg);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El proveedor no tiene teléfono.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proveedor no encontrado en la lista.')),
      );
    }
  }
}
