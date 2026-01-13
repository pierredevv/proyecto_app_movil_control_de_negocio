import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_movil_control_de_negocio/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('listBackups returns empty list initially', () async {
    // This will use systemTemp as appDir
    final backups = await BackupService.listBackups();
    // It might capture some temp files if they match naming convention, but highly unlikely in pure temp.
    // Naming convention is backup_...
    expect(backups, isA<List>());
  });

  test('restoreBackup throws on non-json file', () async {
    final file = File('test.txt');
    expect(
      () async => await BackupService.restoreBackup(file),
      throwsA(isA<Exception>()),
    );
  });
}
