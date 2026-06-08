class RolePermission {
  final int? id;
  final int roleId;
  final String module;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const RolePermission({
    this.id,
    required this.roleId,
    required this.module,
    this.canView = false,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  RolePermission copyWith({
    int? id,
    int? roleId,
    String? module,
    bool? canView,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
  }) {
    return RolePermission(
      id: id ?? this.id,
      roleId: roleId ?? this.roleId,
      module: module ?? this.module,
      canView: canView ?? this.canView,
      canCreate: canCreate ?? this.canCreate,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role_id': roleId,
      'module': module,
      'can_view': canView ? 1 : 0,
      'can_create': canCreate ? 1 : 0,
      'can_edit': canEdit ? 1 : 0,
      'can_delete': canDelete ? 1 : 0,
    };
  }

  factory RolePermission.fromMap(Map<String, dynamic> map) {
    return RolePermission(
      id: map['id'] as int?,
      roleId: map['role_id'] as int,
      module: map['module'] as String,
      canView: (map['can_view'] as int? ?? 0) == 1,
      canCreate: (map['can_create'] as int? ?? 0) == 1,
      canEdit: (map['can_edit'] as int? ?? 0) == 1,
      canDelete: (map['can_delete'] as int? ?? 0) == 1,
    );
  }
}
