import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/invoice_item.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/snackbar_service.dart';

import '../models/category.dart';

enum SortOption { nameAsc, stockAsc, priceAsc, priceDesc }

enum StockStatus { sufficient, moderate, critical }

class InventoryProvider extends ChangeNotifier {
  late final DatabaseService _db;

  InventoryProvider({DatabaseService? db}) {
    _db = db ?? DatabaseService();
  }

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Filter State
  SortOption _currentSort = SortOption.nameAsc;
  List<int> _selectedCategories = [];
  List<StockStatus> _selectedStockStatuses = [];
  RangeValues? _priceRange;
  RangeValues? _stockRange;

  // Pagination State
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Getters
  SortOption get currentSort => _currentSort;
  List<int> get selectedCategories => _selectedCategories;
  List<StockStatus> get selectedStockStatuses => _selectedStockStatuses;
  RangeValues? get priceRange => _priceRange;
  RangeValues? get stockRange => _stockRange;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String get searchQuery => _searchQuery;

  // Legacy getter compatibility if needed, though we should migrate usage
  int? get selectedCategoryId =>
      _selectedCategories.isNotEmpty ? _selectedCategories.first : null;

  int get activeFilterCount {
    int count = 0;
    if (_currentSort != SortOption.nameAsc) count++;
    if (_selectedCategories.isNotEmpty) count++;
    if (_selectedStockStatuses.isNotEmpty) count++;
    if (_priceRange != null) count++;
    if (_stockRange != null) count++;
    return count;
  }

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  List<Product> get frequentProducts => _frequentProducts;
  bool get isLoading => _isLoading;

  List<Product> _frequentProducts = [];
  List<Product> _lowStockProducts = [];

  List<Product> get lowStockProducts => _lowStockProducts;

  Future<void> loadLowStockProducts() async {
    try {
      _lowStockProducts = await _db.getProducts(stockStatuses: ['critical']);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading low stock products: $e");
    }
  }

  List<Product> get filteredProducts {
    // Logic moved to SQL. Returning _products directly.
    return _products;
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    // Debounce could be added here preferably
    loadProducts(reset: true);
  }

  void setFilters({
    SortOption? sort,
    List<int>? categories,
    List<StockStatus>? stockStatuses,
    RangeValues? priceRange,
    RangeValues? stockRange,
  }) {
    if (sort != null) _currentSort = sort;
    if (categories != null) _selectedCategories = categories;
    if (stockStatuses != null) _selectedStockStatuses = stockStatuses;
    if (priceRange != null) _priceRange = priceRange;
    if (stockRange != null) _stockRange = stockRange;
    loadProducts(reset: true);
  }

  void clearFilters() {
    _currentSort = SortOption.nameAsc;
    _selectedCategories = [];
    _selectedStockStatuses = [];
    _priceRange = null;
    _stockRange = null;
    // Keep search query as it's usually separate, or clear it too?
    // Usually search is separate. keeping it.
    loadProducts(reset: true);
  }

  void removeFilter(String type, [dynamic value]) {
    switch (type) {
      case 'category':
        _selectedCategories.remove(value);
        break;
      case 'stockStatus':
        _selectedStockStatuses.remove(value);
        break;
      case 'price':
        _priceRange = null;
        break;
      case 'stock':
        _stockRange = null;
        break;
      case 'sort':
        _currentSort = SortOption.nameAsc;
        break;
    }

    loadProducts(reset: true);
  }

  // Legacy support wrapper
  void setCategoryFilter(int? categoryId) {
    if (categoryId == null) {
      _selectedCategories = [];
    } else {
      _selectedCategories = [categoryId];
    }
    loadProducts(reset: true);
  }

