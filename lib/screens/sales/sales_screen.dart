import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/database_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_helper.dart';
import '../../utils/input_validators.dart';

// Widgets
import '../../widgets/sales/sales_header.dart';
import '../../widgets/sales/customer_selection_card.dart';
import '../../widgets/sales/product_search_bar.dart';
import '../../widgets/sales/frequent_products_list.dart';
import '../../widgets/sales/cart_empty_state.dart';
import '../../widgets/sales/cart_item_card.dart';
import '../../widgets/sales/cart_total_footer.dart';
import '../../widgets/sales/sale_unit_picker_sheet.dart';
import '../../widgets/sales/checkout_sheet.dart'; // NEW IMPORT
import '../inventory/barcode_scanner_view.dart';
import '../../services/snackbar_service.dart';

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
    final theme = Theme.of(context);
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.scaffoldBackgroundColor, // Adapt to theme
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ProductSearchModal(),
    );

    if (product != null && context.mounted) {
      _addToCart(product);
    }
  }

  Future<void> _startBarcodeScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerView()),
    );

    if (!mounted) return;

    if (result != null && result is String) {
      // Find product by barcode
      final inventory = context.read<InventoryProvider>();
      final products = inventory.products;
      final product = products.cast<Product?>().firstWhere(
            (p) => p?.barcode == result,
            orElse: () => null,
          );

      if (product != null) {
        _addToCart(product);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto no encontrado (Código: $result)')),
        );
      }
    }
  }

  void _addToCart(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaleUnitPickerSheet(
        product: product,
        onConfirm: (option, qty) {
          try {
            final allowNegativeStock = context.read<SettingsProvider>().profile.allowNegativeStock;
            context
                .read<CartProvider>()
                .addToCart(product, option: option, qty: qty, allowNegativeStock: allowNegativeStock);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: AppTheme.redAccent),
            );
          }
        },
      ),
    );
  }

  void _processCheckout(BuildContext context, double finalTotal, {bool isQuick = false}) async {
    final cart = context.read<CartProvider>();
    final inventory = context.read<InventoryProvider>();
    final customers = context.read<CustomerProvider>().customers;
    final db = DatabaseService();
    final settings = context.read<SettingsProvider>().profile;

    if (cart.items.isEmpty) return;

    final adjustmentAmount = finalTotal - cart.total;

    double? amountReceived;
    double amountTendered = 0.0;
    DateTime? paymentDueDate;
    String paymentMethod = 'EFECTIVO';
    String? customClientName;
    String? ciNit;

    if (isQuick) {
      amountReceived = finalTotal;
      amountTendered = finalTotal;
    } else {
      Customer? selectedCustomer;
      if (cart.selectedCustomer != null) {
        try {
          selectedCustomer = customers.firstWhere((c) => c.id == cart.selectedCustomer?.id);
        } catch (e) {
          debugPrint('Customer lookup failed: $e');
        }
      }

      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => CheckoutSheet(
          totalAmount: finalTotal,
          initialClientName: selectedCustomer?.name,
          initialCiNit: selectedCustomer?.ciNit,
          initialAmountReceived: cart.editingOriginalSaleId != null ? cart.editingOriginalAmountPaid : null,
        ),
      );

      if (result == null || !context.mounted) return;

      amountReceived = result['amountReceived'] as double?;
      amountTendered = result['amountTendered'] as double? ?? 0.0;
      paymentDueDate = result['paymentDueDate'] as DateTime?;
      paymentMethod = result['paymentMethod'] as String? ?? 'EFECTIVO';
      customClientName = result['clientName'] as String?;
      ciNit = result['ciNit'] as String?;
    }

    try {
      final autoClear = settings.autoClearCartAfterSale;
      final sale = await cart.checkout(db,
          autoClear: autoClear,
          amountReceived: amountReceived,
          amountTendered: amountTendered,
          clientCiNit: ciNit,
          paymentDueDate: paymentDueDate,
          paymentMethod: paymentMethod,
          adjustmentAmount: adjustmentAmount,
          allowNegativeStock: settings.allowNegativeStock);
      inventory.processSale(sale.items);

      if (context.mounted) {
        context.read<DashboardProvider>().loadDashboardData();
        if (sale.customerId != null) {
          context.read<CustomerProvider>().loadCustomers();
        }

        // Show Success & Share
        _showSuccessSheet(context, sale, customClientName: customClientName, ciNit: ciNit);
      }
    } catch (e) {
      if (context.mounted) {
        InputValidators.showValidationError(
            context, 'Error al procesar venta: $e');
      }
    }
  }

  void _showSuccessSheet(BuildContext context, dynamic sale, {String? customClientName, String? ciNit}) async {
    // Generate PDF bytes
    final profile = context.read<SettingsProvider>().profile;
    final bytes = await PdfGeneratorService().generateInvoice(
      sale, 
      profile, 
      ciNit: ciNit, 
      customClientName: customClientName != null && customClientName.isNotEmpty ? customClientName : null,
    );
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Ticket_${sale.id}.pdf');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.primary, size: 64),
            const SizedBox(height: 16),
            Text('¡Venta Exitosa!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                  label: Text('Volver',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Pattern (Optional - Low Opacity)
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

          Column(
            children: [
              // Header & Top Controls
              Consumer<CartProvider>(
                builder: (context, cart, _) => SalesHeader(
                  cartItemCount:
                      cart.items.fold(0, (sum, i) => sum + i.quantity.toInt()),
                  onClearCart: () => _handleClearCart(context, cart),
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
              ProductSearchBar(
                onTap: () => _showProductSearch(context),
                onScanTap: _startBarcodeScan,
              ),

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
                              Expanded(
                                child: Text(
                                  'Carrito (${cart.items.length} ítems)',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_shopping_cart, color: AppTheme.primary),
                                    onPressed: () => _showProductSearch(context),
                                    tooltip: 'Agregar producto',
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _handleClearCart(context, cart),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16, color: AppTheme.redAccent),
                                    label: const Text('Vaciar',
                                        style:
                                            TextStyle(color: AppTheme.redAccent)),
                                  )
                                ],
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
                                          stock: 0)); // Prevent infinite stock constraint when not loaded

                              return CartItemCard(
                                key: ValueKey(
                                    '${item.productId}_$index'), // Unique key for animation
                                index: index,
                                item: item,
                                canIncrement: () {
                                  final otherBaseUnits = cart.items
                                      .where((i) => i.productId == item.productId && i != item)
                                      .fold(0.0, (sum, i) => sum + i.baseUnitsTotal);
                                  final nextBaseUnits =
                                      (item.quantity + 1) * item.unitsPerSaleUnit;
                                  return nextBaseUnits + otherBaseUnits <=
                                      (item.maxBaseStock ?? product.stock);
                                }(),
                                onUpdateQty: (qty) {
                                  try {
                                    final allowNegativeStock = context.read<SettingsProvider>().profile.allowNegativeStock;
                                    cart.updateQuantity(
                                        index, qty, item.maxBaseStock ?? product.stock, allowNegativeStock: allowNegativeStock);
                                  } catch (e) {
                                    SnackbarService.showError(e.toString());
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
                        allowInvoiceAdjustments: context.read<SettingsProvider>().profile.allowInvoiceAdjustments,
                        onCheckout: (finalTotal) => _processCheckout(context, finalTotal),
                        onQuickCheckout: (finalTotal) => _processCheckout(context, finalTotal, isQuick: true),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleClearCart(BuildContext context, CartProvider cart) {
    if (context.read<SettingsProvider>().profile.confirmClearCart) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vaciar Carrito'),
          content: const Text(
              '¿Está seguro de eliminar todos los productos del carrito?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                cart.clearCart();
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Carrito vaciado')),
                );
              },
              child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      cart.clearCart();
    }
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
  InventoryProvider? _inventoryProvider;
  String _savedInventoryQuery = '';

  @override
  void initState() {
    super.initState();
    _inventoryProvider = context.read<InventoryProvider>();
    _savedInventoryQuery = _inventoryProvider?.searchQuery ?? '';
    if (_savedInventoryQuery.isNotEmpty) {
      // Clear immediately to show all products initially in modal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inventoryProvider?.setSearchQuery('');
      });
    }
  }

  @override
  void dispose() {
    _inventoryProvider?.setSearchQuery(_savedInventoryQuery);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showOutOfStock =
        context.watch<SettingsProvider>().profile.showOutOfStockInPOS;
    final provider = context.watch<InventoryProvider>();
    final products = showOutOfStock
        ? provider.filteredProducts
        : provider.filteredProducts
            .where((p) => p.stock > 0)
            .toList();

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
          Text('Agregar Producto',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre...',
              hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              filled: true,
              fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
            child: products.isEmpty
                  ? Center(
                      child: Text('No hay productos',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5))))
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => Divider(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.1),
                          height: 1),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface)),
                          subtitle: Text(
                              'Stock: ${p.stockInSaleUnits.toStringAsFixed(1)} ${p.saleUnit} | ${CurrencyHelper.simple(p.price)}',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
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
