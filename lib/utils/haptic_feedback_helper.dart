import 'package:flutter/services.dart';

class HapticFeedbackHelper {
  /// Light impact for button presses
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for successful actions
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for destructive actions (e.g. deleting, cancelling)
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Vibrate for a standard duration
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }
}
