import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

enum EuSnackbarType { success, error, info, warning }

/// centralized Snackbar utility for EUPHIRE
class EuSnackbar {
  static OverlayEntry? _currentOverlay;
  static Timer? _currentTimer;

  static void show(
    BuildContext context, {
    required String message,
    EuSnackbarType type = EuSnackbarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    EdgeInsetsGeometry? margin,
  }) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    _currentTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;

    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case EuSnackbarType.success:
        backgroundColor = const Color(0xFF0F3935);
        icon = Icons.check_circle_outline;
        iconColor = EuDesignTokens.success;
        break;
      case EuSnackbarType.error:
        backgroundColor = const Color(0xFF0F3935);
        icon = Icons.error_outline;
        iconColor = EuDesignTokens.error;
        break;
      case EuSnackbarType.warning:
        backgroundColor = const Color(0xFF0F3935);
        icon = Icons.warning_amber_rounded;
        iconColor = EuDesignTokens.warning;
        break;
      case EuSnackbarType.info:
        backgroundColor = const Color(0xFF0F3935);
        icon = Icons.info_outline;
        iconColor = EuDesignTokens.ember;
        break;
    }

    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding:
                    margin ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child:
                    Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: iconColor, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (actionLabel != null && onAction != null)
                                TextButton(
                                  onPressed: () {
                                    _currentOverlay?.remove();
                                    _currentOverlay = null;
                                    _currentTimer?.cancel();
                                    onAction();
                                  },
                                  child: Text(
                                    actionLabel,
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                        .animate()
                        .slideY(
                          begin: -1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(),
              ),
            ),
          ),
        );
      },
    );

    _currentOverlay = entry;
    overlayState.insert(entry);

    _currentTimer = Timer(duration, () {
      if (_currentOverlay != null) {
        _currentOverlay?.remove();
        _currentOverlay = null;
      }
    });
  }

  // Convenience methods
  static void error(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) => show(
    context,
    message: message,
    type: EuSnackbarType.error,
    margin: margin,
  );

  static void success(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) => show(
    context,
    message: message,
    type: EuSnackbarType.success,
    margin: margin,
  );

  static void info(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) => show(
    context,
    message: message,
    type: EuSnackbarType.info,
    margin: margin,
  );

  static void warning(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) => show(
    context,
    message: message,
    type: EuSnackbarType.warning,
    margin: margin,
  );
}
