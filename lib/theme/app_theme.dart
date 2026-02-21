import 'package:flutter/material.dart';

class AppTheme {
  // 🔥 Colors
  static const primaryBlue = Color(0xFF0D47A1);
  static const accentOrange = Color(0xFFFF6D00);
  static const backgroundWhite = Color(0xFFF5F5F7);
  static const textDark = Color(0xFF1A1A1A);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundWhite,
    primaryColor: primaryBlue,
    fontFamily: 'Roboto',

    // ✅ Text Theme
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textDark),
      bodyMedium: TextStyle(color: textDark),
      titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle:
          TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: const Color(0x660D47A1),
      ),
    ),

    // 🔴 FIX IS HERE: CardTheme -> CardThemeData
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x1A000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
