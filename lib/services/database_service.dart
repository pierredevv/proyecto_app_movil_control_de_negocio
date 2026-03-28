import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/transaction_model.dart';
import '../models/invoice_item.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/note.dart';
import '../models/import_result.dart'; // Added for ImportResult

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Constructor for mocking in tests
  @visibleForTesting
  DatabaseService.forTesting();

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
      return await openDatabase(_testDbPath!, version: 13,
          onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA foreign_keys = ON');
      }, onCreate: (db, version) async {
        await _createTables(db);
        await _createCategoriesTable(db);
        await _createSuppliersTable(db);
        await _createNotesTable(db);
      }, onUpgrade: (db, old, newV) async {
        await _runMigrations(db, old, newV);
      });
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dulces_pierre.db');

    return await openDatabase(
      path,
      version: 13, // Updated to version 13 for Treasury Module
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _createCategoriesTable(db);
        await _createSuppliersTable(db); // Ensure fresh install gets suppliers
        await _createNotesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _runMigrations(db, oldVersion, newVersion);
      },
    );
  }

  Future<void> _runMigrations(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCategoriesTable(db);
    }
    if (oldVersion < 3) {
      await _createSuppliersTable(db);
      // Add supplier_id to products table
      try {
        await db.execute('ALTER TABLE products ADD COLUMN supplier_id INTEGER');
      } catch (e) {
        // Column might already exist if dev re-ran code
        debugPrint('Error adding supplier_id column: $e');
      }
    }
    if (oldVersion < 4) {
      // Add unit_type and units_per_box
      try {
        await db.execute(
            "ALTER TABLE products ADD COLUMN unit_type TEXT DEFAULT 'UNI'");
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
    if (oldVersion < 7) {
      await _createNotesTable(db);
    }
    if (oldVersion < 8) {
      // Add wholesale properties
      try {
        await db.execute(
            "ALTER TABLE products ADD COLUMN packaging_info TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE transaction_items ADD COLUMN sale_unit TEXT DEFAULT 'UNI'");
        await db.execute(
            "ALTER TABLE transaction_items ADD COLUMN units_per_sale_unit REAL DEFAULT 1.0");
        await db.execute(
            "ALTER TABLE transaction_items ADD COLUMN packaging_info TEXT DEFAULT ''");

        // Removed: V8 migration for stock was flawed because stock is ALWAYS stored in base units natively.
        // await db.execute('''
        //   UPDATE products
        //   SET stock = stock * units_per_box
        //   WHERE units_per_box > 1 AND is_active = 1
        // ''');
      } catch (e) {
        debugPrint('Error adding V8 properties: $e');
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN reference_id INTEGER");
      } catch (e) {
        debugPrint('Error adding reference_id: $e');
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN amount_paid REAL DEFAULT 0");
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN payment_due_date INTEGER");
        await db.execute('''
          CREATE TABLE sale_payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            date INTEGER NOT NULL,
            note TEXT,
            FOREIGN KEY (sale_id) REFERENCES transactions(id)
          )
        ''');
        // Mark existing sales as fully paid (backwards compatibility)
        await db.execute(
            "UPDATE transactions SET amount_paid = total_amount WHERE type = 'sale' AND status = 'COMPLETED'");
      } catch (e) {
        debugPrint('Error adding V10 details: $e');
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute(
            "ALTER TABLE products ADD COLUMN weighted_average_cost REAL DEFAULT 0");
        await db.execute(
            "ALTER TABLE transaction_items ADD COLUMN unit_cost_at_sale_time REAL DEFAULT 0");
        await db.execute('''
          CREATE TABLE inventory_movements(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            movement_type TEXT NOT NULL,
            quantity REAL NOT NULL,
            reference_type TEXT,
            reference_id INTEGER,
            unit_cost_at_movement REAL NOT NULL DEFAULT 0,
            created_timestamp INTEGER NOT NULL,
            FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_inventory_product_date ON inventory_movements(product_id, created_timestamp DESC)');
        await db.execute(
            'CREATE INDEX idx_transactions_customer_date ON transactions(entity_id, date DESC)');
            
        // Migrate existing cost to WAC for existing products
        await db.execute("UPDATE products SET weighted_average_cost = cost");
      } catch (e) {
        debugPrint('Error adding V11 details: $e');
      }
    }
    if (oldVersion < 12) {
      try {
        await db.execute('''
          CREATE TABLE entity_ledgers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL, 
            entity_id INTEGER NOT NULL,
            transaction_source_type TEXT NOT NULL, 
            transaction_reference_id INTEGER NOT NULL,
            date INTEGER NOT NULL,
            debit_amount REAL NOT NULL DEFAULT 0,
            credit_amount REAL NOT NULL DEFAULT 0,
            materialized_running_balance REAL NOT NULL DEFAULT 0,
            note TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_ledgers_entity_date ON entity_ledgers(entity_type, entity_id, date ASC)');

        // Chronological Retrospective Migration
        final allTxns = await db.query('transactions', orderBy: 'date ASC');
        Map<String, double> runningBalances = {};
        
        await db.transaction((txn) async {
          for (var t in allTxns) {
            if (t['status'] == 'VOIDED') continue;

            final type = t['type'] as String;
            final entityId = t['entity_id'] as int?;
            if (entityId == null) continue;

            final date = t['date'] as int;
            final totalAmount = (t['total_amount'] as num).toDouble();
            final amountPaid = (t['amount_paid'] as num?)?.toDouble() ?? 0.0;
            final id = t['id'] as int;

            String entityType;
            if (type == 'sale' || type == 'payment') {
              entityType = 'CUSTOMER';
            } else if (type == 'purchase') {
              entityType = 'SUPPLIER';
            } else {
              continue; // Exclude pure expenses that have no entity_id linked
            }

            final balanceKey = '${entityType}_$entityId';
            double currentBalance = runningBalances[balanceKey] ?? 0.0;

            if (type == 'sale') {
              // 1. Log Invoice (Debit)
              currentBalance += totalAmount;
              await txn.insert('entity_ledgers', {
                'entity_type': entityType,
                'entity_id': entityId,
                'transaction_source_type': 'INVOICE',
                'transaction_reference_id': id,
                'date': date,
                'debit_amount': totalAmount,
                'credit_amount': 0.0,
                'materialized_running_balance': currentBalance,
                'note': 'Venta Histórica',
              });

              // 2. Log Payment if there was a down payment
              if (amountPaid > 0) {
                currentBalance -= amountPaid;
                await txn.insert('entity_ledgers', {
                  'entity_type': entityType,
                  'entity_id': entityId,
                  'transaction_source_type': 'PAYMENT',
                  'transaction_reference_id': id,
                  'date': date + 1, // Slightly after the invoice
                  'debit_amount': 0.0,
                  'credit_amount': amountPaid,
                  'materialized_running_balance': currentBalance,
                  'note': 'Pago inicial Histórico',
                });
              }
            } else if (type == 'payment') {
              currentBalance -= totalAmount;
              await txn.insert('entity_ledgers', {
                'entity_type': entityType,
                'entity_id': entityId,
                'transaction_source_type': 'PAYMENT',
                'transaction_reference_id': id,
                'date': date,
                'debit_amount': 0.0,
                'credit_amount': totalAmount,
                'materialized_running_balance': currentBalance,
                'note': 'Abono Histórico',
              });
            } else if (type == 'purchase') {
              currentBalance += totalAmount;
              await txn.insert('entity_ledgers', {
                'entity_type': entityType,
                'entity_id': entityId,
                'transaction_source_type': 'PURCHASE',
                'transaction_reference_id': id,
                'date': date,
                'debit_amount': totalAmount,
                'credit_amount': 0.0,
                'materialized_running_balance': currentBalance,
                'note': 'Compra Histórica',
              });
              // Note for backwards compatibility purchases had no amount_paid tracking in v10. So it's 100% debt initially.
            }
            runningBalances[balanceKey] = currentBalance;
          }
        });
      } catch (e) {
        debugPrint('Error adding V12 details (Ledger): $e');
      }
    }
    
    // Sprint C - Treasury Module v13
    if (oldVersion < 13) {
      try {
        await db.execute('''
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_id INTEGER NOT NULL,
            entity_type TEXT NOT NULL, 
            amount REAL NOT NULL,
            date INTEGER NOT NULL,
            payment_method TEXT NOT NULL,
            note TEXT
          )
        ''');
        
        await db.execute('''
          CREATE TABLE payment_allocations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_id INTEGER NOT NULL,
            transaction_id INTEGER NOT NULL, 
            allocated_amount REAL NOT NULL,
            FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
            FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
          )
        ''');
        
        await db.execute('CREATE INDEX idx_payments_entity_date ON payments(entity_id, entity_type, date DESC)');
        await db.execute('CREATE INDEX idx_allocations_transaction ON payment_allocations(transaction_id)');

        // Migration: Move old 'sale_payments' down-payments into the new treasury system
        await db.transaction((txn) async {
           // Find matching entity_id for sale_payments
           final oldPayments = await txn.rawQuery('''
              SELECT sp.id, sp.sale_id, sp.amount, sp.date, sp.note, t.entity_id 
              FROM sale_payments sp
              JOIN transactions t ON sp.sale_id = t.id
           ''');
           
           for (var op in oldPayments) {
              final entityId = op['entity_id'] as int?;
              if (entityId == null) continue; // Skip anonymous payments
              
              final newPaymentId = await txn.insert('payments', {
                  'entity_id': entityId,
                  'entity_type': 'CUSTOMER',
                  'amount': op['amount'],
                  'date': op['date'],
                  'payment_method': 'EFECTIVO', // Legacy default
                  'note': op['note'] ?? 'Historical anonymous sale payment'
              });
              
              await txn.insert('payment_allocations', {
                  'payment_id': newPaymentId,
                  'transaction_id': op['sale_id'],
                  'allocated_amount': op['amount']
              });
           }
           
           // Migrate generic unallocated 'payment' transactions into payments table
           final genericPayments = await txn.query('transactions', where: "type = 'payment' AND status != 'VOIDED'");
           for (var gp in genericPayments) {
              final entityId = gp['entity_id'] as int?;
              if (entityId == null) continue;
              
              await txn.insert('payments', {
                  'entity_id': entityId,
                  'entity_type': 'CUSTOMER',
                  'amount': gp['total_amount'],
                  'date': gp['date'],
                  'payment_method': 'EFECTIVO', // Legacy default
                  'note': 'Abono histórico'
              });
           }
           // We do NOT delete the generic transactions to keep the ledger and history intact.
           // However, from now on, all UI will read from 'payments'.
        });
      } catch (e) {
        debugPrint('Error adding V13 details (Treasury): $e');
      }
    }
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
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
        weighted_average_cost REAL NOT NULL DEFAULT 0,
        stock REAL NOT NULL DEFAULT 0, -- Changed to REAL
        min_stock INTEGER NOT NULL DEFAULT 0,
        category_id INTEGER,
        supplier_id INTEGER,
        unit_type TEXT DEFAULT 'UNI',
        units_per_box REAL DEFAULT 1.0,
        packaging_info TEXT DEFAULT '',
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
        reference_id INTEGER,
        date INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        amount_paid REAL DEFAULT 0,
        payment_due_date INTEGER,
        status TEXT
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
        unit_cost_at_sale_time REAL DEFAULT 0,
        subtotal REAL NOT NULL,
        sale_unit TEXT DEFAULT 'UNI',
        units_per_sale_unit REAL DEFAULT 1.0,
        packaging_info TEXT DEFAULT '',
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Sale Payments Table
    await db.execute('''
      CREATE TABLE sale_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        FOREIGN KEY (sale_id) REFERENCES transactions(id)
      )
    ''');

    // Inventory Movements Table (V11)
    await db.execute('''
      CREATE TABLE inventory_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        unit_cost_at_movement REAL NOT NULL DEFAULT 0,
        created_timestamp INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_inventory_product_date ON inventory_movements(product_id, created_timestamp DESC)');
    await db.execute(
        'CREATE INDEX idx_transactions_customer_date ON transactions(entity_id, date DESC)');

    // Entity Ledgers Table (V12)
    await db.execute('''
      CREATE TABLE entity_ledgers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL, 
        entity_id INTEGER NOT NULL,
        transaction_source_type TEXT NOT NULL, 
        transaction_reference_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        debit_amount REAL NOT NULL DEFAULT 0,
        credit_amount REAL NOT NULL DEFAULT 0,
        materialized_running_balance REAL NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_ledgers_entity_date ON entity_ledgers(entity_type, entity_id, date ASC)');

    // Treasury Module (V13)
    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_id INTEGER NOT NULL,
        entity_type TEXT NOT NULL, 
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        note TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE payment_allocations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_id INTEGER NOT NULL,
        transaction_id INTEGER NOT NULL, 
        allocated_amount REAL NOT NULL,
        FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('CREATE INDEX idx_payments_entity_date ON payments(entity_id, entity_type, date DESC)');
    await db.execute('CREATE INDEX idx_allocations_transaction ON payment_allocations(transaction_id)');
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
    final map = product.toMap();
    if (map['weighted_average_cost'] == null || map['weighted_average_cost'] == 0.0) {
      map['weighted_average_cost'] = map['cost'];
    }
    final id = await db.insert('products', map);
    if (product.stock > 0) {
      await db.insert('inventory_movements', {
        'product_id': id,
        'movement_type': 'INITIAL_STOCK',
        'quantity': product.stock,
        'unit_cost_at_movement': product.cost,
        'created_timestamp': DateTime.now().millisecondsSinceEpoch
      });
    }
    return id;
  }

  Future<List<Product>> getProducts({
    String? searchQuery,
    List<int>? categoryIds,
    List<String>? stockStatuses, // 'sufficient', 'moderate', 'critical'
    double? minPrice,
    double? maxPrice,
    double? minStock,
    double? maxStock,
    String sortColumn = 'name',
    bool sortAscending = true,
    int? limit,
    int? offset,
  }) async {
    final db = await database;

    String whereClause = 'is_active = 1';
    List<dynamic> args = [];

    // 1. Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR barcode LIKE ?)';
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    // 2. Categories
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      whereClause += ' AND category_id IN ($placeholders)';
      args.addAll(categoryIds);
    }

    // 3. Stock Status
    // Logic must match Provider: Critical (<3), Moderate (3-10), Sufficient (>10)
    if (stockStatuses != null && stockStatuses.isNotEmpty) {
      List<String> statusClauses = [];
      for (var status in stockStatuses) {
        if (status == 'critical') {
          statusClauses
              .add('(min_stock > 0 AND stock / units_per_box <= min_stock)');
        } else if (status == 'moderate') {
          statusClauses.add(
              '(min_stock > 0 AND stock / units_per_box > min_stock AND stock / units_per_box <= min_stock * 2)');
        } else if (status == 'sufficient') {
          statusClauses
              .add('(min_stock = 0 OR stock / units_per_box > min_stock * 2)');
        }
      }
      if (statusClauses.isNotEmpty) {
        whereClause += ' AND (${statusClauses.join(' OR ')})';
      }
    }

    // 4. Price Range
    if (minPrice != null) {
      whereClause += ' AND price >= ?';
      args.add(minPrice);
    }
    if (maxPrice != null) {
      whereClause += ' AND price <= ?';
      args.add(maxPrice);
    }

    // 5. Stock Range
    if (minStock != null) {
      whereClause += ' AND stock >= ?';
      args.add(minStock);
    }
    if (maxStock != null) {
      whereClause += ' AND stock <= ?';
      args.add(maxStock);
    }

    // 6. Sorting
    String orderBy = '$sortColumn ${sortAscending ? 'ASC' : 'DESC'}';

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: args,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> getProductsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    
    return await db.transaction((txn) async {
       // Query old stock to detect changes
       final oldRecord = await txn.query('products', columns: ['stock'], where: 'id = ?', whereArgs: [product.id]);
       double oldStock = oldRecord.isNotEmpty ? (oldRecord.first['stock'] as num).toDouble() : 0.0;
       
       final map = product.toMap();
       if ((map['weighted_average_cost'] as double?) == 0.0) {
         map['weighted_average_cost'] = map['cost'];
       }
       
       final result = await txn.update(
         'products',
         map,
         where: 'id = ?',
         whereArgs: [product.id],
       );
       
       if (product.id != null && oldStock != product.stock) {
          final diff = product.stock - oldStock;
          await txn.insert('inventory_movements', {
            'product_id': product.id,
            'movement_type': 'INVENTORY_ADJUSTMENT',
            'quantity': diff,
            'reference_type': 'MANUAL_EDIT',
            'reference_id': product.id,
            'unit_cost_at_movement': product.cost,
            'created_timestamp': DateTime.now().millisecondsSinceEpoch,
          });
       }
       return result;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }



  // ---------------------------------------------------------------------------
  // IMPORT OPERATIONS
  // ---------------------------------------------------------------------------
  Future<Map<String, int>> insertImportedProducts(
      List<ProductImportRow> rows) async {
    final db = await database;
    int insertedCount = 0;
    int updatedCount = 0;
    int errorCount = 0;

    await db.transaction((txn) async {
      for (final row in rows) {
        try {
          // 1. Resolve Category ID
          int? categoryId;
          final catQuery = row.category.trim();
          if (catQuery.isNotEmpty) {
            final existingCat = await txn.query(
              'categories',
              where: 'name LIKE ?',
              whereArgs: [catQuery],
              limit: 1,
            );

            if (existingCat.isNotEmpty) {
              categoryId = existingCat.first['id'] as int;
            } else {
              categoryId = await txn.insert('categories', {
                'name': catQuery,
              });
            }
          }

          // 2. Check Barcode Collision
          final bcQuery = row.barcode.trim();
          bool exists = false;
          int? existingId;

          if (bcQuery.isNotEmpty) {
            final existingProd = await txn.query(
              'products',
              where: 'barcode = ?',
              whereArgs: [bcQuery],
              limit: 1,
            );
            if (existingProd.isNotEmpty) {
              exists = true;
              existingId = existingProd.first['id'] as int;
            }
          }

          if (exists && existingId != null) {
            // Update existing product stock
            final existingItem = await txn.query('products',
                where: 'id = ?', whereArgs: [existingId], limit: 1);
            final currentStock =
                (existingItem.first['stock'] as num).toDouble();
            
            final oldWac = (existingItem.first['weighted_average_cost'] as num?)?.toDouble() ?? 0.0;
            final newTotalStock = currentStock + row.stockBase;
            final newCost = row.cost > 0 ? row.cost : (existingItem.first['cost'] as num).toDouble();
            final newWac = newTotalStock > 0 ? ((currentStock * oldWac) + (row.stockBase * newCost)) / newTotalStock : 0.0;

            await txn.update(
              'products',
              {
                'stock': newTotalStock,
                'price': row.price > 0 ? row.price : existingItem.first['price'],
                'cost': newCost,
                'weighted_average_cost': newWac,
                'is_active': 1,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            
            await txn.insert('inventory_movements', { 
                'product_id': existingId, 
                'movement_type': 'INVENTORY_ADJUSTMENT', 
                'quantity': row.stockBase, 
                'reference_type': 'IMPORT', 
                'unit_cost_at_movement': row.cost > 0 ? row.cost : existingItem.first['cost'], 
                'created_timestamp': DateTime.now().millisecondsSinceEpoch, 
            });

            updatedCount++;
          } else {
            // Insert new product
            await txn.insert('products', {
              'name': row.name,
              'barcode': row.barcode,
              'price': row.price,
              'cost': row.cost,
              'weighted_average_cost': row.cost,
              'stock': row.stockBase, // Always in base units
              'min_stock': 0,
              'category_id': categoryId,
              'supplier_id': null,
              'unit_type': row.saleUnit,
              'units_per_box': row.unitsPerSaleUnit,
              'packaging_info': row.packagingInfo,
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'image_path': null,
              'is_active': 1,
            });
            insertedCount++;
          }
        } catch (e) {
          debugPrint('Error inserting row ${row.name}: $e');
          errorCount++;
        }
      }
    });

    return {
      'inserted': insertedCount,
      'updated': updatedCount,
      'errors': errorCount,
    };
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
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, 
        COALESCE(
          (SELECT materialized_running_balance 
           FROM entity_ledgers 
           WHERE entity_type = 'CUSTOMER' AND entity_id = c.id 
           ORDER BY date DESC, id DESC LIMIT 1), 
        0.0) as ledger_debt
      FROM customers c
    ''');
    return List.generate(maps.length, (i) {
      final mutableMap = Map<String, dynamic>.from(maps[i]);
      mutableMap['total_debt'] = mutableMap['ledger_debt'];
      return Customer.fromMap(mutableMap);
    });
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
    final hasHistory = await db.query('transactions', where: 'entity_id = ?', whereArgs: [id]);
    final hasPayments = await db.query('payments', where: 'entity_id = ? AND entity_type = ?', whereArgs: [id, 'CUSTOMER']);
    final hasLedger = await db.query('entity_ledgers', where: 'entity_type = ? AND entity_id = ?', whereArgs: ['CUSTOMER', id], limit: 1);
    if (hasHistory.isNotEmpty || hasPayments.isNotEmpty || hasLedger.isNotEmpty) {
      throw Exception('No se puede eliminar porque tiene historial contable o abonos registrados');
    }
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSACTION OPERATIONS (ATOMIC)
  // ---------------------------------------------------------------------------
  // Sprint C - Fetch linked payments for an invoice
    Future<List<Map<String, dynamic>>> getTransactionPayments(int transactionId) async {
       final db = await database;
       return await db.rawQuery('''
          SELECT p.date, p.payment_method, p.note, pa.allocated_amount as amount
          FROM payment_allocations pa
          JOIN payments p ON pa.payment_id = p.id
          WHERE pa.transaction_id = ?
          ORDER BY date DESC
       ''', [transactionId]);
    }

  Future<int> insertSale(Sale sale, {String paymentMethod = 'EFECTIVO'}) async {
    final db = await database;

    return await db.transaction((txn) async {
      final saleId = await txn.insert('transactions', sale.toMap());

      for (var item in sale.items) {
        // 1. Get current stock inside transaction (Atomic check)
        final List<Map<String, dynamic>> result = await txn.query(
          'products',
          columns: ['stock', 'name', 'weighted_average_cost'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        if (result.isEmpty) {
          throw Exception('Producto no encontrado: ID ${item.productId}');
        }

        final currentStock = (result.first['stock'] as num).toDouble();
        final productName = result.first['name'] as String;
        final currentWac = (result.first['weighted_average_cost'] as num?)?.toDouble() ?? 0.0;

        // 2. Check availability (NUEVO: Validar contra baseUnitsTotal)
        if (currentStock < item.baseUnitsTotal) {
          throw Exception(
              'Stock insuficiente para "$productName". Disponible: $currentStock unidades base');
        }

        // 3. Insert Item
        await txn.insert('transaction_items', {
          'transaction_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost_at_sale_time': currentWac,
          'subtotal': item.subtotal,
          'sale_unit': item.saleUnit,
          'units_per_sale_unit': item.unitsPerSaleUnit,
          'packaging_info': item.packagingInfo,
        });

        // 3b. Insert Inventory Movement (Event Sourcing)
        await txn.insert('inventory_movements', {
          'product_id': item.productId,
          'movement_type': 'SALE_DELIVERY',
          'quantity': -item.baseUnitsTotal,
          'reference_type': 'SALE',
          'reference_id': saleId,
          'unit_cost_at_movement': currentWac,
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // 4. Update Stock Cache (NUEVO: Descontar baseUnitsTotal en lugar de quantity)
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item.baseUnitsTotal, item.productId],
        );
      }

      // 5. Update Entity Ledger (and keep legacy total_debt for fallback during UI transition)
      final pendingAmount = sale.totalAmount - sale.amountPaid;
      if (sale.customerId != null) {
        double currentBalance = 0;
        final ledgerQuery = await txn.query(
            'entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', sale.customerId],
            orderBy: 'date DESC, id DESC',
            limit: 1
        );
        if (ledgerQuery.isNotEmpty) {
            currentBalance = (ledgerQuery.first['materialized_running_balance'] as num).toDouble();
        }
        
        // Log Invoice
        await txn.insert('entity_ledgers', {
            'entity_type': 'CUSTOMER',
            'entity_id': sale.customerId,
            'transaction_source_type': 'INVOICE',
            'transaction_reference_id': saleId,
            'date': DateTime.now().millisecondsSinceEpoch,
            'debit_amount': sale.totalAmount,
            'credit_amount': 0.0,
            'materialized_running_balance': currentBalance + sale.totalAmount,
            'note': 'Venta'
        });
        currentBalance += sale.totalAmount;

        if (sale.amountPaid > 0) {
            await txn.insert('entity_ledgers', {
                'entity_type': 'CUSTOMER',
                'entity_id': sale.customerId,
                'transaction_source_type': 'PAYMENT',
                'transaction_reference_id': saleId,
                'date': DateTime.now().millisecondsSinceEpoch + 1,
                'debit_amount': 0.0,
                'credit_amount': sale.amountPaid,
                'materialized_running_balance': currentBalance - sale.amountPaid,
                'note': 'Pago inicial'
            });
        }

        if (pendingAmount > 0) {
          await txn.rawUpdate(
            'UPDATE customers SET total_debt = total_debt + ? WHERE id = ?',
            [pendingAmount, sale.customerId],
          );
        }
      }

      // 6. If a down payment is recorded, create entry in payments and allocation
      if (sale.amountPaid > 0 && sale.customerId != null) {
        final paymentId = await txn.insert('payments', {
          'entity_id': sale.customerId,
          'entity_type': 'CUSTOMER',
          'amount': sale.amountPaid,
          'date': DateTime.now().millisecondsSinceEpoch,
          'payment_method': paymentMethod,
          'note': 'Pago inicial',
        });
        await txn.insert('payment_allocations', {
          'payment_id': paymentId,
          'transaction_id': saleId,
          'allocated_amount': sale.amountPaid,
        });
      }

      return saleId;
    });
  }

  Future<void> deleteSale(int saleId) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Check if already voided
      final List<Map<String, dynamic>> transaction = await txn.query(
        'transactions',
        columns: ['status', 'entity_id', 'total_amount', 'amount_paid'],
        where: 'id = ?',
        whereArgs: [saleId],
      );

      if (transaction.isEmpty) throw Exception('Venta no encontrada');
      if (transaction.first['status'] == 'VOIDED') {
        throw Exception('Esta venta ya ha sido anulada');
      }

      // 2. Get items to restore stock
      final List<Map<String, dynamic>> items = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [saleId],
      );

      for (var item in items) {
        final productId = item['product_id'] as int;
        final targetQty = item['quantity'] as num;
        final targetUpx = item['units_per_sale_unit'] != null
            ? (item['units_per_sale_unit'] as num).toDouble()
            : 1.0;
        final baseUnitsReturn = targetQty * targetUpx;
        final unitCost = (item['unit_cost_at_sale_time'] as num?)?.toDouble() ?? 0.0;

        // 3a. Insert Compensating Inventory Movement
        await txn.insert('inventory_movements', {
          'product_id': productId,
          'movement_type': 'SALE_VOID_REVERSAL',
          'quantity': baseUnitsReturn,
          'reference_type': 'VOID_SALE',
          'reference_id': saleId,
          'unit_cost_at_movement': unitCost,
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // 3b. Restore Stock Cache (NUEVO: retornar base units completas)
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [baseUnitsReturn, productId],
        );
      }

      // 4. Mark as VOIDED
      await txn.update(
        'transactions',
        {'status': 'VOIDED'},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // 5. Compensating Ledger entries for Voiding AND Decrease Customer Debt if it was a credit sale (NUEVO)
      final customerId = transaction.first['entity_id'];
      if (customerId != null) {
        final totalAmount = (transaction.first['total_amount'] as num).toDouble();
        final amountPaid = (transaction.first['amount_paid'] as num?)?.toDouble() ?? 0.0;

        // 5a. Ledger compensation
        final ledgerQuery = await txn.query(
            'entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', customerId],
            orderBy: 'date DESC, id DESC',
            limit: 1
        );
        double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0;
        
        final pendingAmount = totalAmount - amountPaid;
        
        // Invoice Reversal (Reverse ALL the invoiced amount. The previous payment is automatically left as a credit balance)
        await txn.insert('entity_ledgers', {
            'entity_type': 'CUSTOMER',
            'entity_id': customerId,
            'transaction_source_type': 'INVOICE_VOID_REVERSAL',
            'transaction_reference_id': saleId,
            'date': DateTime.now().millisecondsSinceEpoch,
            'debit_amount': 0.0,
            'credit_amount': totalAmount,
            'materialized_running_balance': currentBalance - totalAmount,
            'note': 'Anulación de Venta (Reversión Total)'
        });

        // Clear payment allocations mapping to this sale so funds become unallocated global credit
        await txn.delete('payment_allocations', where: 'transaction_id = ?', whereArgs: [saleId]);

        // 5b. Update legacy customer debt (reduce by pending amount)
        await txn.rawUpdate(
          'UPDATE customers SET total_debt = total_debt - ? WHERE id = ?',
          [pendingAmount, customerId],
        );
      }
    });
  }

  Future<void> receiveSalePayment(int saleId, double amount,
      {String? note, String paymentMethod = 'EFECTIVO'}) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Get Sale
      final List<Map<String, dynamic>> transaction = await txn.query(
        'transactions',
        columns: ['status', 'entity_id', 'total_amount', 'amount_paid'],
        where: 'id = ?',
        whereArgs: [saleId],
      );

      if (transaction.isEmpty) throw Exception('Venta no encontrada');
      if (transaction.first['status'] == 'VOIDED') {
        throw Exception('Esta venta está anulada');
      }

      final total = transaction.first['total_amount'] as num;
      final currentPaid = transaction.first['amount_paid'] as num? ?? 0.0;
      final pending = total - currentPaid;

      // Allows a small tolerance for floating point errors
      if (amount > pending + 0.01) {
        throw Exception(
            'El monto supera el saldo pendiente. Pendiente: Bs. ${pending.toStringAsFixed(2)}');
      }

      // 2. Extract Customer and Insert Treasury Payment Record
      final customerId = transaction.first['entity_id'];
      if (customerId == null) throw Exception('La venta no tiene un cliente asignado');
      
      final paymentId = await txn.insert('payments', {
        'entity_id': customerId,
        'entity_type': 'CUSTOMER',
        'amount': amount,
        'date': DateTime.now().millisecondsSinceEpoch,
        'payment_method': paymentMethod,
        'note': note ?? 'Abono',
      });
      
      await txn.insert('payment_allocations', {
        'payment_id': paymentId,
        'transaction_id': saleId,
        'allocated_amount': amount,
      });

      // 3. Update Sale Status & amount_paid
      final newPaid = currentPaid + amount;
      final newStatus = (newPaid >= total - 0.01) ? 'COMPLETED' : 'PARTIAL';
      await txn.update(
        'transactions',
        {
          'amount_paid': newPaid,
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // 4. Update Ledger and Decrease legacy Customer Debt
      if (customerId != null) {
        final ledgerQuery = await txn.query(
            'entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', customerId],
            orderBy: 'date DESC, id DESC',
            limit: 1
        );
        double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0;
        
        await txn.insert('entity_ledgers', {
            'entity_type': 'CUSTOMER',
            'entity_id': customerId,
            'transaction_source_type': 'PAYMENT',
            'transaction_reference_id': paymentId,
            'date': DateTime.now().millisecondsSinceEpoch,
            'debit_amount': 0.0,
            'credit_amount': amount,
            'materialized_running_balance': currentBalance - amount,
            'note': note ?? 'Abono',
        });

        await txn.rawUpdate(
          'UPDATE customers SET total_debt = total_debt - ? WHERE id = ?',
          [amount, customerId],
        );
      }
    });
  }

  // Sprint C - Treasury Module Global Payment Distribution
  Future<int> receiveGlobalPayment({
    required int customerId,
    required double totalAmount,
    required String paymentMethod, // 'EFECTIVO', 'QR', 'TRANSFERENCIA'
    String? note,
    required Map<int, double> allocations, // sale_id -> allocated_amount
  }) async {
    final db = await database;

    return await db.transaction((txn) async {
       // Validate against real ledger debt
       final initialLedgerQuery = await txn.query('entity_ledgers',
           where: 'entity_type = ? AND entity_id = ?',
           whereArgs: ['CUSTOMER', customerId],
           orderBy: 'date DESC, id DESC',
           limit: 1);
       final currentDebt = initialLedgerQuery.isNotEmpty ? (initialLedgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0;
       if (currentDebt <= 0) {
          throw Exception('El cliente no tiene deudas pendientes (saldo: Bs. ${currentDebt.toStringAsFixed(2)}).');
       }
       if (totalAmount > currentDebt + 0.01) {
          throw Exception('El abono (Bs. ${totalAmount.toStringAsFixed(2)}) excede la deuda total del cliente (Bs. ${currentDebt.toStringAsFixed(2)}).');
       }

       // 1. Insert Global Payment
       final paymentId = await txn.insert('payments', {
         'entity_id': customerId,
         'entity_type': 'CUSTOMER',
         'amount': totalAmount,
         'date': DateTime.now().millisecondsSinceEpoch,
         'payment_method': paymentMethod,
         'note': note ?? 'Abono Global',
       });

       double totalAllocated = 0.0;
       
       // 2. Process Allocations
       for (var entry in allocations.entries) {
          final saleId = entry.key;
          final allocatedAmount = entry.value;

          if (allocatedAmount <= 0) continue;
          totalAllocated += allocatedAmount;

          // Validate against pending amount
          final List<Map<String, dynamic>> transaction = await txn.query(
            'transactions',
            columns: ['status', 'total_amount', 'amount_paid'],
            where: 'id = ? AND entity_id = ?',
            whereArgs: [saleId, customerId],
          );

          if (transaction.isEmpty) throw Exception('Venta #$saleId no encontrada o no pertenece al cliente');
          if (transaction.first['status'] == 'VOIDED') throw Exception('La venta #$saleId está anulada');

          final total = transaction.first['total_amount'] as num;
          final currentPaid = transaction.first['amount_paid'] as num? ?? 0.0;
          final pending = total - currentPaid;

          if (allocatedAmount > pending + 0.01) {
             throw Exception('El monto supera al saldo pendiente en Venta #$saleId.');
          }

          // Insert Allocation
          await txn.insert('payment_allocations', {
             'payment_id': paymentId,
             'transaction_id': saleId,
             'allocated_amount': allocatedAmount,
          });

          // Update Sale Status & amount_paid
          final newPaid = currentPaid + allocatedAmount;
          final newStatus = (newPaid >= total - 0.01) ? 'COMPLETED' : 'PARTIAL';
          await txn.update(
             'transactions',
             {
               'amount_paid': newPaid,
               'status': newStatus,
             },
             where: 'id = ?',
             whereArgs: [saleId],
          );
       }
       
       if (totalAllocated > totalAmount + 0.01) {
           throw Exception('La suma de distribuciones supera el monto depositado.');
       }

       // 3. Update Ledger and Decrease legacy Customer Debt
       final ledgerQuery = await txn.query(
           'entity_ledgers',
           where: 'entity_type = ? AND entity_id = ?',
           whereArgs: ['CUSTOMER', customerId],
           orderBy: 'date DESC, id DESC',
           limit: 1
       );
       double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0;
       
       final double unallocated = totalAmount - totalAllocated;
       final double applied = totalAmount - unallocated;
       final int timestamp = DateTime.now().millisecondsSinceEpoch;

       if (applied > 0) {
         await txn.insert('entity_ledgers', {
             'entity_type': 'CUSTOMER',
             'entity_id': customerId,
             'transaction_source_type': 'PAYMENT',
             'transaction_reference_id': paymentId,
             'date': timestamp,
             'debit_amount': 0.0,
             'credit_amount': applied,
             'materialized_running_balance': currentBalance - applied,
             'note': note ?? 'Abono Global ($paymentMethod)',
         });
       }

       if (unallocated > 0) {
         await txn.insert('entity_ledgers', {
             'entity_type': 'CUSTOMER',
             'entity_id': customerId,
             'transaction_source_type': 'CREDIT_BALANCE',
             'transaction_reference_id': paymentId,
             'date': timestamp + 1, // Avoid overlapping exactly the same ms
             'debit_amount': 0.0,
             'credit_amount': unallocated,
             'materialized_running_balance': currentBalance - totalAmount,
             'note': 'Saldo a favor (Anticipo) - $paymentMethod',
         });
       }

       await txn.rawUpdate(
         'UPDATE customers SET total_debt = total_debt - ? WHERE id = ?',
         [totalAmount, customerId],
       );

       return paymentId;
    });
  }

  Future<int> insertPurchase(Purchase purchase) async {
    final db = await database;

    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('transactions', purchase.toMap());

      for (var item in purchase.items) {
        // 1. Query current WAC and stock
        final List<Map<String, dynamic>> prodResult = await txn.query(
          'products',
          columns: ['stock', 'weighted_average_cost'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        
        double currentStock = 0.0;
        double currentWac = 0.0;
        if (prodResult.isNotEmpty) {
           currentStock = (prodResult.first['stock'] as num).toDouble();
           currentWac = (prodResult.first['weighted_average_cost'] as num?)?.toDouble() ?? 0.0;
        }

        // 2. Insert item
        await txn.insert('transaction_items', {
          'transaction_id': purchaseId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
          'sale_unit': item.saleUnit,
          'units_per_sale_unit': item.unitsPerSaleUnit,
          'packaging_info': item.packagingInfo,
        });

        // 3. Calculate new WAC
        final totalOldValue = currentStock > 0 ? currentStock * currentWac : 0.0;
        final newInvestment = item.quantity * item.unitPrice;
        final newTotalStock = currentStock + item.baseUnitsTotal;
        
        final newWac = newTotalStock > 0 ? (totalOldValue + newInvestment) / newTotalStock : 0.0;
        final unitCostInBaseUnits = item.baseUnitsTotal > 0 ? newInvestment / item.baseUnitsTotal : 0.0;

        final unitCostBase = item.baseUnitsTotal > 0 
            ? (item.quantity * item.unitPrice) / item.baseUnitsTotal 
            : item.unitPrice;

        // 4. Insert Inventory Movement
        await txn.insert('inventory_movements', {
          'product_id': item.productId,
          'movement_type': 'PURCHASE_RECEIPT',
          'quantity': item.baseUnitsTotal,
          'reference_type': 'PURCHASE',
          'reference_id': purchaseId,
          'unit_cost_at_movement': unitCostInBaseUnits,
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // 5. Update Stock Cache, Cost, and WAC
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ?, cost = ?, weighted_average_cost = ? WHERE id = ?',
          [item.baseUnitsTotal, unitCostBase, newWac, item.productId],
        );
      }

      if (purchase.supplierId != null) {
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['SUPPLIER', purchase.supplierId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble()
            : 0.0;

        await txn.insert('entity_ledgers', {
          'entity_type': 'SUPPLIER',
          'entity_id': purchase.supplierId,
          'transaction_source_type': 'PURCHASE',
          'transaction_reference_id': purchaseId,
          'date': DateTime.now().millisecondsSinceEpoch,
          'debit_amount': purchase.totalAmount,
          'credit_amount': 0.0,
          'materialized_running_balance': currentBalance + purchase.totalAmount,
          'note': 'Registro de Compra',
        });
        currentBalance += purchase.totalAmount;

        if (purchase.amountPaid > 0) {
          await txn.insert('entity_ledgers', {
            'entity_type': 'SUPPLIER',
            'entity_id': purchase.supplierId,
            'transaction_source_type': 'PAYMENT',
            'transaction_reference_id': purchaseId,
            'date': DateTime.now().millisecondsSinceEpoch + 1,
            'debit_amount': 0.0,
            'credit_amount': purchase.amountPaid,
            'materialized_running_balance': currentBalance - purchase.amountPaid,
            'note': 'Pago de Compra',
          });

          final paymentId = await txn.insert('payments', {
            'entity_id': purchase.supplierId,
            'entity_type': 'SUPPLIER',
            'amount': purchase.amountPaid,
            'date': DateTime.now().millisecondsSinceEpoch,
            'payment_method': 'EFECTIVO',
            'note': 'Pago en efectivo'
          });

          await txn.insert('payment_allocations', {
            'payment_id': paymentId,
            'transaction_id': purchaseId,
            'allocated_amount': purchase.amountPaid,
          });
        }
      }

      return purchaseId;
    });
  }

  Future<void> deletePurchase(int purchaseId) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Check if already voided
      final List<Map<String, dynamic>> transaction = await txn.query(
        'transactions',
        columns: ['status', 'reference_id', 'entity_id', 'total_amount', 'amount_paid'],
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      if (transaction.isEmpty) throw Exception('Compra no encontrada');
      if (transaction.first['status'] == 'VOIDED') {
        throw Exception('Esta compra ya ha sido anulada');
      }

      // 2. Get items to decrease stock
      final List<Map<String, dynamic>> items = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [purchaseId],
      );

      for (var item in items) {
        final productId = item['product_id'] as int;
        final targetQty = item['quantity'] as num;
        final targetUpx = item['units_per_sale_unit'] != null
            ? (item['units_per_sale_unit'] as num).toDouble()
            : 1.0;
        final baseUnitsDeduct = targetQty * targetUpx;
        final subtotal = (item['subtotal'] as num).toDouble();
        final unitCost = baseUnitsDeduct > 0 ? subtotal / baseUnitsDeduct : 0.0;

        // 3a. Insert Compensating Inventory Movement
        await txn.insert('inventory_movements', {
          'product_id': productId,
          'movement_type': 'PURCHASE_VOID_REVERSAL',
          'quantity': -baseUnitsDeduct,
          'reference_type': 'VOID_PURCHASE',
          'reference_id': purchaseId,
          'unit_cost_at_movement': unitCost,
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // 3b. Decrease Stock Cache (NUEVO: remover base units completas)
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [baseUnitsDeduct, productId],
        );
      }

      // 4. Mark as VOIDED
      await txn.update(
        'transactions',
        {'status': 'VOIDED'},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      // 4b. Revert Ledger
      final supplierId = transaction.first['entity_id'];
      if (supplierId != null) {
        final totalAmount = (transaction.first['total_amount'] as num).toDouble();
        final ledgerQuery = await txn.query('entity_ledgers', 
            where: 'entity_type = ? AND entity_id = ?', 
            whereArgs: ['SUPPLIER', supplierId], 
            orderBy: 'date DESC, id DESC', limit: 1); 
        double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0; 

        await txn.insert('entity_ledgers', { 
            'entity_type': 'SUPPLIER', 
            'entity_id': supplierId, 
            'transaction_source_type': 'PURCHASE_VOID_REVERSAL', 
            'transaction_reference_id': purchaseId, 
            'date': DateTime.now().millisecondsSinceEpoch, 
            'debit_amount': 0.0, 
            'credit_amount': totalAmount, 
            'materialized_running_balance': currentBalance - totalAmount, 
            'note': 'Anulación de Compra', 
        }); 

        // Release the money so it remains as an advance/balance in favor of the supplier
        await txn.delete('payment_allocations', where: 'transaction_id = ?', whereArgs: [purchaseId]);
      }

      // 5. If linked to an order, revert the order to PENDING
      final refId = transaction.first['reference_id'];
      if (refId != null) {
        final orderQuery = await txn.query(
          'transactions',
          where: 'id = ? AND type = ?',
          whereArgs: [refId, 'order'],
        );
        if (orderQuery.isNotEmpty) {
          await txn.update(
            'transactions',
            {'status': 'PENDING'},
            where: 'id = ?',
            whereArgs: [refId],
          );
        }
      }
    });
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await database;
    await db.transaction((txn) async {
      final order = await txn.query('transactions', columns: ['status'], where: 'id = ?', whereArgs: [orderId]); 
      if (order.isNotEmpty && order.first['status'] == 'RECEIVED') { 
        throw Exception('You cannot cancel an order that has already been received. Please cancel the associated Purchase instead.'); 
      }
      await txn.update(
        'transactions',
        {'status': 'VOIDED'},
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  /// Realiza un pago rápido heredado sin asignar a ninguna venta específica.
  /// Genera un abono a favor del cliente creando registros genéricos sin 'payment_allocations'.
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
      
      // Update entity_ledgers since this is a deposit
      final ledgerQuery = await txn.query(
          'entity_ledgers',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['CUSTOMER', customerId],
          orderBy: 'date DESC',
          limit: 1);
      double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0;
      await txn.insert('entity_ledgers', {
          'entity_type': 'CUSTOMER',
          'entity_id': customerId,
          'transaction_source_type': 'PAYMENT',
          'transaction_reference_id': id,
          'date': DateTime.now().millisecondsSinceEpoch,
          'debit_amount': 0.0,
          'credit_amount': amount,
          'materialized_running_balance': currentBalance - amount,
          'note': 'Registro de Abono',
      });

      // Also insert into new system for consistency
      await txn.insert('payments', {
        'entity_id': customerId,
        'entity_type': 'CUSTOMER',
        'amount': amount,
        'date': DateTime.now().millisecondsSinceEpoch,
        'payment_method': 'EFECTIVO',
        'note': 'Abono rápido',
      });

      return id;
    });
  }

  Future<void> deletePayment(int paymentId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Point directly to the payments table (V13)
      final results = await txn.query('payments', where: 'id = ?', whereArgs: [paymentId]);
      if (results.isEmpty) return;

      final payment = results.first;
      final amount = (payment['amount'] as num).toDouble();
      final entityId = payment['entity_id'] as int;
      final entityType = payment['entity_type'] as String;

      // 1. Revert assignments
      final allocations = await txn.query('payment_allocations', where: 'payment_id = ?', whereArgs: [paymentId]);
      for (var a in allocations) {
        final tId = a['transaction_id'] as int;
        final allocAmt = (a['allocated_amount'] as num).toDouble();

        final tRecord = await txn.query('transactions', columns: ['amount_paid', 'total_amount'], where: 'id = ?', whereArgs: [tId]);
        if (tRecord.isNotEmpty) {
          final newPaid = (tRecord.first['amount_paid'] as num).toDouble() - allocAmt;
          final total = (tRecord.first['total_amount'] as num).toDouble();
          final newStatus = newPaid >= total - 0.01 ? 'COMPLETED' : (newPaid <= 0 ? 'CREDIT' : 'PARTIAL');
          await txn.update('transactions', {'amount_paid': newPaid, 'status': newStatus}, where: 'id = ?', whereArgs: [tId]);
        }
      }

      // 2. Reverse debt depending on entity type
      if (entityType == 'CUSTOMER') {
        await txn.rawUpdate('UPDATE customers SET total_debt = total_debt + ? WHERE id = ?', [amount, entityId]);
      }

      // 3. Delete payment and allocations
      await txn.delete('payment_allocations', where: 'payment_id = ?', whereArgs: [paymentId]);
      await txn.delete('payments', where: 'id = ?', whereArgs: [paymentId]);

      // 4. Register reverse in Ledger
      final ledgerQuery = await txn.query('entity_ledgers', where: 'entity_type = ? AND entity_id = ?', whereArgs: [entityType, entityId], orderBy: 'date DESC, id DESC', limit: 1);
      double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0;
      await txn.insert('entity_ledgers', {
        'entity_type': entityType, 'entity_id': entityId,
        'transaction_source_type': 'PAYMENT_VOID_REVERSAL',
        'transaction_reference_id': paymentId, 'date': DateTime.now().millisecondsSinceEpoch,
        'debit_amount': entityType == 'CUSTOMER' ? amount : 0.0,
        'credit_amount': entityType == 'SUPPLIER' ? amount : 0.0,
        'materialized_running_balance': entityType == 'CUSTOMER' ? currentBalance + amount : currentBalance - amount,
        'note': 'Anulación de Pago',
      });
    });
  }

  Future<void> deleteExpense(int expenseId) async {
    final db = await database;
    await db.update(
      'transactions',
      {'status': 'VOIDED'},
      where: 'id = ? AND type = ?',
      whereArgs: [expenseId, 'expense'],
    );
  }

  Future<List<Transaction>> getCustomerHistory(int customerId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: "entity_id = ? AND status != 'VOIDED' AND (type = ? OR type = ?)",
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
      where: "type = ? AND status != 'VOIDED'",
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
      where: "type = ? AND status != 'VOIDED'",
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
  // ORDER OPERATIONS (Scenario B)
  // ---------------------------------------------------------------------------

  Future<int> insertOrder(Order order) async {
    final db = await database;

    return await db.transaction((txn) async {
      final orderId = await txn.insert('transactions', order.toMap());

      for (var item in order.items) {
        await txn.insert('transaction_items', {
          'transaction_id': orderId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
          'sale_unit': item.saleUnit,
          'units_per_sale_unit': item.unitsPerSaleUnit,
          'packaging_info': item.packagingInfo,
        });
        // NOTE: We do NOT update stock here. Stock is updated when status -> RECEIVED.
      }
      return orderId;
    });
  }

  Future<List<Order>> getOrders({int limit = 20, int offset = 0}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: "type = ? AND status NOT IN ('VOIDED', 'CANCELLED')",
      whereArgs: ['order'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    List<Order> orders = [];

    for (var map in maps) {
      final id = map['id'] as int;
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );

      final items = List.generate(
          itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
      orders.add(Order.fromMap(map, items));
    }

    return orders;
  }

  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    final db = await database;

    // Get current status to prevent double-crediting if already received
    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      columns: ['status', 'entity_name', 'total_amount', 'entity_id'],
      where: 'id = ?',
      whereArgs: [orderId],
    );

    if (result.isEmpty) throw Exception('Order $orderId not found');

    final currentStatus = result.first['status'] as String;
    final supplierName = result.first['entity_name'] as String?;
    final totalAmount = (result.first['total_amount'] as num).toDouble();

    // Prevent re-triggering stock increase if already Received
    if (currentStatus == 'RECEIVED' && newStatus == 'RECEIVED') {
      return;
    }

    await db.transaction((txn) async {
      // 1. Update Status
      await txn.update(
        'transactions',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 2. Logic: If status becomes RECEIVED, we increase stock (Purchase Logic)
      if (newStatus == 'RECEIVED' && currentStatus != 'RECEIVED') {
        // Fetch items
        final itemsMaps = await txn.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [orderId],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));

        // NEW: Create a "Purchase" transaction to reflect this in analytics/history
        final entityId = result.first['entity_id'] as int?;
        final purchaseId = await txn.insert('transactions', {
          'type': 'purchase',
          'entity_id': entityId,
          'entity_name': supplierName,
          'reference_id': orderId,
          'date': DateTime.now().millisecondsSinceEpoch,
          'total_amount': totalAmount,
          'status': 'COMPLETED',
        });

        if (entityId != null) { 
          final ledgerQuery = await txn.query('entity_ledgers', where: 'entity_type = ? AND entity_id = ?', whereArgs: ['SUPPLIER', entityId], orderBy: 'date DESC, id DESC', limit: 1); 
          double currentBalance = ledgerQuery.isNotEmpty ? (ledgerQuery.first['materialized_running_balance'] as num).toDouble() : 0.0; 
          await txn.insert('entity_ledgers', { 
            'entity_type': 'SUPPLIER', 
            'entity_id': entityId, 
            'transaction_source_type': 'PURCHASE', 
            'transaction_reference_id': purchaseId, 
            'date': DateTime.now().millisecondsSinceEpoch, 
            'debit_amount': totalAmount, 
            'credit_amount': 0.0, 
            'materialized_running_balance': currentBalance + totalAmount, 
            'note': 'Recepción de Pedido', 
          }); 
        }

        for (var item in items) {
          // 1. Query current WAC and stock
          final List<Map<String, dynamic>> prodResult = await txn.query(
            'products',
            columns: ['stock', 'weighted_average_cost'],
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          
          double currentStock = 0.0;
          double currentWac = 0.0;
          if (prodResult.isNotEmpty) {
             currentStock = (prodResult.first['stock'] as num).toDouble();
             currentWac = (prodResult.first['weighted_average_cost'] as num?)?.toDouble() ?? 0.0;
          }

          // 2. Calculate new WAC
          final totalOldValue = currentStock > 0 ? currentStock * currentWac : 0.0;
          final newInvestment = item.quantity * item.unitPrice;
          final newTotalStock = currentStock + item.baseUnitsTotal;
          
          final newWac = newTotalStock > 0 ? (totalOldValue + newInvestment) / newTotalStock : 0.0;
          final unitCostInBaseUnits = item.baseUnitsTotal > 0 ? newInvestment / item.baseUnitsTotal : 0.0;

          // 3. Insert Inventory Movement
          await txn.insert('inventory_movements', {
            'product_id': item.productId,
            'movement_type': 'PURCHASE_RECEIPT',
            'quantity': item.baseUnitsTotal,
            'reference_type': 'ORDER_RECEIPT',
            'reference_id': orderId,
            'unit_cost_at_movement': unitCostInBaseUnits,
            'created_timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          // 4. Update Stock Cache, Cost, and WAC
          await txn.rawUpdate(
            'UPDATE products SET stock = stock + ?, cost = ?, weighted_average_cost = ? WHERE id = ?',
            [item.baseUnitsTotal, unitCostInBaseUnits, newWac, item.productId],
          );

          // NEW: Link this item to the Purchase Transaction
          await txn.insert('transaction_items', {
            'transaction_id': purchaseId,
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'subtotal': item.subtotal,
            'sale_unit': item.saleUnit,
            'units_per_sale_unit': item.unitsPerSaleUnit,
            'packaging_info': item.packagingInfo,
          });
        }
      }
      // Note: If reverting FROM Received to Pending, should we decrease stock?
      // For safety, let's say NO for now unless explicitly requested.
      // Reverting 'Received' is complex (what if stock was already sold?).
    });
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
      WHERE type = 'sale' AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Anonymous Sales Cash
    final anonymousSalesResult = await db.rawQuery('''
      SELECT SUM(amount_paid) as total 
      FROM transactions 
      WHERE type = 'sale' AND entity_id IS NULL AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Expenses
    final expensesResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM transactions 
      WHERE type = 'expense' AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Payments IN (Customer Deposits)
    final paymentsResult = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM payments 
      WHERE entity_type = 'CUSTOMER' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Payments OUT (Supplier Payments)
    final supplierPaymentsResult = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM payments 
      WHERE entity_type = 'SUPPLIER' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    // Purchases (amount actually spent)
    final purchasesResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM transactions 
      WHERE type = 'purchase' AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);

    final totalSales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalAnonymousSalesCash = (anonymousSalesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPayments =
        (paymentsResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalSupplierPayments = 
        (supplierPaymentsResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPurchasesPaid =
        (purchasesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final cashIn = totalAnonymousSalesCash + totalPayments;

    return {
      'sales': totalSales,
      'expenses': totalExpenses,
      'payments': totalPayments,
      'purchases': totalPurchasesPaid,
      'balance': cashIn - totalExpenses - totalSupplierPayments,
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
    bool hideVoided = false,
  }) async {
    final db = await database;

    // Build Query
    String whereClause = "1=1";
    if (hideVoided) {
      whereClause += " AND status != 'VOIDED' AND status != 'RECEIVED'";
    }
    List<dynamic> args = [];

    if (type != null) {
      whereClause += " AND type = ? AND status != 'VOIDED'";
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
      } else if (tType == 'order') {
        final id = map['id'] as int;
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Order.fromMap(map, items));
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
      where: "status != 'VOIDED'",
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
      } else if (type == 'order') {
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        final items = List.generate(
            itemsMaps.length, (i) => InvoiceItem.fromMap(itemsMaps[i]));
        transactions.add(Order.fromMap(map, items));
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
        WHERE type = 'sale' AND status != 'VOIDED' AND date BETWEEN ? AND ?
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
      WHERE t.type = 'sale' AND t.status != 'VOIDED'
      GROUP BY ti.product_id
      ORDER BY frequency DESC
      LIMIT ?
    ''', [limit]);

    return result.map((row) => row['product_id'] as int).toList();
  }

  Future<List<Map<String, dynamic>>> getOverdueSales() async {
    final db = await database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return await db.query(
      'transactions',
      where:
          "(status = 'PARTIAL' OR status = 'CREDIT') AND type = 'sale' AND payment_due_date IS NOT NULL AND payment_due_date < ?",
      whereArgs: [nowMs],
    );
  }

  Future<int> getPendingSalesCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM transactions WHERE (status='PARTIAL' OR status='CREDIT') AND type='sale'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAgingReport() async {
    final db = await database;
    final now = DateTime.now();

    // 1. Get true ledger running balance for all customers
    final customers = await getCustomers();
    final Map<int, Map<String, dynamic>> reportMap = {};

    for (var c in customers) {
      if (c.totalDebt <= 0) continue; // Skip if no debt

      double remainingDebt = c.totalDebt;
      
      final Map<String, dynamic> customerReport = {
        'customer_id': c.id,
        'customer_name': c.name,
        'current': 0.0,
        'days_30_60': 0.0,
        'days_60_plus': 0.0,
        'total': c.totalDebt,
      };

      // 2. Query all INVOICES (debits) for this customer from the ledger, NEWEST to OLDEST
      final invoices = await db.rawQuery(''' 
        SELECT el.* FROM entity_ledgers el 
        JOIN transactions t ON el.transaction_reference_id = t.id 
        WHERE el.entity_type = ? AND el.entity_id = ? 
        AND el.transaction_source_type = 'INVOICE' AND t.status != 'VOIDED' 
        ORDER BY el.date DESC 
      ''', ['CUSTOMER', c.id]);

      for (var inv in invoices) {
        if (remainingDebt <= 0) break;

        final invoiceAmount = (inv['debit_amount'] as num).toDouble();
        final dateMs = inv['date'] as int;
        final baseDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
        final difference = now.difference(baseDate).inDays;

        final amountToAllocate = invoiceAmount < remainingDebt ? invoiceAmount : remainingDebt;

        if (difference > 60) {
          customerReport['days_60_plus'] = (customerReport['days_60_plus'] as double) + amountToAllocate;
        } else if (difference > 30) {
          customerReport['days_30_60'] = (customerReport['days_30_60'] as double) + amountToAllocate;
        } else {
          customerReport['current'] = (customerReport['current'] as double) + amountToAllocate;
        }

        remainingDebt -= amountToAllocate;
      }

      // If there's STILL remaining debt (e.g., initial balances without invoice entries)
      if (remainingDebt > 0.01) {
          // Dump it in the oldest bucket
          customerReport['days_60_plus'] = (customerReport['days_60_plus'] as double) + remainingDebt;
      }

      reportMap[c.id!] = customerReport;
    }

    final result = reportMap.values.toList();
    result.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return result;
  }

  Future<Map<String, dynamic>> exportDatabase() async {
    final db = await database;
    final products = await db.query('products');
    final customers = await db.query('customers');
    final transactions = await db.query('transactions');
    final invoiceItems = await db.query('transaction_items');
    final suppliers = await db.query('suppliers');
    final categories = await db.query('categories');
    final notes = await db.query('notes');
    
    // V10 y V12 tables
    final inventoryMovements = await db.query('inventory_movements');
    final entityLedgers = await db.query('entity_ledgers');
    final payments = await db.query('payments');
    final paymentAllocations = await db.query('payment_allocations');
    final salePayments = await db.query('sale_payments');

    final version = await db.getVersion();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'version': version,
      'data': {
        'products': products,
        'customers': customers,
        'transactions': transactions,
        'transaction_items': invoiceItems,
        'suppliers': suppliers,
        'categories': categories,
        'notes': notes,
        'inventory_movements': inventoryMovements,
        'entity_ledgers': entityLedgers,
        'payments': payments,
        'payment_allocations': paymentAllocations,
        'sale_payments': salePayments,
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

    // Validate if you have transactions (purchases/orders) 
    final hasHistory = await db.query('transactions', where: 'entity_id = ? AND type IN (?, ?)', whereArgs: [id, 'purchase', 'order']); 

    // Validate if there are payments/credits in Treasury V13
    final hasPayments = await db.query('payments', where: 'entity_id = ? AND entity_type = ?', whereArgs: [id, 'SUPPLIER']);

    if (hasHistory.isNotEmpty || hasPayments.isNotEmpty) {
      throw Exception('No se puede eliminar porque tiene historial contable, pedidos o abonos registrados.');
    }

    // Validate if the supplier is assigned to any product
    final hasProducts = await db.query('products', where: 'supplier_id = ?', whereArgs: [id]);

    if (hasProducts.isNotEmpty) {
      await db.update('products', {'supplier_id': null}, where: 'supplier_id = ?', whereArgs: [id]); 
    } 

    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // NOTES OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('notes', orderBy: 'updated_at DESC');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
