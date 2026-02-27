import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../models/import_result.dart';
import 'packaging_parser.dart';

class ImportService {
  // Alias detection dictionary
  static final Map<String, List<String>> _columnAliases = {
    'name': ['NOMBRE', 'PRODUCTO', 'DESCRIPCION', 'ARTICULO', 'ITEM'],
    'barcode': ['CODIGO', 'BARCODE', 'CÓDIGO', 'EAN', 'UPC', 'SKU'],
    'cost': ['COSTO', 'PRECIO COSTO', 'PC', 'COST'],
    'price': ['PRECIO', 'PRECIO VENTA', 'PV', 'PRICE'],
    'stock': ['STOCK', 'CANTIDAD', 'INVENTARIO', 'QTY', 'SALDO'],
    'category': ['CATEGORIA', 'CATEGORÍA', 'FAMILIA', 'GRUPO', 'LINEA'],
    'measure': ['MEDIDA', 'UNIDAD', 'PRESENTACION', 'EMPAQUE', 'FORMATO'],
  };

  /// Main entry point for file picking and parsing
  static Future<ImportParseResult?> pickAndParse() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User canceled
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'xlsx' || extension == 'xls') {
        return await _parseExcel(file.bytes!);
      } else if (extension == 'csv') {
        // file.bytes might be null on some platforms (like large files on mobile)
        // In reality, FilePicker withData:true loads bytes. If not, fallback to File path.
        if (file.bytes != null) {
          return await _parseCsvFromBytes(file.bytes!);
        } else if (file.path != null) {
          return await _parseCsvFromFile(file.path!);
        }
      }
      throw Exception('Formato de archivo no soportado: $extension');
    } catch (e) {
      debugPrint('Error en pickAndParse: $e');
      throw Exception('Error al abrir archivo: $e');
    }
  }

  static Future<ImportParseResult> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);

    // Take the first sheet by default, or the active one
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName];

    if (table == null || table.rows.isEmpty) {
      throw Exception(
          'El archivo Excel está vacío o no contiene hojas válidas.');
    }

    final headersRow = table.rows.first;
    final headers =
        headersRow.map((cell) => cell?.value?.toString().trim() ?? '').toList();

    return _parseRows(headers, table.rows.skip(1).toList());
  }

  static Future<ImportParseResult> _parseCsvFromBytes(List<int> bytes) async {
    final content = utf8.decode(bytes); // Warning: assumes UTF-8
    return _parseCsvContent(content);
  }

  static Future<ImportParseResult> _parseCsvFromFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    return _parseCsvContent(content);
  }

  static Future<ImportParseResult> _parseCsvContent(String content) async {
    final csvTable = const CsvToListConverter().convert(content);
    if (csvTable.isEmpty) throw Exception('El archivo CSV está vacío.');

    final headers = csvTable.first.map((e) => e.toString().trim()).toList();
    final rowsData = csvTable.skip(1).map((row) {
      return row.map((e) => e.toString().trim()).toList();
    }).toList();

    return _parseRowsStringOnly(headers, rowsData);
  }

  /// Evaluates headers against aliases
  static Map<String, int> _detectColumns(List<String> headers) {
    final mapping = <String, int>{};

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toUpperCase();
      if (h.isEmpty) continue;

      _columnAliases.forEach((key, aliases) {
        if (!mapping.containsKey(key)) {
          // Take first match
          if (aliases.any((alias) => h == alias || h.contains(alias))) {
            mapping[key] = i;
          }
        }
      });
    }
    return mapping;
  }

  /// Core logic turning raw row generic cells into ProductImportRow
  static Future<ImportParseResult> _parseRows(
      List<String> headers, List<List<Data?>> rawRows) async {
    // Convert Data? to String for uniformity
    final stringRows = rawRows.map((row) {
      return row.map((cell) => cell?.value?.toString().trim() ?? '').toList();
    }).toList();

    return _parseRowsStringOnly(headers, stringRows);
  }

  static Future<ImportParseResult> _parseRowsStringOnly(
      List<String> headers, List<List<String>> stringRows) async {
    final colMap = _detectColumns(headers);
    final List<ProductImportRow> validRows = [];
    final List<ImportRowError> errors = [];

    // Reverse map for debugging/UI
    final reverseMap = {
      for (var entry in colMap.entries) entry.key: headers[entry.value]
    };

    if (!colMap.containsKey('name')) {
      throw Exception('No se detectó la columna obligatoria: Nombre/Producto.');
    }

    int idxName = colMap['name']!;
    int? idxBarcode = colMap['barcode'];
    int? idxCost = colMap['cost'];
    int? idxPrice = colMap['price'];
    int? idxStock = colMap['stock'];
    int? idxCategory = colMap['category'];
    int? idxMeasure = colMap['measure'];

    for (int i = 0; i < stringRows.length; i++) {
      final row = stringRows[i];
      // Skip empty rows
      if (row.isEmpty || (row.length > idxName && row[idxName].isEmpty)) {
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
        final measureStr = idxMeasure != null && row.length > idxMeasure
            ? row[idxMeasure]
            : '';

        // Parsing Numerics intelligently (handle commas, letters, etc)
        final cost = _parseDoubleSafe(costStr);
        final price = _parseDoubleSafe(priceStr);
        final stockRaw = _parseDoubleSafe(
            stockStr); // This is stock in "saleUnit" (e.g. 5 boxes)

        // Parsing Packaging
        final parsedPkg = PackagingParser.parse(measureStr);

        // Convert raw stock to Base Unit Stock
        final stockBase = stockRaw * parsedPkg.unitsPerSaleUnit;

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
        errors.add(ImportRowError(i + 2,
            'Error parseando fila: $e')); // i+2 accounting for 0-index and header
      }
    }

    return ImportParseResult(
      rows: validRows,
      errors: errors,
      columnMapping: reverseMap,
    );
  }

  static double _parseDoubleSafe(String val) {
    if (val.isEmpty) return 0.0;
    // Remove currency symbols, fix commas to dots
    String clean = val.replaceAll(RegExp(r'[^\d.,-]'), '');
    clean = clean.replaceAll(',', '.');
    // If multiple dots exist, remove all but last (e.g., 1.000.50 -> 1000.50)
    final parts = clean.split('.');
    if (parts.length > 2) {
      clean = '${parts.sublist(0, parts.length - 1).join()}.${parts.last}';
    }
    return double.tryParse(clean) ?? 0.0;
  }
}
