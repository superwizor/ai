import 'package:flutter/material.dart';

/// EUPHIRE Design Tokens - Single Source of Truth
///
/// Based on EUPHIRE Brand Book.
/// All colors, spacing, radii, and effects should come from here.
abstract final class EuDesignTokens {
  EuDesignTokens._();

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS - Primary Palette
  // ═══════════════════════════════════════════════════════════════════════════

  /// Ember - Primary accent color
  /// Usage: CTAs, highlights, active states
  /// Hex: #FCAE2F | RGB: 252, 174, 47
  static const Color ember = Color(0xFFFCAE2F);

  /// Evergreen - Main visual tone
  /// Usage: Backgrounds, surfaces
  /// Hex: #004D54 | RGB: 0, 77, 84
  static const Color evergreen = Color(0xFF004D54);

  /// Obsidian Black - Neutral base (dark)
  /// Usage: Text on light, dark elements
  /// Hex: #1F1F1F | RGB: 31, 31, 31
  static const Color obsidianBlack = Color(0xFF1F1F1F);
  static const Color ebonyBlack = obsidianBlack; // Alias for ease of use
  static const Color black =
      obsidianBlack; // Alias for standard black replacement

  /// Frost White - Neutral base (light)
  /// Usage: Text on dark, light backgrounds
  /// Hex: #FAFAFA | RGB: 250, 250, 250
  static const Color frostWhite = Color(0xFFFAFAFA);

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS - Complementary Palette
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mist - Subdued accent
  /// Usage: Secondary elements, disabled states
  /// Hex: #B2CACC | RGB: 178, 202, 204
  static const Color mist = Color(0xFFB2CACC);

  /// Nocturne - Depth color
  /// Usage: Gradients, large areas, deep backgrounds
  /// Hex: #002E32 | RGB: 0, 46, 50
  static const Color nocturne = Color(0xFF002E32);

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS - Accent Palette (Controlled, spot usage only)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Aurora - Spot accent (purple)
  /// Hex: #6759FF | RGB: 103, 89, 255
  static const Color aurora = Color(0xFF6759FF);

  /// Magma - Spot accent (red/orange)
  /// Hex: #D84515 | RGB: 216, 69, 21
  static const Color magma = Color(0xFFD84515);

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS - Deck Colors
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color deckYellow = Color(0xFFF5A623); // Labirynt Rozmów
  static const Color deckPurple = Color(0xFF6B5BFF); // Pokoje Duszy
  static const Color deckRed = Color(0xFFD64515); // Zbliżenia
  static const Color deckTeal = Color(0xFF2E8B94); // Rozwój
  static const Color deckClay = Color(0xFFC07A50); // Synergia
  static const Color deckMist = Color(0xFF8FA3AD); // Lodołamacz

  /// Blue Grey - History fallback
  static const Color blueGrey = Color(0xFF607D8B);

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS - Semantic
  // ═══════════════════════════════════════════════════════════════════════════

  /// Success color
  static const Color success = Color(0xFF4ADE80);

  /// Error/Destructive color
  static const Color error = Color(0xFFEF4444);

  /// Warning color
  static const Color warning = Color(0xFFFBBF24);

  /// Info color
  static const Color info = Color(0xFF3B82F6);

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS - Surface variants
  // ═══════════════════════════════════════════════════════════════════════════

  /// Glass surface (dark mode)
  static const Color glassDark = Color(0x1AFFFFFF); // 10% white
  static const Color glassWhite =
      glassDark; // Alias for semantic clarity on dark backgrounds

  /// Glass border (dark mode)
  static const Color glassBorderDark = Color(0x33FFFFFF); // 20% white

  /// Glass surface (light mode)
  static const Color glassLight = Color(0x0D000000); // 5% black

  /// Glass border (light mode)
  static const Color glassBorderLight = Color(0x1A000000); // 10% black

  // ═══════════════════════════════════════════════════════════════════════════
  // SPACING - 8-point grid system
  // ═══════════════════════════════════════════════════════════════════════════

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space56 = 56;
  static const double space64 = 64;

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Small radius - Buttons, toggles, inputs
  static const double radiusSmall = 6;

  /// Medium radius - Cards, tiles
  static const double radiusMedium = 12;

  /// Large radius - Modals, bottom sheets
  static const double radiusLarge = 20;

  /// Extra large radius - Special elements
  static const double radiusXLarge = 28;

  /// Full/Pill radius - Avatars, pills, badges
  static const double radiusFull = 999;

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS (as BorderRadius objects for convenience)
  // ═══════════════════════════════════════════════════════════════════════════

  static BorderRadius get borderRadiusSmall =>
      BorderRadius.circular(radiusSmall);
  static BorderRadius get borderRadiusMedium =>
      BorderRadius.circular(radiusMedium);
  static BorderRadius get borderRadiusLarge =>
      BorderRadius.circular(radiusLarge);
  static BorderRadius get borderRadiusXLarge =>
      BorderRadius.circular(radiusXLarge);
  static BorderRadius get borderRadiusFull => BorderRadius.circular(radiusFull);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENT SIZES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Button heights
  static const double buttonHeightSmall = 36;
  static const double buttonHeightMedium = 44;
  static const double buttonHeightLarge = 52;

  /// Icon sizes
  static const double iconSizeSmall = 16;
  static const double iconSizeMedium = 20;
  static const double iconSizeLarge = 24;
  static const double iconSizeXLarge = 32;

  /// Avatar sizes
  static const double avatarSizeSmall = 32;
  static const double avatarSizeMedium = 40;
  static const double avatarSizeLarge = 56;
  static const double avatarSizeXLarge = 80;

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Duration durationInstant = Duration(milliseconds: 50);
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVerySlow = Duration(milliseconds: 800);

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveSnap = Curves.easeOutBack;

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS & ELEVATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Subtle elevation - Cards, tiles
  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Medium elevation - Floating elements
  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  /// Large elevation - Modals, dialogs
  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// Ember glow - Primary CTA buttons
  static List<BoxShadow> shadowEmber({double opacity = 0.3}) => [
    BoxShadow(
      color: ember.withValues(alpha: opacity),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Aurora glow - Premium elements
  static List<BoxShadow> shadowAurora({double opacity = 0.3}) => [
    BoxShadow(
      color: aurora.withValues(alpha: opacity),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main background gradient (Evergreen → Nocturne)
  static const LinearGradient gradientBackground = LinearGradient(
    colors: [evergreen, nocturne],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Deep gradient (Nocturne → Obsidian)
  static const LinearGradient gradientDeep = LinearGradient(
    colors: [nocturne, obsidianBlack],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Ember gradient (for highlights)
  static LinearGradient get gradientEmber => LinearGradient(
    colors: [ember, ember.withValues(alpha: 0.8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASS MORPHISM DECORATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Glass card decoration for dark mode
  static BoxDecoration get glassDecorationDark => BoxDecoration(
    color: glassDark,
    borderRadius: borderRadiusMedium,
    border: Border.all(color: glassBorderDark),
  );

  /// Glass card decoration for light mode
  static BoxDecoration get glassDecorationLight => BoxDecoration(
    color: glassLight,
    borderRadius: borderRadiusMedium,
    border: Border.all(color: glassBorderLight),
  );
}
