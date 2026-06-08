import 'package:flutter/material.dart';
import 'currency_helper.dart';
// Centralized validators for the entire application
class InputValidators {
  // Validation of positive decimal numbers
  static String? validatePositiveDecimal(String? value,
      {String fieldName = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }

    final number = double.tryParse(value.trim());
    if (number == null) {
      return 'Ingrese un número válido';
    }

    if (number <= 0) {
      return '$fieldName debe ser mayor a 0';
    }

    return null;
  }

  // Validation of positive integers
  static String? validatePositiveInteger(String? value,
      {String fieldName = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }

    final number = int.tryParse(value.trim());
    if (number == null) {
      return 'Ingrese un número entero válido';
    }

    if (number < 0) {
      return '$fieldName no puede ser negativo';
    }

    return null;
  }

  // Price vs. cost validation
  static String? validatePriceVsCost(String? priceStr, String? costStr) {
    if (priceStr == null || priceStr.isEmpty) return null;
    if (costStr == null || costStr.isEmpty) return null;

    final price = double.tryParse(priceStr);
    final cost = double.tryParse(costStr);

    if (price == null || cost == null) return null;

    if (price < cost) {
      return '⚠️ El precio de venta es menor al costo. Tendrás pérdidas.';
    }

    return null;
  }

  // Validation of available stock
  static String? validateStockAvailability(
      String? quantityStr, double availableStock,
      {String productName = 'producto'}) {
    if (quantityStr == null || quantityStr.trim().isEmpty) {
      return 'Ingrese una cantidad';
    }

    final quantity = double.tryParse(quantityStr.trim());
    if (quantity == null) {
      return 'Ingrese un número válido';
    }

    if (quantity <= 0) {
      return 'La cantidad debe ser mayor a 0';
    }

    if (quantity > availableStock) {
      return 'Stock insuficiente. Disponible: $availableStock';
    }

    return null;
  }

  // Name validation (not empty, no dangerous special characters)
  static String? validateName(String? value, {String fieldName = 'Nombre'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }

    if (value.trim().length < 2) {
      return '$fieldName debe tener al menos 2 caracteres';
    }

    if (value.trim().length > 100) {
      return '$fieldName es demasiado largo (máx. 100 caracteres)';
    }

    return null;
  }

  // Bolivian phone number validation
  static String? validateBolivianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }

    // Remove spaces, hyphens, parentheses
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Bolivian format: 8 digits or +591 + 8 digits
    if (cleaned.length == 8 && RegExp(r'^\d{8}$').hasMatch(cleaned)) {
      return null; // Valid
    }

    if (cleaned.startsWith('591') && cleaned.length == 11) {
      return null; // Valid with country code
    }

    if (cleaned.startsWith('+591') && cleaned.length == 12) {
      return null; // Valid with +
    }

    return 'Formato inválido. Ej: 70123456 o +59170123456';
  }

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Email inválido';
    }

    return null;
  }

  // Barcode validation (allow numbers and letters)
  static String? validateBarcode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }

    if (value.trim().length < 4) {
      return 'Código muy corto (mín. 4 caracteres)';
    }

    if (value.trim().length > 50) {
      return 'Código muy largo (máx. 50 caracteres)';
    }

    return null;
  }

  // Payment amount validation vs debt
  static String? validatePaymentAmount(String? amountStr, double totalDebt) {
    if (amountStr == null || amountStr.trim().isEmpty) {
      return 'Ingrese el monto del pago';
    }

    final amount = double.tryParse(amountStr.trim());
    if (amount == null) {
      return 'Ingrese un monto válido';
    }

    if (amount <= 0) {
      return 'El monto debe ser mayor a 0';
    }

    if (amount > totalDebt) {
      return '⚠️ El monto excede la deuda total (${CurrencyHelper.simple(totalDebt)})';
    }

    return null;
  }

  // Sanitize input (prevent injections)
  static String sanitizeInput(String input) {
    // Remove dangerous characters but keep accents and ñ
    return input.replaceAll(RegExp(r'[<>{}[\]\\]'), '').trim();
  }

  // Show error in UI
  static void showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // Show warning in UI
  static void showValidationWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
