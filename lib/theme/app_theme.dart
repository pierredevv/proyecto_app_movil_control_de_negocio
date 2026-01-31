import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // New Design System Colors
  static const Color backgroundBlack = Color(0xFF151924);
  static const Color greenAccent = Color(0xFF5FD068);
  static const Color redAccent = Color(0xFFFF6B6B);
  static const Color blueIcon = Color(0xFF4A90E2);
  static const Color yellowIcon = Color(0xFFF5A623);
  static const Color purpleIcon = Color(0xFF9B51E0);
  static const Color greenIcon = Color(0xFF4ECDC4); // Distinct from greenAccent

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A8C1);
  static const Color textTertiary = Color(0xFF6B7494);

  // Backward compatibility
  static const Color textSecondaryLight = textTertiary; // Was 6B7280
  static const Color textSecondaryDark = textSecondary; // Was 9CA3AF

  // Existing colors (kept for compatibility, but mapped where possible)
  static const Color primary = redAccent; // Mapping primary to new red roughly
  static const Color secondary = blueIcon;
  static const Color emerald = greenAccent;

  static const Color backgroundLight =
      Color(0xFFF3F4F6); // Valid for light mode if needed?
  // The design specifically asks for Dark Mode #151924 as Main Background.

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: const Color(0xFFF3F4F6), // Light gray background
    cardColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
      surfaceContainerHighest:
          Color(0xFFFFFFFF), // For glass effects in light mode
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1F2937),
      outline: Color(0xFFE5E7EB),
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: const Color(0xFF1F2937),
      displayColor: const Color(0xFF111827),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF4B5563)),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundBlack,
    cardColor: const Color(0xFF1E2432), // Slightly lighter than bg
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: Color(0xFF1E2432),
      surfaceContainerHighest: Color(0xFF242B3D),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      outline: Color(0xFF2D3748),
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
    iconTheme: const IconThemeData(
      color: textPrimary,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1E2432),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1E2432),
      modalBackgroundColor: Color(0xFF1E2432),
    ),
  );
}
