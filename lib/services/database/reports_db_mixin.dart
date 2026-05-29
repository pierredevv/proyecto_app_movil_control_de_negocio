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
    final sevenDaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6))
        .millisecondsSinceEpoch;
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    // Optimized: 1 query with GROUP BY instead of 7 individual queries
    final queryResult = await db.rawQuery('''
      SELECT strftime('%Y-%m-%d', date/1000, 'unixepoch', 'localtime') as day_key,
             SUM(total_amount) as total
      FROM transactions
      WHERE type = 'sale' AND status != 'VOIDED'
        AND date BETWEEN ? AND ?
      GROUP BY day_key
      ORDER BY day_key ASC
    ''', [sevenDaysAgo, endOfToday]);

    // Index results by day key for O(1) lookup
    final Map<String, double> salesByDay = {};
    for (var row in queryResult) {
      salesByDay[row['day_key'] as String] =
          (row['total'] as num?)?.toDouble() ?? 0.0;
    }

    // Fill all 7 days (including days with 0 sales)
    List<Map<String, dynamic>> result = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      result.add({
        'date': DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
        'amount': salesByDay[key] ?? 0.0,
      });
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // DETAILED SALES REPORT BY DATE RANGE
  // ---------------------------------------------------------------------------
  /// Returns comprehensive sales metrics for a given date range.
  /// Used by SalesPeriodReportScreen for export and display.
  Future<Map<String, dynamic>> getSalesReportByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // 1. Aggregate sales metrics
    final salesAgg = await db.rawQuery('''
      SELECT COUNT(*) as tx_count, 
             COALESCE(SUM(total_amount), 0) as total_sales,
             COALESCE(AVG(total_amount), 0) as avg_ticket
      FROM transactions
      WHERE type = 'sale' AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [startMs, endMs]);

    final txCount = (salesAgg.first['tx_count'] as int?) ?? 0;
    final totalSales =
        (salesAgg.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final avgTicket =
        (salesAgg.first['avg_ticket'] as num?)?.toDouble() ?? 0.0;

    // 2. Product-level metrics: quantity sold, units by type, COGS
    final productMetrics = await db.rawQuery('''
      SELECT COALESCE(SUM(ti.quantity * ti.units_per_sale_unit), 0) as total_base_units,
             COALESCE(SUM(ti.quantity), 0) as total_sale_units,
             COALESCE(SUM(ti.unit_cost_at_sale_time * ti.quantity * ti.units_per_sale_unit), 0) as total_cogs
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.type = 'sale' AND t.status != 'VOIDED' AND t.date BETWEEN ? AND ?
    ''', [startMs, endMs]);

    final totalBaseUnits =
        (productMetrics.first['total_base_units'] as num?)?.toDouble() ?? 0.0;
    final totalSaleUnits =
        (productMetrics.first['total_sale_units'] as num?)?.toDouble() ?? 0.0;
    final totalCogs =
        (productMetrics.first['total_cogs'] as num?)?.toDouble() ?? 0.0;

    // 3. Unit breakdown by sale_unit type (CAJ, UNI, BOL, etc.)
    final unitBreakdown = await db.rawQuery('''
      SELECT ti.sale_unit, 
             COALESCE(SUM(ti.quantity), 0) as qty
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.type = 'sale' AND t.status != 'VOIDED' AND t.date BETWEEN ? AND ?
      GROUP BY ti.sale_unit
      ORDER BY qty DESC
    ''', [startMs, endMs]);

    // 4. Top 5 products by revenue
    final topProducts = await db.rawQuery('''
      SELECT ti.product_id, ti.product_name, 
             SUM(ti.quantity) as total_qty,
             SUM(ti.subtotal) as total_revenue,
             ti.sale_unit
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.type = 'sale' AND t.status != 'VOIDED' AND t.date BETWEEN ? AND ?
      GROUP BY ti.product_id
      ORDER BY total_revenue DESC
      LIMIT 5
    ''', [startMs, endMs]);

    return {
      'total_sales': totalSales,
      'transaction_count': txCount,
      'avg_ticket': avgTicket,
      'total_base_units_sold': totalBaseUnits,
      'total_sale_units_sold': totalSaleUnits,
      'total_cogs': totalCogs,
      'gross_profit': totalSales - totalCogs,
      'gross_margin_pct':
          totalSales > 0 ? ((totalSales - totalCogs) / totalSales) * 100 : 0.0,
      'unit_breakdown': unitBreakdown
          .map((r) => {
                'sale_unit': r['sale_unit'],
                'quantity': (r['qty'] as num?)?.toDouble() ?? 0.0,
              })
          .toList(),
      'top_products': topProducts
          .map((r) => {
                'product_id': r['product_id'],
                'product_name': r['product_name'],
                'total_qty': (r['total_qty'] as num?)?.toDouble() ?? 0.0,
                'total_revenue':
                    (r['total_revenue'] as num?)?.toDouble() ?? 0.0,
                'sale_unit': r['sale_unit'],
              })
          .toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // EXPENSE SUMMARY BY DATE RANGE
  // ---------------------------------------------------------------------------
  /// Returns expense totals grouped by category for a given date range.
  /// Works with both categorized (V20+) and uncategorized expenses.
  Future<Map<String, dynamic>> getExpenseSummaryByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // Total expenses
    final totalResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total,
             COUNT(*) as count
      FROM transactions
      WHERE type = 'expense' AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [startMs, endMs]);

    final totalExpenses =
        (totalResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalCount = (totalResult.first['count'] as int?) ?? 0;

    // By category (if expense_categories table exists / V20+)
    List<Map<String, dynamic>> byCategory = [];
    try {
      byCategory = await db.rawQuery('''
        SELECT ec.id as cat_id, ec.name as cat_name, ec.icon, ec.color,
               COALESCE(SUM(t.total_amount), 0) as cat_total,
               COUNT(t.id) as cat_count
        FROM expense_categories ec
        LEFT JOIN transactions t ON t.expense_category_id = ec.id 
             AND t.type = 'expense' AND t.status != 'VOIDED' 
             AND t.date BETWEEN ? AND ?
        GROUP BY ec.id
        ORDER BY cat_total DESC
      ''', [startMs, endMs]);
    } catch (_) {
      // expense_categories table may not exist yet (pre-V20)
    }

    // Uncategorized expenses
    final uncatResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total,
             COUNT(*) as count
      FROM transactions
      WHERE type = 'expense' AND status != 'VOIDED' 
            AND expense_category_id IS NULL
            AND date BETWEEN ? AND ?
    ''', [startMs, endMs]);

    return {
      'total_expenses': totalExpenses,
      'total_count': totalCount,
      'by_category': byCategory
          .map((r) => {
                'id': r['cat_id'],
                'name': r['cat_name'],
                'icon': r['icon'],
                'color': r['color'],
                'total': (r['cat_total'] as num?)?.toDouble() ?? 0.0,
                'count': (r['cat_count'] as int?) ?? 0,
              })
          .toList(),
      'uncategorized_total':
          (uncatResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'uncategorized_count': (uncatResult.first['count'] as int?) ?? 0,
    };
  }

  // ---------------------------------------------------------------------------
  // CASH SUMMARY FOR REGISTER SESSION
  // ---------------------------------------------------------------------------
  /// Returns cash-only summary from a register open timestamp to now.
  /// Critical distinction: credit sales do NOT count as cash inflow.
  /// Only anonymous sales (cash at counter) + customer payments count as inflow.
  /// Expenses + supplier payments count as outflow.
  Future<Map<String, dynamic>> getCashSummaryByDateRange(
      int fromDateMs, int toDateMs) async {
    final db = await database;

    // Cash IN: Anonymous sales (entity_id IS NULL = cash at counter)
    final anonymousSales = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_paid), 0) as total
      FROM transactions
      WHERE type = 'sale' AND entity_id IS NULL AND status != 'VOIDED'
        AND date BETWEEN ? AND ?
    ''', [fromDateMs, toDateMs]);

    // Cash IN: Customer payments (cobros)
    final customerPayments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM payments
      WHERE entity_type = 'CUSTOMER' AND date BETWEEN ? AND ?
    ''', [fromDateMs, toDateMs]);

    // Cash OUT: Expenses
    final expenses = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total
      FROM transactions
      WHERE type = 'expense' AND status != 'VOIDED'
        AND date BETWEEN ? AND ?
    ''', [fromDateMs, toDateMs]);

    // Cash OUT: Supplier payments
    final supplierPayments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM payments
      WHERE entity_type = 'SUPPLIER' AND date BETWEEN ? AND ?
    ''', [fromDateMs, toDateMs]);

    // Cash OUT: Anonymous purchases (cash purchases without supplier)
    final anonymousPurchases = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_paid), 0) as total
      FROM transactions
      WHERE type = 'purchase' AND entity_id IS NULL AND status != 'VOIDED'
        AND date BETWEEN ? AND ?
    ''', [fromDateMs, toDateMs]);

    // Accrual context (informational, not cash)
    final accrualSales = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count
      FROM transactions
      WHERE type = 'sale' AND status != 'VOIDED' AND date BETWEEN ? AND ?
    ''', [fromDateMs, toDateMs]);

    final cashInAnon =
        (anonymousSales.first['total'] as num?)?.toDouble() ?? 0.0;
    final cashInPayments =
        (customerPayments.first['total'] as num?)?.toDouble() ?? 0.0;
    final cashOutExpenses =
        (expenses.first['total'] as num?)?.toDouble() ?? 0.0;
    final cashOutSupplier =
        (supplierPayments.first['total'] as num?)?.toDouble() ?? 0.0;
    final cashOutPurchases =
        (anonymousPurchases.first['total'] as num?)?.toDouble() ?? 0.0;

    final totalCashIn = cashInAnon + cashInPayments;
    final totalCashOut = cashOutExpenses + cashOutSupplier + cashOutPurchases;

    return {
      'cash_in_sales': cashInAnon,
      'cash_in_payments': cashInPayments,
      'total_cash_in': totalCashIn,
      'cash_out_expenses': cashOutExpenses,
      'cash_out_supplier_payments': cashOutSupplier,
      'cash_out_purchases': cashOutPurchases,
      'total_cash_out': totalCashOut,
      'net_cash': totalCashIn - totalCashOut,
      'accrual_sales_total':
          (accrualSales.first['total'] as num?)?.toDouble() ?? 0.0,
      'accrual_sales_count': (accrualSales.first['count'] as int?) ?? 0,
    };
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
