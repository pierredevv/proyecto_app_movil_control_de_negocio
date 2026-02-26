import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:proyecto_app_movil_control_de_negocio/services/database_service.dart';
import 'package:proyecto_app_movil_control_de_negocio/providers/customer_provider.dart';
import 'package:proyecto_app_movil_control_de_negocio/providers/inventory_provider.dart';
import 'package:proyecto_app_movil_control_de_negocio/models/customer.dart';
import 'package:proyecto_app_movil_control_de_negocio/models/product.dart';
import 'package:proyecto_app_movil_control_de_negocio/models/transaction_model.dart';
import 'package:proyecto_app_movil_control_de_negocio/models/invoice_item.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('System Validations', () {
    test('Customer Provider should reject empty name', () async {
      final provider = CustomerProvider();
      DatabaseService().setTestDbPath(inMemoryDatabasePath);

      final badCustomer = Customer(name: '  ', phone: '1234');

      expect(
        () async => await provider.addCustomer(badCustomer),
        throwsA(isA<Exception>()),
      );
    });

    test('Inventory Provider should reject price < cost', () async {
      final provider = InventoryProvider();
      DatabaseService().setTestDbPath(inMemoryDatabasePath);

      final badProduct = Product(
        name: 'Loss Leader',
        barcode: '111',
        price: 10.0,
        cost: 15.0, // Cost > Price
        stock: 100,
        minStock: 5,
        supplierId: null,
        saleUnit: 'UNI',
        unitsPerSaleUnit: 1.0,
      );

      expect(
        () async => await provider.addProduct(badProduct),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Atomic Stock Logic', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      dbService.setTestDbPath(inMemoryDatabasePath);
    });

    test('Selling reduces stock correctly', () async {
      // 1. Create Product
      final p = Product(
          name: 'Test',
          barcode: 'ABC',
          price: 20,
          cost: 10,
          stock: 100,
          minStock: 5);
      await dbService.insertProduct(p);
      final products = await dbService.getProducts();
      final productId = products.first.id!;

      // 2. Perform Sale
      final saleItem = InvoiceItem(
          productId: productId,
          productName: 'Test',
          quantity: 5,
          unitPrice: 20,
          subtotal: 100);
      final sale =
          Sale(date: DateTime.now(), totalAmount: 100, items: [saleItem]);

      await dbService.insertSale(sale);

      // 3. Verify Stock
      final updatedProducts = await dbService.getProducts();
      expect(updatedProducts.first.stock, 95);
    });

    test('Overselling throws exception', () async {
      // 1. Create Product with 10 stock
      final p = Product(
          name: 'Rare',
          barcode: 'R',
          price: 100,
          cost: 50,
          stock: 10,
          minStock: 2);
      await dbService.insertProduct(p);
      final products = await dbService.getProducts();
      final product = products.firstWhere((p) => p.name == 'Rare');
      final productId = product.id!;

      // 2. Try to sell 11
      final saleItem = InvoiceItem(
          productId: productId,
          productName: 'Rare',
          quantity: 11,
          unitPrice: 100,
          subtotal: 1100);
      final sale =
          Sale(date: DateTime.now(), totalAmount: 1100, items: [saleItem]);

      expect(
        () async => await dbService.insertSale(sale),
        throwsA(isA<Exception>()),
      );
    });
  });
}
