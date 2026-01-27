import 'package:flutter/material.dart';
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

  // Controllers for Stock Range Inputs
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _maxStockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<InventoryProvider>();
    // Initialize draft state from provider
    _sortOption = provider.currentSort;
    _selectedCategories = List.from(provider.selectedCategories);
    _selectedStockStatuses = List.from(provider.selectedStockStatuses);
    _priceRange = provider.priceRange ?? const RangeValues(0, 100);

    // Init controllers if range exists, else default empty
    if (provider.stockRange != null) {
      _minStockController.text = provider.stockRange!.start.toStringAsFixed(0);
      _maxStockController.text = provider.stockRange!.end.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minStockController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    // Parse stock text fields
    double minStock = double.tryParse(_minStockController.text) ?? 0;
    double maxStock = double.tryParse(_maxStockController.text) ?? 999;

    // Only set stock range if inputs are non-empty/modified (logic can be refined)
    RangeValues? finalStockRange;
    if (_minStockController.text.isNotEmpty ||
        _maxStockController.text.isNotEmpty) {
      finalStockRange = RangeValues(minStock, maxStock);
    }

    context.read<InventoryProvider>().setFilters(
          sort: _sortOption,
          categories: _selectedCategories,
          stockStatuses: _selectedStockStatuses,
          priceRange:
              _priceRange, // Check if modified from default logic? For now pass it.
          stockRange: finalStockRange,
        );
    Navigator.pop(context); // Close drawer
  }

  void _clearFilters() {
    setState(() {
      _sortOption = SortOption.nameAsc;
      _selectedCategories = [];
      _selectedStockStatuses = [];
      _priceRange = const RangeValues(0, 100);
      _minStockController.clear();
      _maxStockController.clear();
    });
    // Optional: Immediately apply clear? The design says "Clear Filters" button inside panel.
    // Usually it just clears draft, but user expectation might be reset.
    // Let's Just clear draft.
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<InventoryProvider>().categories;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.cardColor;
    final borderColor = theme.dividerColor;
    final primaryColor = theme.primaryColor;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Sort By
                _buildSectionTitle('Ordenar por'),
                _buildSortOption(SortOption.nameAsc, 'Nombre (A-Z)'),
                _buildSortOption(SortOption.stockAsc, 'Stock (Menor a Mayor)'),
                _buildSortOption(SortOption.priceAsc, 'Precio (Menor a Mayor)'),
                _buildSortOption(
                    SortOption.priceDesc, 'Precio (Mayor a Menor)'),
                const SizedBox(height: 24),

                // 2. Stock Status
                _buildSectionTitle('Estado de Stock'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStockChip(StockStatus.sufficient, 'Suficiente',
                        const Color(0xFF10B981)),
                    _buildStockChip(StockStatus.moderate, 'Moderado',
                        const Color(0xFFF59E0B)),
                    _buildStockChip(StockStatus.critical, 'Crítico',
                        const Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Categories
                _buildSectionTitle('Categorías'),
                const SizedBox(height: 12),
                // Internal Search (Visual only for now or functional?)
                // Plan said "Internal search bar". Let's add a placeholder.
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar categoría...',
                    prefixIcon: Icon(Icons.search,
                        size: 20, color: theme.iconTheme.color),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey[800] : const Color(0xFFF9FAFB),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories
                          .map((cat) => _buildCategoryChip(cat))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Price Range
                _buildSectionTitle('Rango de Precio'),
                RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 500, // Adjust max based on real data if possible
                  divisions: 50,
                  labels: RangeLabels('\$${_priceRange.start.round()}',
                      '\$${_priceRange.end.round()}'),
                  onChanged: (values) {
                    setState(() {
                      _priceRange = values;
                    });
                  },
                  activeColor: primaryColor,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Min: \$${_priceRange.start.round()}',
                        style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color)),
                    Text('Max: \$${_priceRange.end.round()}+',
                        style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Stock Range
                _buildSectionTitle('Filtro de Stock'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildStockInput(
                            'Mínimo Stock', '0', _minStockController)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildStockInput(
                            'Máximo Stock', '999', _maxStockController)),
                  ],
                ),
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Limpiar',
                        style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFEF4444), // Primary Red
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Aplicar Filtros',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // We can show active count from DRAFT state or Provider?
    // "Filter & Sort . 3 active" -> This usually means draft active?
    int activeCount = 0;
    if (_sortOption != SortOption.nameAsc) activeCount++;
    if (_selectedCategories.isNotEmpty) activeCount++;
    if (_selectedStockStatuses.isNotEmpty) activeCount++;
    if (_minStockController.text.isNotEmpty) activeCount++;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          20, 50, 20, 20), // Top padding for status bar
      child: Row(
        children: [
          Text(
            'Filtrar y Ordenar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (activeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSortOption(SortOption option, String label) {
    final isSelected = _sortOption == option;
    return InkWell(
      onTap: () {
        setState(() {
          _sortOption = option;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFEF4444) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockChip(StockStatus status, String label, Color color) {
    final isSelected = _selectedStockStatuses.contains(status);
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon based on status
          if (isSelected)
            const Icon(Icons.check, size: 16, color: Colors.white)
          else
            Icon(
                status == StockStatus.sufficient
                    ? Icons.check_circle_outline
                    : status == StockStatus.moderate
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline,
                size: 16,
                color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: isSelected ? Colors.white : color)),
        ],
      ),
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedStockStatuses.add(status);
          } else {
            _selectedStockStatuses.remove(status);
          }
        });
      },
    );
  }

  Widget _buildCategoryChip(Category category) {
    final isSelected = _selectedCategories.contains(category.id);
    return FilterChip(
      label: Text(category.name),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCategories.add(category.id!);
          } else {
            _selectedCategories.remove(category.id);
          }
        });
      },
      selectedColor: const Color(0xFFEF4444),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  Widget _buildStockInput(
      String label, String placeholder, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: placeholder,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
        ),
      ],
    );
  }
}
