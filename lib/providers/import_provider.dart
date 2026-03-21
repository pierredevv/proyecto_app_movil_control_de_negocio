import 'package:flutter/foundation.dart';
import '../services/import_service.dart';
import '../services/database_service.dart';
import '../models/import_result.dart';

enum ImportStep { pending, parsing, preview, inserting, done, error }

class ImportProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  ImportStep _step = ImportStep.pending;
  ImportStep get step => _step;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ImportParseResult? _parseResult;
  ImportParseResult? get parseResult => _parseResult;

  /// IDs de las filas que el usuario decide NO importar en la vista de confirmación.
  final Set<int> _deselectedRows = {};
  Set<int> get deselectedRows => _deselectedRows;

  Map<String, int>? _insertResult;
  Map<String, int>? get insertResult => _insertResult;

  void reset() {
    _step = ImportStep.pending;
    _errorMessage = null;
    _parseResult = null;
    _deselectedRows.clear();
    _insertResult = null;
    notifyListeners();
  }

  void toggleRowSelection(int index) {
    if (_deselectedRows.contains(index)) {
      _deselectedRows.remove(index);
    } else {
      _deselectedRows.add(index);
    }
    notifyListeners();
  }

  bool isRowSelected(int index) => !_deselectedRows.contains(index);

  Future<void> pickAndParseFile() async {
    try {
      _step = ImportStep.parsing;
      _errorMessage = null;
      _deselectedRows.clear();
      notifyListeners();

      final result = await ImportService.pickAndParse();

      if (result == null) {
        // Usuario canceló FilePicker
        _step = ImportStep.pending;
        notifyListeners();
        return;
      }

      _parseResult = result;
      _step = ImportStep.preview;
      notifyListeners();
    } catch (e) {
      _step = ImportStep.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> confirmImport() async {
    if (_parseResult == null) return;

    try {
      _step = ImportStep.inserting;
      notifyListeners();

      // Filtrar filas desmarcadas
      final List<ProductImportRow> rowsToInsert = [];
      for (int i = 0; i < _parseResult!.rows.length; i++) {
        if (!_deselectedRows.contains(i)) {
          rowsToInsert.add(_parseResult!.rows[i]);
        }
      }

      if (rowsToInsert.isEmpty) {
        throw Exception('No hay productos seleccionados para importar.');
      }

      _insertResult = await _db.insertImportedProducts(rowsToInsert);

      _step = ImportStep.done;
      notifyListeners();
    } catch (e) {
      _step = ImportStep.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> applyManualMapping(Map<String, int> explicitMapping) async {
    if (_parseResult == null) return;
    
    _step = ImportStep.parsing;
    notifyListeners();
    
    try {
      _parseResult = await ImportService.parseWithOverrides(
        _parseResult!.rawHeaders,
        _parseResult!.rawStringRows,
        explicitMapping
      );
      _step = ImportStep.preview;
      notifyListeners();
    } catch (e) {
      _step = ImportStep.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
