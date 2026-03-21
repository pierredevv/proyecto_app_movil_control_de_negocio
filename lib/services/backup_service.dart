import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'database_service.dart';

enum BackupType { full, products, clients, suppliers, parties }

enum ExportFormat { json, excel, csv }

class BackupService {
  static const String _backupFolderName = 'Backups';
  static const int _maxBackups = 10;

  // ✅ PUBLIC: EXPORT DATA
  static Future<File> exportData({
    required BackupType type,
    required ExportFormat format,
  }) async {
    try {
      final dbService = DatabaseService();
      final fullData = await dbService.exportDatabase();
      final data = fullData['data'] as Map<String, dynamic>;

      // Filter data based on BackupType
      final Map<String, dynamic> filteredData = _filterData(data, type);

      // Generate content based on Format
      List<int> bytes;
      String extension;

      switch (format) {
        case ExportFormat.json:
          final jsonString = const JsonEncoder.withIndent('  ').convert({
            'version': fullData['version'],
            'timestamp': fullData['timestamp'],
            'data': filteredData,
          });
          bytes = utf8.encode(jsonString);
          extension = 'json';
          break;
        case ExportFormat.excel:
          bytes = _generateExcel(filteredData, type);
          extension = 'xlsx';
          break;
        case ExportFormat.csv:
          final csvString = _generateCsv(filteredData, type);
          bytes = utf8.encode(csvString);
          extension = 'csv';
          break;
      }

      // Save File
      return await _saveFile(bytes, type, extension);
    } catch (e) {
      debugPrint('Export Error: $e');
      throw Exception('Error al exportar ($type, $format): $e');
    }
  }

  // ✅ FILTER DATA
  static Map<String, dynamic> _filterData(
      Map<String, dynamic> data, BackupType type) {
    if (type == BackupType.full) return data;

    final result = <String, dynamic>{};

    if (type == BackupType.products) {
      result['products'] = data['products'];
      result['categories'] = data['categories'];
    } else if (type == BackupType.clients) {
      result['customers'] = data['customers'];
    } else if (type == BackupType.suppliers) {
      result['suppliers'] = data['suppliers'];
    } else if (type == BackupType.parties) {
      result['customers'] = data['customers'];
      result['suppliers'] = data['suppliers'];
    }
    return result;
  }

