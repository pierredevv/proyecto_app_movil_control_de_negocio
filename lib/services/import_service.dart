import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../models/import_result.dart';
import 'packaging_parser.dart';

/// Handles picking and parsing product inventory files.
///
/// IMPORTANT: Only .xlsx / .xls files are accepted.
/// CSV support has been intentionally removed because embedded line-breaks in
/// product descriptions break sequential CSV parsing, causing column shifting
/// and corrupted numeric values. Native Excel cells are immune to this issue.
class ImportService {
  // ---------------------------------------------------------------------------
  // Column alias dictionary
  // ---------------------------------------------------------------------------
  // Each key maps to an ordered list of header aliases (compared in
  // UPPER-CASE, with partial match support). The FIRST matching column wins.
  static final Map<String, List<String>> _columnAliases = {
    'name': [
      'NOMBRE',
      'PRODUCTO',
      'DESCRIPCION',
      'DESCRIPCIÓN',
      'ARTICULO',
      'ARTÍCULO',
      'ITEM',
    ],
    'barcode': [
      'CODIGO',
      'CÓDIGO',
      'BARCODE',
      'EAN',
      'UPC',
      'SKU',
    ],
    'cost': [
      'COSTO',
      'PRECIO COSTO',
      'PC',
      'COST',
    ],
    'price': [
      'PRECIO',
      'PRECIO VENTA',
      'PV',
      'PRICE',
    ],
    'stock': [
      'STOCK',
      'CANTIDAD',
      'INVENTARIO',
      'QTY',
      'SALDO',
    ],
    'category': [
      'CATEGORIA',
      'CATEGORÍA',
      'FAMILIA',
      'GRUPO',
      'LINEA',
      'LÍNEA',
    ],
    // -------------------------------------------------------------------------
    // Packaging columns — explicit, no regex guessing
    // -------------------------------------------------------------------------
    // Maps to the "Tipo de Unidad" column.
    // Expected values: "Caja", "Unidad", "Tira", "Blíster", etc.
    'saleUnit': [
      'TIPO DE UNIDAD',
      'TIPO UNIDAD',
      'UNIDAD',
      'UNIT',
      'TIPO',
      'PACKAGING',
      'UNIDAD DE VENTA',
      'SALE UNIT',
      'PRESENTACION',
      'PRESENTACIÓN',
      'EMPAQUE',
    ],
    // Maps to the "Cantidad por Paquete" column.
    // Expected values: numeric (1, 12, 24, …)
    'unitsPerPkg': [
      'CANTIDAD POR PAQUETE',
      'CANT POR PAQUETE',
      'CANTIDAD PAQUETE',
      'CANTIDAD POR PKG',
      'MULTIPLICADOR',
      'MULTIPLIER',
      'UNIDADES POR PAQUETE',
      'UNITS PER PACKAGE',
      'UNIDADES PAQUETE',
    ],
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Opens the OS file picker restricted to Excel files and parses the result.
  ///
  /// Returns `null` when the user cancels.
  /// Throws an [Exception] for unsupported formats or parse failures.
  static Future<ImportParseResult?> pickAndParse() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        // CSV explicitly excluded — see class doc-comment for rationale.
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled.
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'xlsx' || extension == 'xls') {
        List<int> bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = File(file.path!).readAsBytesSync();
        } else {
          throw Exception('No se pudo obtener el contenido del archivo.');
        }
        return await _parseExcel(bytes);
      }

      // Should never reach here given the allowedExtensions filter, but kept
      // as a safety net.
      throw Exception(
        'Formato de archivo no compatible: .$extension\n'
        'Por favor, usa un archivo Excel (.xlsx o .xls).',
      );
    } catch (e) {
      debugPrint('Error en pickAndParse: $e');
      throw Exception('Error al abrir el archivo: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Excel parsing
  // ---------------------------------------------------------------------------

  static Future<ImportParseResult> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);

    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName];

    if (table == null || table.rows.isEmpty) {
      throw Exception(
          'El archivo Excel está vacío o no contiene hojas válidas.');
    }

    final headersRow = table.rows.first;
    final headers = headersRow
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .toList();

    // Convert Data? cells to plain strings, preserving embedded line-breaks as
    // spaces (they are part of the cell value in xlsx, not structural).
    final stringRows = table.rows.skip(1).map((row) {
      return row
          .map((cell) =>
              cell?.value?.toString().replaceAll('\n', ' ').trim() ?? '')
          .toList();
    }).toList();

    return _parseRowsStringOnly(headers, stringRows);
  }

  // ---------------------------------------------------------------------------
  // Column detection
  // ---------------------------------------------------------------------------

  /// Matches each header to its canonical key via the alias dictionary.
  static Map<String, int> _detectColumns(List<String> headers) {
    final mapping = <String, int>{};

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toUpperCase();
      if (h.isEmpty) continue;

      _columnAliases.forEach((key, aliases) {
        if (!mapping.containsKey(key)) {
          if (aliases.any((alias) => h == alias || h.contains(alias))) {
            mapping[key] = i;
          }
        }
      });
    }
    return mapping;
  }

  // ---------------------------------------------------------------------------
  // Row parsing
  // ---------------------------------------------------------------------------

  static Future<ImportParseResult> _parseRowsStringOnly(
    List<String> headers,
    List<List<String>> stringRows, {
    Map<String, int>? explicitMapping,
    bool? useCommaAsDecimal,
  }) async {
    final colMap = _detectColumns(headers);
    if (explicitMapping != null) {
      colMap.addAll(explicitMapping);
    }

    if (!colMap.containsKey('name')) {
      throw Exception(
          'No se detectó la columna obligatoria: Nombre / Producto.');
    }

    final reverseMap = {
      for (final entry in colMap.entries) entry.key: headers[entry.value]
    };

    final int idxName = colMap['name']!;
    final int? idxBarcode = colMap['barcode'];
    final int? idxCost = colMap['cost'];
    final int? idxPrice = colMap['price'];
    final int? idxStock = colMap['stock'];
    final int? idxCategory = colMap['category'];
    final int? idxSaleUnit = colMap['saleUnit'];
    final int? idxUnitsPerPkg = colMap['unitsPerPkg'];

    final List<ProductImportRow> validRows = [];
    final List<ImportRowError> errors = [];

    for (int i = 0; i < stringRows.length; i++) {
      final row = stringRows[i];

      // Skip blank rows.
      if (row.isEmpty ||
          (row.length > idxName && row[idxName].isEmpty) ||
          row.length <= idxName) {
        continue;
      }

      try {
        final name = row[idxName];

        final barcode = idxBarcode != null && row.length > idxBarcode
            ? row[idxBarcode]
            : '';
        final costStr =
            idxCost != null && row.length > idxCost ? row[idxCost] : '0';
        final priceStr =
            idxPrice != null && row.length > idxPrice ? row[idxPrice] : '0';
        final stockStr =
            idxStock != null && row.length > idxStock ? row[idxStock] : '0';
        final categoryStr = idxCategory != null && row.length > idxCategory
            ? row[idxCategory]
            : '';

        // Packaging — read from explicit columns; fall back to defaults.
        final rawUnitType =
            idxSaleUnit != null && row.length > idxSaleUnit
                ? row[idxSaleUnit]
                : '';
        final rawQtyPerPkg =
            idxUnitsPerPkg != null && row.length > idxUnitsPerPkg
                ? row[idxUnitsPerPkg]
                : '';

        final ParsedPackaging parsedPkg =
            (rawUnitType.isEmpty && rawQtyPerPkg.isEmpty)
                ? PackagingParser.defaults()
                : PackagingParser.fromExplicitColumns(
                    rawUnitType: rawUnitType,
                    rawQuantityPerPkg: rawQtyPerPkg,
                  );

        final cost = _parseDoubleSafe(costStr, useCommaAsDecimal: useCommaAsDecimal);
        final price = _parseDoubleSafe(priceStr, useCommaAsDecimal: useCommaAsDecimal);
        // Stock in the spreadsheet is expressed in sale-units (e.g. 5 boxes).
        // Convert to base units for the internal inventory model.
        final stockBase =
            _parseDoubleSafe(stockStr, useCommaAsDecimal: useCommaAsDecimal) * parsedPkg.unitsPerSaleUnit;

        validRows.add(ProductImportRow(
          name: name,
          barcode: barcode,
          cost: cost,
          price: price,
          stockBase: stockBase,
          category: categoryStr,
          saleUnit: parsedPkg.saleUnit,
          unitsPerSaleUnit: parsedPkg.unitsPerSaleUnit,
          packagingInfo: parsedPkg.packagingInfo,
        ));
      } catch (e) {
        errors.add(ImportRowError(
          i + 2, // +1 for 0-index, +1 for header row.
          'Error al parsear fila: $e',
        ));
      }
    }

    return ImportParseResult(
      rows: validRows,
      errors: errors,
      columnMapping: reverseMap,
      rawHeaders: headers,
      rawStringRows: stringRows,
    );
  }

  // ---------------------------------------------------------------------------
  // Public override entry point (for the column-mapping UI)
  // ---------------------------------------------------------------------------

  static Future<ImportParseResult> parseWithOverrides(
    List<String> headers,
    List<List<String>> stringRows,
    Map<String, int> explicitMapping, {
    bool? useCommaAsDecimal,
  }) {
    return _parseRowsStringOnly(
      headers,
      stringRows,
      explicitMapping: explicitMapping,
      useCommaAsDecimal: useCommaAsDecimal,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parses a numeric string that may contain thousands separators, currency
  /// symbols, or use commas as decimal separators.
  static double _parseDoubleSafe(String val, {bool? useCommaAsDecimal}) {
    if (val.isEmpty) return 0.0;
    
    // Strip everything except digits, comma, dot, and minus
    String clean = val.replaceAll(RegExp(r'[^\d.,-]'), '');
    if (clean.isEmpty) return 0.0;

    if (useCommaAsDecimal != null) {
      if (useCommaAsDecimal) {
        // Force comma as decimal: remove all dots, replace comma with dot
        clean = clean.replaceAll('.', '');
        clean = clean.replaceAll(',', '.');
      } else {
        // Force dot as decimal: remove all commas
        clean = clean.replaceAll(',', '');
      }
      return double.tryParse(clean) ?? 0.0;
    }

    int lastComma = clean.lastIndexOf(',');
    int lastDot = clean.lastIndexOf('.');

    // If both exist
    if (lastComma != -1 && lastDot != -1) {
      if (lastDot > lastComma) {
        // American format: 1,234.56 -> dot is decimal
        clean = clean.replaceAll(',', '');
      } else {
        // European format: 1.234,56 -> comma is decimal
        clean = clean.replaceAll('.', '');
        clean = clean.replaceAll(',', '.');
      }
    } else if (lastComma != -1) {
      // Only comma exists (e.g., "15,50" or "1,550")
      final parts = clean.split(',');
      // If the last part has exactly 3 digits, it's highly likely a thousand separator
      if (parts.last.length == 3 && parts.length > 1) {
        clean = clean.replaceAll(',', '');
      } else {
        clean = clean.replaceAll(',', '.');
      }
    } else if (lastDot != -1) {
      // Only dot exists (e.g., "15.50" or "1.550")
      final parts = clean.split('.');
      if (parts.last.length == 3 && parts.length > 1) {
        clean = clean.replaceAll('.', '');
      }
    }

    return double.tryParse(clean) ?? 0.0;
  }
}
