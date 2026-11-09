import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF8E8AEF);
  static const Color backgroundColor = Color(0xFFF8F7FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF25233A);

  static const Color mutedTextColor = Color(0xFF77758B);
  static const Color borderColor = Color(0xFFEAE8F5);
  static const Color softPurpleColor = Color(0xFFEDEAFF);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: cardColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    ),

    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderColor),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 25,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: textColor),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: mutedTextColor),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: mutedTextColor),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    ),

    dividerColor: borderColor,
  );
}
