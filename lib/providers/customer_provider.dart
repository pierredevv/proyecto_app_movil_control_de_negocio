import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  List<Customer> get filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    final query = _searchQuery.toLowerCase();
    return _customers.where((c) {
      return c.name.toLowerCase().contains(query) ||
          (c.phone != null && c.phone!.contains(query));
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _customers = await _db.getCustomers();
    } catch (e) {
      debugPrint("Error loading customers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      if (customer.id != null) {
        await _db.updateCustomer(customer);
      } else {
        await _db.insertCustomer(customer);
      }
      await loadCustomers();
    } catch (e) {
      debugPrint("Error adding/updating customer: $e");
      rethrow;
    }
  }

  Future<void> addPayment(int customerId, double amount) async {
    try {
      await _db.insertPayment(customerId, amount);
      await loadCustomers();
    } catch (e) {
      debugPrint("Error adding payment: $e");
      rethrow;
    }
  }

  Future<void> deleteCustomer(int id) async {
    try {
      await _db.deleteCustomer(id);
      await loadCustomers();
    } catch (e) {
      debugPrint("Error deleting customer: $e");
      rethrow;
    }
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint('Could not launch $launchUri');
      }
    } catch (e) {
      debugPrint('Error launching phone call: $e');
    }
  }
}
