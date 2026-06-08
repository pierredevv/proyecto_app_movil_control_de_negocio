import 'package:flutter/material.dart';
import '../models/cash_register.dart';
import '../services/database_service.dart';

class CashRegisterProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  CashRegister? _activeRegister;
  CashRegister? get activeRegister => _activeRegister;
  bool get hasActiveRegister => _activeRegister != null;

  List<CashRegister> _history = [];
  List<CashRegister> get history => _history;

  Map<String, dynamic> _currentSessionSummary = {};
  Map<String, dynamic> get currentSessionSummary => _currentSessionSummary;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> checkActiveSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeRegister = await _db.getOpenRegister();
      if (_activeRegister != null) {
        await loadSessionSummary();
      }
    } catch (e) {
      debugPrint('Error checking active cash register: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSessionSummary() async {
    if (_activeRegister == null) return;
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _currentSessionSummary = await _db.getRegisterSessionSummary(
        _activeRegister!.openDate.millisecondsSinceEpoch,
        nowMs,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cash register session summary: $e');
    }
  }

  Future<void> openSession(double openingBalance, {int? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.openRegister(openingBalance, userId: userId);
      await checkActiveSession();
    } catch (e) {
      debugPrint('Error opening cash register session: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> closeSession(double closingBalance, String? notes) async {
    if (_activeRegister == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      await loadSessionSummary(); // Refresh summary before close
      final expected = _activeRegister!.openingBalance +
          (_currentSessionSummary['net_cash'] as double? ?? 0.0);
      
      await _db.closeRegister(
        _activeRegister!.id!,
        closingBalance,
        expected,
        notes,
      );
      _activeRegister = null;
      _currentSessionSummary = {};
      await loadHistory();
    } catch (e) {
      debugPrint('Error closing cash register session: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({int limit = 30}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _history = await _db.getRegisterHistory(limit: limit);
    } catch (e) {
      debugPrint('Error loading cash register history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
