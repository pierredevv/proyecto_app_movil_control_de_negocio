import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/transaction_model.dart';
import '../models/invoice_item.dart';
import '../models/category.dart';
import '../models/supplier.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  String? _testDbPath;

  @visibleForTesting
  void setTestDbPath(String path) {
    _testDbPath = path;
    _database = null; // Reset
  }

  Future<Database> _initDatabase() async {
    if (_testDbPath != null) {
      return await openDatabase(_testDbPath!, version: 4,
          onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      }, onCreate: (db, version) async {
        await _createTables(db);
        await _createCategoriesTable(db);
        await _createSuppliersTable(db);
      }, onUpgrade: (db, old, newV) async {
        // For tests we usually start fresh, but logic here:
        // ... same upgrade logic if needed, but inMemory usually starts fresh
        if (old < 2) await _createCategoriesTable(db);
        if (old < 3) await _createSuppliersTable(db);
        // ... etc
      });
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dulces_pierre.db');

    return await openDatabase(
      path,
      version: 6, // Updated to version 6
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _createCategoriesTable(db);
        await _createSuppliersTable(db); // Ensure fresh install gets suppliers
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCategoriesTable(db);
        }
        if (oldVersion < 3) {
          await _createSuppliersTable(db);
          // Add supplier_id to products table
          try {
            await db
                .execute('ALTER TABLE products ADD COLUMN supplier_id INTEGER');
          } catch (e) {
            // Column might already exist if dev re-ran code
            debugPrint('Error adding supplier_id column: $e');
          }
        }
        if (oldVersion < 4) {
          // Add unit_type and units_per_box
          try {
            await db.execute(
                "ALTER TABLE products ADD COLUMN unit_type TEXT DEFAULT 'UN'");
            await db.execute(
                "ALTER TABLE products ADD COLUMN units_per_box REAL DEFAULT 1.0");
          } catch (e) {
            debugPrint('Error adding V4 columns: $e');
          }
        }
        if (oldVersion < 5) {
          // Add image_path
          try {
            await db.execute("ALTER TABLE products ADD COLUMN image_path TEXT");
          } catch (e) {
            debugPrint('Error adding image_path column: $e');
          }
        }
        if (oldVersion < 6) {
          // Soft delete support
          try {
            await db.execute(
                "ALTER TABLE products ADD COLUMN is_active INTEGER DEFAULT 1");
          } catch (e) {
            debugPrint('Error adding is_active column: $e');
          }
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // Products Table
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        stock REAL NOT NULL DEFAULT 0, -- Changed to REAL
        min_stock INTEGER NOT NULL DEFAULT 0,
        category_id INTEGER,
        supplier_id INTEGER,
        unit_type TEXT DEFAULT 'UN',
        units_per_box REAL DEFAULT 1.0,
        created_at INTEGER,
        image_path TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Customers Table
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        total_debt REAL DEFAULT 0,
        created_at INTEGER
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        entity_id INTEGER,
        entity_name TEXT,
        date INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT,
        FOREIGN KEY (entity_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // Indexes
    await db
        .execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute(
        'CREATE INDEX idx_transactions_entity ON transactions(entity_id)');

    // Transaction Items Table
    await db.execute('''
      CREATE TABLE transaction_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.insert('categories', {'name': 'General'});
    await db.insert('categories', {'name': 'Bebidas'});
    await db.insert('categories', {'name': 'Snacks'});
    await db.insert('categories', {'name': 'Insumos'});
  }

  Future<void> _createSuppliersTable(Database db) async {
    await db.execute('''
      CREATE TABLE suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        category TEXT,
        address TEXT,
        created_at INTEGER
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // CATEGORY OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCT OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateProductStock(int id, int newStock) async {
    final db = await database;
    return await db.update(
      'products',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSACTION OPERATIONS (ATOMIC)
  // ---------------------------------------------------------------------------
  Future<int> insertSale(Sale sale) async {
    final db = await database;

    return await db.transaction((txn) async {
      final saleId = await txn.insert('transactions', sale.toMap());

      for (var item in sale.items) {
        // 1. Get current stock inside transaction (Atomic check)
        final List<Map<String, dynamic>> result = await txn.query(
          'products',
          columns: ['stock', 'name'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        if (result.isEmpty) {
          throw Exception('Producto no encontrado: ID ${item.productId}');
        }

        final currentStock = (result.first['stock'] as num).toDouble();
        final productName = result.first['name'] as String;

        // 2. Check availability
        if (currentStock < item.quantity) {
          throw Exception(
              'Stock insuficiente para "$productName". Disponible: $currentStock');
        }

        // 3. Insert Item
        await txn.insert('transaction_items', {
          'transaction_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
        });

        // 4. Update Stock
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return saleId;
    });
  }

  Future<int> insertPurchase(Purchase purchase) async {
    final db = await database;

    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('transactions', purchase.toMap());

      for (var item in purchase.items) {
        await txn.insert('transaction_items', {
          'transaction_id': purchaseId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
        });

        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ?, cost = ? WHERE id = ?',
          [item.quantity, item.unitPrice, item.productId],
        );
      }
      return purchaseId;
    });
  }

  Future<int> insertPayment(int customerId, double amount) async {
    final db = await database;

    return await db.transaction((txn) async {
      final id = await txn.insert('transactions', {
        'type': 'payment',
        'entity_id': customerId,
        'date': DateTime.now().millisecondsSinceEpoch,
        'total_amount': amount,
        'status': 'COMPLETED',
      });

      await txn.rawUpdate(
        'UPDATE customers SET total_debt = total_debt - ? WHERE id = ?',
        [amount, customerId],
      );
      return id;
    });
  }

  Future<List<Transaction>> getCustomerHistory(int customerId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'entity_id = ? AND (type = ? OR type = ?)',
      whereArgs: [customerId, 'sale', 'payment'],
      orderBy: 'date DESC',
    );

    List<Transaction> transactions = [];

    for (var map in maps) {
      final type = map['type'] as String;
      if (type == 'sale') {
        final id = map['id'] as int;
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Sale.fromMap(map, items));
      } else if (type == 'payment') {
        transactions.add(Payment.fromMap(map));
      }
    }
    return transactions;
  }

  Future<List<Sale>> getSales({int limit = 20, int offset = 0}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: ['sale'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    List<Sale> sales = [];

    for (var map in maps) {
      final id = map['id'] as int;
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );

      final items = List.generate(
          itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
      sales.add(Sale.fromMap(map, items));
    }

    return sales;
  }

  Future<List<Purchase>> getPurchases({int limit = 20, int offset = 0}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: ['purchase'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    List<Purchase> purchases = [];

    for (var map in maps) {
      final id = map['id'] as int;
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );

      final items = List.generate(
          itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
      purchases.add(Purchase.fromMap(map, items));
    }

    return purchases;
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD ANALYTICS
  // ---------------------------------------------------------------------------

  Future<int> insertExpense(String description, double amount) async {
    final db = await database;
    return await db.insert('transactions', {
      'type': 'expense',
      'entity_name': description,
      'date': DateTime.now().millisecondsSinceEpoch,
      'total_amount': amount,
      'status': 'COMPLETED',
    });
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    // Sales (and count)
    final salesResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM transactions 
      WHERE type = 'sale' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Expenses
    final expensesResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM transactions 
      WHERE type = 'expense' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Payments
    final paymentsResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM transactions 
      WHERE type = 'payment' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Purchases
    final purchasesResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM transactions 
      WHERE type = 'purchase' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    final totalSales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPayments =
        (paymentsResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPurchases =
        (purchasesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'sales': totalSales,
      'expenses': totalExpenses,
      'payments': totalPayments,
      'purchases': totalPurchases,
      'balance': (totalSales + totalPayments) - totalExpenses - totalPurchases,
    };
  }

  // ---------------------------------------------------------------------------
  // HISTORY & FILTERS (Phase 8)
  // ---------------------------------------------------------------------------

  Future<List<Transaction>> getTransactions({
    int limit = 50,
    int offset = 0,
    String? type,
    int? startDate,
    int? endDate,
  }) async {
    final db = await database;

    // Build Query
    String whereClause = '1=1';
    List<dynamic> args = [];

    if (type != null) {
      whereClause += ' AND type = ?';
      args.add(type);
    }

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      args.add(startDate);
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      args.add(endDate);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    List<Transaction> transactions = [];

    for (var map in maps) {
      final tType = map['type'] as String;
      if (tType == 'sale') {
        // Optimization: Maybe don't fetch items for list view?
        // But Transaction model requires items for Sale/Purchase currently (checking Model)
        // Sale.fromMap expects items.
        // Let's fetch items for now, or make items optional in fromMap.
        // Assuming we need to show total amount, which is in 'transactions' table already.
        // However, generic Transaction factory might need helper.
        // Let's check Sale.fromMap.
        // For list view, we might not need items.
        // Let's fetch valid empty items to avoid N+1 if possible, or simple fetch.
        // Actually, fetching items for 50 rows is 50 queries. Not ideal.
        // But for "Refinement", let's be safe.
        final id = map['id'] as int;
        // Optimization: For history list, we often just need the total and name.
        // We can pass empty list if Sale.fromMap allows.
        // Checking Sale.fromMap... it likely assigns items.
        // Let's just do the query for now.
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Sale.fromMap(map, items));
      } else if (tType == 'purchase') {
        final id = map['id'] as int;
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Purchase.fromMap(map, items));
      } else if (tType == 'payment') {
        transactions.add(Payment.fromMap(map));
      } else if (tType == 'expense') {
        transactions.add(Expense.fromMap(map));
      }
    }

    // Quick fix for Expense support if Model not ready:
    // If I didn't create Expense class in models/transaction_model.dart, I should.
    // For now, let's filter Expense OUT of the loop if I can't parse it.
    // But I implemented `insertExpense`.

    return transactions;
  }

  // (Existing code)
  Future<List<Transaction>> getRecentTransactions({int limit = 5}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );

    List<Transaction> transactions = [];

    for (var map in maps) {
      final id = map['id'] as int;
      final type = map['type'] as String;

      if (type == 'sale') {
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Sale.fromMap(map, items));
      } else if (type == 'purchase') {
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Purchase.fromMap(map, items));
      } else if (type == 'payment') {
        transactions.add(Payment.fromMap(map));
      } else if (type == 'expense') {
        transactions.add(Expense.fromMap(map));
      }
    }

    return transactions;
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final db = await database;
    final now = DateTime.now();

    List<Map<String, dynamic>> result = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final start =
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59)
          .millisecondsSinceEpoch;

      final query = await db.rawQuery('''
        SELECT SUM(total_amount) as total 
        FROM transactions 
        WHERE type = 'sale' AND date BETWEEN ? AND ?
      ''', [start, end]);

      final total = (query.first['total'] as num?)?.toDouble() ?? 0.0;

      result.add({
        'date': start,
        'amount': total,
      });
    }

    return result;
  }

  Future<List<int>> getFrequentProductIds({int limit = 5}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT ti.product_id, COUNT(ti.product_id) as frequency
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.type = 'sale'
      GROUP BY ti.product_id
      ORDER BY frequency DESC
      LIMIT ?
    ''', [limit]);

    return result.map((row) => row['product_id'] as int).toList();
  }

  Future<Map<String, dynamic>> exportDatabase() async {
    final db = await database;
    final products = await db.query('products');
    final customers = await db.query('customers');
    final transactions = await db.query('transactions');
    final invoiceItems = await db.query('transaction_items');
    final suppliers = await db.query('suppliers');
    final categories = await db.query('categories');

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'version': 1,
      'data': {
        'products': products,
        'customers': customers,
        'transactions': transactions,
        'invoice_items': invoiceItems,
        'suppliers': suppliers,
        'categories': categories,
      }
    };
  }

  // ---------------------------------------------------------------------------
  // SUPPLIER OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('suppliers');
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
