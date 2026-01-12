import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../providers/inventory_provider.dart';
import '../../services/database_service.dart';
import '../../models/supplier.dart';
import '../../theme/app_theme.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;

  List<Category> _categories = [];
  List<Supplier> _suppliers = [];
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  String _unitType = 'UN';
  late TextEditingController _unitsPerBoxController;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name);
    _barcodeController = TextEditingController(text: p?.barcode);
    _priceController = TextEditingController(text: p?.price.toString());
    _costController = TextEditingController(text: p?.cost.toString());
    _stockController = TextEditingController(text: p?.stock.toString());
    _minStockController = TextEditingController(text: p?.minStock.toString());
    _selectedCategoryId = p?.categoryId;
    _selectedSupplierId = p?.supplierId;
    _unitType = p?.unitType ?? 'UN';
    _unitsPerBoxController =
        TextEditingController(text: p?.unitsPerBox.toString() ?? '1.0');

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await _db.getCategories();
      final suppliers = await _db.getSuppliers();
      if (mounted) {
        setState(() {
          _categories = categories;
          _suppliers = suppliers;
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitsPerBoxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0;
    final stock = double.tryParse(_stockController.text) ?? 0;
    final minStock = int.tryParse(_minStockController.text) ?? 0;
    final unitsPerBox = double.tryParse(_unitsPerBoxController.text) ?? 1.0;

    final newProduct = Product(
      id: widget.product?.id,
      name: name,
      barcode: barcode,
      price: price,
      cost: cost,
      stock: stock,
      minStock: minStock,
      categoryId: _selectedCategoryId,
      supplierId: _selectedSupplierId,
      unitType: _unitType,
      unitsPerBox: unitsPerBox,
      createdAt: widget.product?.createdAt,
    );

    try {
      final provider = context.read<InventoryProvider>();
      if (widget.product == null) {
        await provider.addProduct(newProduct);
      } else {
        await provider.updateProduct(newProduct);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Producto' : 'Nuevo Producto'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar Producto'),
                    content: const Text(
                        '¿Estás seguro de que deseas eliminar este producto?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Eliminar')),
                    ],
                  ),
                );

                if (confirm != true) return;
                if (!context.mounted) return;

                final provider = context.read<InventoryProvider>();
                await provider.deleteProduct(widget.product!.id!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del Producto *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((c) {
                return DropdownMenuItem<int>(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
              hint: const Text('Seleccionar Categoría'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedSupplierId,
              decoration: const InputDecoration(
                labelText: 'Proveedor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: _suppliers.map((s) {
                return DropdownMenuItem<int>(
                  value: s.id,
                  child: Text(s.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSupplierId = value;
                });
              },
              hint: const Text('Seleccionar Proveedor (Opcional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unitType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Unidad',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UN', child: Text('Unidad (UN)')),
                      DropdownMenuItem(value: 'BX', child: Text('Caja (BX)')),
                      DropdownMenuItem(
                          value: 'KG', child: Text('Kilogramo (KG)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _unitType = value;
                        });
                      }
                    },
                  ),
                ),
                if (_unitType != 'UN') ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitsPerBoxController,
                      decoration: const InputDecoration(
                        labelText: 'Unidades por Caja/Kg',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Código de Barras',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _barcodeController.clear(),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(labelText: 'Costo *'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (double.tryParse(value) == null) return 'Inválido';
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration:
                        const InputDecoration(labelText: 'Precio Venta *'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      final p = double.tryParse(value);
                      if (p == null) return 'Inválido';

                      final cost = double.tryParse(_costController.text) ?? 0;
                      if (p < cost) return 'Menor que costo!';

                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration:
                        const InputDecoration(labelText: 'Stock Actual *'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    decoration:
                        const InputDecoration(labelText: 'Stock Mínimo'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Guardar Producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
