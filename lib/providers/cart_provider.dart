import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale_unit_option.dart';
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

  // NUEVO: Agregado parametro 'option' y 'qty'
  void addToCart(Product product,
      {required SaleUnitOption option, double qty = 1.0}) {
    // Check si ya existe con la misma presentación (saleUnit + unitsPerSaleUnit)
    final index = _items.indexWhere((item) =>
        item.productId == product.id &&
        item.saleUnit == option.unitCode &&
        item.unitsPerSaleUnit == option.unitsPerSaleUnit);

    // Calc base units in cart para *todo* este producto (sumando todas las presentaciones)
    final totalBaseUnitsInCart = _items
        .where((item) => item.productId == product.id)
        .fold(0.0, (sum, item) => sum + item.baseUnitsTotal);

    // Calc de nuevas base units a agregar
    final newBaseUnitsRequested = qty * option.unitsPerSaleUnit;

    // Validación general de Stock usando UNIDADES BASE
    if (totalBaseUnitsInCart + newBaseUnitsRequested > product.stock) {
      final freeBaseUnits = product.stock - totalBaseUnitsInCart;
      final availableSaleUnits = freeBaseUnits > 0 ? freeBaseUnits / option.unitsPerSaleUnit : 0.0;
      throw Exception(
          'Stock insuficiente. Disponible: ${availableSaleUnits.toStringAsFixed(1)} ${option.unitCode}');
    }

    if (index != -1) {
      // Incrementar cantidad de misma presentación
      final existing = _items[index];
      final newQuantity = existing.quantity + qty;
      _items[index] = existing.copyWith(
        quantity: newQuantity,
        subtotal: newQuantity * existing.unitPrice,
      );
    } else {
      // Agregar nueva línea de producto
      _items.add(InvoiceItem(
        productId: product.id!,
        productName: product.name,
        quantity: qty,
        unitPrice: option.price,
        subtotal: qty * option.price,
        maxBaseStock: product.stock,
        saleUnit: option.unitCode,
        unitsPerSaleUnit: option.unitsPerSaleUnit,
        packagingInfo: option.unitCode == 'UNI'
            ? ''
            : product.packagingInfo, // Copiar solo si no es unidad simple
      ));
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  // UPDATED: Cambiando maxStock referenciándolo a baseUnits
  void updateQuantity(int index, double newQuantity, double maxBaseStock) {
    if (newQuantity <= 0) {
      removeFromCart(index);
      return;
    }

    final targetItem = _items[index];
    final baseUnitsRequested = newQuantity * targetItem.unitsPerSaleUnit;

    // Sum other entries of this exact product already sitting in the active cart
    final otherBaseUnitsInCart = _items
        .where((item) => item.productId == targetItem.productId && item != targetItem)
        .fold(0.0, (sum, item) => sum + item.baseUnitsTotal);

    // Validate using Base Units metrics cumulatively
    final effectiveMaxStock = targetItem.maxBaseStock ?? maxBaseStock;
    if (baseUnitsRequested + otherBaseUnitsInCart > effectiveMaxStock) {
      final freeBaseUnits = effectiveMaxStock - otherBaseUnitsInCart;
      final maxAvailableOptionUnits = freeBaseUnits > 0 ? freeBaseUnits / targetItem.unitsPerSaleUnit : 0.0;
      throw Exception(
          'Stock insuficiente. Disponible: ${maxAvailableOptionUnits.toStringAsFixed(1)} ${targetItem.saleUnit}');
    }

    _items[index] = targetItem.copyWith(
      quantity: newQuantity,
      subtotal: newQuantity * targetItem.unitPrice,
    );
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _selectedCustomer = null;
    notifyListeners();
  }

  Future<Sale> checkout(DatabaseService db,
      {bool autoClear = true,
      double? amountReceived,
      DateTime? paymentDueDate,
      String paymentMethod = 'EFECTIVO'}) async {
    if (_items.isEmpty) throw Exception('El carrito está vacío');

    _isLoading = true;
    notifyListeners();

    try {
      final saleTotal = total;
      final received = amountReceived ?? saleTotal;
      final String saleStatus = received >= saleTotal - 0.01
          ? 'COMPLETED'
          : received > 0
              ? 'PARTIAL'
              : 'CREDIT';

      final sale = Sale(
        date: DateTime.now(),
        totalAmount: saleTotal,
        amountPaid: received,
        paymentDueDate: paymentDueDate,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        items: List.from(_items),
        status: saleStatus,
      );

      final id = await db.insertSale(sale, paymentMethod: paymentMethod);
      final completedSale = sale.copyWith(id: id);

      if (autoClear) {
        clearCart();
      }
      return completedSale;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
