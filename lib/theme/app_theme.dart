import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🎨 MASTER COLOR PALETTE (ClickOut Design System)
class AppColors {
  // Primary
  static const brandGreen = Color(0xFF16a34a);
  static const deepGreen = Color(0xFF052e16);
  static const mintSurface = Color(0xFFdcfce7);
  static const appBg = Color(0xFFf0fdf4);

  // Accents
  static const flashYellow = Color(0xFFf59e0b);
  static const rewardPurple = Color(0xFF7c3aed);
  static const trustBlue = Color(0xFF0ea5e9);
  static const errorRed = Color(0xFFef4444);

  // Neutrals
  static const white = Color(0xFFffffff);
  static const surface = Color(0xFFf9fafb);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6b7280);
  static const border = Color(0xFFe5e7eb);

  // 🚀 LEGACY COLORS (UNCOMMENTED: To fix errors in older screens)
  static const primaryBlue = Color(0xFF0D47A1);
  static const accentOrange = Color(0xFFFF6D00);
  static const backgroundWhite = Color(0xFFF5F5F7);
  static const textDark = Color(0xFF1A1A1A);
}

// 🔤 MASTER TYPOGRAPHY SYSTEM (🚀 Updated with Local Fonts)
class AppTextStyles {
  // Headings & Display: SairaStencil
  static TextStyle heroNumber = const TextStyle(
      fontFamily: 'SairaStencil',
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: AppColors.brandGreen);

  static TextStyle screenTitle = const TextStyle(
      fontFamily: 'SairaStencil',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);

  static TextStyle sectionHead = const TextStyle(
      fontFamily: 'SairaStencil',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);

  // Body & Labels: ShareTech
  static TextStyle body = const TextStyle(
      fontFamily: 'ShareTech',
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary);

  static TextStyle meta = const TextStyle(
      fontFamily: 'ShareTech',
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary);

  static TextStyle badge = const TextStyle(
      fontFamily: 'SairaStencil', // Using stencil for punchy badges
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.08,
      color: AppColors.white);
}

class AppTheme {
  // ⚠️ LEGACY COLORS (Temporary: to keep old screens alive during redesign)
  static const primaryBlue = Color(0xFF0D47A1);
  static const accentOrange = Color(0xFFFF6D00);
  static const backgroundWhite = Color(0xFFF5F5F7);
  static const textDark = Color(0xFF1A1A1A);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.appBg,
    primaryColor: AppColors.brandGreen,

    // Default Text Theme injection
    textTheme: GoogleFonts.dmSansTextTheme().copyWith(
      titleLarge: AppTextStyles.screenTitle,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: AppColors.brandGreen.withOpacity(0.4),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 2,
      shadowColor: const Color(0x1A000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
