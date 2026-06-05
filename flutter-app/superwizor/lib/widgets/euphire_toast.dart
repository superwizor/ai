// EuphireToast — Apple HUD-style toast notification system.
//
// Architecture (3-layer):
//   EuphireToast          — Public API (static methods, zero state)
//   _ToastManager         — Singleton lifecycle owner (overlay, animation, timer)
//   _EuphireToastWidget   — Pure UI (reads MediaQuery from its own overlay context)
//
// The widget lives in the root Overlay, so its BuildContext always reflects
// the physical window — viewPadding (notch, Dynamic Island, status bar),
// disableAnimations (Reduce Motion), textScaler (Large Text) all Just Work
// regardless of whether the caller invoked the toast from a bottom sheet,
// a dialog, or a deeply nested route.
//
// Usage:
//   EuphireToast.success(context, message: 'Zapisano zmiany');
//   EuphireToast.error(context, message: 'Błąd usunięcia');
//   EuphireToast.info(context, message: 'Skopiowano do schowka');

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/euphire_theme.dart';

// ---------------------------------------------------------------------------
// Public API — call-site unchanged, all 50+ usages keep working.
// ---------------------------------------------------------------------------

class EuphireToast {
  EuphireToast._();

  static void success(BuildContext context, {required String message}) =>
      show(context, message: message, icon: Icons.check_circle_rounded, accentColor: const Color(0xFF5EEDCC));

  static void error(BuildContext context, {required String message}) =>
      show(context, message: message, icon: Icons.error_rounded, accentColor: EuphireColors.magma);

  static void info(BuildContext context, {required String message}) =>
      show(context, message: message, icon: Icons.info_rounded, accentColor: EuphireColors.ember);

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color accentColor = const Color(0xFF5EEDCC),
    Duration duration = const Duration(seconds: 2),
  }) {
    _ToastManager.instance.show(context, message: message, icon: icon, accentColor: accentColor, duration: duration);
  }
}

// ---------------------------------------------------------------------------
// Singleton lifecycle manager — owns overlay entry, animation, auto-dismiss.
// ---------------------------------------------------------------------------

class _ToastManager {
  _ToastManager._();
  static final instance = _ToastManager._();

  OverlayEntry? _entry;
  AnimationController? _controller;

  void show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color accentColor,
    required Duration duration,
  }) {
    _dismiss();

    (accentColor == EuphireColors.magma)
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact();

    final overlay = Overlay.of(context, rootOverlay: true);

    final controller = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _controller = controller;

    // Build animations once here — they depend only on the controller,
    // not on any BuildContext, so they are stable for the toast's lifetime.
    final slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
    );
    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _EuphireToastWidget(
        slide: slide,
        fade: fade,
        message: message,
        icon: icon,
        accentColor: accentColor,
        onDismiss: _dismiss,
      ),
    );
    _entry = entry;

    overlay.insert(entry);
    controller.forward();

    Future.delayed(duration, () {
      if (_entry == entry) _dismiss();
    });
  }

  void _dismiss() {
    final controller = _controller;
    final entry = _entry;
    _controller = null;
    _entry = null;

    if (controller == null || entry == null) return;
    if (!entry.mounted) {
      controller.dispose();
      return;
    }

    controller.reverse().then((_) {
      if (entry.mounted) entry.remove();
      controller.dispose();
    });
  }
}

// ---------------------------------------------------------------------------
// Pure UI — reads MediaQuery from its own (root overlay) context.
// ---------------------------------------------------------------------------

class _EuphireToastWidget extends StatelessWidget {
  const _EuphireToastWidget({
    required this.slide,
    required this.fade,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.onDismiss,
  });

  final Animation<Offset> slide;
  final Animation<double> fade;
  final String message;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // viewPadding = physical system chrome (notch / Dynamic Island / status bar).
    // Unlike MediaQuery.padding, it is never consumed/zeroed by ancestors.
    // No clamp — viewPadding is already correct per-device:
    //   iPhone SE (no notch): ~20pt   iPhone 14 (notch): ~47pt
    //   iPhone 14 Pro (DI):   ~59pt   Android (punch-hole): ~24-48pt
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget pill = _buildPill(context);
    if (!reduceMotion) {
      pill = SlideTransition(position: slide, child: pill);
    }

    return Positioned(
      top: topInset + 12,
      left: 20,
      right: 20,
      child: FadeTransition(opacity: fade, child: pill),
    );
  }

  Widget _buildPill(BuildContext context) {
    return Semantics(
      label: message,
      liveRegion: true,
      child: GestureDetector(
        onTap: onDismiss,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -100) onDismiss();
        },
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xF0122A2D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.15), blurRadius: 24, spreadRadius: -2),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
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
                      child: ExcludeSemantics(
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
                          maxLines: MediaQuery.textScalerOf(context).scale(13) > 16 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
