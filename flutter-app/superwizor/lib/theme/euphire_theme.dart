// EUPHIRE Design System — Superwizor AI
//
// Transplanted from Labirynt Premium's production theme (AppTheme/AppColors)
// with Superwizor-specific clinical-context adjustments.
//
// Font hierarchy (3-font system):
//   • Montserrat — headings, CTA buttons, navigation titles (SemiBold/Bold)
//   • Merriweather — body text, paragraphs, reading content (Regular/Italic)
//   • RobotoMono — labels, timestamps, technical data, overlines
//
// Color system:
//   • Evergreen (#004D54) → primary surface, backgrounds
//   • Nocturne (#002E32) → deep backgrounds, gradient terminus
//   • Ember (#FCAE2F) → primary accent, CTA, active states
//   • Frost White (#FAFAFA) → text on dark
//   • Mist (#B2CACC) → secondary text, disabled
//   • Obsidian (#1F1F1F) → text on light, dark elements
//   • Aurora (#6759FF) → premium elements
//   • Magma (#D84515) → errors, critical alerts

import 'package:flutter/material.dart';

// ─── Color Tokens ──────────────────────────────────────────

class EuphireColors {
  // Brand Core
  static const Color ember = Color(0xFFFCAE2F);
  static const Color evergreen = Color(0xFF004D54);
  static const Color obsidianBlack = Color(0xFF1F1F1F);
  static const Color frostWhite = Color(0xFFFAFAFA);

  // Complementary
  static const Color mist = Color(0xFFB2CACC);
  static const Color nocturne = Color(0xFF002E32);
  static const Color aurora = Color(0xFF6759FF);
  static const Color magma = Color(0xFFD84515);

  // Derived / UI-specific (matches Labirynt AppColors)
  static const Color deepTealBackground = Color(0xFF142428);
  static const Color surfaceTeal = Color(0xFF1F353A);
  static const Color glassBorder = Color(0xFF3A5055);

  // ── Gradients ──

  /// Standard background: Evergreen → Nocturne (top-down).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [evergreen, nocturne],
  );

  /// Deep gradient: Nocturne → Obsidian (diagonal).
  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [nocturne, obsidianBlack],
  );

  // ── Elevation & Shadows ──

  /// Ember Glow — main CTA buttons (matches Labirynt spec).
  static List<BoxShadow> get emberGlow => [
        BoxShadow(
          color: ember.withValues(alpha: 0.30),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Subtle card elevation (Shadow Small from design system).
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Medium elevation for dropdowns/floating (Shadow Medium).
  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Large elevation for modals (Shadow Large).
  static List<BoxShadow> get largeShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Glassmorphism Helpers ──

  /// Dark-mode glass surface (White 10% + blur).
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    double surfaceOpacity = 0.10,
    double borderOpacity = 0.20,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: surfaceOpacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
      ),
    );
  }
}

// ─── ThemeData ──────────────────────────────────────────────

class EuphireTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: EuphireColors.ember,
      scaffoldBackgroundColor: EuphireColors.evergreen,

      colorScheme: const ColorScheme.dark(
        primary: EuphireColors.ember,
        secondary: EuphireColors.mist,
        // "To co na wierzchu ma być jaśniejsze" — surface is a thin
        // white wash so elevated widgets sit lighter on the background.
        surface: Color(0x0CFFFFFF),
        error: EuphireColors.magma,
        onPrimary: EuphireColors.obsidianBlack,
        onSecondary: EuphireColors.obsidianBlack,
        onSurface: EuphireColors.frostWhite,
        onError: EuphireColors.frostWhite,
        surfaceContainer: EuphireColors.nocturne,
      ),

      // ── Typography ──
      // Matches Labirynt's 3-font hierarchy exactly.
      textTheme: TextTheme(
        // ── display* = Montserrat (big headings) ──
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
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 1.0,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.2,
        ),

        // ── headline/title = Montserrat (screen titles, section heads) ──
        headlineLarge: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.2,
          letterSpacing: 0.5,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.3,
        ),
        titleSmall: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
          height: 1.3,
          letterSpacing: 0.5,
        ),

        // ── body* = Montserrat (readable content) ──
        bodyLarge: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: EuphireColors.frostWhite,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: EuphireColors.frostWhite.withValues(alpha: 0.85),
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: EuphireColors.frostWhite.withValues(alpha: 0.6),
          height: 1.5,
        ),

        // ── label* = RobotoMono (technical, overlines, stamps) ──
        labelLarge: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: EuphireColors.ember,
          height: 1.5,
          letterSpacing: 1.5,
        ),
        labelMedium: TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: EuphireColors.frostWhite.withValues(alpha: 0.54),
          height: 1.5,
          letterSpacing: 1.0,
        ),
        labelSmall: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: EuphireColors.mist,
          height: 1.5,
          letterSpacing: 2.0,
        ),
      ),

      // ── AppBar ──
      // Matches Labirynt: transparent, centered, Montserrat title,
      // letter-spacing 2.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: EuphireColors.frostWhite),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: EuphireColors.frostWhite,
          letterSpacing: 2,
        ),
      ),

      // ── Buttons ──
      // Labirynt pattern: Ember bg, Obsidian fg, RobotoMono labels,
      // Ember Glow shadow, pill-ish radius.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EuphireColors.ember,
          foregroundColor: EuphireColors.obsidianBlack,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EuphireColors.frostWhite,
          side: BorderSide(
            color: EuphireColors.frostWhite.withValues(alpha: 0.2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EuphireColors.ember,
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ──
      // Glassmorphism input: White 10% fill, White 20% border, Ember focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        labelStyle: TextStyle(
          fontFamily: 'Merriweather',
          color: EuphireColors.frostWhite.withValues(alpha: 0.6),
          height: 1.1,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: EuphireColors.ember.withValues(alpha: 0.9),
          height: 1.1,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          color: EuphireColors.frostWhite.withValues(alpha: 0.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(
            color: EuphireColors.ember,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(
            color: EuphireColors.magma,
            width: 1.5,
          ),
        ),
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: EuphireColors.nocturne,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.10),
        thickness: 1,
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ),
      
      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EuphireColors.evergreen,
        contentTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
