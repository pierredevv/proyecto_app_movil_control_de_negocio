part of '../database_service.dart';

mixin CustomersDb on CoreDb {
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
    final hasHistory =
        await db.query('transactions', where: 'entity_id = ?', whereArgs: [id]);
    final hasPayments = await db.query('payments',
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [id, 'CUSTOMER']);
    final hasLedger = await db.query('entity_ledgers',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['CUSTOMER', id],
        limit: 1);
    if (hasHistory.isNotEmpty ||
        hasPayments.isNotEmpty ||
        hasLedger.isNotEmpty) {
      throw Exception(
          'No se puede eliminar porque tiene historial contable o abonos registrados');
    }
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
