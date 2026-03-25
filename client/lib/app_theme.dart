import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────
  static const Color bg = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF111111);
  static const Color green = Color(0xFF00FF41);
  static const Color greenDim = Color(0xFF006B1C);
  static const Color greenDark = Color(0xFF001A07);
  static const Color cyan = Color(0xFF00FFFF);
  static const Color amber = Color(0xFFFFAA00);
  static const Color red = Color(0xFFFF3333);
  static const Color border = Color(0xFF1A3A1A);
  static const Color textDim = Color(0xFF4A7A4A);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: green,
          secondary: cyan,
          surface: surface,
          error: red,
          onPrimary: bg,
          onSurface: green,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: green,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'monospace',
            color: green,
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: green),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: green,
          unselectedItemColor: Color(0xFF2A4A2A),
          selectedLabelStyle: TextStyle(
              fontFamily: 'monospace', fontSize: 10, letterSpacing: 1),
          unselectedLabelStyle: TextStyle(
              fontFamily: 'monospace', fontSize: 10, letterSpacing: 1),
          elevation: 0,
        ),
        dividerColor: border,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'monospace', color: green),
          bodyMedium: TextStyle(fontFamily: 'monospace', color: green),
          bodySmall: TextStyle(fontFamily: 'monospace', color: textDim),
          labelLarge: TextStyle(fontFamily: 'monospace', color: green),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
              borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: green)),
          labelStyle: TextStyle(fontFamily: 'monospace', color: textDim),
          hintStyle: TextStyle(fontFamily: 'monospace', color: Color(0xFF2A4A2A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: greenDark,
            foregroundColor: green,
            side: const BorderSide(color: green),
            textStyle: const TextStyle(
                fontFamily: 'monospace', letterSpacing: 2),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero),
          ),
        ),
      );
}
