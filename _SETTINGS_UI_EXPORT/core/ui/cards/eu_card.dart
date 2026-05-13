import 'package:flutter/material.dart';
import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// EUPHIRE styled card with glass morphism effect
///
/// Example:
/// ```dart
/// EuCard(
///   child: Text('Card content'),
/// )
/// ```
class EuCard extends StatelessWidget {
  /// Card content
  final Widget child;

  /// Optional padding (defaults to 16)
  final EdgeInsetsGeometry? padding;

  /// Optional margin
  final EdgeInsetsGeometry? margin;

  /// Border radius override
  final BorderRadius? borderRadius;

  /// Background color override
  final Color? backgroundColor;

  /// Show border
  final bool showBorder;

  /// Enable shadow
  final bool enableShadow;

  /// Tap callback
  final VoidCallback? onTap;

  const EuCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
    this.enableShadow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final effectiveBgColor =
        backgroundColor ??
        (isDarkMode ? EuDesignTokens.glassDark : EuDesignTokens.glassLight);

    final borderColor = isDarkMode
        ? EuDesignTokens.glassBorderDark
        : EuDesignTokens.glassBorderLight;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: borderRadius ?? EuDesignTokens.borderRadiusMedium,
        border: showBorder ? Border.all(color: borderColor) : null,
        boxShadow: enableShadow ? EuDesignTokens.shadowSmall : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? EuDesignTokens.borderRadiusMedium,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(EuDesignTokens.space16),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? EuDesignTokens.borderRadiusMedium,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Elevated card variant with more prominent shadow
class EuElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const EuElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDarkMode ? EuDesignTokens.nocturne : Colors.white,
        borderRadius: EuDesignTokens.borderRadiusMedium,
        boxShadow: EuDesignTokens.shadowMedium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: EuDesignTokens.borderRadiusMedium,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(EuDesignTokens.space16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Outlined card with border only
class EuOutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final VoidCallback? onTap;

  const EuOutlinedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final effectiveBorderColor =
        borderColor ??
        (isDarkMode
            ? EuDesignTokens.glassBorderDark
            : EuDesignTokens.glassBorderLight);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: EuDesignTokens.borderRadiusMedium,
        border: Border.all(color: effectiveBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: EuDesignTokens.borderRadiusMedium,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(EuDesignTokens.space16),
            child: child,
          ),
        ),
      ),
    );
  }
}
