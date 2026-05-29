part of '../database_service.dart';

mixin NotificationsDb on CoreDb {
  Future<List<AppNotification>> getNotifications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AppNotification.fromMap(map)).toList();
  }

  Future<void> insertNotification(AppNotification notif) async {
    final db = await database;
    await db.insert(
      'notifications',
      notif.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNotification(AppNotification notif) async {
    final db = await database;
    await db.update(
      'notifications',
      notif.toMap(),
      where: 'id = ?',
      whereArgs: [notif.id],
    );
  }

  Future<void> deleteNotification(String id) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearNotifications() async {
    final db = await database;
    await db.delete('notifications');
  }
}
