import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/supplier.dart';
import '../../models/invoice_item.dart';
import '../../models/product.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class PurchaseFormScreen extends StatefulWidget {
  final Transaction? initialTransactionToDuplicate;
  final bool initialIsOrder;
  final int? editingOriginalId;

  const PurchaseFormScreen({
    super.key,
    this.initialIsOrder = false,
    this.initialTransactionToDuplicate,
    this.editingOriginalId,
  });

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  Supplier? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  final List<InvoiceItem> _items = [];
  bool _isOrder = false;

  @override
  void initState() {
    super.initState();
    _isOrder = widget.initialIsOrder;

    // Load data from duplicate transaction if necessary
    if (widget.initialTransactionToDuplicate != null) {
      final t = widget.initialTransactionToDuplicate!;
      _isOrder = t.type == TransactionType.order;
      // We keep the date as today, since they are duplicating to create a NEW record right now,
      // not backdating it to the original date.

      _items.addAll(t.items.map((i) => i.copyWith()));

      // We will need to set the supplier after the provider loads
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supplierProvider = context.read<SupplierProvider>();
      supplierProvider.loadSuppliers().then((_) {
        if (widget.initialTransactionToDuplicate != null && mounted) {
          final supplierName = widget.initialTransactionToDuplicate! is Purchase
              ? (widget.initialTransactionToDuplicate as Purchase).supplierName
              : (widget.initialTransactionToDuplicate as Order).supplierName;

          if (supplierName != null && supplierName != 'Proveedor General') {
            try {
              final match = supplierProvider.suppliers
                  .firstWhere((s) => s.name == supplierName);
              setState(() {
                _selectedSupplier = match;
              });
            } catch (e) {
              // Supplier might have been deleted, ignore
            }
          }
        }
      });
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF1E2432),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addItem() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ProductSearchModal(),
    );

    if (product != null) {
      setState(() {
        _items.add(InvoiceItem(
          productId: product.id!,
          productName: product.name,
          quantity: 1,
          unitPrice: product.cost,
          subtotal: product.cost,
          saleUnit: product.saleUnit,
          unitsPerSaleUnit: product.unitsPerSaleUnit,
          packagingInfo: product.packagingInfo,
        ));
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto'),
          backgroundColor: AppTheme.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2432),
        title: const Text('Confirmar Compra',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Se guardará la compra por Bs. ${_totalAmount.toStringAsFixed(2)}\nEsto aumentará el stock y actualizará los costos.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar',
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      if (_isOrder) {
        final order = Order(
          date: _selectedDate,
          totalAmount: _totalAmount,
          supplierName: _selectedSupplier?.name ?? 'Proveedor General',
          items: _items,
          status: 'PENDING',
        );
        await context.read<InventoryProvider>().addOrder(order);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido registrado exitosamente'),
              backgroundColor: AppTheme.greenAccent,
            ),
          );
        }
      } else {
        final purchase = Purchase(
          date: _selectedDate,
          totalAmount: _totalAmount,
          supplierName: _selectedSupplier?.name ?? 'Proveedor General',
          items: _items,
          status: 'COMPLETED',
        );

        await context.read<InventoryProvider>().addPurchase(purchase);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compra registrada exitosamente'),
              backgroundColor: AppTheme.greenAccent,
            ),
          );
        }
      }

      if (widget.editingOriginalId != null) {
        try {
          await DatabaseService().deletePurchase(widget.editingOriginalId!);
        } catch (_) {}
      }

      if (mounted) {
        context.read<DashboardProvider>().loadDashboardData();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isOrder ? 'Nuevo Pedido' : 'Registrar Compra',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Elements...
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Supplier & Date Fields
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3, // More space for Supplier
                                  child: _buildGlassField(
                                    icon: Icons.store,
                                    label: 'Proveedor',
                                    child: Consumer<SupplierProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButtonHideUnderline(
                                          child: DropdownButton<Supplier>(
                                            value: _selectedSupplier,
                                            hint: const Text(
                                                'Proveedor General',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            dropdownColor:
                                                const Color(0xFF1E2432),
                                            style: const TextStyle(
                                                color: Colors.white),
                                            icon: const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.white70),
                                            isExpanded: true,
                                            items: [
                                              const DropdownMenuItem<Supplier>(
                                                value: null,
                                                child:
                                                    Text('Proveedor General'),
                                              ),
                                              ...provider.suppliers.map(
                                                (s) => DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s.name),
                                                ),
                                              )
                                            ],
                                            onChanged: (val) => setState(
                                                () => _selectedSupplier = val),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: GestureDetector(
                                    onTap: _pickDate,
                                    child: _buildGlassField(
                                      icon: Icons.calendar_today,
                                      label: 'Fecha',
                                      child: Text(
                                        DateFormat('dd/MM/yy')
                                            .format(_selectedDate),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 2. Schedule as Order Checkbox
                          _buildOrderToggle(),

                          const SizedBox(height: 24),

                          // 3. Products Header
                          Divider(
                              color: Colors.white.withValues(alpha: 0.1),
                              height: 1),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Productos',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add_circle,
                                    color: AppTheme.primary, size: 18),
                                label: const Text(
                                  'Agregar Producto',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 4. Products List or Empty State
                          if (_items.isEmpty)
                            _buildEmptyState()
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _PurchaseItemRow(
                                  key: ValueKey(_items[index].productId),
                                  item: _items[index],
                                  product: context
                                      .read<InventoryProvider>()
                                      .products
                                      .firstWhere(
                                          (p) =>
                                              p.id == _items[index].productId,
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

                          // Space for fixed footer
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Bottom Total Card (Fixed)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildTotalCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassField(
      {required IconData icon, required String label, required Widget child}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF), // White 15%
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x1AFFFFFF), // White 10%
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 10)),
                Row(
                  children: [
                    // Icon(icon, color: const Color(0xFFA0A8C1), size: 20),
                    // const SizedBox(width: 12),
                    Expanded(child: child),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isOrder = !_isOrder),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: Color(0xFF4A90E2), size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agendar como Pedido',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'No afectará el stock hasta que se reciba',
                          style: TextStyle(
                            color: Colors.grey[400], // #A0A8C1
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Custom Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _isOrder ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isOrder
                            ? AppTheme.primary
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: _isOrder
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Agrega productos a la compra',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFA0A8C1),
            ),
          ),
        ],
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF), // White 15%
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Total a Pagar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFA0A8C1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bs. ${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary, // Coral
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 16),
                // SAVE BUTTON
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _save,
                      borderRadius: BorderRadius.circular(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'GUARDAR COMPRA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
  bool _isBox = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.unitsPerSaleUnit > 1 &&
        widget.item.quantity > 0 &&
        widget.item.quantity % widget.product.unitsPerSaleUnit == 0) {
      _isBox = true;
      _qtyController = TextEditingController(
          text: (widget.item.quantity / widget.product.unitsPerSaleUnit)
              .toStringAsFixed(0));
    } else {
      _isBox = false;
      _qtyController =
          TextEditingController(text: widget.item.quantity.toString());
    }
    
    final displayCost = _isBox ? widget.item.unitPrice * widget.product.unitsPerSaleUnit : widget.item.unitPrice;
    _costController =
        TextEditingController(text: displayCost.toString());
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
    final multiplier = _isBox ? widget.product.unitsPerSaleUnit : 1.0;
    
    final totalQty = rawQty * multiplier;
    final unitPrice = multiplier > 0 ? (cost / multiplier) : cost;

    if (totalQty != widget.item.quantity || unitPrice != widget.item.unitPrice) {
      widget.onChanged(widget.item.copyWith(
        quantity: totalQty,
        unitPrice: unitPrice,
        subtotal: totalQty * unitPrice,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product Icon
                // Product Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    image: (widget.product.imagePath != null &&
                            widget.product.imagePath!.isNotEmpty)
                        ? DecorationImage(
                            image: FileImage(File(widget.product.imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (widget.product.imagePath != null &&
                          widget.product.imagePath!.isNotEmpty)
                      ? null
                      : Center(
                          child: Text(
                            widget.item.productName.isNotEmpty
                                ? widget.item.productName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.productName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 24,
                              child: TextField(
                                controller: _qtyController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  border: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white10)),
                                  enabledBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white10)),
                                  suffixText: _isBox ? ' Cajas' : ' Unid',
                                  suffixStyle: const TextStyle(
                                      color: Colors.white38, fontSize: 10),
                                ),
                                onChanged: (_) => _updateValues(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('x',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 24,
                              child: TextField(
                                controller: _costController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  border: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white10)),
                                  enabledBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white10)),
                                  prefixText: 'Bs. ',
                                  suffixText: _isBox ? ' /caja' : ' /uni',
                                  prefixStyle: const TextStyle(
                                      color: Colors.white38, fontSize: 10),
                                ),
                                onChanged: (_) => _updateValues(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Subtotal & Delete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${widget.item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: widget.onRemove,
                      child: const Icon(Icons.close,
                          color: AppTheme.redAccent, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
  InventoryProvider? _inventoryProvider;
  String _savedQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inventoryProvider = context.read<InventoryProvider>();
    _savedQuery = _inventoryProvider?.searchQuery ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inventoryProvider?.setSearchQuery('');
    });
  }

  @override
  void dispose() {
    _inventoryProvider?.setSearchQuery(_savedQuery);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final products = provider.filteredProducts;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2432),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0x1AFFFFFF),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o código...',
                      hintStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      provider.setSearchQuery(val);
                    },
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: products.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No se encontraron productos',
                        style: TextStyle(color: Colors.white54)),
                  ))
                : Container(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5),
                    child: ListView.separated(
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.white10),
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              image: (p.imagePath != null &&
                                      p.imagePath!.isNotEmpty)
                                  ? DecorationImage(
                                      image: FileImage(File(p.imagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child:
                                (p.imagePath != null && p.imagePath!.isNotEmpty)
                                    ? null
                                    : Center(
                                        child: Text(
                                          p.name.isNotEmpty
                                              ? p.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                              'Stock: ${p.stock} | Costo: ${p.cost.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white54)),
                          trailing:
                              const Icon(Icons.add, color: AppTheme.primary),
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
