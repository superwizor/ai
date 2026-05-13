import 'package:flutter/material.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

class EuErrorWidget extends StatelessWidget {
  final Object error; // In RSOD this will be used as the Title
  final VoidCallback? onRetry;
  final String?
  customMessage; // Legacy prop, used as subtitle if subtitle is null
  final String? subtitle;
  final String? retryText;

  const EuErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
    this.subtitle,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    // If error is purely a custom String from RSOD, we use it as the main title
    final bool isCustomTitle = error is String;
    final String title = isCustomTitle ? error as String : 'Coś poszło nie tak';

    final String message =
        subtitle ??
        customMessage ??
        "Mamy problem z odświeżeniem tego widoku. Spróbuj ponownie.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3935).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: EuDesignTokens.error.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EuDesignTokens.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: EuDesignTokens.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      (retryText ?? 'SPRÓBUJ PONOWNIE').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
