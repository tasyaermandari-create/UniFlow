import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF4385F5);
  static const Color secondary = Color(0xFF75A9FF);
  static const Color softBlue = Color(0xFFDBEAFE);
  static const Color lightBlue = Color(0xFFF0F6FF);
  static const Color background = Color(0xFFF5F8FF);
  static const Color navy = Color(0xFF172554);
  static const Color grey = Color(0xFF718096);
  static const Color white = Colors.white;

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: navy,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        hintStyle: const TextStyle(color: grey),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: softBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: softBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  static BoxDecoration cardDecoration({
    Color color = white,
    double radius = 22,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration blueGradient({double radius = 22}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF78AEFF), Color(0xFF4385F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.20),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}
