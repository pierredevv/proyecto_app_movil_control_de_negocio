import 'dart:io';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../models/product.dart';
import '../../models/category.dart';
import '../../providers/inventory_provider.dart';
import '../../services/database_service.dart';
import '../../models/supplier.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validators.dart';
import 'barcode_scanner_view.dart';
import 'category_selection_modal.dart';

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
  late TextEditingController _unitsPerBoxController;

  List<Category> _categories = [];
  List<Supplier> _suppliers = [];
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  String _unitType = 'UN';
  bool _isLoading = true;
  String? _imagePath;
  bool _showLowStockAlert = false;

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
    _imagePath = p?.imagePath;
    _showLowStockAlert = (p?.minStock ?? 0) > 0;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar Foto'),
                onTap: () async {
                  final img =
                      await picker.pickImage(source: ImageSource.camera);
                  if (!context.mounted) return;
                  Navigator.pop(context, img);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () async {
                  final img =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (!context.mounted) return;
                  Navigator.pop(context, img);
                },
              ),
            ],
          ),
        ),
      );

      if (image != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String savedPath = path.join(appDir.path, fileName);
        await image.saveTo(savedPath);

        setState(() {
          _imagePath = savedPath;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    // Navigate to BarcodeScannerView
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerView()),
    );

    if (!mounted) return;

    if (result != null && result is String) {
      if (!mounted) return;
      setState(() {
        _barcodeController.text = result;
      });
    }
  }

  Future<void> _selectCategory() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CategorySelectionModal(selectedCategoryId: _selectedCategoryId),
    );

    if (!mounted) return;

    if (result != null && result is Category) {
      setState(() {
        _selectedCategoryId = result.id;
      });
      // Optionally reload categories if a new one was added, but the modal returns the object so we strictly need ID.
      // If new category was added, InventoryProvider.categories is updated.
      // We should update our local _categories list.
      _loadInitialData(); // Reload to be safe
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0;
    final stock = double.tryParse(_stockController.text) ?? 0;
    final minStock =
        _showLowStockAlert ? (int.tryParse(_minStockController.text) ?? 0) : 0;
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
      imagePath: _imagePath,
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
    final theme = Theme.of(context);

    // Find selected category name
    String categoryName = 'Seleccionar Categoría';
    if (_selectedCategoryId != null) {
      final cat = _categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => Category(id: -1, name: 'Desconocido'),
      );
      if (cat.id != -1) categoryName = cat.name;
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        // Main scrollable area
                        padding: const EdgeInsets.fromLTRB(20, 100, 20,
                            100), // Top pad for header, Bottom for button
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Section
                              Center(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                            shape: BoxShape.circle,
                                            image: _imagePath != null
                                                ? DecorationImage(
                                                    image: FileImage(
                                                        File(_imagePath!)),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                            border: _imagePath == null
                                                ? Border.all(
                                                    color: theme.dividerColor)
                                                : null),
                                        child: _imagePath == null
                                            ? Icon(Icons.camera_alt,
                                                size: 40,
                                                color: theme.iconTheme.color
                                                    ?.withValues(alpha: 0.5))
                                            : null,
                                      ),
                                      if (_imagePath != null)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            child: const Icon(Icons.edit,
                                                size: 16, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_imagePath == null)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text('Subir Imagen',
                                        style: TextStyle(
                                            color: theme.primaryColor)),
                                  ),
                                ),

                              const SizedBox(height: 30),

                              // Name
                              _buildSectionTitle('Información Básica'),
                              TextFormField(
                                controller: _nameController,
                                decoration: _inputDecoration(
                                    'Nombre del Producto *',
                                    Icons.inventory_2_outlined),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                validator: InputValidators.validateName,
                              ),
                              const SizedBox(height: 16),

                              // Barcode
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _barcodeController,
                                      decoration: _inputDecoration(
                                          'Código de Barras', Icons.qr_code),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton.filledTonal(
                                    onPressed: _scanBarcode,
                                    icon: const Icon(Icons.qr_code_scanner),
                                    tooltip: 'Escanear',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Category
                              InkWell(
                                onTap: _selectCategory,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: _inputDecoration(
                                      'Categoría', Icons.category_outlined),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(categoryName,
                                          style: TextStyle(
                                              color: _selectedCategoryId != null
                                                  ? theme.textTheme.bodyLarge
                                                      ?.color
                                                  : theme.hintColor)),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                              _buildSectionTitle('Precios'),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _costController,
                                      decoration: _inputDecoration(
                                          'Costo *', Icons.attach_money),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (val) => InputValidators
                                          .validatePositiveDecimal(val,
                                              fieldName: 'Costo'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceController,
                                      decoration: _inputDecoration(
                                          'Precio Venta *',
                                          Icons.sell_outlined),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (val) {
                                        final err = InputValidators
                                            .validatePositiveDecimal(val,
                                                fieldName: 'Precio');
                                        if (err != null) return err;
                                        return InputValidators
                                            .validatePriceVsCost(
                                                val, _costController.text);
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),
                              _buildSectionTitle('Inventario & Alertas'),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _stockController,
                                      decoration: _inputDecoration(
                                          'Stock Actual *',
                                          Icons.warehouse_outlined),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (val) =>
                                          val == null || val.isEmpty
                                              ? 'Requerido'
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Warnings / Alerts Toggle
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Alertas de Stock Bajo'),
                                subtitle: Text(_showLowStockAlert
                                    ? 'Activado'
                                    : 'Desactivado'),
                                value: _showLowStockAlert,
                                onChanged: (val) {
                                  setState(() {
                                    _showLowStockAlert = val;
                                  });
                                },
                              ),

                              if (_showLowStockAlert) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                    controller: _minStockController,
                                    decoration: _inputDecoration('Stock Mínimo',
                                        Icons.warning_amber_rounded),
                                    keyboardType: TextInputType.number,
                                    validator: (val) {
                                      if (_showLowStockAlert) {
                                        return InputValidators
                                            .validatePositiveInteger(val,
                                                fieldName: 'Stock Mínimo');
                                      }
                                      return null;
                                    }),
                              ],

                              const SizedBox(height: 24),
                              ExpansionTile(
                                title: const Text('Opciones Avanzadas'),
                                tilePadding: EdgeInsets.zero,
                                children: [
                                  // Supplier
                                  DropdownButtonFormField<int>(
                                    initialValue: _selectedSupplierId,
                                    decoration: _inputDecoration('Proveedor',
                                        Icons.local_shipping_outlined),
                                    items: _suppliers.map((s) {
                                      return DropdownMenuItem<int>(
                                        value: s.id,
                                        child: Text(s.name),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(
                                        () => _selectedSupplierId = val),
                                    hint: const Text('Seleccionar Proveedor'),
                                  ),
                                  const SizedBox(height: 16),
                                  // Units
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _unitType,
                                          decoration: _inputDecoration(
                                              'Unidad', Icons.scale),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'UN',
                                                child: Text('Unidad')),
                                            DropdownMenuItem(
                                                value: 'BX',
                                                child: Text('Caja')),
                                            DropdownMenuItem(
                                                value: 'KG', child: Text('Kg')),
                                          ],
                                          onChanged: (val) =>
                                              setState(() => _unitType = val!),
                                        ),
                                      ),
                                      if (_unitType != 'UN') ...[
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _unitsPerBoxController,
                                            decoration: _inputDecoration(
                                                'Equivalencia', Icons.numbers),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Fixed Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 90, // Include Status Bar
                    padding: const EdgeInsets.only(
                        top: 30, left: 20, right: 20, bottom: 10),
                    decoration: BoxDecoration(
                      color:
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                      border: Border(
                          bottom: BorderSide(
                              color:
                                  theme.dividerColor.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Editar Producto' : 'Nuevo Producto',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fixed Action Button
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isEdit ? 'Guardar Cambios' : 'Crear Producto',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Theme.of(context).cardColor,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
      ),
    );
  }
}
