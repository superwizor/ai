// EuphireToast — Apple HUD-style toast notification system.
//
// Uses Overlay instead of SnackBar to avoid "Floating SnackBar presented
// off screen" crashes caused by Scaffold layout constraints. The toast
// slides in from the top with a spring animation, dark glassmorphic pill.
//
// Usage:
//   EuphireToast.success(context, message: 'Zapisano zmiany');
//   EuphireToast.error(context, message: 'Błąd usunięcia');
//   EuphireToast.info(context, message: 'Skopiowano do schowka');

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/euphire_theme.dart';

class EuphireToast {
  EuphireToast._();

  static OverlayEntry? _currentEntry;
  static AnimationController? _currentController;

  /// Success toast (teal-green glow, check icon).
  static void success(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      accentColor: const Color(0xFF5EEDCC),
    );
  }

  /// Error toast (magma glow, error icon).
  static void error(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      icon: Icons.error_rounded,
      accentColor: EuphireColors.magma,
    );
  }

  /// Info toast (ember glow, info icon).
  static void info(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      icon: Icons.info_rounded,
      accentColor: EuphireColors.ember,
    );
  }

  /// Generic toast — Apple HUD style via Overlay (no SnackBar crashes).
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color accentColor = const Color(0xFF5EEDCC),
    Duration duration = const Duration(seconds: 2),
  }) {
    // Dismiss any existing toast immediately
    _dismiss();

    // Haptic feedback — error gets heavier tap
    if (accentColor == EuphireColors.magma) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final topPadding = MediaQuery.of(context).padding.top;

    // Create animation controller via the overlay's TickerProvider
    final controller = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _currentController = controller;

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: topPadding + 8,
        left: 20,
        right: 20,
        child: SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                // Swipe up to dismiss
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -100) {
                  _dismiss();
                }
              },
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xF0122A2D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 18, color: accentColor),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              message,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: EuphireColors.frostWhite,
                                height: 1.3,
                                letterSpacing: 0.1,
                                decoration: TextDecoration.none,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // Animate in
    controller.forward();

    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        _dismiss();
      }
    });
  }

  static void _dismiss() {
    final controller = _currentController;
    final entry = _currentEntry;

    if (controller != null && entry != null && entry.mounted) {
      _currentController = null;
      _currentEntry = null;

      controller.reverse().then((_) {
        if (entry.mounted) entry.remove();
        controller.dispose();
      });
    } else {
      if (entry != null && entry.mounted) entry.remove();
      controller?.dispose();
      _currentEntry = null;
      _currentController = null;
    }
  }
}
