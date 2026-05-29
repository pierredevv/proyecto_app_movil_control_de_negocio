import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  String _errorMessage = '';

  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  // Summary Metrics
  double _totalSalesToday = 0.0;
  double _totalPurchasesToday = 0.0;
  double _cashInToday = 0.0;
  double _cashOutToday = 0.0;
  double _netBalance = 0.0;

  double get totalSalesToday => _totalSalesToday;
  double get totalPurchasesToday => _totalPurchasesToday;
  double get cashInToday => _cashInToday;
  double get cashOutToday => _cashOutToday;
  double get netBalance => _netBalance;


  // Recent Activity
  List<Transaction> _recentTransactions = [];
  List<Transaction> get recentTransactions => _recentTransactions;

  // Chart Data
  List<Map<String, dynamic>> _weeklySales = [];
  List<Map<String, dynamic>> get weeklySales => _weeklySales;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      // 1. Load today's summary
      final summary = await _db.getTodaySummary();
      _totalSalesToday = summary['accrual_sales'] ?? 0.0;
      _totalPurchasesToday = summary['accrual_purchases'] ?? 0.0;
      _cashInToday = summary['cash_in'] ?? 0.0;
      _cashOutToday = summary['cash_out'] ?? 0.0;
      _netBalance = summary['net_cash_balance'] ?? 0.0;

      // 2. Load recent transactions
      _recentTransactions = await _db.getRecentTransactions(limit: 5);

      // 3. Load chart data
      _weeklySales = await _db.getWeeklySales();
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      debugPrint('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(String description, double amount, {int? categoryId}) async {
    try {
      await _db.insertExpense(description, amount, categoryId: categoryId);
      await loadDashboardData(); // Refresh summary
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }
}
