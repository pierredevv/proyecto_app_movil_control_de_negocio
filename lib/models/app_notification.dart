class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool isRead;
  final String? type; // 'low_stock', etc

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
    this.type,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      date: date,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }
}
