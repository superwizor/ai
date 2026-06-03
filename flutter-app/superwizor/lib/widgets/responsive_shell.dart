import 'package:flutter/material.dart';

/// Responsive wrapper that constrains content width on wide screens
/// (desktop/tablet) while leaving mobile layout untouched.
///
/// Insert via [MaterialApp.builder] for a global, consistent effect.
///
/// On screens narrower than [mobileBreakpoint] the child renders
/// full-width with no constraint. Above that threshold, the child is
/// centered and capped at [maxContentWidth].
///
/// The background colour is drawn full-bleed behind the constrained
/// content so there's no ugly white strip on the sides.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxContentWidth = 640,
    this.mobileBreakpoint = 600,
  });

  final Widget child;

  /// Maximum logical-pixel width for the content area on wide screens.
  final double maxContentWidth;

  /// Below this width the shell is a transparent passthrough.
  final double mobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Mobile / narrow — don't touch the layout at all.
    if (screenWidth < mobileBreakpoint) return child;

    // Wide screen — full-bleed background + centered, constrained content.
    // The background teal comes from the app's dominant surface colour
    // so both login (gradient) and home (solid) screens look natural.
    return ColoredBox(
      color: const Color(0xFF002E32), // EuphireColors.nocturne
      child: Center(
        child: SizedBox(
          width: maxContentWidth,
          child: child,
        ),
      ),
    );
  }
}
