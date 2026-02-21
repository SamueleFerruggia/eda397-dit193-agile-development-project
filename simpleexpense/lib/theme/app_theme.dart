import 'package:flutter/material.dart';

/// Application theme configuration
class AppTheme {
  /// Font families
  static const String fontFamilyBody = 'DM Sans';
  static const String fontFamilyDisplay = 'Fraunces';

  /// Color palette
  static const Color background = Color(0xFFFBF7F2);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF000000);
  static const Color primary = Color(0xFFC26D4A);
  static const Color primaryDark = Color(0xFF8A3F2A);
  static const Color primaryLight = Color(0xFFF3C6B3);
  static const Color secondary = Color(0xFF7A9B76);
  static const Color secondaryDark = Color(0xFF3E5E4A);
  static const Color secondaryLight = Color(0xFFD7E6DA);
  static const Color success = Color(0xFF3F7D4C);
  static const Color warning = Color(0xFFD9A441);
  static const Color error = Color(0xFFC2413A);

  /// Primary color
  static const Color primaryColor = primary;

  /// Secondary color
  static const Color secondaryColor = secondary;

  /// Light theme data
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: textLight,
        primaryContainer: primaryLight,
        onPrimaryContainer: primaryDark,
        secondary: secondary,
        onSecondary: textLight,
        secondaryContainer: secondaryLight,
        onSecondaryContainer: secondaryDark,
        error: error,
        onError: textLight,
        surface: background,
        onSurface: textDark,
      ),
      textTheme: TextTheme(
        // Headers - Fraunces
        displayLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textDark,
          height: 1.2,
        ),
        displayMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
          height: 1.3,
        ),
        displaySmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        headlineLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        headlineMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        headlineSmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        titleMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        titleSmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        // Body / paragraph / caption - DM Sans
        bodyLarge: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textDark,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: secondaryDark,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: secondaryDark,
          height: 1.3,
        ),
        // Labels - Fraunces
        labelLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        labelMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        labelSmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: secondaryDark,
          height: 1.3,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamilyDisplay,
          color: textLight,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamilyDisplay,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: primary,
          foregroundColor: textLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamilyDisplay,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamilyDisplay,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 16,
          color: secondaryDark,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 16,
          color: secondaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: textLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Dark theme data (optional)
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        onPrimary: textDark,
        primaryContainer: primaryDark,
        onPrimaryContainer: primaryLight,
        secondary: secondaryLight,
        onSecondary: textDark,
        secondaryContainer: secondaryDark,
        onSecondaryContainer: secondaryLight,
        error: error,
        onError: textLight,
        surface: primaryDark,
        onSurface: textLight,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textLight,
          height: 1.2,
        ),
        displayMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textLight,
          height: 1.3,
        ),
        displaySmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        headlineLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        headlineMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        headlineSmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        titleMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        titleSmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        bodyLarge: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textLight,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: secondaryLight,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          fontFamily: fontFamilyBody,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: secondaryLight,
          height: 1.3,
        ),
        labelLarge: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        labelMedium: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textLight,
          height: 1.3,
        ),
        labelSmall: const TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: secondaryLight,
          height: 1.3,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamilyDisplay,
          color: textLight,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
