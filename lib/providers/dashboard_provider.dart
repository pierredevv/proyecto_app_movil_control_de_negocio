import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Summary Metrics
  double _totalSalesToday = 0.0;
  double _totalPurchasesToday = 0.0;
  double _netBalance = 0.0;
  // TODO: Add low stock count integration from InventoryProvider if needed here

  double get totalSalesToday => _totalSalesToday;
  double get totalPurchasesToday => _totalPurchasesToday;
  double get netBalance => _netBalance;

  // Recent Activity
  List<Transaction> _recentTransactions = [];
  List<Transaction> get recentTransactions => _recentTransactions;

  // Chart Data
  List<Map<String, dynamic>> _weeklySales = [];
  List<Map<String, dynamic>> get weeklySales => _weeklySales;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load today's summary
      final summary = await _db.getTodaySummary();
      _totalSalesToday = summary['sales'] ?? 0.0;
      _totalPurchasesToday = summary['purchases'] ?? 0.0;
      _netBalance = summary['balance'] ?? 0.0;

      // 2. Load recent transactions
      _recentTransactions = await _db.getRecentTransactions(limit: 5);

      // 3. Load chart data
      _weeklySales = await _db.getWeeklySales();
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(String description, double amount) async {
    try {
      await _db.insertExpense(description, amount);
      await loadDashboardData(); // Refresh summary
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  void refresh() {
    loadDashboardData();
  }
}
