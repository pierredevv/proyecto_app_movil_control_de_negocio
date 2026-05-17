import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { debug, info, warning, error }

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  File? _oldLogFile;
  final int _maxFileSize = 2 * 1024 * 1024; // 2 MB limit
  
  bool _isDebugModeEnabled = false;

  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app.log');
      _oldLogFile = File('${directory.path}/app_old.log');

      final prefs = await SharedPreferences.getInstance();
      _isDebugModeEnabled = prefs.getBool('enable_debug_logging') ?? false;

      _writeLog(LogLevel.info, 'LoggerService', 'Logging initialized.');
    } catch (e) {
      debugPrint('Failed to initialize LoggerService: $e');
    }
  }

  void setDebugMode(bool enabled) {
    _isDebugModeEnabled = enabled;
  }

  void d(String tag, String message) => _log(LogLevel.debug, tag, message);
  void i(String tag, String message) => _log(LogLevel.info, tag, message);
  void w(String tag, String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.warning, tag, message, error, stackTrace);
  void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, tag, message, error, stackTrace);

  Future<void> _log(LogLevel level, String tag, String message,
      [dynamic error, StackTrace? stackTrace]) async {
    // If not in debug mode, ignore DEBUG logs. Production default is WARNING/INFO/ERROR.
    if (level == LogLevel.debug && !_isDebugModeEnabled) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final sanitizedMessage = _sanitize(message);
    
    final levelStr = level.toString().split('.').last;
    
    final buffer = StringBuffer();
    buffer.writeln('[$timestamp] [$levelStr] [$tag] $sanitizedMessage');
    
    if (error != null) {
      buffer.writeln('Error: ${_sanitize(error.toString())}');
    }
    if (stackTrace != null) {
      buffer.writeln('Stack: $stackTrace');
    }

    final logString = buffer.toString();
    
    // Print to console if in debug mode
    if (kDebugMode) {
      debugPrint(logString);
    }

    await _writeLog(level, tag, logString);
  }

  Future<void> _writeLog(LogLevel level, String tag, String content) async {
    if (_logFile == null) return;

    try {
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size >= _maxFileSize) {
          // Rotate logs: delete old one if exists, rename current to old
          if (await _oldLogFile!.exists()) {
            await _oldLogFile!.delete();
          }
          await _logFile!.rename(_oldLogFile!.path);
          // Re-create the current log file
          _logFile = File(_logFile!.path);
        }
      }

      await _logFile!.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  /// Removes sensitive information from logs before writing to disk
  String _sanitize(String input) {
    // Example: Masking passwords or tokens if they ever get passed.
    // 'password': 'mysecretpassword' -> 'password': '***'
    String sanitized = input;
    
    final patternsToMask = [
      RegExp(r'(password"?\s*[:=]\s*"?)[^",\s}]+("?)', caseSensitive: false),
      RegExp(r'(token"?\s*[:=]\s*"?)[^",\s}]+("?)', caseSensitive: false),
      RegExp(r'(secret"?\s*[:=]\s*"?)[^",\s}]+("?)', caseSensitive: false),
    ];

    for (var pattern in patternsToMask) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        return '${match.group(1)}***${match.group(2)}';
      });
    }

    return sanitized;
  }

  Future<File?> getLogFile() async {
    if (_logFile != null && await _logFile!.exists()) {
      return _logFile;
    }
    return null;
  }
}
