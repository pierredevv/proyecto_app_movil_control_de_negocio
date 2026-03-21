import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/category.dart';

class InventoryFilterPanel extends StatefulWidget {
  const InventoryFilterPanel({super.key});

  @override
  State<InventoryFilterPanel> createState() => _InventoryFilterPanelState();
}

class _InventoryFilterPanelState extends State<InventoryFilterPanel> {
  // Local state for draft filters
  late SortOption _sortOption;
  late List<int> _selectedCategories;
  late List<StockStatus> _selectedStockStatuses;
  late RangeValues _priceRange;

  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _maxStockController = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  String _categorySearchQuery = '';

  @override
  void initState() {
    super.initState();
    final provider = context.read<InventoryProvider>();
    // Initialize draft state from provider
    _sortOption = provider.currentSort;
    _selectedCategories = List.from(provider.selectedCategories);
    _selectedStockStatuses = List.from(provider.selectedStockStatuses);
    _priceRange = provider.priceRange ?? const RangeValues(0, 500); // Expanded

    // Init controllers if range exists, else default empty
    if (provider.stockRange != null) {
      _minStockController.text = provider.stockRange!.start.toStringAsFixed(0);
      _maxStockController.text = provider.stockRange!.end.toStringAsFixed(0);
    }
    
    _categorySearchController.addListener(() {
      setState(() {
        _categorySearchQuery = _categorySearchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _minStockController.dispose();
    _maxStockController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    // Parse stock text fields
    double minStock = double.tryParse(_minStockController.text) ?? 0;
    double maxStock = double.tryParse(_maxStockController.text) ?? 999;

    // Only set stock range if inputs are non-empty
    RangeValues? finalStockRange;
    if (_minStockController.text.isNotEmpty ||
        _maxStockController.text.isNotEmpty) {
      finalStockRange = RangeValues(minStock, maxStock);
    }

    context.read<InventoryProvider>().setFilters(
          sort: _sortOption,
          categories: _selectedCategories,
          stockStatuses: _selectedStockStatuses,
          priceRange: _priceRange,
          stockRange: finalStockRange,
        );
    Navigator.pop(context); // Close Bottom Sheet
  }

  void _clearFilters() {
    setState(() {
      _sortOption = SortOption.nameAsc;
      _selectedCategories = [];
      _selectedStockStatuses = [];
      _priceRange = const RangeValues(0, 500);
      _minStockController.clear();
      _maxStockController.clear();
      _categorySearchController.clear();
      _categorySearchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<InventoryProvider>().categories;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12), // High blur
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15), // White 15% opacity
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10), width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDynamicHandle(),
                _buildHeader(context),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSortSection(),
                        _buildDivider(),
                        _buildStockStatusSection(),
                        _buildDivider(),
                        _buildCategoriesSection(categories),
                        _buildDivider(),
                        _buildPriceRangeSection(),
                        _buildDivider(),
                        _buildStockFieldsSection(),
                        const SizedBox(height: 24),
                        _buildBottomButtons(context),
                        const SizedBox(height: 16),
                      ],
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

  Widget _buildDynamicHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Filtrar y Ordenar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 24),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // ==== 4. SORT BY SECTION ====
  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Ordenar por'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSortCard(SortOption.nameAsc, 'Nombre\n(A-Z)'),
            _buildSortCard(SortOption.stockAsc, 'Stock\n(Menor a Mayor)'),
            _buildSortCard(SortOption.priceAsc, 'Precio\n(Menor a Mayor)'),
            _buildSortCard(SortOption.priceDesc, 'Precio\n(Mayor a Menor)'),
          ],
        ),
      ],
    );
  }

  Widget _buildSortCard(SortOption option, String title) {
    final isSelected = _sortOption == option;
    // Calculation to make exactly 2 columns with 8px spacing
    final cardWidth = (MediaQuery.of(context).size.width - 32 - 8) / 2;

    return GestureDetector(
      onTap: () => setState(() => _sortOption = option),
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B6B).withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF6B6B)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Radio Indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF6B6B)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==== 5. STOCK STATUS SECTION ====
  Widget _buildStockStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Estado de Stock'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(StockStatus.sufficient, 'Suficiente',
                const Color(0xFF51CF66), Icons.check_circle),
            _buildStatusChip(StockStatus.moderate, 'Moderado',
                const Color(0xFFFFA94D), Icons.warning),
            _buildStatusChip(StockStatus.critical, 'Crítico',
                const Color(0xFFFF6B6B), Icons.error),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(
      StockStatus status, String label, Color hue, IconData iconData) {
    final isSelected = _selectedStockStatuses.contains(status);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedStockStatuses.remove(status);
          } else {
            _selectedStockStatuses.add(status);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? hue.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? hue : hue.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              color: isSelected ? hue : hue.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? hue : hue.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==== 6 & 7. CATEGORIES SECTION ====
  Widget _buildCategoriesSection(List<Category> categories) {
    final filteredCategories = categories
        .where((c) => c.name.toLowerCase().contains(_categorySearchQuery))
        .toList();
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Categorías'),
        // Glassmorphic Search Input
        Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: TextField(
                controller: _categorySearchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Buscar categoría...',
                  hintStyle: TextStyle(
                    color: Color(0xFF6B7494),
                    fontSize: 15,
                  ),
                  prefixIcon:
                      Icon(Icons.search, color: Color(0xFFA0A8C1), size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ),
        ),
        // Wrappable Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredCategories.map((c) => _buildCategoryChip(c)).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(Category category) {
    final isSelected = _selectedCategories.contains(category.id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCategories.remove(category.id);
          } else {
            _selectedCategories.add(category.id!);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A90E2).withValues(alpha: 0.2) // Blue 20%
              : const Color(0xFF333333).withValues(alpha: 0.3), // Dark Gray 30%
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A90E2)
                : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category.name,
          style: TextStyle(
            color:
                isSelected ? const Color(0xFF4A90E2) : const Color(0xFFA0A8C1),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ==== 8. PRICE RANGE SECTION ====
  Widget _buildPriceRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Rango de Precio'),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFFF6B6B),
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
            thumbColor: const Color(0xFFFF6B6B),
            overlayColor: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
            trackHeight: 4.0,
          ),
          child: RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000,
            divisions: 100,
            onChanged: (values) => setState(() => _priceRange = values),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min: \$${_priceRange.start.round()}',
                style: const TextStyle(fontSize: 14, color: Colors.white)),
            Text('Max: \$${_priceRange.end.round()}+',
                style: const TextStyle(fontSize: 14, color: Colors.white)),
          ],
        )
      ],
    );
  }

  // ==== 9. STOCK FILTER SECTION ====
  Widget _buildStockFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Filtro de Stock'),
        Row(
          children: [
            Expanded(
              child: _buildGlassInputBox(
                label: 'Mínimo Stock',
                placeholder: '0',
                controller: _minStockController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGlassInputBox(
                label: 'Máximo Stock',
                placeholder: '999',
                controller: _maxStockController,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildGlassInputBox({
    required String label,
    required String placeholder,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFA0A8C1),
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(color: Color(0xFF6B7494)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==== 10. BOTTOM BUTTONS ====
  Widget _buildBottomButtons(BuildContext context) {
    return Row(
      children: [
        // Clean Button (45%)
        Expanded(
          flex: 45,
          child: GestureDetector(
            onTap: _clearFilters,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: const Center(
                    child: Text(
                      'Limpiar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Apply Filters Button (55%)
        Expanded(
          flex: 55,
          child: GestureDetector(
            onTap: _applyFilters,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  'Aplicar Filtros',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
