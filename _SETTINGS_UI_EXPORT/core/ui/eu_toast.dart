import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';
import 'package:labirynt_premium/src/core/theme/eu_text_styles.dart';

class EuphireToast {
  static void show(BuildContext context, {required String message}) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child:
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          EuDesignTokens.nocturne,
                          EuDesignTokens.evergreen.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: EuDesignTokens.ember,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: EuTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, curve: Curves.easeOutQuad)
                  .slideY(
                    begin: -0.5,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad,
                  )
                  .then(delay: 2500.ms)
                  .fadeOut(duration: 400.ms, curve: Curves.easeInQuad)
                  .slideY(
                    begin: 0,
                    end: -0.5,
                    duration: 400.ms,
                    curve: Curves.easeInQuad,
                  ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 3500), () {
      overlayEntry.remove();
    });
  }
}
