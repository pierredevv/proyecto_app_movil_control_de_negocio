part of '../database_service.dart';

mixin CoreDb {
  // Abstract methods fulfilled by SchemaDb mixin
  Future<void> _runMigrations(Database db, int oldVersion, int newVersion);
  Future<void> _createNotesTable(Database db);
  Future<void> _createTables(Database db);
  Future<void> _createCategoriesTable(Database db);
  Future<void> _createSuppliersTable(Database db);

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
      return await openDatabase(_testDbPath!, version: 21,
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
      version:
          21, // Updated to version 21 for cash register + persistent notifications
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

    // V20 and V21 tables
    List<Map<String, dynamic>> cashRegisters = [];
    List<Map<String, dynamic>> expenseCategories = [];
    List<Map<String, dynamic>> notifications = [];
    try {
      cashRegisters = await db.query('cash_registers');
      expenseCategories = await db.query('expense_categories');
      notifications = await db.query('notifications');
    } catch (_) {}

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
        'cash_registers': cashRegisters,
        'expense_categories': expenseCategories,
        'notifications': notifications,
      }
    };
  }
}
