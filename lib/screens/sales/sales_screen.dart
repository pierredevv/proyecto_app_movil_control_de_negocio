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
import '../../models/invoice_item.dart';
import '../../theme/app_theme.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  void _showProductSearch(BuildContext context) async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _ProductSearchModal(),
    );

    if (product != null && context.mounted) {
      try {
        context.read<CartProvider>().addToCart(product);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _processCheckout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final inventory = context.read<InventoryProvider>();
    final db = DatabaseService();

    if (cart.items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Venta'),
        content: Text('Total a cobrar: Bs. ${cart.total.toStringAsFixed(2)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cobrar',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      // 1. Save Sale to DB
      final sale = await cart.checkout(db);

      // 2. Update Local Inventory (Optimistic)
      inventory.processSale(sale.items);

      // Refresh Dashboard
      if (context.mounted) {
        context.read<DashboardProvider>().loadDashboardData();
      }

      if (!context.mounted) return;

      // 3. Generate PDF & Share
      final file = await InvoiceService.generateInvoice(sale);

      if (!context.mounted) return;

      await showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text('¡Venta Exitosa!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
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
                  ),
                ],
              )
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart,
                color: Colors.white, size: 28),
            onPressed: () => _showProductSearch(context),
            tooltip: 'Agregar Producto',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.read<CartProvider>().clearCart(),
            tooltip: 'Limpiar Carrito',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Customer Selector
          const _CustomerHeader(),
          const Divider(height: 1),
          // Cart Items
          Expanded(
            child: Consumer<CartProvider>(
              builder: (context, cart, child) {
                if (cart.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('El carrito está vacío',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showProductSearch(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Productos'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 20),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    // Find product to check real-time stock limits
                    final product = context
                        .read<InventoryProvider>()
                        .products
                        .firstWhere((p) => p.id == item.productId,
                            orElse: () => Product(
                                id: -1,
                                name: 'Unknown',
                                barcode: '',
                                price: 0,
                                cost: 0,
                                stock: 0));

                    return _CartItemRow(
                      item: item,
                      maxStock: product.stock,
                      onUpdateQty: (qty) {
                        try {
                          cart.updateQuantity(index, qty, product.stock);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            duration: const Duration(milliseconds: 1000),
                          ));
                        }
                      },
                      onRemove: () => cart.removeFromCart(index),
                      onTapQuantity: () => _showQuantityDialog(
                        context,
                        item,
                        product.stock,
                        (newQty) {
                          try {
                            cart.updateQuantity(index, newQty, product.stock);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              duration: const Duration(milliseconds: 1000),
                            ));
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
              ],
            ),
            child: SafeArea(
              child: Consumer<CartProvider>(
                builder: (context, cart, child) {
                  return Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total a Cobrar',
                              style: TextStyle(fontSize: 12)),
                          Text(
                            'Bs. ${cart.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: cart.items.isEmpty || cart.isLoading
                            ? null
                            : () => _processCheckout(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: cart.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('COBRAR'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, InvoiceItem item,
      double maxStock, ValueChanged<double> onUpdate) {
    final controller = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad: ${item.productName}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Cantidad',
            suffixText: '/ $maxStock',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                if (val > maxStock) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Cantidad excede stock disponible')));
                  return;
                }
                onUpdate(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final customers = context.watch<CustomerProvider>().customers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: cart.selectedCustomer?.id,
                hint: const Text('Cliente: Público General'),
                isDense: true,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Cliente: Público General'),
                  ),
                  ...customers.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (id) {
                  if (id == null) {
                    cart.setCustomer(null);
                  } else {
                    final c = customers.firstWhere((c) => c.id == id);
                    cart.setCustomer(c);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final InvoiceItem item;
  final double maxStock;
  final ValueChanged<double> onUpdateQty;
  final VoidCallback onRemove;
  final VoidCallback onTapQuantity; // New Callback

  const _CartItemRow({
    required this.item,
    required this.maxStock,
    required this.onUpdateQty,
    required this.onRemove,
    required this.onTapQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} x Bs. ${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.primary,
                  onPressed: () => onUpdateQty(item.quantity - 1),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                InkWell(
                  onTap: onTapQuantity,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 40, // Slightly wider
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.primary,
                  onPressed: item.quantity >= maxStock
                      ? null
                      : () => onUpdateQty(item.quantity + 1),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              'Bs. ${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusing the same logic as PurchaseForm but simplified for just selection
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
    final products = provider.filteredProducts
        .where((p) => p.stock > 0)
        .toList(); // Only available

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Agregar a Venta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                provider.setSearchQuery(val);
              },
            ),
          ),
          Flexible(
            child: products.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No hay productos disponibles'),
                  ))
                : Container(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          title: Text(p.name),
                          subtitle:
                              Text('Stock: ${p.stock} | Precio: ${p.price}'),
                          trailing: const Icon(Icons.add_shopping_cart),
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