  Future<void> loadProducts({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _hasMore = true;
      _products = [];
      _isLoading = true;
      notifyListeners();
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      // Convert Enums/Complex types to simple types for DB
      List<String>? statusStrings;
      if (_selectedStockStatuses.isNotEmpty) {
        statusStrings = _selectedStockStatuses.map((s) => s.name).toList();
      }

      String sortCol = 'name';
      bool sortAsc = true;
      switch (_currentSort) {
        case SortOption.nameAsc:
          sortCol = 'name';
          sortAsc = true;
          break;
        case SortOption.stockAsc:
          sortCol = 'stock';
          sortAsc = true;
          break;
        case SortOption.priceAsc:
          sortCol = 'price';
          sortAsc = true;
          break;
        case SortOption.priceDesc:
          sortCol = 'price';
          sortAsc = false;
          break;
      }

      final newProducts = await _db.getProducts(
        searchQuery: _searchQuery,
        categoryIds: _selectedCategories,
        stockStatuses: statusStrings,
        minPrice: _priceRange?.start,
        maxPrice: _priceRange?.end,
        minStock: _stockRange?.start,
        maxStock: _stockRange?.end,
        sortColumn: sortCol,
        sortAscending: sortAsc,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      if (newProducts.length < _pageSize) {
        _hasMore = false;
      }

      if (reset) {
        _products = newProducts;
        _currentPage = 1; // Point to next page
      } else {
        _products.addAll(newProducts);
        _currentPage++;
      }

      // Also load categories if they haven't been loaded or simple reload
      if (reset || _categories.isEmpty) {
        _categories = await _db.getCategories();
      }

      if (reset) {
        _lowStockProducts = await _db.getProducts(stockStatuses: ['critical']);
      }
    } catch (e) {
      debugPrint("Error loading products/categories: $e");
      SnackbarService.showError("Error al cargar inventario");
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _db.getCategories();
      // Don't notify here if we want to avoid UI jumps, but usually fine
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading categories: $e");
      SnackbarService.showError("Error al cargar categorías");
    }
  }

  Future<void> loadFrequentProducts() async {
    try {
      final ids = await _db.getFrequentProductIds(limit: 5);
      // Fetch products by ID
      _frequentProducts = await _db.getProductsByIds(ids);

      // No longer need filtering or mapping from _products
      // _frequentProducts logic handled above with direct DB fetch

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading frequent products: $e");
    }
  }

  Future<void> addCategory(String name) async {
    try {
      final category = Category(name: name);
      await _db.insertCategory(category);
      await loadCategories();
      SnackbarService.showSuccess("Categoría agregada");
    } catch (e) {
      debugPrint("Error adding category: $e");
      SnackbarService.showError("Error al agregar categoría");
      rethrow;
    }
  }

  Future<void> addProduct(Product product) async {
    // ... existing implementation
    try {
      if (product.price < product.cost) {
        throw Exception("El precio no puede ser menor al costo");
      }
      if (product.id != null) {
        await _db.updateProduct(product);
      } else {
        await _db.insertProduct(product);
      }
      await loadProducts(reset: true);
      SnackbarService.showSuccess("Producto guardado exitosamente");
    } catch (e) {
      debugPrint("Error adding/updating product: $e");
      SnackbarService.showError("Error al guardar producto: ${e.toString()}");
      rethrow;
    }
  }

  // Category Definitions Wrappers (Optional, or use DB directly in Manager)
  Future<void> reloadCategories() async {
    await loadCategories();
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _db.updateProduct(product);
      await loadProducts(reset: true);
    } catch (e) {
      debugPrint("Error updating product: $e");
      SnackbarService.showError("Error al actualizar producto");
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _db.deleteProduct(id);
      await loadProducts(reset: true);
      SnackbarService.showSuccess("Producto eliminado");
    } catch (e) {
      debugPrint("Error deleting product: $e");
      SnackbarService.showError("Error al eliminar producto");
      rethrow;
    }
  }

  Future<void> adjustStock(int productId, double deltaBaseUnits, String reason, {String? note, double? unitCost}) async {
    try {
      await _db.adjustStock(productId, deltaBaseUnits, reason, note: note, unitCost: unitCost);
      await loadProducts(reset: true);
      loadLowStockProducts();
      SnackbarService.showSuccess("Stock ajustado exitosamente");
    } catch (e) {
      debugPrint("Error adjusting stock: $e");
      SnackbarService.showError("Error al ajustar stock: $e");
      rethrow;
    }
  }

  Future<void> addPurchase(Purchase purchase, {String paymentMethod = 'EFECTIVO'}) async {
    try {
      await _db.insertPurchase(purchase, paymentMethod: paymentMethod);
      // Removed optimistic update: query DB directly to adhere to SSOT
      await loadProducts(reset: true);
      loadLowStockProducts();
    } catch (e) {
      debugPrint("Error adding purchase: $e");
      rethrow;
    }
  }

  Future<void> addOrder(Order order) async {
    try {
      await _db.insertOrder(order);
      // No stock update for orders until received
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding order: $e");
      rethrow;
    }
  }

  void processSale(List<InvoiceItem> soldItems) {
    for (var item in soldItems) {
      final index = _products.indexWhere((p) => p.id == item.productId);
      if (index != -1) {
        final p = _products[index];
        _products[index] = p.copyWith(
          stock: p.stock - item.baseUnitsTotal,
        );
      }
    }
    notifyListeners();
    loadLowStockProducts();
  }

  // Valuation: Sum (Stock * Cost)
  double get totalInventoryValue {
    return _products.fold(0.0, (sum, product) {
      final unitCost = product.weightedAverageCost > 0 
          ? product.weightedAverageCost 
          : (product.cost / (product.unitsPerSaleUnit > 0 ? product.unitsPerSaleUnit : 1));
      return sum + (product.stock * unitCost);
    });
  }

  Future<void> updateStock(int productId, double quantity) async {
    // Logic to update local state optimistically or reload?
    // For now reload for safety
    await loadProducts(reset: true);
  }
}
