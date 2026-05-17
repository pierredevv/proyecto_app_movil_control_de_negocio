/// Represents the resolved packaging information for an imported product.
class ParsedPackaging {
  final String saleUnit;
  final double unitsPerSaleUnit;
  final String packagingInfo;

  ParsedPackaging({
    required this.saleUnit,
    required this.unitsPerSaleUnit,
    required this.packagingInfo,
  });

  @override
  String toString() =>
      'saleUnit: $saleUnit, multiplier: $unitsPerSaleUnit, info: $packagingInfo';
}

/// Resolves explicit packaging columns from the Excel file.
///
/// No regex guessing — values come directly from two dedicated columns:
///   • "TIPO DE UNIDAD"  (e.g. "Caja", "Unidad", "Tira", "Blíster")
///   • "CANTIDAD POR PAQUETE" (e.g. 1, 12, 24)
///
/// If either column is absent the safe defaults are returned:
///   saleUnit = 'UNI', unitsPerSaleUnit = 1.0
class PackagingParser {
  /// Maps human-friendly values written in the spreadsheet to canonical codes.
  static const Map<String, String> _unitAliases = {
    // Box variants
    'CAJA': 'CAJ',
    'CAJ': 'CAJ',
    'BOX': 'CAJ',
    // Unit variants
    'UNIDAD': 'UNI',
    'UNI': 'UNI',
    'UNIT': 'UNI',
    'PZA': 'UNI',
    'PIEZA': 'UNI',
    // Strip variants
    'TIRA': 'TIR',
    'TIR': 'TIR',
    'STRIP': 'TIR',
    // Blister variants
    'BLISTER': 'BLI',
    'BLÍSTER': 'BLI',
    'BLI': 'BLI',
    // Pack variants
    'PAQUETE': 'PAQ',
    'PAQ': 'PAQ',
    'PACK': 'PAQ',
    // Bag variants
    'BOLSA': 'BOL',
    'BOL': 'BOL',
    'BAG': 'BOL',
    // Bottle / flask variants
    'BOTELLA': 'BOT',
    'BOT': 'BOT',
    'FRASCO': 'FRA',
    'FRA': 'FRA',
    // Sachet
    'SOBRE': 'SOB',
    'SOB': 'SOB',
    'SACHET': 'SOB',
    // Weight / Volume
    'KG': 'KIL',
    'KILO': 'KIL',
    'KILOGRAMO': 'KIL',
    'KILOGRAMS': 'KIL',
    'G': 'GRA',
    'GR': 'GRA',
    'GRAMO': 'GRA',
    'GRAMS': 'GRA',
    'L': 'LIT',
    'LT': 'LIT',
    'LITRO': 'LIT',
    'LITER': 'LIT',
    'ML': 'MIL',
    'MILILITRO': 'MIL',
  };

  /// Resolves explicit values from the spreadsheet columns.
  ///
  /// [rawUnitType]        — raw value from the "TIPO DE UNIDAD" column.
  /// [rawQuantityPerPkg]  — raw value from the "CANTIDAD POR PAQUETE" column.
  static ParsedPackaging fromExplicitColumns({
    required String rawUnitType,
    required String rawQuantityPerPkg,
  }) {
    final unitKey = rawUnitType.trim().toUpperCase();
    final saleUnit = _unitAliases[unitKey] ?? (unitKey.isNotEmpty ? unitKey : 'UNI');

    final qty = double.tryParse(
          rawQuantityPerPkg.trim().replaceAll(',', '.'),
        ) ??
        1.0;
    final unitsPerSaleUnit = qty > 0 ? qty : 1.0;

    return ParsedPackaging(
      saleUnit: saleUnit,
      unitsPerSaleUnit: unitsPerSaleUnit,
      packagingInfo: rawUnitType.trim(),
    );
  }

  /// Returns safe defaults when both packaging columns are absent.
  static ParsedPackaging defaults() => ParsedPackaging(
        saleUnit: 'UNI',
        unitsPerSaleUnit: 1.0,
        packagingInfo: '',
      );
}
