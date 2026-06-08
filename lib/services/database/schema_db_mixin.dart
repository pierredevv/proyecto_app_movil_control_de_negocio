part of '../database_service.dart';

mixin SchemaDb on CoreDb {
  @override
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
                'debit_amount': 0.0,
                'credit_amount': totalAmount,
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

        await db.execute(
            'CREATE INDEX idx_payments_entity_date ON payments(entity_id, entity_type, date DESC)');
        await db.execute(
            'CREATE INDEX idx_allocations_transaction ON payment_allocations(transaction_id)');

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
          final genericPayments = await txn.query('transactions',
              where: "type = 'payment' AND status != 'VOIDED'");
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

    // Sprint 1 - Stock Adjustment and Supplier Invoices v14
    if (oldVersion < 14) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN supplier_invoice_ref TEXT");
      } catch (e) {
        debugPrint('Error adding supplier_invoice_ref column: $e');
      }
    }

    // Sprint 2 - Vyapar Stabilization v15
    if (oldVersion < 15) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN adjustment_amount REAL DEFAULT 0.0");

        // Repair Legacy Data: A/P Ledger Correction
        await db.execute('''
          UPDATE entity_ledgers 
          SET credit_amount = debit_amount, debit_amount = 0.0 
          WHERE entity_type = 'SUPPLIER' AND transaction_source_type = 'PURCHASE' AND debit_amount > 0 
        ''');
      } catch (e) {
        debugPrint('V15 migration error: $e');
      }
    }

    // Sprint 3 - Core Feature Parity v16
    if (oldVersion < 16) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN secondary_unit TEXT");
        await db.execute(
            "ALTER TABLE products ADD COLUMN units_per_secondary REAL");

        // Repair Legacy Data: Complete Recalculation of Supplier Ledgers
        // Ensure that purchases (credits) increase debt and payments (debits) decrease it.
        final supplierLedgers = await db.query('entity_ledgers',
            where: "entity_type = 'SUPPLIER'",
            orderBy: 'entity_id ASC, date ASC, id ASC');
        Map<int, double> supplierBalances = {};

        await db.transaction((txn) async {
          for (var row in supplierLedgers) {
            final eId = row['entity_id'] as int;
            final cred = (row['credit_amount'] as num).toDouble(); // Purchases
            final deb = (row['debit_amount'] as num).toDouble(); // Payments

            final newBal = (supplierBalances[eId] ?? 0.0) + cred - deb;
            supplierBalances[eId] = newBal;

            await txn.update(
                'entity_ledgers', {'materialized_running_balance': newBal},
                where: 'id = ?', whereArgs: [row['id']]);
          }
        });
      } catch (e) {
        debugPrint('V16 migration error: $e');
      }
    }
    
    // Sprint 4 - Treasury Stabilization v17
    if (oldVersion < 17) {
      try {
        await db.transaction((txn) async {
          // Find all payments missing a reference_id and try to bind them backwards
          final legacyPayments = await txn.query('transactions', where: "type = 'payment' AND reference_id IS NULL AND status != 'VOIDED'");
          for (var t in legacyPayments) {
             final tId = t['id'];
             final entityId = t['entity_id'];
             final amount = t['total_amount'];
             final date = t['date'];
             
             if (entityId != null && amount != null && date != null) {
                 final matches = await txn.query('payments', where: 'entity_id = ? AND amount = ? AND abs(date - ?) < 10000', whereArgs: [entityId, amount, date]);
                 if (matches.isNotEmpty) {
                     await txn.update('transactions', {'reference_id': matches.first['id']}, where: 'id = ?', whereArgs: [tId]);
                 }
             }
          }
        });
      } catch (e) {
        debugPrint('V17 migration error: $e');
      }
    }

    // Sprint 5 - Print Preview Fixes v18
    if (oldVersion < 18) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN client_ci_nit TEXT");
        await db.execute("ALTER TABLE transactions ADD COLUMN amount_tendered REAL DEFAULT 0.0");
      } catch (e) {
        debugPrint('V18 migration error: $e');
      }
    }

    // Sprint 6 - Legal CI/NIT on Entities v19
    if (oldVersion < 19) {
      try {
        await db.execute("ALTER TABLE customers ADD COLUMN ci_nit TEXT");
        await db.execute("ALTER TABLE suppliers ADD COLUMN ci_nit TEXT");
      } catch (e) {
        debugPrint('V19 migration error: $e');
      }
    }

    // V20: Cash Registers and Expense Categories
    if (oldVersion < 20) {
      try {
        await db.execute('''
          CREATE TABLE cash_registers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER DEFAULT NULL,
            open_date INTEGER NOT NULL,
            close_date INTEGER,
            opening_balance REAL NOT NULL DEFAULT 0,
            closing_balance REAL,
            expected_balance REAL,
            difference REAL,
            status TEXT NOT NULL DEFAULT 'OPEN',
            notes TEXT
          )
        ''');
      } catch (e) {
        debugPrint('V20 cash_registers table error: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE expense_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT DEFAULT 'category',
            color TEXT DEFAULT '0xFF6B7494'
          )
        ''');
        
        // Seed default expense categories
        await db.insert('expense_categories', {'name': 'Alquiler', 'icon': 'home', 'color': '0xFF4A90E2'});
        await db.insert('expense_categories', {'name': 'Servicios', 'icon': 'bolt', 'color': '0xFFF5A623'});
        await db.insert('expense_categories', {'name': 'Sueldos', 'icon': 'people', 'color': '0xFF9B51E0'});
        await db.insert('expense_categories', {'name': 'Mantenimiento', 'icon': 'build', 'color': '0xFF4ECDC4'});
        await db.insert('expense_categories', {'name': 'Impuestos', 'icon': 'receipt', 'color': '0xFFFF6B6B'});
        await db.insert('expense_categories', {'name': 'Transporte', 'icon': 'local_shipping', 'color': '0xFF51CF66'});
        await db.insert('expense_categories', {'name': 'Otros', 'icon': 'category', 'color': '0xFF6B7494'});
      } catch (e) {
        debugPrint('V20 expense_categories seeding error: $e');
      }

      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN expense_category_id INTEGER');
      } catch (e) {
        debugPrint('V20 alter transactions table error: $e');
      }
    }

    // V21: Persistent Notifications
    if (oldVersion < 21) {
      try {
        await db.execute('''
          CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT,
            type TEXT NOT NULL,
            is_read INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint('V21 notifications table error: $e');
      }
    }

    // V22: RBAC (Roles, Users, Permissions, Active Session)
    if (oldVersion < 22) {
      try {
        await db.execute('''
          CREATE TABLE roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            description TEXT,
            is_system INTEGER NOT NULL DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint('V22 roles table error: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            pin_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            last_login INTEGER
          )
        ''');
      } catch (e) {
        debugPrint('V22 users table error: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE user_roles (
            user_id INTEGER NOT NULL,
            role_id INTEGER NOT NULL,
            PRIMARY KEY (user_id, role_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint('V22 user_roles table error: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE role_permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role_id INTEGER NOT NULL,
            module TEXT NOT NULL,
            can_view INTEGER NOT NULL DEFAULT 0,
            can_create INTEGER NOT NULL DEFAULT 0,
            can_edit INTEGER NOT NULL DEFAULT 0,
            can_delete INTEGER NOT NULL DEFAULT 0,
            UNIQUE(role_id, module),
            FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint('V22 role_permissions table error: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE active_session (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_id INTEGER,
            logged_in_at INTEGER NOT NULL,
            last_activity_at INTEGER,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
          )
        ''');
      } catch (e) {
        debugPrint('V22 active_session table error: $e');
      }

      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN performed_by_user_id INTEGER');
      } catch (e) {
        debugPrint('V22 alter transactions performed_by_user_id error: $e');
      }
    }
  }

  @override
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

  @override
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
        secondary_unit TEXT,
        units_per_secondary REAL,
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
        ci_nit TEXT,
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
        adjustment_amount REAL DEFAULT 0.0,
        amount_paid REAL DEFAULT 0,
        payment_due_date INTEGER,
        status TEXT,
        supplier_invoice_ref TEXT,
        client_ci_nit TEXT,
        amount_tendered REAL DEFAULT 0.0,
        expense_category_id INTEGER,
        performed_by_user_id INTEGER
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

    await db.execute(
        'CREATE INDEX idx_payments_entity_date ON payments(entity_id, entity_type, date DESC)');
    await db.execute(
        'CREATE INDEX idx_allocations_transaction ON payment_allocations(transaction_id)');

    // V20: cash_registers
    await db.execute('''
      CREATE TABLE cash_registers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER DEFAULT NULL,
        open_date INTEGER NOT NULL,
        close_date INTEGER,
        opening_balance REAL NOT NULL DEFAULT 0,
        closing_balance REAL,
        expected_balance REAL,
        difference REAL,
        status TEXT NOT NULL DEFAULT 'OPEN',
        notes TEXT
      )
    ''');

    // V20: expense_categories
    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT 'category',
        color TEXT DEFAULT '0xFF6B7494'
      )
    ''');

    // Seed default expense categories
    await db.insert('expense_categories', {'name': 'Alquiler', 'icon': 'home', 'color': '0xFF4A90E2'});
    await db.insert('expense_categories', {'name': 'Servicios', 'icon': 'bolt', 'color': '0xFFF5A623'});
    await db.insert('expense_categories', {'name': 'Sueldos', 'icon': 'people', 'color': '0xFF9B51E0'});
    await db.insert('expense_categories', {'name': 'Mantenimiento', 'icon': 'build', 'color': '0xFF4ECDC4'});
    await db.insert('expense_categories', {'name': 'Impuestos', 'icon': 'receipt', 'color': '0xFFFF6B6B'});
    await db.insert('expense_categories', {'name': 'Transporte', 'icon': 'local_shipping', 'color': '0xFF51CF66'});
    await db.insert('expense_categories', {'name': 'Otros', 'icon': 'category', 'color': '0xFF6B7494'});

    // V21: notifications
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT,
        type TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // V22: RBAC tables
    await db.execute('''
      CREATE TABLE roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        description TEXT,
        is_system INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        last_login INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE user_roles (
        user_id INTEGER NOT NULL,
        role_id INTEGER NOT NULL,
        PRIMARY KEY (user_id, role_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE role_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role_id INTEGER NOT NULL,
        module TEXT NOT NULL,
        can_view INTEGER NOT NULL DEFAULT 0,
        can_create INTEGER NOT NULL DEFAULT 0,
        can_edit INTEGER NOT NULL DEFAULT 0,
        can_delete INTEGER NOT NULL DEFAULT 0,
        UNIQUE(role_id, module),
        FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE active_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER,
        logged_in_at INTEGER NOT NULL,
        last_activity_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
  }

  @override
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

  @override
  Future<void> _createSuppliersTable(Database db) async {
    await db.execute('''
      CREATE TABLE suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        category TEXT,
        address TEXT,
        ci_nit TEXT,
        created_at INTEGER
      )
    ''');
  }
}
