part of '../database_service.dart';

mixin ReportsDb on CoreDb {
  // Abstract methods fulfilled by other mixins
  Future<List<Customer>> getCustomers();
  Future<List<Supplier>> getSuppliers();

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

    // Anonymous Purchases Cash (Outflow)
    final anonymousPurchasesResult = await db.rawQuery('''
      SELECT SUM(amount_paid) as total 
      FROM transactions 
      WHERE type = 'purchase' AND entity_id IS NULL AND status != 'VOIDED' AND date BETWEEN ? AND ?
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
    final totalAnonymousSalesCash =
        (anonymousSalesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPayments =
        (paymentsResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalSupplierPayments =
        (supplierPaymentsResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPurchasesPaid =
        (purchasesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalAnonymousPurchasesCash =
        (anonymousPurchasesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final cashIn = totalAnonymousSalesCash + totalPayments;
    final cashOut =
        totalExpenses + totalSupplierPayments + totalAnonymousPurchasesCash;

    return {
      'accrual_sales': totalSales,
      'accrual_purchases': totalPurchasesPaid,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'net_cash_balance': cashIn - cashOut,
    };
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

  Future<List<Map<String, dynamic>>> getAgingReport(
      {String entityType = 'CUSTOMER'}) async {
    final db = await database;
    final now = DateTime.now();

    final isCustomer = entityType == 'CUSTOMER';
    final List<dynamic> entities =
        isCustomer ? await getCustomers() : await getSuppliers();
    final sourceType = isCustomer ? 'INVOICE' : 'PURCHASE';

    final entityIds =
        entities.where((e) => e.totalDebt > 0).map((e) => e.id).toList();
    final Map<int, List<Map<String, dynamic>>> invoicesByEntity = {};

    if (entityIds.isNotEmpty) {
      for (var i = 0; i < entityIds.length; i += 900) {
        final chunk = entityIds.sublist(
            i, i + 900 > entityIds.length ? entityIds.length : i + 900);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final invoicesChunk = await db.rawQuery('''
          SELECT el.* FROM entity_ledgers el 
          JOIN transactions t ON el.transaction_reference_id = t.id 
          WHERE el.entity_type = ? AND el.entity_id IN ($placeholders) 
          AND el.transaction_source_type = ? AND t.status != 'VOIDED' 
          ORDER BY el.date DESC 
        ''', [entityType, ...chunk, sourceType]);

        for (var inv in invoicesChunk) {
          final eId = inv['entity_id'] as int;
          invoicesByEntity.putIfAbsent(eId, () => []);
          invoicesByEntity[eId]!.add(inv);
        }
      }
    }

    final Map<int, Map<String, dynamic>> reportMap = {};

    for (var e in entities) {
      if (e.totalDebt <= 0) continue; // Skip if no debt

      double remainingDebt = e.totalDebt;

      final Map<String, dynamic> entityReport = {
        'entity_id': e.id,
        'entity_name': e.name,
        'current': 0.0,
        'days_30_60': 0.0,
        'days_60_plus': 0.0,
        'total': e.totalDebt,
      };

      final invoices = invoicesByEntity[e.id] ?? [];

      for (var inv in invoices) {
        if (remainingDebt <= 0) break;

        final invoiceAmount = isCustomer
            ? (inv['debit_amount'] as num).toDouble()
            : (inv['credit_amount'] as num).toDouble();

        // Safety check if debit_amount was mistakenly configured as 0 (e.g. some manual modifications)
        if (invoiceAmount <= 0) continue;

        final dateMs = inv['date'] as int;
        final baseDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
        final difference = now.difference(baseDate).inDays;

        final amountToAllocate =
            invoiceAmount < remainingDebt ? invoiceAmount : remainingDebt;

        if (difference > 60) {
          entityReport['days_60_plus'] =
              (entityReport['days_60_plus'] as double) + amountToAllocate;
        } else if (difference > 30) {
          entityReport['days_30_60'] =
              (entityReport['days_30_60'] as double) + amountToAllocate;
        } else {
          entityReport['current'] =
              (entityReport['current'] as double) + amountToAllocate;
        }

        remainingDebt -= amountToAllocate;
      }

      // If there's STILL remaining debt (e.g., initial balances without invoice entries)
      if (remainingDebt > 0.01) {
        // Dump it in the current bucket
        entityReport['current'] =
            (entityReport['current'] as double) + remainingDebt;
      }

      reportMap[e.id!] = entityReport;
    }

    final result = reportMap.values.toList();
    result
        .sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return result;
  }

  // ---------------------------------------------------------------------------
  // LEDGER STATEMENTS
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getEntityLedgers(
      String entityType, int entityId) async {
    final db = await database;
    return await db.query(
      'entity_ledgers',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'date DESC, id DESC',
    );
  }

  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end,
      {TransactionType? type}) async {
    final db = await database;
    String whereClause = 'date >= ? AND date <= ?';
    List<dynamic> whereArgs = [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch
    ];

    if (type != null) {
      whereClause += ' AND type = ?';
      if (type == TransactionType.sale) {
        whereArgs.add('sale');
      } else if (type == TransactionType.purchase) {
        whereArgs.add('purchase');
      } else if (type == TransactionType.expense) {
        whereArgs.add('expense');
      } else if (type == TransactionType.payment) {
        whereArgs.add('payment');
      } else if (type == TransactionType.order) {
        whereArgs.add('order');
      }
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    List<int> transactionIds = maps.map((m) => m['id'] as int).toList();
    Map<int, List<InvoiceItem>> itemsByTransaction = {};

    if (transactionIds.isNotEmpty) {
      for (var i = 0; i < transactionIds.length; i += 900) {
        final chunk = transactionIds.sublist(i,
            i + 900 > transactionIds.length ? transactionIds.length : i + 900);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id IN ($placeholders)',
          whereArgs: chunk,
        );
        for (var row in itemsMaps) {
          final tId = row['transaction_id'] as int;
          itemsByTransaction.putIfAbsent(tId, () => []);
          itemsByTransaction[tId]!.add(InvoiceItem.fromMap(row));
        }
      }
    }

    List<Transaction> transactions = [];
    for (var map in maps) {
      final items = itemsByTransaction[map['id']] ?? [];

      if (map['type'] == 'sale') {
        transactions.add(Sale.fromMap(map, items));
      } else if (map['type'] == 'purchase') {
        transactions.add(Purchase.fromMap(map, items));
      } else if (map['type'] == 'expense') {
        transactions.add(Expense.fromMap(map));
      } else if (map['type'] == 'payment') {
        transactions.add(Payment.fromMap(map));
      } else if (map['type'] == 'order') {
        transactions.add(Order.fromMap(map, items));
      }
    }
    return transactions;
  }
}
