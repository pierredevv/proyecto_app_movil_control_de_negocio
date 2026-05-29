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

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: (map['body'] as String?) ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      isRead: (map['is_read'] as int) == 1,
      type: map['type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead ? 1 : 0,
      'created_at': date.millisecondsSinceEpoch,
    };
  }
}
