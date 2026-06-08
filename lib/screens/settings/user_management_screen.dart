import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pin_pad.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  List<Role> _roles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseService();
    final users = await db.getAllUsers();
    final roles = await db.getAllRoles();
    if (!mounted) return;
    setState(() {
      _users = users;
      _roles = roles;
      _loading = false;
    });
  }

  Future<void> _showUserDialog({User? user}) async {
    final isEdit = user != null;
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final displayNameCtrl = TextEditingController(text: user?.displayName ?? '');
    final selectedRoleIds = <int>{};
    if (isEdit) {
      final db = DatabaseService();
      final userRoles = await db.getUserRoles(user.id!);
      for (final r in userRoles) {
        selectedRoleIds.add(r.id!);
      }
    } else {
      selectedRoleIds.add(_roles.first.id!);
    }

    String newPin = '';
    String? pinError;
    int step = 0;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEdit ? 'Editar Usuario' : 'Nuevo Usuario',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (step == 0) ...[
                      TextField(
                        controller: usernameCtrl,
                        enabled: !isEdit,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          labelStyle:
                              TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: displayNameCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          labelStyle:
                              TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Roles',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _roles.map((r) {
                          final sel = selectedRoleIds.contains(r.id);
                          return FilterChip(
                            label: Text(r.displayName),
                            selected: sel,
                            onSelected: (v) {
                              setSheetState(() {
                                if (v) {
                                  selectedRoleIds.add(r.id!);
                                } else {
                                  selectedRoleIds.remove(r.id!);
                                }
                              });
                            },
                            selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                            backgroundColor: AppTheme.surfaceSlate,
                            labelStyle: TextStyle(
                              color: sel
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                            side: BorderSide(
                              color: sel
                                  ? AppTheme.primary
                                  : AppTheme.textTertiary,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          if (usernameCtrl.text.trim().isEmpty ||
                              displayNameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Completa todos los campos')),
                            );
                            return;
                          }
                          if (selectedRoleIds.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Selecciona al menos un rol')),
                            );
                            return;
                          }
                          setSheetState(() => step = 1);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isEdit ? 'Siguiente' : 'Siguiente'),
                      ),
                    ] else ...[
                      Text(
                        isEdit
                            ? 'Nuevo PIN para ${user.displayName}'
                            : 'Crea el PIN del usuario',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PinPad(
                        onChanged: (k) {
                          setSheetState(() {
                            pinError = null;
                            if (k == 'DEL') {
                              if (newPin.isNotEmpty) {
                                newPin = newPin.substring(0, newPin.length - 1);
                              }
                              return;
                            }
                            if (newPin.length < 6) {
                              newPin += k;
                            }
                          });
                        },
                        maxLength: 6,
                        filledLength: newPin.length,
                        errorText: pinError,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: newPin.length < 4
                            ? null
                            : () async {
                                final db = DatabaseService();
                                final auth = AuthService();
                                if (isEdit) {
                                  await auth.changePin(user.id!, newPin);
                                } else {
                                  final stored = auth.createPinHash(newPin);
                                  final parts = stored.split(':');
                                  final newUser = User(
                                    username: usernameCtrl.text
                                        .toLowerCase()
                                        .trim(),
                                    displayName:
                                        displayNameCtrl.text.trim(),
                                    pinHash: parts[1],
                                    salt: parts[0],
                                    createdAt: DateTime.now(),
                                  );
                                  await db.createUser(
                                      newUser, selectedRoleIds.toList());
                                }
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                await _load();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isEdit ? 'Guardar PIN' : 'Crear Usuario'),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          step = 0;
                          newPin = '';
                        }),
                        child: const Text('Volver'),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(User user) async {
    final db = DatabaseService();
    final adminCount = await db.countAdmins();
    final userRoles = await db.getUserRoles(user.id!);
    final isAdmin = userRoles.any((r) => r.name == 'admin');
    if (!mounted) return;
    if (isAdmin && adminCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No se puede eliminar el único administrador')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Eliminar Usuario',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '¿Eliminar a ${user.displayName}? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await db.deleteUser(user.id!);
    await _load();
  }

  Future<void> _toggleActive(User user) async {
    final db = DatabaseService();
    if (user.isActive) {
      final adminCount = await db.countAdmins();
      final userRoles = await db.getUserRoles(user.id!);
      final isAdmin = userRoles.any((r) => r.name == 'admin');
      if (isAdmin && adminCount <= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No se puede desactivar el único administrador')),
        );
        return;
      }
    }
    await db.setUserActive(user.id!, !user.isActive);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        title: const Text('Gestión de Usuarios'),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Text('No hay usuarios',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final u = _users[i];
                      return _UserCard(
                        user: u,
                        onEdit: () => _showUserDialog(user: u),
                        onDelete: () => _confirmDelete(u),
                        onToggleActive: () => _toggleActive(u),
                      );
                    },
                  ),
                ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.isActive
                ? AppTheme.primary
                : AppTheme.textTertiary,
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: user.isActive
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (!user.isActive)
                  const Text(
                    'Inactivo',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleActive,
            icon: Icon(
              user.isActive ? Icons.toggle_on : Icons.toggle_off,
              color:
                  user.isActive ? AppTheme.success : AppTheme.textTertiary,
              size: 32,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppTheme.textSecondary),
            color: AppTheme.surfaceSlate,
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}
