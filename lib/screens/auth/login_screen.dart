import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pin_pad.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  User? _selectedUser;
  String _pin = '';
  String? _error;
  bool _loadingUsers = true;
  bool _submitting = false;
  List<User> _users = [];
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final db = DatabaseService();
    final all = await db.getAllUsers();
    final active = all.where((u) => u.isActive).toList();
    if (!mounted) return;
    setState(() {
      _users = active;
      _selectedUser = active.isNotEmpty ? active.first : null;
      _loadingUsers = false;
    });
  }

  void _onPinKey(String key) {
    if (_selectedUser == null) return;

    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final secondsLeft = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _error = 'Demasiados intentos. Intente en $secondsLeft s');
      return;
    } else {
      _lockoutUntil = null;
    }

    setState(() {
      _error = null;
      if (key == 'DEL') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (key == 'OK') {
        if (_pin.length >= 4) {
          _submit();
        } else {
          _error = 'El PIN debe tener al menos 4 dígitos';
        }
        return;
      }
      if (_pin.length < 6) {
        _pin += key;
        if (_pin.length == 6) {
          _submit();
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedUser == null) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_selectedUser!.username, _pin);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!ok) {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
          _error = 'Demasiados intentos. Intente en 30 s';
          _failedAttempts = 0;
        } else {
          _error = auth.lastError ?? 'PIN incorrecto';
        }
        _pin = '';
      } else {
        _failedAttempts = 0;
        _lockoutUntil = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: SafeArea(
        child: _loadingUsers
            ? const Center(child: CircularProgressIndicator())
            : _buildLogin(),
      ),
    );
  }

  Widget _buildLogin() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.store, size: 64, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_users.length > 1)
                    DropdownButtonFormField<User>(
                      isExpanded: true,
                      initialValue: _selectedUser,
                      dropdownColor: AppTheme.cardDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        prefixIcon:
                            const Icon(Icons.person, color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.cardDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _users
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(
                                  u.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (u) {
                        setState(() {
                          _selectedUser = u;
                          _pin = '';
                          _error = null;
                        });
                      },
                    )
                  else if (_users.length == 1)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppTheme.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _users.first.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  PinPad(
                    onChanged: _onPinKey,
                    maxLength: 6,
                    filledLength: _pin.length,
                    errorText: _error,
                  ),
                  if (_submitting)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
