import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';

import '../models/app_notification.dart';
import '../services/settings_service.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> checkLowStock() async {
    try {
      final profile = await SettingsService.getProfile();
      if (!profile.lowStockAlertsEnabled) return;

      final products = await _db.getProducts();
      final lowStockProducts =
          products.where((p) => p.stockInSaleUnits <= p.minStock).toList();

      for (var product in lowStockProducts) {
        final notifId = 'low_stock_${product.id}';
        final alreadyNotified = _notifications.any((n) => n.id == notifId);

        if (!alreadyNotified) {
          _addNotification(
            id: notifId,
            title: 'Alerta de Stock Bajo',
            body:
                'Tienes poco stock de "${product.name}", ¡por favor reabastece!',
            type: 'low_stock',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking low stock: $e');
    }
  }

  void _addNotification({
    String? id,
    required String title,
    required String body,
    String? type,
  }) {
    final notification = AppNotification(
      id: id ?? const Uuid().v4(),
      title: title,
      body: body,
      date: DateTime.now(),
      type: type,
    );
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
