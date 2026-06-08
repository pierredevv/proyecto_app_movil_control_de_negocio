class User {
  final int? id;
  final String username;
  final String displayName;
  final String pinHash;
  final String salt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const User({
    this.id,
    required this.username,
    required this.displayName,
    required this.pinHash,
    required this.salt,
    this.isActive = true,
    required this.createdAt,
    this.lastLogin,
  });

  User copyWith({
    int? id,
    String? username,
    String? displayName,
    String? pinHash,
    String? salt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      pinHash: pinHash ?? this.pinHash,
      salt: salt ?? this.salt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'pin_hash': pinHash,
      'salt': salt,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_login': lastLogin?.millisecondsSinceEpoch,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      pinHash: map['pin_hash'] as String,
      salt: map['salt'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      lastLogin: map['last_login'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login'] as int)
          : null,
    );
  }
}
