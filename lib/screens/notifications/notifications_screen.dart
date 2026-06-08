import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: AppTheme.blueIcon),
              tooltip: 'Marcar todo como leído',
              onPressed: () => provider.markAllAsRead(),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: AppTheme.redAccent),
              tooltip: 'Limpiar todo',
              onPressed: () => provider.clearAll(),
            ),
        ],
      ),
      body: BoundedDesktopWrapper(child: Stack(
        children: [
          // Background Blobs (Soft ambient lighting)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.blueIcon.withValues(alpha: isDark ? 0.08 : 0.03),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blueIcon.withValues(alpha: isDark ? 0.15 : 0.05),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes notificaciones',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isLowStock = notification.type == 'low_stock';
                      final colorAccent = isLowStock ? const Color(0xFFF59F00) : AppTheme.blueIcon;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: notification.isRead
                              ? theme.cardColor.withValues(alpha: 0.5)
                              : colorAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: notification.isRead
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                                : colorAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Dismissible(
                              key: Key(notification.id),
                              background: Container(
                                color: AppTheme.redAccent.withValues(alpha: 0.8),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                provider.removeNotification(notification.id);
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorAccent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isLowStock ? Icons.warning_amber_rounded : Icons.notifications_none,
                                    color: colorAccent,
                                  ),
                                ),
                                title: Text(
                                  notification.title,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.body,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(notification.date),
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => provider.markAsRead(notification.id),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),),
    );
  }
}
