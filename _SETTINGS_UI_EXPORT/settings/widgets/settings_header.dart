import 'package:flutter/material.dart';

import 'package:labirynt_premium/src/core/theme/app_theme.dart';
import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Settings screen header with logo and title
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    bool canPop = false;
    try {
      // Use ModalRoute.isFirst to check if this specific route can be popped.
      // This avoids false positives when a modal is open (like the language selector).
      canPop = ModalRoute.of(context)?.isFirst == false;
    } catch (_) {
      // Ignore exception related to deactivated ancestor during language change
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: EuDesignTokens.space24,
        right: EuDesignTokens.space16,
        top: EuDesignTokens.space16,
        bottom: EuDesignTokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Close Button on same row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  context.l10n.settingsTitle,
                  style: AppTheme.textTheme.displayLarge?.copyWith(
                    color: EuDesignTokens.ember,
                  ),
                ),
              ),
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),

          const SizedBox(height: EuDesignTokens.space8),

          // Subtitle
          Text(
            context.l10n.settingsSubtitle,
            style: AppTheme.textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
