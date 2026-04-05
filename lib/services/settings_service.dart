import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';

class SettingsService {
  static const _keyProfile = 'business_profile';
  static const _keyThemeMode = 'theme_mode';

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  static Future<void> setThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, value);
  }

  static Future<double> getTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('text_scale') ?? 1.0;
  }

  static Future<void> setTextScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale', value);
  }

  static Future<BusinessProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
    if (raw == null) return const BusinessProfile();
    try {
      return BusinessProfile.fromMap(jsonDecode(raw));
    } catch (_) {
      return const BusinessProfile();
    }
  }

  static Future<void> saveProfile(BusinessProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toMap()));
  }
}
