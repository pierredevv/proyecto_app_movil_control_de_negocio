import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class BackupService {
  static Future<void> createAndShareBackup() async {
    try {
      final dbService = DatabaseService();
      final data = await dbService.exportDatabase();

      // Convert to formatted JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Save to temporary file
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final timestamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}";
      final fileName = "backup_dulces_pierre_$timestamp.json";
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(jsonString);

      // Share
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Respaldo de Base de Datos - Dulces Pierre ($timestamp)',
        ),
      );
    } catch (e) {
      throw Exception('Error creating backup: $e');
    }
  }
}
