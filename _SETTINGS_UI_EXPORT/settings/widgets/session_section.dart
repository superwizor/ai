import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/providers/session_provider.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';

/// Session management section
///
/// Allows user to reset game progress and start fresh.
class SessionSection extends ConsumerWidget {
  const SessionSection({super.key});

  Future<bool?> _showResetConfirmationDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? EuDesignTokens.nocturne : Colors.white;
    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: EuDesignTokens.borderRadiusMedium,
        ),
        title: Text(
          context.l10n.settingsSessionResetConfirmTitle,
          style: TextStyle(
            fontFamily: 'Merriweather',
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context.l10n.settingsSessionResetConfirmContent,
          style: TextStyle(
            fontFamily: 'Merriweather',
            color: textColor.withValues(alpha: 0.7),
            height: 1.5,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              context.l10n.settingsSessionResetConfirmCancel,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: textColor.withValues(alpha: 0.54),
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              context.l10n.settingsSessionResetConfirmReset,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: EuDesignTokens.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? EuDesignTokens.glassDark : Colors.white;
    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;
    final subtitleColor = textColor.withValues(alpha: 0.54);
    final borderColor = isDarkMode
        ? EuDesignTokens.glassBorderDark
        : EuDesignTokens.glassBorderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(
            left: EuDesignTokens.space16,
            bottom: EuDesignTokens.space8,
          ),
          child: Text(
            context.l10n.settingsSessionHeader,
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
        ),

        // Session Card
        Container(
          padding: const EdgeInsets.all(EuDesignTokens.space20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: EuDesignTokens.borderRadiusMedium,
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: isDarkMode ? null : EuDesignTokens.shadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.settingsSessionNewGameTitle,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: EuDesignTokens.space8),
              Text(
                context.l10n.settingsSessionNewGameDescription,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: EuDesignTokens.space16),
              SizedBox(
                width: double.infinity,
                child: EuButton.ghost(
                  label: context.l10n.settingsSessionNewGameButton,
                  leadingIcon: Icons.refresh,
                  onPressed: () async {
                    final confirm = await _showResetConfirmationDialog(context);
                    if (confirm == true) {
                      AppHaptics.lightImpact(ref);
                      ref.read(sessionProvider.notifier).resetSession();
                      if (context.mounted) {
                        EuSnackbar.success(
                          context,
                          context.l10n.settingsSessionResetSuccess,
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
