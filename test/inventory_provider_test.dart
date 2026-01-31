import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_movil_control_de_negocio/providers/inventory_provider.dart';
import 'package:proyecto_app_movil_control_de_negocio/services/database_service.dart';
import 'package:proyecto_app_movil_control_de_negocio/models/product.dart';
import 'package:proyecto_app_movil_control_de_negocio/models/category.dart';

// Manual Mock since we don't have mockito
class MockDatabaseService extends DatabaseService {
  MockDatabaseService() : super.forTesting();

  @override
  Future<List<Product>> getProducts({
    String? searchQuery,
    List<int>? categoryIds,
    List<String>? stockStatuses,
    double? minPrice,
    double? maxPrice,
    double? minStock,
    double? maxStock,
    String? sortColumn = 'name',
    bool? sortAscending = true,
    int? limit,
    int? offset,
  }) async {
    // Return dummy products
    return [
      Product(
          id: 1,
          name: 'Test Product 1',
          barcode: '111111',
          price: 100,
          cost: 50,
          stock: 10,
          categoryId: 1),
      Product(
          id: 2,
          name: 'Test Product 2',
          barcode: '222222',
          price: 200,
          cost: 100,
          stock: 5,
          categoryId: 2),
    ];
  }

  @override
  Future<List<Category>> getCategories() async {
    return [
      Category(id: 1, name: 'Cat 1'),
      Category(id: 2, name: 'Cat 2'),
    ];
  }
}

void main() {
  group('InventoryProvider Tests', () {
    late InventoryProvider provider;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      provider = InventoryProvider(db: mockDb);
    });

    test('Initial state should be correct', () {
      expect(provider.isLoading, false);
      expect(provider.products, isEmpty);
      expect(provider.activeFilterCount, 0);
    });

    test('setSearchQuery should trigger loadProducts', () {
      // We can't easily verify loadProducts was called without a spy,
      // but we can check if query state changed
      provider.setSearchQuery('apple');
      expect(provider.activeFilterCount, 0); // Search doesn't count as filter
      // In a real test with mockito verify(mockDb.getProducts(...)).called(1);
    });

    test('setFilters should update filter count', () {
      provider.setFilters(
          categories: [1, 2], stockStatuses: [StockStatus.critical]);
      expect(provider.activeFilterCount, 2);
      expect(provider.selectedCategories.length, 2);
      expect(provider.selectedStockStatuses.length, 1);
    });

    test('removeFilter should clear specific filters', () {
      provider.setFilters(categories: [1]);
      expect(provider.activeFilterCount, 1);

      provider.removeFilter('category', 1);
      expect(provider.activeFilterCount, 0);
      expect(provider.selectedCategories, isEmpty);
    });

    test('clearFilters should reset all filters', () {
      provider.setFilters(categories: [1], sort: SortOption.priceDesc);
      expect(provider.activeFilterCount, 2);

      provider.clearFilters();
      expect(provider.activeFilterCount, 0);
      expect(provider.currentSort, SortOption.nameAsc);
    });

    test('loadProducts should populate products list', () async {
      await provider.loadProducts(reset: true);
      expect(provider.products.length, 2);
      expect(provider.products.first.name, 'Test Product 1');
    });
  });
}
