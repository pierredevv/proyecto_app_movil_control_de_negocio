import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/supplier.dart';
import '../../models/invoice_item.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // final _supplierController = TextEditingController(); // Replaced by Dropdown
  Supplier? _selectedSupplier;
  final _dateController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  final List<InvoiceItem> _items = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    // Ensure suppliers are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().loadSuppliers();
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _addItem() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _ProductSearchModal(),
    );

    if (product != null) {
      // Check if already exists? Maybe merge? For now just add new row
      setState(() {
        _items.add(InvoiceItem(
          productId: product.id!,
          productName: product.name,
          quantity: 1,
          unitPrice: product.cost, // Default to current cost
          subtotal: product.cost, // 1 * cost
        ));
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Compra'),
        content: Text(
            'Se guardará la compra por Bs. ${_totalAmount.toStringAsFixed(2)}\nEsto aumentará el stock y actualizará los costos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final purchase = Purchase(
        date: _selectedDate,
        totalAmount: _totalAmount,
        supplierName: _selectedSupplier?.name ?? 'Proveedor General',
        items: _items,
        status: 'COMPLETED',
      );

      await context.read<InventoryProvider>().addPurchase(purchase);

      if (mounted) {
        context.read<DashboardProvider>().loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra registrada exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Compra'),
      ),
      body: Column(
        children: [
          // Header Form
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Consumer<SupplierProvider>(
                      builder: (context, provider, child) {
                        return DropdownButtonFormField<Supplier>(
                          initialValue: _selectedSupplier,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor',
                            hintText: 'Seleccionar',
                            prefixIcon: Icon(Icons.store),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 15),
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<Supplier>(
                              value: null,
                              child: Text('Proveedor General'),
                            ),
                            ...provider.suppliers.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedSupplier = val;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: _pickDate,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Items Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Productos',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Producto'),
                ),
              ],
            ),
          ),
          // Items List
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Agrega productos a la compra',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _PurchaseItemRow(
                        key: ValueKey(_items[index].productId),
                        item: _items[index],
                        // We need the product details for conversion logic.
                        // Ideally we should cache product info or look it up.
                        // Since we don't have the full product object here in _items (only name/id),
                        // and we don't want to async fetch in build,
                        // we can rely on Consumer<InventoryProvider> to find it.
                        product: context
                            .read<InventoryProvider>()
                            .products
                            .firstWhere((p) => p.id == _items[index].productId,
                                orElse: () => Product(
                                    name: 'N/A',
                                    barcode: '',
                                    price: 0,
                                    cost: 0,
                                    stock: 0)),
                        onChanged: (updatedItem) {
                          setState(() {
                            _items[index] = updatedItem;
                          });
                        },
                        onRemove: () => _removeItem(index),
                      );
                    },
                  ),
          ),
          // Total Footer
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
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total a Pagar',
                          style: TextStyle(fontSize: 12)),
                      Text(
                        'Bs. ${_totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('GUARDAR'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseItemRow extends StatefulWidget {
  final InvoiceItem item;
  final Product product;
  final ValueChanged<InvoiceItem> onChanged;
  final VoidCallback onRemove;

  const _PurchaseItemRow({
    super.key,
    required this.item,
    required this.product,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_PurchaseItemRow> createState() => _PurchaseItemRowState();
}

class _PurchaseItemRowState extends State<_PurchaseItemRow> {
  late TextEditingController _qtyController;
  late TextEditingController _costController;
  bool _isBox = false; // Toggle state

  @override
  void initState() {
    super.initState();
    // Logic to restore "Box" view if quantity matches
    if (widget.product.unitsPerBox > 1 &&
        widget.item.quantity > 0 &&
        widget.item.quantity % widget.product.unitsPerBox == 0) {
      _isBox = true;
      _qtyController = TextEditingController(
          text: (widget.item.quantity / widget.product.unitsPerBox)
              .toStringAsFixed(
                  widget.item.quantity % widget.product.unitsPerBox == 0
                      ? 0
                      : 2)); // Clean decimal
    } else {
      _isBox = false;
      _qtyController =
          TextEditingController(text: widget.item.quantity.toString());
    }

    _costController =
        TextEditingController(text: widget.item.unitPrice.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _updateValues() {
    final rawQty = double.tryParse(_qtyController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0.0;

    final multiplier = _isBox ? widget.product.unitsPerBox : 1.0;
    final totalQty = rawQty * multiplier;

    // Only notify if changed
    if (totalQty != widget.item.quantity || cost != widget.item.unitPrice) {
      widget.onChanged(widget.item.copyWith(
        quantity: totalQty,
        unitPrice: cost,
        subtotal: totalQty * cost,
      ));
    }
  }

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
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Align to top
              children: [
                Expanded(
                  flex: 3, // Give more space to Quantity column
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.product.unitsPerBox > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: SingleChildScrollView(
                            // Prevent Overflow
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text('Por: ',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isBox = false;
                                      // Recalculate text for Unit view
                                      final rawQty = double.tryParse(
                                              _qtyController.text) ??
                                          0;
                                      // Current is Box, switch to Unit -> Multiply
                                      _qtyController.text =
                                          (rawQty * widget.product.unitsPerBox)
                                              .toString();
                                      _updateValues();
                                    });
                                  },
                                  child: Text('Unid.',
                                      style: TextStyle(
                                        fontWeight: !_isBox
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: !_isBox
                                            ? AppTheme.primary
                                            : Colors.grey,
                                        fontSize: 12,
                                      )),
                                ),
                                const Text(' | ',
                                    style: TextStyle(fontSize: 12)),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isBox = true;
                                      // Recalculate text for Box view
                                      final rawQty = double.tryParse(
                                              _qtyController.text) ??
                                          0;
                                      // Current is Unit, switch to Box -> Divide
                                      _qtyController.text =
                                          (rawQty / widget.product.unitsPerBox)
                                              .toString();
                                      _updateValues();
                                    });
                                  },
                                  child: Text(
                                      'Caja (${widget.product.unitsPerBox.toStringAsFixed(0)}u)',
                                      style: TextStyle(
                                        fontWeight: _isBox
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _isBox
                                            ? AppTheme.primary
                                            : Colors.grey,
                                        fontSize: 12,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ),
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: _isBox ? 'Cajas' : 'Cantidad',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _updateValues(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2, // Slightly less space for Cost
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: widget.product.unitsPerBox > 1
                            ? 20.0
                            : 0), // Align with input
                    child: TextFormField(
                      controller: _costController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Costo Unit.',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                        prefixText: 'Bs. ',
                      ),
                      onChanged: (_) => _updateValues(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        'Bs. ${widget.item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchModal extends StatefulWidget {
  const _ProductSearchModal();

  @override
  State<_ProductSearchModal> createState() => _ProductSearchModalState();
}

class _ProductSearchModalState extends State<_ProductSearchModal> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Only Listen to provider, don't read full db again if optimized
    final provider = context.watch<InventoryProvider>();
    final products = provider.filteredProducts;

    return Padding(
      // Padding for keyboard
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Seleccionar Producto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                provider.setSearchQuery(val);
              },
            ),
          ),
          // Results
          Flexible(
            child: products.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No se encontraron productos'),
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
                          subtitle: Text(
                              'Stock: ${p.stock} | Costo: ${p.cost.toStringAsFixed(2)}'),
                          trailing: const Icon(Icons.add),
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
