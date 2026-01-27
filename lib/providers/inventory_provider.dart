import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/invoice_item.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

import '../models/category.dart';

enum SortOption { nameAsc, stockAsc, priceAsc, priceDesc }

enum StockStatus { sufficient, moderate, critical }

class InventoryProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Filter State
  SortOption _currentSort = SortOption.nameAsc;
  List<int> _selectedCategories =
      []; // Replaces single _selectedCategoryId logic
  List<StockStatus> _selectedStockStatuses = [];
  RangeValues? _priceRange;
  RangeValues? _stockRange;

  // Getters
  SortOption get currentSort => _currentSort;
  List<int> get selectedCategories => _selectedCategories;
  List<StockStatus> get selectedStockStatuses => _selectedStockStatuses;
  RangeValues? get priceRange => _priceRange;
  RangeValues? get stockRange => _stockRange;

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
  bool get isLoading => _isLoading;

  List<Product> get filteredProducts {
    var result = List<Product>.from(_products);

    // 1. Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.barcode.contains(query);
      }).toList();
    }

    // 2. Categories
    if (_selectedCategories.isNotEmpty) {
      result = result
          .where((p) => _selectedCategories.contains(p.categoryId))
          .toList();
    }

    // 3. Stock Status
    if (_selectedStockStatuses.isNotEmpty) {
      result = result.where((p) {
        bool matches = false;
        for (final status in _selectedStockStatuses) {
          if (status == StockStatus.sufficient && p.stock > 10) {
            matches = true;
          }
          if (status == StockStatus.moderate && p.stock >= 3 && p.stock <= 10) {
            matches = true;
          }
          if (status == StockStatus.critical && p.stock < 3) {
            matches = true;
          }
        }
        return matches;
      }).toList();
    }

    // 4. Price Range
    if (_priceRange != null) {
      result = result
          .where((p) =>
              p.price >= _priceRange!.start && p.price <= _priceRange!.end)
          .toList();
    }

    // 5. Stock Range
    if (_stockRange != null) {
      result = result
          .where((p) =>
              p.stock >= _stockRange!.start && p.stock <= _stockRange!.end)
          .toList();
    }

    // 6. Sorting
    result.sort((a, b) {
      switch (_currentSort) {
        case SortOption.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortOption.stockAsc:
          return a.stock.compareTo(b.stock);
        case SortOption.priceAsc:
          return a.price.compareTo(b.price);
        case SortOption.priceDesc:
          return b.price.compareTo(a.price);
      }
    });

    return result;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
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
    notifyListeners();
  }

  void clearFilters() {
    _currentSort = SortOption.nameAsc;
    _selectedCategories = [];
    _selectedStockStatuses = [];
    _priceRange = null;
    _stockRange = null;
    // Keep search query as it's usually separate, or clear it too?
    // Usually search is separate. keeping it.
    notifyListeners();
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
    notifyListeners();
  }

  // Legacy support wrapper
  void setCategoryFilter(int? categoryId) {
    if (categoryId == null) {
      _selectedCategories = [];
    } else {
      _selectedCategories = [categoryId];
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _db.getProducts();
      // Also load categories if they haven't been loaded or simple reload
      _categories = await _db.getCategories();
    } catch (e) {
      debugPrint("Error loading products/categories: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _db.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  Future<void> addCategory(String name) async {
    try {
      final category = Category(name: name);
      await _db.insertCategory(category);
      await loadCategories();
    } catch (e) {
      debugPrint("Error adding category: $e");
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
      await loadProducts();
    } catch (e) {
      debugPrint("Error adding/updating product: $e");
      rethrow;
    }
  }

  // ... updateProduct, deleteProduct, addPurchase ...

  // ... existing methods ...

  // Category Definitions Wrappers (Optional, or use DB directly in Manager)
  Future<void> reloadCategories() async {
    await loadCategories();
  }

  // ... (Rest of file)

  Future<void> updateProduct(Product product) async {
    try {
      await _db.updateProduct(product);
      await loadProducts();
    } catch (e) {
      debugPrint("Error updating product: $e");
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _db.deleteProduct(id);
      await loadProducts();
    } catch (e) {
      debugPrint("Error deleting product: $e");
      rethrow;
    }
  }

  Future<void> addPurchase(Purchase purchase) async {
    try {
      await _db.insertPurchase(purchase);

      // Optimistic Update / Refresh
      // Since cost and stock changed for multiple products, reloading might be safest
      // to keep sync with DB trigger/logic if any.
      // But we can also iterate and update local state for speed.
      for (var item in purchase.items) {
        final index = _products.indexWhere((p) => p.id == item.productId);
        if (index != -1) {
          final p = _products[index];
          _products[index] = p.copyWith(
            stock: p.stock + item.quantity,
            cost: item.unitPrice,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding purchase: $e");
      rethrow;
    }
  }

  void processSale(List<InvoiceItem> soldItems) {
    for (var item in soldItems) {
      final index = _products.indexWhere((p) => p.id == item.productId);
      if (index != -1) {
        final p = _products[index];
        _products[index] = p.copyWith(
          stock: p.stock - item.quantity,
        );
      }
    }
    notifyListeners();
  }

  // Valuation: Sum (Stock * Cost)
  double get totalInventoryValue {
    return _products.fold(0.0, (sum, product) {
      return sum + (product.stock * product.cost);
    });
  }

  List<Product> get lowStockProducts {
    return _products.where((p) => p.stock <= p.minStock).toList();
  }

  Future<void> updateStock(int productId, double quantity) async {
    // Logic to update local state optimistically or reload?
    // For now reload for safety
    await loadProducts();
  }
}
