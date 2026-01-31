import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/database_service.dart';
import '../../services/invoice_service.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validators.dart';

// Widgets
import '../../widgets/sales/sales_header.dart';
import '../../widgets/sales/customer_selection_card.dart';
import '../../widgets/sales/product_search_bar.dart';
import '../../widgets/sales/frequent_products_list.dart';
import '../../widgets/sales/cart_empty_state.dart';
import '../../widgets/sales/cart_item_card.dart';
import '../../widgets/sales/cart_total_footer.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    // Load frequent products after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadFrequentProducts();
    });
  }

  void _showProductSearch(BuildContext context) async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E2432),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ProductSearchModal(),
    );

    if (product != null && context.mounted) {
      _addToCart(product);
    }
  }

  void _addToCart(Product product) {
    try {
      context.read<CartProvider>().addToCart(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.redAccent),
      );
    }
  }

  void _processCheckout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final inventory = context.read<InventoryProvider>();
    final db = DatabaseService();

    if (cart.items.isEmpty) return;

    // Direct checkout or Confirmation Dialog? Dialog is safer.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2432),
        title: const Text('Confirmar Venta',
            style: TextStyle(color: Colors.white)),
        content: Text('Total a cobrar: Bs. ${cart.total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Cobrar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      final sale = await cart.checkout(db);
      inventory.processSale(sale.items);

      if (context.mounted) {
        context.read<DashboardProvider>().loadDashboardData();

        // Show Success & Share
        _showSuccessSheet(context, sale);
      }
    } catch (e) {
      if (context.mounted) {
        InputValidators.showValidationError(
            context, 'Error al procesar venta: $e');
      }
    }
  }

  void _showSuccessSheet(BuildContext context, dynamic sale) async {
    // Generate PDF
    final file = await InvoiceService.generateInvoice(sale);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2432),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.primary, size: 64),
            const SizedBox(height: 16),
            const Text('¡Venta Exitosa!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Volver',
                      style: TextStyle(color: Colors.white)),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file.path)],
                        text: 'Ticket de Venta #${sale.id}',
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir Ticket'),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Background Gradient (Dark Theme)
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A), // Deep dark background
      body: Stack(
        children: [
          // Background Pattern (Optional - Low Opacity)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03, // Very subtle
              child: Image.asset(
                'assets/images/pattern.png', // Fallback if exists, or remove.
                repeat: ImageRepeat.repeat,
                errorBuilder: (c, e, s) =>
                    const SizedBox.shrink(), // Safe fallback
              ),
            ),
          ),

          Column(
            children: [
              // Header & Top Controls
              Consumer<CartProvider>(
                builder: (context, cart, _) => SalesHeader(
                  cartItemCount:
                      cart.items.fold(0, (sum, i) => sum + i.quantity.toInt()),
                  onClearCart: () => cart.clearCart(),
                ),
              ),

              const SizedBox(height: 8),

              // Customer Selector
              Consumer2<CartProvider, CustomerProvider>(
                builder: (context, cart, custProvider, _) =>
                    CustomerSelectionCard(
                  selectedCustomer: cart.selectedCustomer,
                  customers: custProvider.customers,
                  onChanged: (c) => cart.setCustomer(c),
                ),
              ),

              // Search Bar
              ProductSearchBar(onTap: () => _showProductSearch(context)),

              // Content Area (Frequent Items + Cart List)
              Expanded(
                child: Consumer2<CartProvider, InventoryProvider>(
                  builder: (context, cart, inventory, child) {
                    if (cart.items.isEmpty) {
                      // EMPTY STATE
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Frequent Products
                            FrequentProductsList(
                              frequentProducts: inventory.frequentProducts,
                              onProductSelect: (product) => _addToCart(product),
                            ),
                            const SizedBox(height: 40),
                            // Animated Empty Cart
                            CartEmptyState(
                              onAddProducts: () => _showProductSearch(context),
                            ),
                          ],
                        ),
                      );
                    }

                    // CART LIST
                    return Column(
                      children: [
                        // Cart Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Carrito (${cart.items.length} ítems)',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: () => cart.clearCart(),
                                icon: const Icon(Icons.delete_outline,
                                    size: 16, color: AppTheme.redAccent),
                                label: const Text('Vaciar',
                                    style:
                                        TextStyle(color: AppTheme.redAccent)),
                              )
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemCount: cart.items.length,
                            itemBuilder: (context, index) {
                              final item = cart.items[index];
                              // Find product for max stock check
                              final product = context
                                  .read<InventoryProvider>()
                                  .products
                                  .firstWhere((p) => p.id == item.productId,
                                      orElse: () => Product(
                                          id: -1,
                                          name: '',
                                          barcode: '',
                                          price: 0,
                                          cost: 0,
                                          stock: 100)); // Default fallback

                              return CartItemCard(
                                key: ValueKey(
                                    '${item.productId}_$index'), // Unique key for animation
                                index: index,
                                item: item,
                                onUpdateQty: (qty) {
                                  try {
                                    cart.updateQuantity(
                                        index, qty, product.stock);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: AppTheme.redAccent,
                                      duration:
                                          const Duration(milliseconds: 1000),
                                    ));
                                  }
                                },
                                onRemove: () => cart.removeFromCart(index),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom Footer
              Consumer<CartProvider>(
                builder: (context, cart, _) => cart.items.isNotEmpty
                    ? CartTotalFooter(
                        total: cart.total,
                        onCheckout: () => _processCheckout(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Local Search Modal
class _ProductSearchModal extends StatefulWidget {
  const _ProductSearchModal();

  @override
  State<_ProductSearchModal> createState() => _ProductSearchModalState();
}

class _ProductSearchModalState extends State<_ProductSearchModal> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final products =
        provider.filteredProducts.where((p) => p.stock > 0).toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 16,
          right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Agregar Producto',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              provider.setSearchQuery(val);
            },
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: products.isEmpty
                  ? const Center(
                      child: Text('No hay productos',
                          style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: products.length,
                      separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withValues(alpha: 0.1),
                          height: 1),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text('Stock: ${p.stock} | Ps. ${p.price}',
                              style: const TextStyle(color: Colors.white54)),
                          trailing: const Icon(Icons.add_circle,
                              color: AppTheme.primary),
                          onTap: () {
                            Navigator.pop(context, p);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
