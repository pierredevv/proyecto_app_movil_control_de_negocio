class Role {
  final int? id;
  final String name;
  final String displayName;
  final String? description;
  final bool isSystem;

  const Role({
    this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.isSystem = true,
  });

  Role copyWith({
    int? id,
    String? name,
    String? displayName,
    String? description,
    bool? isSystem,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'is_system': isSystem ? 1 : 0,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'] as int?,
      name: map['name'] as String,
      displayName: map['display_name'] as String,
      description: map['description'] as String?,
      isSystem: (map['is_system'] as int? ?? 1) == 1,
    );
  }
}
