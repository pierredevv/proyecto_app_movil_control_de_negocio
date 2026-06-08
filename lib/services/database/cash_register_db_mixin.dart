part of '../database_service.dart';

mixin CashRegisterDb on CoreDb {
  Future<int> openRegister(double openingBalance, {int? userId}) async {
    final db = await database;
    // Check if there is an active session
    final active = await getOpenRegister();
    if (active != null) {
      throw Exception('Ya existe una sesión de caja abierta con ID ${active.id}');
    }

    return await db.insert('cash_registers', {
      'open_date': DateTime.now().millisecondsSinceEpoch,
      'opening_balance': openingBalance,
      'status': 'OPEN',
      'user_id': userId,
    });
  }

  Future<CashRegister?> getOpenRegister() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_registers',
      where: "status = 'OPEN'",
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CashRegister.fromMap(maps.first);
  }

  Future<void> closeRegister(
    int id,
    double closingBalance,
    double expectedBalance,
    String? notes,
  ) async {
    final db = await database;
    final difference = closingBalance - expectedBalance;

    await db.update(
      'cash_registers',
      {
        'close_date': DateTime.now().millisecondsSinceEpoch,
        'closing_balance': closingBalance,
        'expected_balance': expectedBalance,
        'difference': difference,
        'status': 'CLOSED',
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CashRegister>> getRegisterHistory({int limit = 30}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_registers',
      orderBy: 'open_date DESC',
      limit: limit,
    );
    return maps.map((map) => CashRegister.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getRegisterSessionSummary(int registerOpenDateMs, int toDateMs) async {
    if (this is ReportsDb) {
      return await (this as ReportsDb).getCashSummaryByDateRange(registerOpenDateMs, toDateMs);
    }
    throw Exception('DatabaseService must implement ReportsDb to get session summary');
  }
}
