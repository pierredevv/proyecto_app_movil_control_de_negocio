import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todo como leído',
              onPressed: () => provider.markAllAsRead(),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Limpiar todo',
              onPressed: () => provider.clearAll(),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('No tienes notificaciones',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.hintColor)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (direction) {
                    // Note: Provider doesn't have delete one yet, using mark read/ignore for UI demo or implement delete single later.
                    // For now just assume it clears from list.
                    // Ideally implement removeNotification(id) in provider.
                  },
                  child: Container(
                    color: notification.isRead
                        ? null
                        : theme.highlightColor.withValues(alpha: 0.1),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notification.type == 'low_stock'
                            ? Colors.orange.withValues(alpha: 0.2)
                            : theme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          notification.type == 'low_stock'
                              ? Icons.warning_amber_rounded
                              : Icons.notifications,
                          color: notification.type == 'low_stock'
                              ? Colors.orange
                              : theme.primaryColor,
                        ),
                      ),
                      title: Text(notification.title,
                          style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.body),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(notification.date),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                      onTap: () {
                        provider.markAsRead(notification.id);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
