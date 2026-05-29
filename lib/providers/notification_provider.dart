import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../models/app_notification.dart';
import '../services/settings_service.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  int _pendingSalesCount = 0;
  int get pendingSalesCount => _pendingSalesCount;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    try {
      final list = await _db.getNotifications();
      _notifications = list;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications from DB: $e');
    }
  }

  Future<void> checkLowStock() async {
    try {
      final profile = await SettingsService.getProfile();
      if (!profile.lowStockAlertsEnabled) return;

      final lowStockProducts = await _db.getProducts(stockStatuses: ['critical']);

      // Load current active notifications to check what's already there
      await loadNotifications();

      // First, clear notifications for products that already have sufficient stock
      final activeProductIds = lowStockProducts.map((p) => 'low_stock_${p.id}').toSet();
      for (var n in _notifications) {
        if (n.type == 'low_stock' && !activeProductIds.contains(n.id)) {
          await _db.deleteNotification(n.id);
        }
      }

      // Add new low stock alerts
      for (var product in lowStockProducts) {
        final notifId = 'low_stock_${product.id}';
        final alreadyNotified = _notifications.any((n) => n.id == notifId);

        if (!alreadyNotified) {
          await _addNotification(
            id: notifId,
            title: 'Alerta de Stock Bajo',
            body: 'Tienes poco stock de "${product.name}", ¡por favor reabastece!',
            type: 'low_stock',
          );
        }
      }

      await loadNotifications(); // Reload final sync list
    } catch (e) {
      debugPrint('Error checking low stock: $e');
    }
  }

  Future<void> checkPendingSales() async {
    try {
      _pendingSalesCount = await _db.getPendingSalesCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking pending sales: $e');
    }
  }

  Future<void> checkOverdueSales() async {
    try {
      final overdueSales = await _db.getOverdueSales();

      // Load current notifications to check duplicates
      await loadNotifications();

      for (var map in overdueSales) {
        final saleId = map['id'] as int;
        final customerName = map['entity_name'] as String? ?? 'Cliente';
        final totalAmount = (map['total_amount'] as num).toDouble();
        final amountPaid = (map['amount_paid'] as num?)?.toDouble() ?? 0.0;
        final pending = totalAmount - amountPaid;

        if (pending <= 0) continue;

        final notifId = 'overdue_sale_$saleId';
        final alreadyNotified = _notifications.any((n) => n.id == notifId);

        if (!alreadyNotified) {
          await _addNotification(
            id: notifId,
            title: 'Cobro Vencido',
            body: 'La venta #$saleId de $customerName tiene un saldo pendiente de Bs. ${pending.toStringAsFixed(2)} que ya venció.',
            type: 'overdue_payment',
          );
        }
      }

      // Refresh counts and notifications
      _pendingSalesCount = await _db.getPendingSalesCount();
      await loadNotifications();
    } catch (e) {
      debugPrint('Error checking overdue sales: $e');
    }
  }

  Future<void> _addNotification({
    String? id,
    required String title,
    required String body,
    String? type,
  }) async {
    final notification = AppNotification(
      id: id ?? const Uuid().v4(),
      title: title,
      body: body,
      date: DateTime.now(),
      type: type,
    );
    await _db.insertNotification(notification);
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final updated = _notifications[index].copyWith(isRead: true);
      await _db.updateNotification(updated);
      await loadNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      if (!n.isRead) {
        await _db.updateNotification(n.copyWith(isRead: true));
      }
    }
    await loadNotifications();
  }

  Future<void> removeNotification(String id) async {
    await _db.deleteNotification(id);
    await loadNotifications();
  }

  Future<void> clearAll() async {
    await _db.clearNotifications();
    await loadNotifications();
  }
}
