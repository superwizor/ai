import 'package:flutter/material.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// EUPHIRE styled toggle switch (Apple-style)
///
/// Active state uses Ember color (#FCAE2F) for clear ON indication.
///
/// Example:
/// ```dart
/// EuToggle(
///   value: isDarkMode,
///   onChanged: (value) => toggleDarkMode(value),
///   label: 'Tryb ciemny',
///   subtitle: 'Dostosuj wygląd aplikacji',
/// )
/// ```
class EuToggle extends StatelessWidget {
  /// Current toggle value
  final bool value;

  /// Callback when value changes. Null disables the toggle.
  final ValueChanged<bool>? onChanged;

  /// Optional primary label text
  final String? label;

  /// Optional secondary/description text
  final String? subtitle;

  /// Leading icon
  final IconData? icon;

  /// Show toggle on the left side instead of right
  final bool toggleFirst;

  const EuToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.subtitle,
    this.icon,
    this.toggleFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onChanged == null;

    final labelColor = isDarkMode
        ? (isDisabled ? Colors.white38 : Colors.white)
        : (isDisabled
              ? EuDesignTokens.obsidianBlack.withValues(alpha: 0.38)
              : EuDesignTokens.obsidianBlack);

    final subtitleColor = isDarkMode
        ? (isDisabled ? Colors.white24 : Colors.white60)
        : (isDisabled
              ? EuDesignTokens.obsidianBlack.withValues(alpha: 0.24)
              : EuDesignTokens.obsidianBlack.withValues(alpha: 0.6));

    final toggle = _buildSwitch(isDarkMode, isDisabled);

    return InkWell(
      onTap: isDisabled ? null : () => onChanged?.call(!value),
      borderRadius: EuDesignTokens.borderRadiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: EuDesignTokens.space12,
          horizontal: EuDesignTokens.space4,
        ),
        child: Row(
          children: [
            if (toggleFirst) ...[
              toggle,
              const SizedBox(width: EuDesignTokens.space12),
            ],
            if (icon != null) ...[
              Icon(
                icon,
                size: EuDesignTokens.iconSizeLarge,
                color: value ? EuDesignTokens.ember : labelColor,
              ),
              const SizedBox(width: EuDesignTokens.space12),
            ],
            if (label != null || subtitle != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null)
                      Text(
                        label!,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 12,
                          color: subtitleColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (!toggleFirst) toggle,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(bool isDarkMode, bool isDisabled) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      // Active state: Ember color for clear ON indication
      activeThumbColor: EuDesignTokens.ember,
      activeTrackColor: EuDesignTokens.ember.withValues(alpha: 0.5),
      // Inactive state
      inactiveThumbColor: isDarkMode ? Colors.white70 : Colors.grey.shade400,
      inactiveTrackColor: isDarkMode
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.grey.shade300,
      // Disabled appearance handled by opacity
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey;
        }
        if (states.contains(WidgetState.selected)) {
          return EuDesignTokens.frostWhite;
        }
        return isDarkMode ? Colors.white70 : Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.withValues(alpha: 0.3);
        }
        if (states.contains(WidgetState.selected)) {
          return EuDesignTokens.ember;
        }
        return isDarkMode
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.grey.shade300;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}

/// Standalone toggle switch without label
class EuSwitchOnly extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const EuSwitchOnly({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: EuDesignTokens.ember,
      activeTrackColor: EuDesignTokens.ember.withValues(alpha: 0.5),
      inactiveThumbColor: isDarkMode ? Colors.white70 : Colors.grey.shade400,
      inactiveTrackColor: isDarkMode
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.grey.shade300,
    );
  }
}
