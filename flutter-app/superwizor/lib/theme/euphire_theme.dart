import 'package:flutter/material.dart';

class EuphireColors {
  static const Color ember = Color(0xFFFCAE2F);
  static const Color evergreen = Color(0xFF004D54);
  static const Color obsidianBlack = Color(0xFF1F1F1F);
  static const Color frostWhite = Color(0xFFFAFAFA);

  static const Color mist = Color(0xFFB2CACC);
  static const Color nocturne = Color(0xFF002E32);
  static const Color aurora = Color(0xFF6759FF);
  static const Color magma = Color(0xFFD84515);
}

class EuphireTheme {
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: EuphireColors.ember,
      scaffoldBackgroundColor: EuphireColors.evergreen,

      colorScheme: const ColorScheme.dark(
        primary: EuphireColors.ember,
        secondary: EuphireColors.mist,
        surface: EuphireColors.nocturne, // Slightly elevated from evergreen
        error: EuphireColors.magma,
        onPrimary: EuphireColors.obsidianBlack,
        onSecondary: EuphireColors.obsidianBlack,
        onSurface: EuphireColors.frostWhite,
        onError: EuphireColors.frostWhite,
      ),

      textTheme: TextTheme(
        // Headings (Montserrat)
        displayLarge: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),

        // Body Text (Merriweather)
        bodyLarge: const TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: EuphireColors.frostWhite,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: EuphireColors.frostWhite,
          height: 1.5,
        ),

        // Labels, Tags, Stamps (Roboto Mono)
        labelLarge: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.5,
          letterSpacing: 1.0,
        ),
        labelSmall: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: EuphireColors.mist,
          height: 1.5,
          letterSpacing: 0.5,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EuphireColors.ember,
          foregroundColor: EuphireColors.obsidianBlack,
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EuphireColors.nocturne,
        labelStyle: const TextStyle(fontFamily: 'Merriweather', color: EuphireColors.mist),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EuphireColors.ember, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EuphireColors.magma, width: 2),
        ),
      ),
    );
  }
}
