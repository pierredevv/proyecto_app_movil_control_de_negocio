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
      return await openDatabase(_testDbPath!, version: 22,
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
    final dbName = await getCurrentDbName();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version:
          22, // Updated to version 22 for RBAC (roles, users, permissions)
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
    } catch (_) {
      // Tables may not exist in older database versions, ignore errors during export
    }

    // V22 RBAC tables
    List<Map<String, dynamic>> roles = [];
    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> userRoles = [];
    List<Map<String, dynamic>> rolePermissions = [];
    try {
      roles = await db.query('roles');
      users = await db.query('users');
      userRoles = await db.query('user_roles');
      rolePermissions = await db.query('role_permissions');
    } catch (_) {
      // Tables may not exist in older database versions, ignore errors during export
    }

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
        'roles': roles,
        'users': users,
        'user_roles': userRoles,
        'role_permissions': rolePermissions,
      }
    };
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  void resetDatabaseInstance() {
    _database = null;
  }

  Future<String> getCurrentDbName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('database_name') ?? 'dulces_pierre.db';
  }

  Future<bool> renameDatabase(String newName) async {
    if (newName.trim().isEmpty) return false;
    if (!newName.endsWith('.db')) {
      newName = '${newName.trim()}.db';
    } else {
      newName = newName.trim();
    }

    final dbPath = await getDatabasesPath();
    final oldName = await getCurrentDbName();
    
    if (oldName == newName) return true;

    final oldDbPath = join(dbPath, oldName);
    final newDbPath = join(dbPath, newName);

    // 1. Close current connection
    await closeDatabase();

    final oldDbFile = File(oldDbPath);
    final oldWalFile = File('$oldDbPath-wal');
    final oldShmFile = File('$oldDbPath-shm');

    final newDbFile = File(newDbPath);
    final newWalFile = File('$newDbPath-wal');
    final newShmFile = File('$newDbPath-shm');

    bool dbMoved = false;
    bool walMoved = false;
    bool shmMoved = false;

    try {
      // 2. Perform file movements
      if (await oldDbFile.exists()) {
        await oldDbFile.rename(newDbPath);
        dbMoved = true;
      }
      
      if (await oldWalFile.exists()) {
        await oldWalFile.rename(newWalFile.path);
        walMoved = true;
      }
      
      if (await oldShmFile.exists()) {
        await oldShmFile.rename(newShmFile.path);
        shmMoved = true;
      }

      // 3. Save new database name config
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('database_name', newName);

      // 4. Force database re-initialization
      resetDatabaseInstance();
      await database; // Re-open DB
      return true;
    } catch (e) {
      debugPrint('Database migration failed: $e');
      
      // 5. Rollback on failure
      try {
        if (dbMoved && await newDbFile.exists()) {
          await newDbFile.rename(oldDbPath);
        }
        if (walMoved && await newWalFile.exists()) {
          await newWalFile.rename(oldWalFile.path);
        }
        if (shmMoved && await newShmFile.exists()) {
          await newShmFile.rename(oldShmFile.path);
        }
      } catch (rollbackError) {
        debugPrint('Critical: Rollback failed: $rollbackError');
      }
      
      resetDatabaseInstance();
      await database; // Re-open old database
      return false;
    }
  }
}
