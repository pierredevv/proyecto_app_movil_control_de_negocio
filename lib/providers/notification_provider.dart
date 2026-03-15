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

  Future<void> checkLowStock() async {
    try {
      final profile = await SettingsService.getProfile();
      if (!profile.lowStockAlertsEnabled) return;

      final products = await _db.getProducts();
      final lowStockProducts = products
          .where((p) => p.minStock > 0 && p.stockInSaleUnits <= p.minStock)
          .toList();

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
      _pendingSalesCount = await _db.getPendingSalesCount();
      final overdueSales = await _db.getOverdueSales();

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
          _addNotification(
            id: notifId,
            title: 'Cobro Vencido',
            body:
                'La venta #$saleId de $customerName tiene un saldo pendiente de Bs. ${pending.toStringAsFixed(2)} que ya venció.',
            type: 'overdue_payment',
          );
        }
      }

      // Also refresh count whenever we check overdue
      _pendingSalesCount = await _db.getPendingSalesCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking overdue sales: $e');
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
