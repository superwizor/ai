import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color ember = Color(0xFFFCAE2F); // Yellow/Gold
  static const Color evergreen = Color(0xFF004D54); // Dark Teal (lighter)
  static const Color nocturne = Color(0xFF013E44); // Deep Teal (Background)
  static const Color softWhite = Color(0xFFF9FBF7); // Sage-tinted white
  static const Color sageActive = Color(
    0xFFE8EDE3,
  ); // Soft green for active pills

  // Superwizor Inspired
  static const Color deepTealBackground = Color(0xFF142428); // Based on images
  static const Color surfaceTeal = Color(
    0xFF1F353A,
  ); // Slightly lighter for cards
  static const Color glassBorder = Color(0xFF3A5055); // Thin border
  static const Color textLight = Color(0xFFE0E6E7);

  static const Color obsidianBlack = Color(0xFF1A1A1A); // Dark elements
  static const Color frostWhite = Color(0xFFFAFAFA);
  static const Color mist = Color(0x99FFFFFF); // Semi-transparent white

  // Deck Colors
  static const Color deckYellow = Color(0xFFF5A623); // Labirynt Rozmów
  static const Color deckPurple = Color(0xFF6B5BFF); // Pokoje Duszy
  static const Color deckRed = Color(0xFFD64515); // Zbliżenia
  static const Color deckTeal = Color(0xFF2E8B94); // Rozwój
  static const Color deckClay = Color(0xFFC07A50); // Synergia
  static const Color deckMist = Color(0xFF8FA3AD); // Lodołamacz

  // Typography - Static Access for direct usage if needed
  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Merriweather',
      fontSize: 32,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: ember,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: frostWhite,
      letterSpacing: 1.0,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: frostWhite,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Merriweather',
      fontSize: 16,
      color: frostWhite,
      height: 1.5,
    ),
    labelSmall: TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 12,
      letterSpacing: 2.0,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ),
  );

  static LinearGradient getGradient(Color baseColor) {
    if (baseColor == nocturne) {
      return const LinearGradient(
        colors: [Color(0xFF064E55), Color(0xFF002E32)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // Fallback gradient
    return LinearGradient(
      colors: [baseColor.withValues(alpha: 0.8), baseColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.nocturne, // Deep background
      primaryColor: AppColors.ember,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.ember,
        secondary: AppColors.evergreen,
        surface: AppColors.obsidianBlack,
        onSurface: AppColors.frostWhite,
        surfaceContainer: AppColors
            .nocturne, // Correct usage for bg in M3 if needed, or stick to surface
      ),

      textTheme: TextTheme(
        // Headlines: Montserrat
        displayLarge: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.ember,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.frostWhite,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.frostWhite,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),

        // Paragraphs: Merriweather
        bodyLarge: const TextStyle(
          fontFamily: 'Merriweather',
          color: AppColors.frostWhite,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Merriweather',
          color: AppColors.mist,
          fontSize: 14,
          height: 1.5,
        ),

        // Technical / UI: Roboto Mono
        labelLarge: const TextStyle(
          fontFamily: 'RobotoMono',
          color: AppColors.ember,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
        labelMedium: const TextStyle(
          fontFamily: 'RobotoMono',
          color: Colors.white54,
          fontSize: 12,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat', // Fallback, uses TextTheme primarily
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.frostWhite,
          letterSpacing: 2,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ember,
          foregroundColor: AppColors.obsidianBlack,
          textStyle: const TextStyle(
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(
        0xFFF2F4F7,
      ), // Light Cool Grey for contrast
      primaryColor: AppColors.ember,

      colorScheme: const ColorScheme.light(
        primary: AppColors.ember,
        secondary: AppColors.evergreen,
        surface: Colors.white,
        onSurface: AppColors.obsidianBlack,
        surfaceContainer: AppColors.frostWhite,
      ),

      textTheme: TextTheme(
        // Headlines: Montserrat
        displayLarge: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.ember,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.obsidianBlack,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.obsidianBlack,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),

        // Paragraphs: Merriweather
        bodyLarge: const TextStyle(
          fontFamily: 'Merriweather',
          color: AppColors.obsidianBlack,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Merriweather',
          color: AppColors.obsidianBlack.withValues(alpha: 0.8),
          fontSize: 14,
          height: 1.5,
        ),

        // Technical / UI: Roboto Mono
        labelLarge: const TextStyle(
          fontFamily: 'RobotoMono',
          color: AppColors.ember,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
        labelMedium: const TextStyle(
          fontFamily: 'RobotoMono',
          color: Colors.black54,
          fontSize: 12,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.obsidianBlack), // Black icons
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.obsidianBlack,
          letterSpacing: 2,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ember,
          foregroundColor: AppColors.obsidianBlack,
          textStyle: const TextStyle(
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // Expose textTheme from AppColors for convenience as 'AppTheme.textTheme' was requested
  static TextTheme get textTheme => AppColors.textTheme;
}
