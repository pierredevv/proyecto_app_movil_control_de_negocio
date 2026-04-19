part of '../database_service.dart';

mixin SuppliersDb on CoreDb {
  // ---------------------------------------------------------------------------
  // SUPPLIER OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*, 
        (SELECT materialized_running_balance FROM entity_ledgers 
         WHERE entity_type = 'SUPPLIER' AND entity_id = s.id 
         ORDER BY date DESC, id DESC LIMIT 1) as total_debt
      FROM suppliers s
    ''');
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
    final hasHistory = await db.query('transactions',
        where: 'entity_id = ? AND type IN (?, ?)',
        whereArgs: [id, 'purchase', 'order']);

    // Validate if there are payments/credits in Treasury V13
    final hasPayments = await db.query('payments',
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [id, 'SUPPLIER']);

    if (hasHistory.isNotEmpty || hasPayments.isNotEmpty) {
      throw Exception(
          'No se puede eliminar porque tiene historial contable, pedidos o abonos registrados.');
    }

    // Validate if the supplier is assigned to any product
    final hasProducts =
        await db.query('products', where: 'supplier_id = ?', whereArgs: [id]);

    if (hasProducts.isNotEmpty) {
      await db.update('products', {'supplier_id': null},
          where: 'supplier_id = ?', whereArgs: [id]);
    }

    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
