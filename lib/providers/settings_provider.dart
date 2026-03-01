import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  BusinessProfile _profile = const BusinessProfile();
  bool _isLoaded = false;

  BusinessProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

  // Shortcuts
  String get whatsapp => _profile.whatsapp;
  String get businessName => _profile.businessName;
  String get invoiceFooter => _profile.invoiceFooter;

  Future<void> loadProfile() async {
    _profile = await SettingsService.getProfile();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateProfile(BusinessProfile updated) async {
    _profile = updated;
    await SettingsService.saveProfile(updated);
    notifyListeners();
  }

  Future<void> updateLogoPath(String? path) async {
    final cleanPath =
        (path == null || path.trim().isEmpty) ? null : path.trim();
    _profile = cleanPath == null
        ? _profile.clearLogo()
        : _profile.copyWith(logoPath: cleanPath);
    await SettingsService.saveProfile(_profile);
    notifyListeners();
  }
}
