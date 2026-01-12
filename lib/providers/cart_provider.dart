import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/invoice_item.dart';
import '../models/transaction_model.dart';
import '../models/customer.dart';
import '../services/database_service.dart';

class CartProvider extends ChangeNotifier {
  final List<InvoiceItem> _items = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;

  List<InvoiceItem> get items => List.unmodifiable(_items);
  Customer? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;

  double get total => _items.fold(0, (sum, item) => sum + item.subtotal);

  void setCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void addToCart(Product product) {
    // Check if already in cart
    final index = _items.indexWhere((item) => item.productId == product.id);

    // Check available stock (current stock - quantity in cart)
    final currentInCart = index != -1 ? _items[index].quantity : 0.0;

    if (currentInCart + 1 > product.stock) {
      throw Exception('Stock insuficiente. Disponible: ${product.stock}');
    }

    if (index != -1) {
      // Increment
      final existing = _items[index];
      _items[index] = existing.copyWith(
        quantity: existing.quantity + 1,
        subtotal: (existing.quantity + 1) * existing.unitPrice,
      );
    } else {
      // Add new
      _items.add(InvoiceItem(
        productId: product.id!,
        productName: product.name,
        quantity: 1,
        unitPrice: product.price,
        subtotal: product.price,
      ));
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, double newQuantity, double maxStock) {
    if (newQuantity <= 0) {
      removeFromCart(index);
      return;
    }

    if (newQuantity > maxStock) {
      throw Exception('Stock insuficiente. Máximo: $maxStock');
    }

    final item = _items[index];
    _items[index] = item.copyWith(
      quantity: newQuantity,
      subtotal: newQuantity * item.unitPrice,
    );
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _selectedCustomer = null;
    notifyListeners();
  }

  Future<Sale> checkout(DatabaseService db) async {
    if (_items.isEmpty) throw Exception('El carrito está vacío');

    _isLoading = true;
    notifyListeners();

    try {
      final sale = Sale(
        date: DateTime.now(),
        totalAmount: total,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        items: List.from(_items),
        status: 'COMPLETED',
      );

      final id = await db.insertSale(sale);
      final completedSale = sale.copyWith(id: id);

      clearCart();
      return completedSale;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
