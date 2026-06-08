import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

enum AuthState { initial, requiresOnboarding, requiresLogin, authenticated }

class AuthProvider extends ChangeNotifier {
  final DatabaseService _db;
  final AuthService _auth;

  AuthProvider({DatabaseService? db, AuthService? auth})
      : _db = db ?? DatabaseService(),
        _auth = auth ?? AuthService();

  AuthState _state = AuthState.initial;
  User? _currentUser;
  List<Role> _currentRoles = [];
  List<UserPermission> _currentPermissions = [];
  String? _lastError;

  AuthState get state => _state;
  User? get currentUser => _currentUser;
  List<Role> get currentRoles => _currentRoles;
  List<UserPermission> get currentPermissions => _currentPermissions;
  String? get lastError => _lastError;

  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isAdmin => _currentRoles.any((r) => r.name == 'admin');
  bool get isGerente => _currentRoles.any((r) => r.name == 'gerente');

  Future<void> initialize() async {
    await _db.seedDefaultRoles();
    final needsBootstrap = await _db.isBootstrapRequired();
    if (needsBootstrap) {
      _state = AuthState.requiresOnboarding;
    } else {
      final session = await _db.getActiveSession();
      if (session != null && session.userId != null) {
        final user = await _db.getUserById(session.userId!);
        if (user != null && user.isActive) {
          _currentUser = user;
          _currentRoles = await _db.getUserRoles(user.id!);
          _currentPermissions =
              await _db.getAggregatedUserPermissions(user.id!);
          _state = AuthState.authenticated;
          notifyListeners();
          return;
        }
        await _db.clearActiveSession();
      }
      _state = AuthState.requiresLogin;
    }
    notifyListeners();
  }

  Future<bool> completeOnboarding({
    required String username,
    required String displayName,
    required String pin,
  }) async {
    _lastError = null;
    try {
      await _auth.createAdminUser(
        username: username,
        displayName: displayName,
        pin: pin,
      );
      final result = await _auth.login(username, pin);
      if (result.success && result.user != null) {
        _currentUser = result.user;
        _currentRoles = await _db.getUserRoles(result.user!.id!);
        _currentPermissions =
            await _db.getAggregatedUserPermissions(result.user!.id!);
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      }
      _lastError = result.error;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String pin) async {
    _lastError = null;
    final result = await _auth.login(username, pin);
    if (result.success && result.user != null) {
      _currentUser = result.user;
      _currentRoles = await _db.getUserRoles(result.user!.id!);
      _currentPermissions =
          await _db.getAggregatedUserPermissions(result.user!.id!);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    }
    _lastError = result.error;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _auth.logout();
    _currentUser = null;
    _currentRoles = [];
    _currentPermissions = [];
    _state = AuthState.requiresLogin;
    notifyListeners();
  }

  void refreshFromDb() async {
    if (_currentUser == null) return;
    final user = await _db.getUserById(_currentUser!.id!);
    if (user == null) {
      await logout();
      return;
    }
    if (!user.isActive) {
      await logout();
      return;
    }
    _currentUser = user;
    _currentRoles = await _db.getUserRoles(user.id!);
    _currentPermissions = await _db.getAggregatedUserPermissions(user.id!);
    notifyListeners();
  }

  bool canView(String module) =>
      _currentPermissions.any((p) => p.module == module && p.canView);

  bool canCreate(String module) =>
      _currentPermissions.any((p) => p.module == module && p.canCreate);

  bool canEdit(String module) =>
      _currentPermissions.any((p) => p.module == module && p.canEdit);

  bool canDelete(String module) =>
      _currentPermissions.any((p) => p.module == module && p.canDelete);
}
