import 'package:intl/intl.dart';

/// Centralized currency formatting utility.
///
/// Replaces hardcoded 'Bs. ' strings throughout the codebase with a single
/// source of truth. If the currency symbol or locale needs to change in the
/// future, only this file needs to be updated.
class CurrencyHelper {
  CurrencyHelper._();

  static String _symbol = 'Bs.';
  static String _locale = 'es_BO';
  static NumberFormat _formatter = NumberFormat.currency(
    symbol: '$_symbol ',
    decimalDigits: 2,
    locale: _locale,
  );

  /// The currency symbol used throughout the application.
  static String get symbol => _symbol;

  /// The locale used for number formatting.
  static String get locale => _locale;

  /// Pre-built [NumberFormat] for currency values.
  ///
  /// Usage: `CurrencyHelper.formatter.format(1234.56)` → `'Bs. 1.234,56'`
  static NumberFormat get formatter => _formatter;

  /// Dynamic configuration updates when BusinessProfile is loaded or saved.
  static void updateConfig({required String symbol, required String locale}) {
    _symbol = symbol;
    _locale = locale;
    _formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 2,
      locale: locale,
    );
  }

  /// Shorthand for formatting a numeric value as currency.
  ///
  /// Usage: `CurrencyHelper.format(1234.56)` → `'Bs. 1.234,56'`
  static String format(num value) => _formatter.format(value);

  /// Formats a value with a simple fixed-decimal representation.
  ///
  /// Usage: `CurrencyHelper.simple(9.5)` → `'Bs. 9.50'`
  ///
  /// Unlike [format], this does NOT apply locale-aware thousand separators.
  /// Use this for inline text where locale formatting would look out of place
  /// (e.g., receipt line items, WhatsApp messages).
  static String simple(num value) =>
      '$_symbol ${value.toStringAsFixed(2)}';
}
