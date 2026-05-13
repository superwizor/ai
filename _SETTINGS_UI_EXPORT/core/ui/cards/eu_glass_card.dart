import 'dart:ui';
import 'package:flutter/material.dart';

/// EUPHIRE Glass Card Component
///
/// A glassmorphism-style card used throughout the app for containers,
/// list items, and interactive elements. Provides consistent styling
/// with customizable blur, opacity, and border.
///
/// Example:
/// ```dart
/// EuGlassCard(
///   child: Text("Content here"),
///   padding: EdgeInsets.all(16),
/// )
/// ```
class EuGlassCard extends StatelessWidget {
  /// Child widget to display inside the card
  final Widget child;

  /// Padding inside the card
  final EdgeInsetsGeometry padding;

  /// Border radius (defaults to 20)
  final double borderRadius;

  /// Background opacity (0.0 to 1.0)
  final double backgroundOpacity;

  /// Border opacity (0.0 to 1.0)
  final double borderOpacity;

  /// Whether to apply blur effect (glassmorphism)
  final bool enableBlur;

  /// Blur strength (only applies if enableBlur is true)
  final double blurStrength;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  const EuGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.backgroundOpacity = 0.05,
    this.borderOpacity = 0.1,
    this.enableBlur = false,
    this.blurStrength = 10,
    this.onTap,
  });

  /// Creates a card with higher opacity for emphasized content
  const EuGlassCard.emphasized({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.backgroundOpacity = 0.1,
    this.borderOpacity = 0.15,
    this.enableBlur = true,
    this.blurStrength = 15,
    this.onTap,
  });

  /// Creates a subtle card for list items
  const EuGlassCard.listItem({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 16,
    this.backgroundOpacity = 0.05,
    this.borderOpacity = 0.08,
    this.enableBlur = false,
    this.blurStrength = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: borderOpacity)
        : Colors.black.withValues(alpha: borderOpacity * 0.5);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );

    // Apply blur if enabled
    if (enableBlur) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
          child: content,
        ),
      );
    }

    // Wrap with gesture detector if onTap is provided
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

/// EUPHIRE Glass Container - simpler version without card semantics
///
/// Use this for simple background containers that don't need
/// card-like behavior.
class EuGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const EuGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}
