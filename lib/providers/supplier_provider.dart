import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SupplierProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  List<Supplier> get filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    final query = _searchQuery.toLowerCase();
    return _suppliers.where((s) {
      return s.name.toLowerCase().contains(query) ||
          (s.category != null && s.category!.toLowerCase().contains(query));
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadSuppliers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _suppliers = await _db.getSuppliers();
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    try {
      if (supplier.id != null) {
        await _db.updateSupplier(supplier);
      } else {
        await _db.insertSupplier(supplier);
      }
      await loadSuppliers();
    } catch (e) {
      debugPrint("Error adding/updating supplier: $e");
      rethrow;
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      await _db.deleteSupplier(id);
      await loadSuppliers();
    } catch (e) {
      debugPrint("Error deleting supplier: $e");
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
        debugPrint('Could not launch using tel scheme');
      }
    } catch (e) {
      debugPrint('Error launching phone call: $e');
    }
  }

  // WhatsApp sending logic moved to WhatsAppHelper
}
