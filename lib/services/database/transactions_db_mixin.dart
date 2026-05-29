part of '../database_service.dart';

mixin TransactionsDb on CoreDb {
  // ---------------------------------------------------------------------------
  // TRANSACTION OPERATIONS (ATOMIC)
  // ---------------------------------------------------------------------------
  // Sprint C - Fetch linked payments for an invoice
  Future<List<Map<String, dynamic>>> getTransactionPayments(
      int transactionId) async {
    final db = await database;
    return await db.rawQuery('''
          SELECT p.date, p.payment_method, p.note, pa.allocated_amount as amount
          FROM payment_allocations pa
          JOIN payments p ON pa.payment_id = p.id
          WHERE pa.transaction_id = ?
          ORDER BY date DESC
       ''', [transactionId]);
  }

  Future<int> insertSale(Sale sale,
      {String paymentMethod = 'EFECTIVO',
      bool allowNegativeStock = false}) async {
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
        final currentWac =
            (result.first['weighted_average_cost'] as num?)?.toDouble() ?? 0.0;

        // 2. Check availability
        if (currentStock < item.baseUnitsTotal && !allowNegativeStock) {
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
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', sale.customerId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        if (ledgerQuery.isNotEmpty) {
          currentBalance =
              (ledgerQuery.first['materialized_running_balance'] as num)
                  .toDouble();
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
      if (sale.amountPaid > 0) {
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
        final unitCost =
            (item['unit_cost_at_sale_time'] as num?)?.toDouble() ?? 0.0;

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
        final totalAmount =
            (transaction.first['total_amount'] as num).toDouble();
        final amountPaid =
            (transaction.first['amount_paid'] as num?)?.toDouble() ?? 0.0;

        // 5a. Ledger compensation
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', customerId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num)
                .toDouble()
            : 0.0;

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
        final allocationsToClear = await txn.query('payment_allocations',
            where: 'transaction_id = ?', whereArgs: [saleId]);
        await txn.delete('payment_allocations',
            where: 'transaction_id = ?', whereArgs: [saleId]);

        // Intercept & destroy orphaned treasury records
        for (var alloc in allocationsToClear) {
          final pId = alloc['payment_id'] as int;
          final remaining = await txn.query('payment_allocations',
              where: 'payment_id = ?', whereArgs: [pId]);
          if (remaining.isEmpty) {
            final paymentRecord =
                await txn.query('payments', where: 'id = ?', whereArgs: [pId]);
            if (paymentRecord.isNotEmpty) {
              final pAmount = (paymentRecord.first['amount'] as num).toDouble();

              final ledgerQ = await txn.query('entity_ledgers',
                  where: 'entity_type = ? AND entity_id = ?',
                  whereArgs: ['CUSTOMER', customerId],
                  orderBy: 'date DESC, id DESC',
                  limit: 1);
              double currBal = ledgerQ.isNotEmpty
                  ? (ledgerQ.first['materialized_running_balance'] as num)
                      .toDouble()
                  : 0.0;

              await txn.insert('entity_ledgers', {
                'entity_type': 'CUSTOMER',
                'entity_id': customerId,
                'transaction_source_type': 'PAYMENT_VOID_REVERSAL',
                'transaction_reference_id': pId,
                'date': DateTime.now().millisecondsSinceEpoch + 1,
                'debit_amount': pAmount,
                'credit_amount': 0.0,
                'materialized_running_balance': currBal + pAmount,
                'note': 'Reversión de Pago Huérfano'
              });

              await txn.delete('payments', where: 'id = ?', whereArgs: [pId]);
            }
          }
        }

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

      // 2. Extract Customer — may be null for occasional-customer sales
      final customerId = transaction.first['entity_id'];

      // N1 FIX: Payment + allocation are always registered even without a customer.
      // Ledger and debt updates are guarded by customerId below.
      final paymentId = await txn.insert('payments', {
        'entity_id': customerId,   // may be null — OK for occasional sales
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

      // 4. Update Ledger and Decrease legacy Customer Debt (only if customer exists)
      if (customerId != null) {
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', customerId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num)
                .toDouble()
            : 0.0;

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

  Future<void> receiveSupplierPayment(int purchaseId, double amount,
      {String? note, String paymentMethod = 'EFECTIVO'}) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Get Purchase
      final List<Map<String, dynamic>> transaction = await txn.query(
        'transactions',
        columns: ['status', 'entity_id', 'total_amount', 'amount_paid'],
        where: 'id = ? AND type = ?',
        whereArgs: [purchaseId, 'purchase'],
      );

      if (transaction.isEmpty) throw Exception('Compra no encontrada');
      if (transaction.first['status'] == 'VOIDED') {
        throw Exception('Esta compra está anulada');
      }

      final total = transaction.first['total_amount'] as num;
      final currentPaid = transaction.first['amount_paid'] as num? ?? 0.0;
      final pending = total - currentPaid;

      if (amount > pending + 0.01) {
        throw Exception(
            'El monto supera el saldo pendiente. Pendiente: Bs. ${pending.toStringAsFixed(2)}');
      }

      final supplierId = transaction.first['entity_id'];
      if (supplierId == null) {
        throw Exception('La compra no tiene un proveedor asignado');
      }

      final paymentId = await txn.insert('payments', {
        'entity_id': supplierId,
        'entity_type': 'SUPPLIER',
        'amount': amount,
        'date': DateTime.now().millisecondsSinceEpoch,
        'payment_method': paymentMethod,
        'note': note ?? 'Abono a Proveedor',
      });

      await txn.insert('payment_allocations', {
        'payment_id': paymentId,
        'transaction_id': purchaseId,
        'allocated_amount': amount,
      });

      // 3. Update Purchase Status & amount_paid
      final newPaid = currentPaid + amount;
      final newStatus = (newPaid >= total - 0.01) ? 'COMPLETED' : 'PARTIAL';
      await txn.update(
        'transactions',
        {
          'amount_paid': newPaid,
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      // 4. Update Ledger reversing logic
      if (supplierId != null) {
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['SUPPLIER', supplierId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num)
                .toDouble()
            : 0.0;

        // DEBIT REDUCES LIABILITY FOR A SUPPLIER
        await txn.insert('entity_ledgers', {
          'entity_type': 'SUPPLIER',
          'entity_id': supplierId,
          'transaction_source_type': 'PAYMENT',
          'transaction_reference_id': paymentId,
          'date': DateTime.now().millisecondsSinceEpoch,
          'debit_amount': amount,
          'credit_amount': 0.0,
          'materialized_running_balance': currentBalance - amount,
          'note': note ?? 'Abono a Proveedor',
        });
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
      final currentDebt = initialLedgerQuery.isNotEmpty
          ? (initialLedgerQuery.first['materialized_running_balance'] as num)
              .toDouble()
          : 0.0;
      if (currentDebt <= 0) {
        throw Exception(
            'El cliente no tiene deudas pendientes (saldo: Bs. ${currentDebt.toStringAsFixed(2)}).');
      }
      if (totalAmount > currentDebt + 0.01) {
        throw Exception(
            'El abono (Bs. ${totalAmount.toStringAsFixed(2)}) excede la deuda total del cliente (Bs. ${currentDebt.toStringAsFixed(2)}).');
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

        if (transaction.isEmpty) {
          throw Exception(
              'Venta #$saleId no encontrada o no pertenece al cliente');
        }
        if (transaction.first['status'] == 'VOIDED') {
          throw Exception('La venta #$saleId está anulada');
        }

        final total = transaction.first['total_amount'] as num;
        final currentPaid = transaction.first['amount_paid'] as num? ?? 0.0;
        final pending = total - currentPaid;

        if (allocatedAmount > pending + 0.01) {
          throw Exception(
              'El monto supera al saldo pendiente en Venta #$saleId.');
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
        throw Exception(
            'La suma de distribuciones supera el monto depositado.');
      }

      // 3. Update Ledger and Decrease legacy Customer Debt
      final ledgerQuery = await txn.query('entity_ledgers',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['CUSTOMER', customerId],
          orderBy: 'date DESC, id DESC',
          limit: 1);
      double currentBalance = ledgerQuery.isNotEmpty
          ? (ledgerQuery.first['materialized_running_balance'] as num)
              .toDouble()
          : 0.0;

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

  Future<int> receiveSupplierGlobalPayment({
    required int supplierId,
    required double totalAmount,
    required String paymentMethod,
    String? note,
    required Map<int, double> allocations, // purchase_id -> allocated_amount
  }) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Validate against real ledger debt
      final initialLedgerQuery = await txn.query('entity_ledgers',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['SUPPLIER', supplierId],
          orderBy: 'date DESC, id DESC',
          limit: 1);
      final currentDebt = initialLedgerQuery.isNotEmpty
          ? (initialLedgerQuery.first['materialized_running_balance'] as num)
              .toDouble()
          : 0.0;
      if (currentDebt <= 0) {
        throw Exception(
            'El proveedor no tiene deudas pendientes (saldo: Bs. ${currentDebt.toStringAsFixed(2)}).');
      }
      if (totalAmount > currentDebt + 0.01) {
        throw Exception(
            'El abono (Bs. ${totalAmount.toStringAsFixed(2)}) excede la deuda total con el proveedor (Bs. ${currentDebt.toStringAsFixed(2)}).');
      }

      // 1. Insert Global Payment
      final paymentId = await txn.insert('payments', {
        'entity_id': supplierId,
        'entity_type': 'SUPPLIER',
        'amount': totalAmount,
        'date': DateTime.now().millisecondsSinceEpoch,
        'payment_method': paymentMethod,
        'note': note ?? 'Abono Global a Proveedor',
      });

      double totalAllocated = 0.0;

      // 2. Process Allocations
      for (var entry in allocations.entries) {
        final purchaseId = entry.key;
        final allocatedAmount = entry.value;

        if (allocatedAmount <= 0) continue;
        totalAllocated += allocatedAmount;

        final txns = await txn.query('transactions',
            columns: ['total_amount', 'amount_paid'],
            where: 'id = ?',
            whereArgs: [purchaseId]);
        if (txns.isEmpty) {
          throw Exception('Compra id $purchaseId no encontrada');
        }

        final tTotal = txns.first['total_amount'] as num;
        final tPaid = txns.first['amount_paid'] as num? ?? 0.0;

        await txn.insert('payment_allocations', {
          'payment_id': paymentId,
          'transaction_id': purchaseId,
          'allocated_amount': allocatedAmount,
        });

        final newPaid = tPaid + allocatedAmount;
        final newStatus = (newPaid >= tTotal - 0.01) ? 'COMPLETED' : 'PARTIAL';
        await txn.update(
            'transactions', {'amount_paid': newPaid, 'status': newStatus},
            where: 'id = ?', whereArgs: [purchaseId]);
      }

      if (totalAllocated > totalAmount + 0.01) {
        throw Exception(
            'La suma de distribuciones supera el monto depositado.');
      }

      final double unallocated = totalAmount - totalAllocated;
      final double applied = totalAmount - unallocated;
      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      if (applied > 0) {
        await txn.insert('entity_ledgers', {
          'entity_type': 'SUPPLIER',
          'entity_id': supplierId,
          'transaction_source_type': 'PAYMENT',
          'transaction_reference_id': paymentId,
          'date': timestamp,
          'debit_amount': applied, // DEBIT for Suppliers
          'credit_amount': 0.0,
          'materialized_running_balance': currentDebt - applied,
          'note': note ?? 'Abono Global a Proveedor ($paymentMethod)',
        });
      }

      if (unallocated > 0) {
        await txn.insert('entity_ledgers', {
          'entity_type': 'SUPPLIER',
          'entity_id': supplierId,
          'transaction_source_type': 'CREDIT_BALANCE',
          'transaction_reference_id': paymentId,
          'date': timestamp + 1, // Avoid overlapping exactly the same ms
          'debit_amount':
              unallocated, // DEBIT for suppliers (reduces liability, essentially acting as an asset / advance payment)
          'credit_amount': 0.0,
          'materialized_running_balance': currentDebt -
              totalAmount, // Deduct the entire totalAmount to reflect the advance
          'note': 'Saldo a favor (Anticipo) - $paymentMethod',
        });
      }

      return paymentId;
    });
  }

  Future<int> insertPurchase(Purchase purchase,
      {String paymentMethod = 'EFECTIVO'}) async {
    final db = await database;

    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('transactions', purchase.toMap());

      for (var item in purchase.items) {
        // 1. Query current WAC, stock, and conversion unit
        final List<Map<String, dynamic>> prodResult = await txn.query(
          'products',
          columns: ['stock', 'weighted_average_cost', 'units_per_box'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        double currentStock = 0.0;
        double currentWac = 0.0;
        double unitsPerBox = 1.0;
        if (prodResult.isNotEmpty) {
          currentStock = (prodResult.first['stock'] as num).toDouble();
          currentWac =
              (prodResult.first['weighted_average_cost'] as num?)?.toDouble() ??
                  0.0;
          unitsPerBox =
              (prodResult.first['units_per_box'] as num?)?.toDouble() ?? 1.0;
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
        final totalOldValue =
            currentStock > 0 ? currentStock * currentWac : 0.0;
        final newInvestment = item.quantity * item.unitPrice;
        final newTotalStock = currentStock + item.baseUnitsTotal;

        final newWac = newTotalStock > 0
            ? (totalOldValue + newInvestment) / newTotalStock
            : 0.0;
        final unitCostInBaseUnits =
            item.baseUnitsTotal > 0 ? newInvestment / item.baseUnitsTotal : 0.0;

        final unitCostBase = item.baseUnitsTotal > 0
            ? (item.quantity * item.unitPrice) / item.baseUnitsTotal
            : item.unitPrice;

        // The true cost for the product mapping is scaled back to the Sales Unit
        final newProductCost = unitCostBase * unitsPerBox;

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
          [item.baseUnitsTotal, newProductCost, newWac, item.productId],
        );
      }

      if (purchase.supplierId != null) {
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['SUPPLIER', purchase.supplierId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num)
                .toDouble()
            : 0.0;

        await txn.insert('entity_ledgers', {
          'entity_type': 'SUPPLIER',
          'entity_id': purchase.supplierId,
          'transaction_source_type': 'PURCHASE',
          'transaction_reference_id': purchaseId,
          'date': DateTime.now().millisecondsSinceEpoch,
          'debit_amount': 0.0,
          'credit_amount': purchase.totalAmount,
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
            'debit_amount': purchase.amountPaid,
            'credit_amount': 0.0,
            'materialized_running_balance':
                currentBalance - purchase.amountPaid,
            'note': 'Pago de Compra',
          });

          final paymentId = await txn.insert('payments', {
            'entity_id': purchase.supplierId,
            'entity_type': 'SUPPLIER',
            'amount': purchase.amountPaid,
            'date': DateTime.now().millisecondsSinceEpoch,
            'payment_method': paymentMethod,
            'note': 'Pago de Compra'
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
        columns: [
          'status',
          'reference_id',
          'entity_id',
          'total_amount',
          'amount_paid'
        ],
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
        final totalAmount =
            (transaction.first['total_amount'] as num).toDouble();
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['SUPPLIER', supplierId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num)
                .toDouble()
            : 0.0;

        await txn.insert('entity_ledgers', {
          'entity_type': 'SUPPLIER',
          'entity_id': supplierId,
          'transaction_source_type': 'PURCHASE_VOID_REVERSAL',
          'transaction_reference_id': purchaseId,
          'date': DateTime.now().millisecondsSinceEpoch,
          'debit_amount': totalAmount,
          'credit_amount': 0.0,
          'materialized_running_balance': currentBalance - totalAmount,
          'note': 'Anulación de Compra',
        });

        // Release the money so it remains as an advance/balance in favor of the supplier
        await txn.delete('payment_allocations',
            where: 'transaction_id = ?', whereArgs: [purchaseId]);
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
      final order = await txn.query('transactions',
          columns: ['status'], where: 'id = ?', whereArgs: [orderId]);
      if (order.isNotEmpty && order.first['status'] == 'RECEIVED') {
        throw Exception(
            'You cannot cancel an order that has already been received. Please cancel the associated Purchase instead.');
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
      final ledgerQuery = await txn.query('entity_ledgers',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['CUSTOMER', customerId],
          orderBy: 'date DESC',
          limit: 1);
      double currentBalance = ledgerQuery.isNotEmpty
          ? (ledgerQuery.first['materialized_running_balance'] as num)
              .toDouble()
          : 0.0;
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
      final paymentId = await txn.insert('payments', {
        'entity_id': customerId,
        'entity_type': 'CUSTOMER',
        'amount': amount,
        'date': DateTime.now().millisecondsSinceEpoch,
        'payment_method': 'EFECTIVO',
        'note': 'Abono rápido',
      });

      await txn.update('transactions', {'reference_id': paymentId},
          where: 'id = ?', whereArgs: [id]);

      return id;
    });
  }

  Future<void> deletePayment(int transactionId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Find the parent transaction
      final tResults = await txn
          .query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (tResults.isEmpty) return;

      final tran = tResults.first;
      final amount = (tran['total_amount'] as num).toDouble();
      final entityId = tran['entity_id'] as int?;
      if (entityId == null) return;

      // 0. Void the original transaction
      await txn.update('transactions', {'status': 'VOIDED'},
          where: 'id = ?', whereArgs: [transactionId]);

      // 1. Point dynamically to the payments table (V13) by finding correlation
      // Uses exact reference_id if available (future proof), otherwise falls back to close timestamp logic
      List<Map<String, dynamic>> results = [];
      if (tran['reference_id'] != null) {
        results = await txn.query('payments',
            where: 'id = ?', whereArgs: [tran['reference_id']]);
      } else {
        results = await txn.query('payments',
            where: 'entity_id = ? AND amount = ? AND abs(date - ?) < 10000',
            whereArgs: [entityId, amount, tran['date']]);
      }
      if (results.isEmpty) {
        // Legacy reversal fallback for old systems
        await txn.rawUpdate(
            'UPDATE customers SET total_debt = total_debt + ? WHERE id = ?',
            [amount, entityId]);
        final ledgerQuery = await txn.query('entity_ledgers',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CUSTOMER', entityId],
            orderBy: 'date DESC, id DESC',
            limit: 1);
        double currentBalance = ledgerQuery.isNotEmpty
            ? (ledgerQuery.first['materialized_running_balance'] as num)
                .toDouble()
            : 0.0;
        await txn.insert('entity_ledgers', {
          'entity_type': 'CUSTOMER',
          'entity_id': entityId,
          'transaction_source_type': 'PAYMENT_VOID_REVERSAL',
          'transaction_reference_id': transactionId,
          'date': DateTime.now().millisecondsSinceEpoch,
          'debit_amount': amount,
          'credit_amount': 0.0,
          'materialized_running_balance': currentBalance + amount,
          'note': 'Anulación de Pago Legado',
        });
        return;
      }

      final payment = results.first;
      final paymentId = payment['id'] as int;
      final entityType = payment['entity_type'] as String;

      // 2. Revert assignments safely
      final allocations = await txn.query('payment_allocations',
          where: 'payment_id = ?', whereArgs: [paymentId]);
      for (var a in allocations) {
        final tId = a['transaction_id'] as int;
        final allocAmt = (a['allocated_amount'] as num).toDouble();

        final tRecord = await txn.query('transactions',
            columns: ['amount_paid', 'total_amount'],
            where: 'id = ?',
            whereArgs: [tId]);
        if (tRecord.isNotEmpty) {
          final newPaid =
              (tRecord.first['amount_paid'] as num).toDouble() - allocAmt;
          final total = (tRecord.first['total_amount'] as num).toDouble();
          final newStatus = newPaid >= total - 0.01
              ? 'COMPLETED'
              : (newPaid <= 0 ? 'CREDIT' : 'PARTIAL');
          await txn.update(
              'transactions', {'amount_paid': newPaid, 'status': newStatus},
              where: 'id = ?', whereArgs: [tId]);
        }
      }

      // 3. Reverse debt depending on entity type
      if (entityType == 'CUSTOMER') {
        await txn.rawUpdate(
            'UPDATE customers SET total_debt = total_debt + ? WHERE id = ?',
            [amount, entityId]);
      }

      // 4. Delete payment and allocations
      await txn.delete('payment_allocations',
          where: 'payment_id = ?', whereArgs: [paymentId]);
      await txn.delete('payments', where: 'id = ?', whereArgs: [paymentId]);

      // 5. Register reverse in Ledger
      final ledgerQuery = await txn.query('entity_ledgers',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: [entityType, entityId],
          orderBy: 'date DESC, id DESC',
          limit: 1);
      double currentBalance = ledgerQuery.isNotEmpty
          ? (ledgerQuery.first['materialized_running_balance'] as num)
              .toDouble()
          : 0.0;
      await txn.insert('entity_ledgers', {
        'entity_type': entityType, 'entity_id': entityId,
        'transaction_source_type': 'PAYMENT_VOID_REVERSAL',
        'transaction_reference_id': paymentId,
        'date': DateTime.now().millisecondsSinceEpoch,
        'debit_amount': entityType == 'CUSTOMER' ? amount : 0.0,
        'credit_amount': entityType == 'SUPPLIER' ? amount : 0.0,
        'materialized_running_balance': currentBalance +
            amount, // Eliminating a payment increases both Customer debt and Supplier liability
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

    List<int> saleIds = [];
    for (var map in maps) {
      if (map['type'] == 'sale') saleIds.add(map['id'] as int);
    }

    Map<int, List<InvoiceItem>> itemsBySale = {};
    for (var i = 0; i < saleIds.length; i += 900) {
      final chunk = saleIds.sublist(
          i, i + 900 > saleIds.length ? saleIds.length : i + 900);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (var row in itemsMaps) {
        final tId = row['transaction_id'] as int;
        itemsBySale.putIfAbsent(tId, () => []);
        itemsBySale[tId]!.add(InvoiceItem.fromMap(row));
      }
    }

    List<Transaction> transactions = [];
    for (var map in maps) {
      final type = map['type'] as String;
      if (type == 'sale') {
        final id = map['id'] as int;
        transactions.add(Sale.fromMap(map, itemsBySale[id] ?? []));
      } else if (type == 'payment') {
        transactions.add(Payment.fromMap(map));
      }
    }
    return transactions;
  }

  Future<List<Transaction>> getSupplierHistory(int supplierId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: "entity_id = ? AND status != 'VOIDED' AND (type = ? OR type = ?)",
      whereArgs: [supplierId, 'purchase', 'payment'],
      orderBy: 'date DESC',
    );

    List<int> purchaseIds = [];
    for (var map in maps) {
      if (map['type'] == 'purchase') purchaseIds.add(map['id'] as int);
    }

    Map<int, List<InvoiceItem>> itemsByPurchase = {};
    for (var i = 0; i < purchaseIds.length; i += 900) {
      final chunk = purchaseIds.sublist(
          i, i + 900 > purchaseIds.length ? purchaseIds.length : i + 900);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (var row in itemsMaps) {
        final tId = row['transaction_id'] as int;
        itemsByPurchase.putIfAbsent(tId, () => []);
        itemsByPurchase[tId]!.add(InvoiceItem.fromMap(row));
      }
    }

    List<Transaction> transactions = [];
    for (var map in maps) {
      final type = map['type'] as String;
      if (type == 'purchase') {
        final id = map['id'] as int;
        transactions.add(Purchase.fromMap(map, itemsByPurchase[id] ?? []));
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

    List<int> saleIds = maps.map((m) => m['id'] as int).toList();
    Map<int, List<InvoiceItem>> itemsBySale = {};

    if (saleIds.isNotEmpty) {
      for (var i = 0; i < saleIds.length; i += 900) {
        final chunk = saleIds.sublist(
            i, i + 900 > saleIds.length ? saleIds.length : i + 900);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id IN ($placeholders)',
          whereArgs: chunk,
        );
        for (var row in itemsMaps) {
          final tId = row['transaction_id'] as int;
          itemsBySale.putIfAbsent(tId, () => []);
          itemsBySale[tId]!.add(InvoiceItem.fromMap(row));
        }
      }
    }

    List<Sale> sales = [];
    for (var map in maps) {
      final id = map['id'] as int;
      sales.add(Sale.fromMap(map, itemsBySale[id] ?? []));
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

    List<int> purchaseIds = maps.map((m) => m['id'] as int).toList();
    Map<int, List<InvoiceItem>> itemsByPurchase = {};

    if (purchaseIds.isNotEmpty) {
      for (var i = 0; i < purchaseIds.length; i += 900) {
        final chunk = purchaseIds.sublist(
            i, i + 900 > purchaseIds.length ? purchaseIds.length : i + 900);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final itemsMaps = await db.query(
          'transaction_items',
          where: 'transaction_id IN ($placeholders)',
          whereArgs: chunk,
        );
        for (var row in itemsMaps) {
          final tId = row['transaction_id'] as int;
          itemsByPurchase.putIfAbsent(tId, () => []);
          itemsByPurchase[tId]!.add(InvoiceItem.fromMap(row));
        }
      }
    }

    List<Purchase> purchases = [];
    for (var map in maps) {
      final id = map['id'] as int;
      purchases.add(Purchase.fromMap(map, itemsByPurchase[id] ?? []));
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
          final ledgerQuery = await txn.query('entity_ledgers',
              where: 'entity_type = ? AND entity_id = ?',
              whereArgs: ['SUPPLIER', entityId],
              orderBy: 'date DESC, id DESC',
              limit: 1);
          double currentBalance = ledgerQuery.isNotEmpty
              ? (ledgerQuery.first['materialized_running_balance'] as num)
                  .toDouble()
              : 0.0;
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
          // 1. Query current WAC, stock, and conversion unit
          final List<Map<String, dynamic>> prodResult = await txn.query(
            'products',
            columns: ['stock', 'weighted_average_cost', 'units_per_box'],
            where: 'id = ?',
            whereArgs: [item.productId],
          );

          double currentStock = 0.0;
          double currentWac = 0.0;
          double unitsPerBox = 1.0;
          if (prodResult.isNotEmpty) {
            currentStock = (prodResult.first['stock'] as num).toDouble();
            currentWac = (prodResult.first['weighted_average_cost'] as num?)
                    ?.toDouble() ??
                0.0;
            unitsPerBox =
                (prodResult.first['units_per_box'] as num?)?.toDouble() ?? 1.0;
          }

          // 2. Calculate new WAC
          final totalOldValue =
              currentStock > 0 ? currentStock * currentWac : 0.0;
          final newInvestment = item.quantity * item.unitPrice;
          final newTotalStock = currentStock + item.baseUnitsTotal;

          final newWac = newTotalStock > 0
              ? (totalOldValue + newInvestment) / newTotalStock
              : 0.0;
          final unitCostInBaseUnits = item.baseUnitsTotal > 0
              ? newInvestment / item.baseUnitsTotal
              : 0.0;
          final newProductCost = unitCostInBaseUnits * unitsPerBox;

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
            [item.baseUnitsTotal, newProductCost, newWac, item.productId],
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

  Future<int> insertExpense(String description, double amount, {int? categoryId}) async {
    final db = await database;
    return await db.insert('transactions', {
      'type': 'expense',
      'entity_name': description,
      'expense_category_id': categoryId,
      'date': DateTime.now().millisecondsSinceEpoch,
      'total_amount': amount,
      'status': 'COMPLETED',
    });
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

    // Batch query for transaction items (N+1 Optimization)
    final List<int> idsWithItems = [];
    for (var map in maps) {
      final tType = map['type'] as String;
      if (tType == 'sale' || tType == 'purchase' || tType == 'order') {
        idsWithItems.add(map['id'] as int);
      }
    }

    // Fetch all required items in one query
    final Map<int, List<InvoiceItem>> groupedItems = {};
    if (idsWithItems.isNotEmpty) {
      final String idList = idsWithItems.join(',');
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id IN ($idList)',
      );
      for (var map in itemsMaps) {
        final tId = map['transaction_id'] as int;
        if (!groupedItems.containsKey(tId)) {
          groupedItems[tId] = [];
        }
        groupedItems[tId]!.add(InvoiceItem.fromMap(map));
      }
    }

    for (var map in maps) {
      final tType = map['type'] as String;
      final id = map['id'] as int;
      final items = groupedItems[id] ?? [];

      if (tType == 'sale') {
        transactions.add(Sale.fromMap(map, items));
      } else if (tType == 'purchase') {
        transactions.add(Purchase.fromMap(map, items));
      } else if (tType == 'payment') {
        transactions.add(Payment.fromMap(map));
      } else if (tType == 'expense') {
        transactions.add(Expense.fromMap(map));
      } else if (tType == 'order') {
        transactions.add(Order.fromMap(map, items));
      }
    }

    return transactions;
  }

  // (Existing code)
  Future<Transaction?> getTransactionById(int id) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'id = ? AND status != ?',
      whereArgs: [id, 'VOIDED'],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final typeStr = maps.first['type'] as String;

    if (typeStr == 'sale' || typeStr == 'purchase') {
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      final items = List.generate(
        itemsMaps.length,
        (i) => InvoiceItem.fromMap(itemsMaps[i]),
      );
      if (typeStr == 'sale') return Sale.fromMap(maps.first, items);
      if (typeStr == 'purchase') return Purchase.fromMap(maps.first, items);
    }

    if (typeStr == 'expense') return Expense.fromMap(maps.first);
    if (typeStr == 'payment') return Payment.fromMap(maps.first);
    return null;
  }

  Future<List<Transaction>> getRecentTransactions({int limit = 5}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: "status != 'VOIDED'",
      orderBy: 'date DESC',
      limit: limit,
    );

    List<Transaction> transactions = [];

    // Batch query for transaction items (N+1 Optimization)
    final List<int> idsWithItems = [];
    for (var map in maps) {
      final tType = map['type'] as String;
      if (tType == 'sale' || tType == 'purchase' || tType == 'order') {
        idsWithItems.add(map['id'] as int);
      }
    }

    // Fetch all required items in one query
    final Map<int, List<InvoiceItem>> groupedItems = {};
    if (idsWithItems.isNotEmpty) {
      final String idList = idsWithItems.join(',');
      final itemsMaps = await db.query(
        'transaction_items',
        where: 'transaction_id IN ($idList)',
      );
      for (var itemMap in itemsMaps) {
        final tId = itemMap['transaction_id'] as int;
        groupedItems
            .putIfAbsent(tId, () => [])
            .add(InvoiceItem.fromMap(itemMap));
      }
    }

    for (var map in maps) {
      final id = map['id'] as int;
      final type = map['type'] as String;

      if (type == 'sale') {
        transactions.add(Sale.fromMap(map, groupedItems[id] ?? []));
      } else if (type == 'purchase') {
        transactions.add(Purchase.fromMap(map, groupedItems[id] ?? []));
      } else if (type == 'order') {
        transactions.add(Order.fromMap(map, groupedItems[id] ?? []));
      } else if (type == 'payment') {
        transactions.add(Payment.fromMap(map));
      } else if (type == 'expense') {
        transactions.add(Expense.fromMap(map));
      }
    }

    return transactions;
  }
}
