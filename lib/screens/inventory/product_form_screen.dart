import 'dart:io';
import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../models/product.dart';
import '../../models/category.dart';
import '../../providers/inventory_provider.dart';
import '../../services/database_service.dart';
import '../../models/supplier.dart';

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
  String _saleUnit = 'UNI';
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
    _saleUnit = p?.saleUnit ?? 'UNI';
    _unitsPerBoxController =
        TextEditingController(text: p?.unitsPerSaleUnit.toString() ?? '1.0');
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
    final unitsPerSaleUnit =
        double.tryParse(_unitsPerBoxController.text) ?? 1.0;

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
      saleUnit: _saleUnit,
      unitsPerSaleUnit: unitsPerSaleUnit,
      packagingInfo: widget.product?.packagingInfo ?? '',
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Assuming dark mode for now as per design

    return Scaffold(
      backgroundColor: const Color(0xFF151924), // Keep base background
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Background Gradient & Blobs
                Positioned.fill(
                  child: Container(
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
                  ),
                ),
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
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
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
                // Pattern Overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: Image.asset(
                      'assets/images/pattern.png',
                      repeat: ImageRepeat.repeat,
                      color: Colors.white,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Scrollable Form Content
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                      top: 100,
                      left: 16,
                      right: 16,
                      bottom: 100 + bottomPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // 1. Image Upload
                        Center(child: _buildImagePicker()),
                        const SizedBox(height: 24),

                        // 2. Basic Information
                        _buildSectionTitle('Información Básica'),
                        _buildGlassTextField(
                          controller: _nameController,
                          label: 'Nombre del Producto *',
                          hintText: 'Ej. Coca Cola 3L',
                          icon: Icons.shopping_bag_outlined,
                          validator: InputValidators.validateName,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 16),
                        _buildBarcodeField(),
                        const SizedBox(height: 16),
                        _buildCategoryDropdown(),

                        const SizedBox(height: 24),

                        // 3. Prices
                        _buildSectionTitle('Precios'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildGlassTextField(
                                controller: _costController,
                                label: 'Costo *',
                                hintText: '0.00',
                                icon: Icons.attach_money,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (val) =>
                                    InputValidators.validatePositiveDecimal(val,
                                        fieldName: 'Costo'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildGlassTextField(
                                controller: _priceController,
                                label: 'Precio Venta *',
                                hintText: '0.00',
                                icon: Icons.sell_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (val) {
                                  final err =
                                      InputValidators.validatePositiveDecimal(
                                          val,
                                          fieldName: 'Precio');
                                  if (err != null) return err;
                                  return InputValidators.validatePriceVsCost(
                                      val, _costController.text);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 4. Inventory & Alerts
                        _buildSectionTitle('Inventario & Alertas'),
                        _buildGlassTextField(
                          controller: _stockController,
                          label: 'Stock Actual *',
                          hintText: '0.00',
                          icon: Icons.inventory_2_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildStockAlertToggle(),

                        // Animated container for min stock
                        AnimatedCrossFade(
                          firstChild: Container(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildGlassTextField(
                              controller: _minStockController,
                              label: 'Stock Mínimo',
                              hintText: 'Ej. 5',
                              icon: Icons.warning_amber_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (_showLowStockAlert) {
                                  return InputValidators
                                      .validatePositiveInteger(val,
                                          fieldName: 'Stock Mínimo');
                                }
                                return null;
                              },
                            ),
                          ),
                          crossFadeState: _showLowStockAlert
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),

                        const SizedBox(height: 24),

                        // 5. Advanced Options (Collapsible)
                        _buildAdvancedOptions(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // 6. Header (Fixed)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(isEdit),
                ),

                // 7. Create/Save Button (Fixed Bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomButton(isEdit, bottomPadding),
                ),
              ],
            ),
    );
  }

  // --- Widgets ---

  Widget _buildHeader(bool isEdit) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 90,
          padding:
              const EdgeInsets.only(top: 30, left: 20, right: 20, bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF151924)
                .withValues(alpha: 0.6), // More transparent
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdit ? 'Editar Producto' : 'Nuevo Producto',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05), // Lighter fill
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: _imagePath != null
                    ? Image.file(
                        File(_imagePath!),
                        fit: BoxFit.cover,
                        width: 160,
                        height: 160,
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 48,
                        color: Color(0xFF6B7494),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Subir Imagen',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFFFF6B6B),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4A90E2),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    String? hintText, // Added hintText
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label above field
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFA0A8C1),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        // Glassmorphism Input Field
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: TextFormField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              validator: validator,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    Colors.white.withValues(alpha: 0.05), // More transparent
                prefixIcon:
                    Icon(icon, color: const Color(0xFFA0A8C1), size: 24),
                suffixIcon: suffix,
                hintText: hintText, // Use hintText
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                hintStyle: const TextStyle(color: Color(0xFF6B7494)),
                // Border States
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF4A90E2), width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
                ),
                errorStyle:
                    const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return _buildGlassTextField(
      controller: _barcodeController,
      label: 'Código de Barras',
      hintText: 'Escanea o ingresa el código',
      icon: Icons.qr_code,
      keyboardType: TextInputType.number,
      suffix: Container(
        margin: const EdgeInsets.all(8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          onPressed: _scanBarcode,
          icon:
              const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Escanear',
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Categoría',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA0A8C1),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        InkWell(
          onTap: _selectCategory,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined,
                        color: Color(0xFFA0A8C1), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCategoryId != null
                            ? _categories
                                .firstWhere(
                                  (c) => c.id == _selectedCategoryId,
                                  orElse: () =>
                                      Category(id: -1, name: 'Desconocido'),
                                )
                                .name
                            : 'General',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more, color: Color(0xFFA0A8C1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockAlertToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alertas de Stock Bajo',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              _showLowStockAlert ? 'Activado' : 'Desactivado',
              style: const TextStyle(fontSize: 14, color: Color(0xFFA0A8C1)),
            ),
          ],
        ),
        Switch.adaptive(
          value: _showLowStockAlert,
          activeTrackColor: const Color(
              0xFFFF6B6B), // Use activeTrackColor instead of activeColor
          inactiveTrackColor: const Color(0xFF6B7494),
          onChanged: (val) {
            setState(() {
              _showLowStockAlert = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Opciones Avanzadas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconColor: const Color(0xFFA0A8C1),
        collapsedIconColor: const Color(0xFFA0A8C1),
        childrenPadding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 16),
          // Supplier Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Proveedor',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFA0A8C1),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue:
                        _selectedSupplierId, // Change value to initialValue
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    icon:
                        const Icon(Icons.expand_more, color: Color(0xFFA0A8C1)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      prefixIcon: const Icon(Icons.local_shipping_outlined,
                          color: Color(0xFFA0A8C1)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF4A90E2), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    items: _suppliers.map((s) {
                      return DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedSupplierId = val),
                    hint: const Text(
                      'Seleccionar Proveedor',
                      style: TextStyle(color: Color(0xFF6B7494)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Units
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Unidad',
                          style: TextStyle(
                              color: Color(0xFFA0A8C1), fontSize: 14)),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              _saleUnit, // Change value to initialValue
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          icon: const Icon(Icons.expand_more,
                              color: Color(0xFFA0A8C1)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            prefixIcon: const Icon(Icons.scale,
                                color: Color(0xFFA0A8C1)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF4A90E2), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'UNI', child: Text('Unidad (UNI)')),
                            DropdownMenuItem(
                                value: 'CAJ', child: Text('Caja (CAJ)')),
                            DropdownMenuItem(
                                value: 'BOL', child: Text('Bolsa (BOL)')),
                            DropdownMenuItem(
                                value: 'KG', child: Text('Kg (KG)')),
                          ],
                          onChanged: (val) => setState(() => _saleUnit = val!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_saleUnit != 'UNI') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGlassTextField(
                    controller: _unitsPerBoxController,
                    label: 'Equivalencia',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(bool isEdit, double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, bottom: 16 + bottomPadding, top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151924).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
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
            child: Center(
              child: Text(
                isEdit ? 'Guardar Cambios' : 'Crear Producto',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
