import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/invoice_item.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

import '../models/category.dart';

class InventoryProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int? _selectedCategoryId;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  int? get selectedCategoryId => _selectedCategoryId;

  List<Product> get filteredProducts {
    var result = _products;

    // Filter by Category
    if (_selectedCategoryId != null) {
      result =
          result.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // Filter by Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.barcode.contains(query);
      }).toList();
    }

    return result;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(int? categoryId) {
    _selectedCategoryId = categoryId;
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

  Future<void> addProduct(Product product) async {
    // ... existing implementation
    try {
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
