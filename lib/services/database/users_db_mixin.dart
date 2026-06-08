part of '../database_service.dart';

mixin UsersDb on CoreDb {
  static const List<String> _modules = [
    'ventas',
    'compras',
    'pedidos',
    'clientes',
    'proveedores',
    'inventario',
    'reportes',
    'gastos',
    'caja',
    'configuracion',
  ];

  Future<void> _seedDefaultRolePermissions() async {
    final db = await database;
    final existingRoles = await db.query('roles');
    if (existingRoles.isEmpty) return;

    final adminRole = existingRoles.firstWhere(
      (r) => r['name'] == 'admin',
      orElse: () => existingRoles.first,
    );
    final adminRoleId = adminRole['id'] as int;

    final existingPerms = await db.query(
      'role_permissions',
      where: 'role_id = ?',
      whereArgs: [adminRoleId],
    );
    if (existingPerms.isNotEmpty) return;

    for (final module in _modules) {
      await db.insert('role_permissions', {
        'role_id': adminRoleId,
        'module': module,
        'can_view': 1,
        'can_create': 1,
        'can_edit': 1,
        'can_delete': 1,
      });
    }
  }

  Future<void> seedDefaultRoles() async {
    final db = await database;
    final existing = await db.query('roles');
    if (existing.isNotEmpty) return;

    await db.insert('roles', {
      'name': 'admin',
      'display_name': 'Administrador',
      'description': 'Acceso completo al sistema',
      'is_system': 1,
    });
    await db.insert('roles', {
      'name': 'gerente',
      'display_name': 'Gerente',
      'description': 'Acceso a ventas, reportes y configuración',
      'is_system': 1,
    });
    await db.insert('roles', {
      'name': 'cajero',
      'display_name': 'Cajero',
      'description': 'Acceso a ventas y caja',
      'is_system': 1,
    });
    await db.insert('roles', {
      'name': 'vendedor',
      'display_name': 'Vendedor',
      'description': 'Acceso solo a ventas y clientes',
      'is_system': 1,
    });

    await _seedDefaultRolePermissions();

    final allRoles = await db.query('roles');
    final gerente = allRoles.firstWhere((r) => r['name'] == 'gerente');
    final cajero = allRoles.firstWhere((r) => r['name'] == 'cajero');
    final vendedor = allRoles.firstWhere((r) => r['name'] == 'vendedor');

    for (final module in _modules) {
      if (module == 'configuracion') {
        await db.insert('role_permissions', {
          'role_id': gerente['id'],
          'module': module,
          'can_view': 1,
          'can_edit': 1,
        });
      } else {
        await db.insert('role_permissions', {
          'role_id': gerente['id'],
          'module': module,
          'can_view': 1,
          'can_create': 1,
          'can_edit': 1,
          'can_delete': 1,
        });
      }
    }

    for (final module in _modules) {
      final canDelete = (module == 'ventas' || module == 'gastos') ? 1 : 0;
      await db.insert('role_permissions', {
        'role_id': cajero['id'],
        'module': module,
        'can_view': 1,
        'can_create': 1,
        'can_edit': 1,
        'can_delete': canDelete,
      });
    }

    for (final module in _modules) {
      if (module == 'ventas' || module == 'clientes') {
        await db.insert('role_permissions', {
          'role_id': vendedor['id'],
          'module': module,
          'can_view': 1,
          'can_create': 1,
          'can_edit': 1,
        });
      }
    }
  }

  Future<int> createUser(User user, List<int> roleIds) async {
    final db = await database;
    return await db.transaction((txn) async {
      final userId = await txn.insert('users', user.toMap());
      for (final roleId in roleIds) {
        await txn.insert('user_roles', {
          'user_id': userId,
          'role_id': roleId,
        });
      }
      return userId;
    });
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final rows = await db.query(
      'users',
      orderBy: 'display_name ASC',
    );
    return rows.map((r) => User.fromMap(r)).toList();
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<List<Role>> getUserRoles(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.* FROM roles r
      INNER JOIN user_roles ur ON ur.role_id = r.id
      WHERE ur.user_id = ?
      ORDER BY r.display_name ASC
    ''', [userId]);
    return rows.map((r) => Role.fromMap(r)).toList();
  }

  Future<List<Role>> getAllRoles() async {
    final db = await database;
    final rows = await db.query('roles', orderBy: 'display_name ASC');
    return rows.map((r) => Role.fromMap(r)).toList();
  }

  Future<List<RolePermission>> getRolePermissions(int roleId) async {
    final db = await database;
    final rows = await db.query(
      'role_permissions',
      where: 'role_id = ?',
      whereArgs: [roleId],
    );
    return rows.map((r) => RolePermission.fromMap(r)).toList();
  }

  Future<List<RolePermission>> getUserPermissions(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT rp.* FROM role_permissions rp
      INNER JOIN user_roles ur ON ur.role_id = rp.role_id
      WHERE ur.user_id = ?
    ''', [userId]);
    return rows.map((r) => RolePermission.fromMap(r)).toList();
  }

  Future<List<UserPermission>> getAggregatedUserPermissions(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        rp.module,
        MAX(rp.can_view) AS can_view,
        MAX(rp.can_create) AS can_create,
        MAX(rp.can_edit) AS can_edit,
        MAX(rp.can_delete) AS can_delete
      FROM role_permissions rp
      INNER JOIN user_roles ur ON ur.role_id = rp.role_id
      WHERE ur.user_id = ?
      GROUP BY rp.module
    ''', [userId]);
    return rows.map((r) => UserPermission(
          module: r['module'] as String,
          canView: (r['can_view'] as int? ?? 0) == 1,
          canCreate: (r['can_create'] as int? ?? 0) == 1,
          canEdit: (r['can_edit'] as int? ?? 0) == 1,
          canDelete: (r['can_delete'] as int? ?? 0) == 1,
        )).toList();
  }

  Future<void> updateUserRoles(int userId, List<int> roleIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('user_roles', where: 'user_id = ?', whereArgs: [userId]);
      for (final roleId in roleIds) {
        await txn.insert('user_roles', {
          'user_id': userId,
          'role_id': roleId,
        });
      }
    });
  }

  Future<void> updateUserPin(int userId, String pinHash, String salt) async {
    final db = await database;
    await db.update(
      'users',
      {'pin_hash': pinHash, 'salt': salt},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateUserLastLogin(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'last_login': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> setUserActive(int userId, bool isActive) async {
    final db = await database;
    await db.update(
      'users',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  Future<int> countUsers() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM users');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> countAdmins() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT ur.user_id) AS c
      FROM user_roles ur
      INNER JOIN roles r ON r.id = ur.role_id
      WHERE r.name = 'admin'
    ''');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<bool> isBootstrapRequired() async {
    return (await countUsers()) == 0;
  }

  Future<ActiveSession?> getActiveSession() async {
    final db = await database;
    final rows = await db.query(
      'active_session',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ActiveSession.fromMap(rows.first);
  }

  Future<void> startActiveSession(int userId) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(
      'active_session',
      {
        'id': 1,
        'user_id': userId,
        'logged_in_at': now.millisecondsSinceEpoch,
        'last_activity_at': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLastActivity() async {
    final db = await database;
    await db.update(
      'active_session',
      {'last_activity_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> clearActiveSession() async {
    final db = await database;
    await db.delete('active_session', where: 'id = ?', whereArgs: [1]);
  }
}

class UserPermission {
  final String module;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const UserPermission({
    required this.module,
    this.canView = false,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
  });
}
