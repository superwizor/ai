import 'package:flutter/material.dart';
import 'app_theme.dart';

/// EUPHIRE Typography System
///
/// Standardized text styles for consistent typography across the application.
/// Usage:
/// ```dart
/// Text('Hello', style: EuTextStyles.h1)
/// ```
class EuTextStyles {
  EuTextStyles._();

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extra Large Heading - Splash screens, Hero sections
  static TextStyle get h1 => const TextStyle(
    fontFamily: 'Merriweather',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: AppColors.ember,
  );

  /// Large Heading - Section headers
  static TextStyle get h2 => const TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.frostWhite,
    letterSpacing: 1.0,
  );

  /// Medium Heading - Card titles, modal headers
  static TextStyle get h3 => const TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.frostWhite,
  );

  /// Small Heading - Subsections
  /// Used in: Quiz question types
  static TextStyle get h4 => const TextStyle(
    fontFamily: 'Merriweather',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.frostWhite,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BODY TEXT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Large Body - Main content, intros
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: 'Merriweather',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.frostWhite,
    height: 1.5,
  );

  /// Medium Body - Standard descriptions
  static TextStyle get bodyMedium => TextStyle(
    fontFamily: 'Merriweather',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.frostWhite.withValues(alpha: 0.8),
    height: 1.5,
  );

  /// Small Body - Hints, footnotes
  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'Merriweather',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.frostWhite.withValues(alpha: 0.6),
    height: 1.4,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // UI / LABEL TEXT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Button Text - Primary actions
  static TextStyle get button => const TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.obsidianBlack,
    letterSpacing: 0.5,
  );

  /// Caption - Tiny text, photo captions
  static TextStyle get caption => TextStyle(
    fontFamily: 'Merriweather',
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.frostWhite.withValues(alpha: 0.5),
    height: 1.4,
  );

  /// Label Large - Input labels, section tags
  static TextStyle get labelLarge => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.frostWhite.withValues(alpha: 0.9),
  );

  /// Label Small - Metadata, timestamps
  static TextStyle get labelSmall => TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.frostWhite.withValues(alpha: 0.5),
    letterSpacing: 1.0,
  );
}
