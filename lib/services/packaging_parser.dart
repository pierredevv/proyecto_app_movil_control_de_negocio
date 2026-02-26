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
  String toString() {
    return 'saleUnit: $saleUnit, multiplier: $unitsPerSaleUnit, info: $packagingInfo';
  }
}

class PackagingParser {
  /// Interpreta la columna "Medida" (o similar) del Excel
  /// y deduce cómo se vende el producto y su multiplicador.
  ///
  /// Ejemplos:
  /// "24X300" -> Caja de 24. saleUnit='CAJ', multiplier=24, info='24x300'
  /// "X 18" -> Caja de 18. saleUnit='CAJ', multiplier=18, info='18'
  /// "3 L" -> Unidad. saleUnit='UNI', multiplier=1, info='3L'
  /// "S/M" -> Unidad. saleUnit='UNI', multiplier=1, info=''
  static ParsedPackaging parse(String rawMeasure) {
    if (rawMeasure.isEmpty) {
      return ParsedPackaging(
        saleUnit: 'UNI',
        unitsPerSaleUnit: 1.0,
        packagingInfo: '',
      );
    }

    final measure = rawMeasure.trim().toUpperCase();

    // 1. Caso explícito de Cajas o "X" multiplicador (Ej: "24X300" o "X 18")
    // Busca un número seguido (o precedido) por una X
    final boxRegex = RegExp(r'^(\d+)\s*X');
    final boxMatch = boxRegex.firstMatch(measure);

    if (boxMatch != null) {
      final multiplierStr = boxMatch.group(1);
      final multiplier = double.tryParse(multiplierStr ?? '1') ?? 1.0;

      return ParsedPackaging(
        saleUnit: 'CAJ',
        unitsPerSaleUnit: multiplier,
        packagingInfo: measure, // Guardamos la info original como empaque
      );
    }

    // Variante: "X 12" o "X12"
    final xFirstRegex = RegExp(r'^X\s*(\d+)');
    final xFirstMatch = xFirstRegex.firstMatch(measure);
    if (xFirstMatch != null) {
      final multiplierStr = xFirstMatch.group(1);
      final multiplier = double.tryParse(multiplierStr ?? '1') ?? 1.0;

      return ParsedPackaging(
        saleUnit: 'CAJ',
        unitsPerSaleUnit: multiplier,
        packagingInfo: measure,
      );
    }

    // 2. Tiras o Paquetes explícitos (Si existen en su data)
    // Ejemplo: "TIRA 12" -> saleUnit: 'TIR', multiplier: 12
    if (measure.contains('TIRA')) {
      final numRegex = RegExp(r'\d+');
      final match = numRegex.firstMatch(measure);
      double multiplier = 1.0;
      if (match != null) {
        multiplier = double.tryParse(match.group(0) ?? '1') ?? 1.0;
      }
      return ParsedPackaging(
        saleUnit: 'TIR',
        unitsPerSaleUnit: multiplier,
        packagingInfo: measure,
      );
    }

    // 3. Fallback: Suponer que es una presentación individual (Botella, Bolsa, etc.)
    // Ej: "3 L", "500 ML", "S/M"
    return ParsedPackaging(
      saleUnit: 'UNI',
      unitsPerSaleUnit: 1.0,
      packagingInfo: measure == 'S/M' ? '' : measure,
    );
  }
}
