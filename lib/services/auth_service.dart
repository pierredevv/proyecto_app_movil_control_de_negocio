import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/user.dart';
import 'database_service.dart';

class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  const AuthResult({required this.success, this.user, this.error});
}

class AuthService {
  final DatabaseService _db;

  AuthService({DatabaseService? db}) : _db = db ?? DatabaseService();

  String generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  String createPinHash(String pin) {
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    return '$salt:$hash';
  }

  bool verifyPinHash(String pin, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salt = parts[0];
    final expected = parts[1];
    final actual = hashPin(pin, salt);
    return actual == expected;
  }

  Future<int> createAdminUser({
    required String username,
    required String displayName,
    required String pin,
  }) async {
    if (pin.length < 4 || pin.length > 6) {
      throw ArgumentError('PIN must be 4-6 digits');
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain only digits');
    }

    final stored = createPinHash(pin);
    final parts = stored.split(':');
    final salt = parts[0];
    final hash = parts[1];

    final user = User(
      username: username.toLowerCase().trim(),
      displayName: displayName.trim(),
      pinHash: hash,
      salt: salt,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final allRoles = await _db.getAllRoles();
    if (allRoles.isEmpty) {
      throw StateError('Roles not seeded. Call seedDefaultRoles() first.');
    }
    final adminRole = allRoles.firstWhere(
      (r) => r.name == 'admin',
      orElse: () => allRoles.first,
    );

    return await _db.createUser(user, [adminRole.id!]);
  }

  Future<AuthResult> login(String username, String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      return const AuthResult(success: false, error: 'PIN inválido');
    }
    final user = await _db.getUserByUsername(username.toLowerCase().trim());
    if (user == null) {
      return const AuthResult(success: false, error: 'Usuario no encontrado');
    }
    if (!user.isActive) {
      return const AuthResult(success: false, error: 'Usuario inactivo');
    }
    final stored = '${user.salt}:${user.pinHash}';
    if (!verifyPinHash(pin, stored)) {
      return const AuthResult(success: false, error: 'PIN incorrecto');
    }
    await _db.updateUserLastLogin(user.id!);
    await _db.startActiveSession(user.id!);
    return AuthResult(success: true, user: user);
  }

  Future<AuthResult> changePin(int userId, String newPin) async {
    if (newPin.length < 4 || newPin.length > 6) {
      return const AuthResult(success: false, error: 'PIN debe tener 4-6 dígitos');
    }
    if (!RegExp(r'^\d+$').hasMatch(newPin)) {
      return const AuthResult(success: false, error: 'PIN solo dígitos');
    }
    final stored = createPinHash(newPin);
    final parts = stored.split(':');
    await _db.updateUserPin(userId, parts[1], parts[0]);
    return const AuthResult(success: true);
  }

  Future<void> logout() async {
    await _db.clearActiveSession();
  }
}
