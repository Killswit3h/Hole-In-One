import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color accentGreen = Color(0xFF81C784);
  static const Color darkBg = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF2A2A2A);
  static const Color textSecondary = Color(0xFF9E9E9E);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primaryGreen,
          secondary: accentGreen,
          surface: surfaceColor,
        ),
        scaffoldBackgroundColor: darkBg,
        cardColor: cardColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(220, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryGreen,
            side: const BorderSide(color: primaryGreen, width: 1.5),
            minimumSize: const Size(220, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 15),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
          labelLarge: TextStyle(
            color: primaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        dividerColor: const Color(0xFF2E2E2E),
        iconTheme: const IconThemeData(color: primaryGreen),
      );
}
