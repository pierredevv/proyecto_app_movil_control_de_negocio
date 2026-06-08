class ActiveSession {
  final int id;
  final int? userId;
  final DateTime loggedInAt;
  final DateTime? lastActivityAt;

  const ActiveSession({
    this.id = 1,
    this.userId,
    required this.loggedInAt,
    this.lastActivityAt,
  });

  ActiveSession copyWith({
    int? id,
    int? userId,
    DateTime? loggedInAt,
    DateTime? lastActivityAt,
  }) {
    return ActiveSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      loggedInAt: loggedInAt ?? this.loggedInAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'logged_in_at': loggedInAt.millisecondsSinceEpoch,
      'last_activity_at': lastActivityAt?.millisecondsSinceEpoch,
    };
  }

  factory ActiveSession.fromMap(Map<String, dynamic> map) {
    return ActiveSession(
      id: map['id'] as int? ?? 1,
      userId: map['user_id'] as int?,
      loggedInAt: DateTime.fromMillisecondsSinceEpoch(
        map['logged_in_at'] as int,
      ),
      lastActivityAt: map['last_activity_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['last_activity_at'] as int,
            )
          : null,
    );
  }
}
