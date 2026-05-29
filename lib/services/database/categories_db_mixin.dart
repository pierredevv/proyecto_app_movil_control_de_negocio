part of '../database_service.dart';

mixin CategoriesDb on CoreDb {
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
  // EXPENSE CATEGORY OPERATIONS (V20+)
  // ---------------------------------------------------------------------------
  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expense_categories');
    return maps.map((map) => ExpenseCategory.fromMap(map)).toList();
  }

  Future<int> insertExpenseCategory(ExpenseCategory category) async {
    final db = await database;
    return await db.insert('expense_categories', category.toMap());
  }

  Future<int> deleteExpenseCategory(int id) async {
    final db = await database;
    return await db.delete(
      'expense_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