  // ✅ GENERATE EXCEL
  static List<int> _generateExcel(Map<String, dynamic> data, BackupType type) {
    var excel = Excel.createExcel();

    // Iterate through tables
    data.forEach((tableName, records) {
      if (records is! List || records.isEmpty) return;

      final sheet = excel[tableName];
      final firstRecord = records.first as Map<String, dynamic>;

      // Header
      sheet.appendRow(
          firstRecord.keys.map((key) => TextCellValue(key)).toList());

      // Rows
      for (final row in records) {
        final rowData = row as Map<String, dynamic>;
        sheet.appendRow(rowData.values
            .map((v) => TextCellValue(v?.toString() ?? ''))
            .toList());
      }
    });

    // Remove default sheet if unused? Excel creates 'Sheet1' by default.
    if (data.isNotEmpty && excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.encode()!;
  }

  // ✅ GENERATE CSV (Simplified: If multiple tables, we might just do the primary one or merge)
  static String _generateCsv(Map<String, dynamic> data, BackupType type) {
    final List<List<dynamic>> rows = [];

    data.forEach((tableName, records) {
      if (records is! List || records.isEmpty) return;

      // Add a header for the Table Name
      rows.add(['--- TABLE: $tableName ---']);
      final firstRecord = records.first as Map<String, dynamic>;

      // Headers
      rows.add(firstRecord.keys.toList());

      // Data
      for (final row in records) {
        final rowData = row as Map<String, dynamic>;
        rows.add(rowData.values.toList());
      }
      rows.add([]); // Empty row separator
    });

    return const ListToCsvConverter().convert(rows);
  }

  // ✅ SAVE FILE (Smart Storage Selection)
  static Future<File> _saveFile(
      List<int> bytes, BackupType type, String extension) async {
    Directory? directory;

    if (!kIsWeb && Platform.isAndroid) {
      // Android 11+ Strategy (Manage External Storage) vs Old Android
      if (await Permission.manageExternalStorage.request().isGranted) {
        directory =
            Directory('/storage/emulated/0/Documents/$_backupFolderName');
      } else if (await Permission.storage.request().isGranted) {
        // Android 10 or lower or partial access
        directory =
            Directory('/storage/emulated/0/Documents/$_backupFolderName');
      }
    }

    // Fallback to App Internal Storage if no external permission or non-Android
    if (directory == null) {
      final docDir = await getApplicationDocumentsDirectory();
      directory = Directory('${docDir.path}/$_backupFolderName');
    }

    if (!await directory.exists()) {
      try {
        await directory.create(recursive: true);
      } catch (e) {
        // Fallback if creating /Documents subdir fails (e.g. Scoped Storage oddity)
        // We shouldn't get here if permissions checked, but just in case:
        final docDir = await getApplicationDocumentsDirectory();
        directory = Directory('${docDir.path}/$_backupFolderName');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    }

    // Generate Filename
    final now = DateTime.now();
    final timestamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";

    final typeName = type.toString().split('.').last;
    final fileName = "backup_${typeName}_$timestamp.$extension";

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Clean old backups for this type/extension
    await _cleanOldBackups(directory, typeName, extension);

    return file;
  }

  static Future<void> _cleanOldBackups(
      Directory dir, String typeName, String ext) async {
    try {
      if (await dir.exists()) {
        final files = dir
            .listSync()
            .where((f) => f.path.contains(typeName) && f.path.endsWith(ext))
            .toList();
        files.sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

        if (files.length > _maxBackups) {
          final toDelete = files.take(files.length - _maxBackups);
          for (final f in toDelete) {
            try {
              await f.delete();
            } catch (e) {
              debugPrint('Could not delete old backup: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning backups: $e');
    }
  }

  // ✅ LIST LOCAL BACKUPS
  static Future<List<FileSystemEntity>> listBackups() async {
    // Check both public and private dirs
    final List<FileSystemEntity> allFiles = [];

    // 1. Public Documents (Only if accessible)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final publicDir =
            Directory('/storage/emulated/0/Documents/$_backupFolderName');
        if (await publicDir.exists()) {
          // This might throw if we don't have permission to read even if it exists
          allFiles.addAll(publicDir.listSync());
        }
      } catch (e) {
        // Ignore permission errors here, just skip
        debugPrint('Could not list public backups: $e');
      }
    }

    // 2. Private App Dir
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final privateDir = Directory('${appDir.path}/$_backupFolderName');
      if (await privateDir.exists()) {
        allFiles.addAll(privateDir.listSync());
      }
    } catch (e) {
      debugPrint('Could not list private backups: $e');
    }

    // Filter Valid
    final validFiles = allFiles
        .where((f) =>
            f.path.endsWith('.json') ||
            f.path.endsWith('.xlsx') ||
            f.path.endsWith('.csv'))
        .toList();

    // Sort Newest
    validFiles
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    // Remove duplicates (same path?) - Paths are distinct between private and public
    return validFiles;
  }

  // ✅ RESTORE (JSON ONLY)
  static Future<void> restoreBackup(File file) async {
    if (!file.path.endsWith('.json')) {
      throw Exception('Solo se pueden restaurar archivos .json');
    }

    // Read
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Auto-Backup existing state before restore
    try {
      await exportData(type: BackupType.full, format: ExportFormat.json);
    } catch (e) {
      debugPrint('Auto-backup before restore failed: $e');
      // Continue restore? Or abort?
      // Abort is safer to avoid data loss without backup.
      // But if backup fails due to permission, user might be stuck.
      // Let's Log and Continue, assuming they want to restore.
    }

    // Restore Logic (Private method, assumed same as before)
    final dbService = DatabaseService();
    final db = await dbService.database;

    await db.transaction((txn) async {
      // ... (Deletion logic same as before, abbreviated here for brevity but CRITICAL)
      // If implementing full replace, I must copy the logic.
      // Since I'm replacing the file, I MUST include the logic.
      await _restoreTransaction(txn, data);
    });
  }

  static Future<void> _restoreTransaction(
      dynamic txn, Map<String, dynamic> root) async {
    final data = root['data'] as Map<String, dynamic>;

    // 1. Read sale_payments into memory BEFORE deletion
    final legacySalePayments = data.containsKey('sale_payments') ? List.from(data['sale_payments']) : [];

    // Clean in correct order (respecting FK) 
    await txn.delete('payment_allocations'); 
    await txn.delete('payments'); 
    await txn.delete('entity_ledgers'); 
    await txn.delete('inventory_movements'); 
    await txn.delete('sale_payments'); 
    await txn.delete('notes'); 
    await txn.delete('transaction_items'); 
    await txn.delete('transactions'); 
    await txn.delete('customers'); 
    await txn.delete('products'); 
    await txn.delete('categories'); 
    await txn.delete('suppliers'); 

    // Restore all tables dynamically based on JSON keys
    final tablesToRestore = data.keys.toList();
    
    for (final tableName in tablesToRestore) { 
      if (data.containsKey(tableName)) { 
        for (final row in data[tableName]) { 
          // Handle 'invoice_items' exported key mapping if needed
          await txn.insert(tableName, row); 
        } 
      } 
    }
    
    // Fallback for legacy backups where transaction_items were exported as invoice_items
    if (data.containsKey('invoice_items') && !data.containsKey('transaction_items')) {
      for (final row in data['invoice_items']) {
        await txn.insert('transaction_items', row);
      }
    }
    
    // Post-Restore Migration: If backup was pre-V13, manually transition sale_payments to payments from memory
    if (legacySalePayments.isNotEmpty && !data.containsKey('payments')) {
        for (var op in legacySalePayments) {
            // we need the customerId. t.entity_id from transactions
            final transRecords = await txn.query('transactions', where: 'id = ?', whereArgs: [op['sale_id']]);
            if (transRecords.isEmpty) continue;
            
            final entityId = transRecords.first['entity_id'] as int?;
            if (entityId == null) continue; // Skip anonymous payments
            
            final newPaymentId = await txn.insert('payments', {
                'entity_id': entityId,
                'entity_type': 'CUSTOMER',
                'amount': op['amount'],
                'date': op['date'],
                'payment_method': 'EFECTIVO', // Legacy default
                'note': op['note'] ?? 'Historical anonymous sale payment'
            });
            
            await txn.insert('payment_allocations', {
                'payment_id': newPaymentId,
                'transaction_id': op['sale_id'],
                'allocated_amount': op['amount']
            });
        }
    }
  }

  // ✅ AUTO BACKUP
  static Future<void> autoBackupIfNeeded() async {
    // Run daily backup for ALL types in default format (JSON for Full, Excel for others)
    // Limitation: checking "last modified" for *each* type is complex.
    // Simple strategy: Check if "backup_full_YYYYMMDD" exists. If not, create ALL.

    try {
      final now = DateTime.now();

      // Attempt to list backups. If this fails completely, we might just try to backup anyway.
      final backups = await listBackups();

      // define "Today" string
      final todayStr =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

      // Check if we have any backup from today
      final hasBackupToday = backups.any((f) => f.path.contains(todayStr));

      if (!hasBackupToday) {
        debugPrint('Starting Auto-Backups...');
        // 1. Full JSON (Recovery)
        await exportData(type: BackupType.full, format: ExportFormat.json);

        // 2. Products Excel
        await exportData(type: BackupType.products, format: ExportFormat.excel);

        // 3. Parties Excel
        await exportData(type: BackupType.parties, format: ExportFormat.excel);
      }
    } catch (e) {
      debugPrint('AutoBackup Error: $e');
    }
  }

  // Restore External
  static Future<bool> restoreFromExternalFile() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path == null) return false;

        if (!path.toLowerCase().endsWith('.json')) {
          throw Exception(
              'El archivo importado no tiene el formato .json requerido.');
        }

        final file = File(path);
        await restoreBackup(file);
        return true;
      }
      return false; // User canceled or no file selected
    } catch (e) {
      throw Exception('Error al importar archivo: $e');
    }
  }

  // ✅ DELETE LOCAL BACKUP
  static Future<void> deleteBackup(FileSystemEntity file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Error al eliminar backup: $e');
    }
  }

  // ✅ GET BACKUP SIZE
  static Future<String> getBackupSize(FileSystemEntity file) async {
    try {
      final size = await file.stat().then((s) => s.size);
      if (size < 1024) {
        return '$size B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Desconocido';
    }
  }
}
