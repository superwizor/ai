import 'package:flutter/material.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// EUPHIRE styled list tile for settings and lists
///
/// Standardized row component with consistent spacing and typography.
///
/// Example:
/// ```dart
/// EuListTile(
///   leading: Icon(Icons.dark_mode),
///   title: 'Tryb ciemny',
///   subtitle: 'Zmień wygląd aplikacji',
///   trailing: EuSwitchOnly(value: isDark, onChanged: toggle),
///   onTap: () => showDetail(),
/// )
/// ```
class EuListTile extends StatelessWidget {
  /// Leading widget (typically an icon)
  final Widget? leading;

  /// Primary title text
  final String title;

  /// Secondary subtitle text
  final String? subtitle;

  /// Trailing widget (toggle, icon, chevron)
  final Widget? trailing;

  /// Tap callback
  final VoidCallback? onTap;

  /// Show chevron indicator (auto-added if onTap is set and no trailing)
  final bool showChevron;

  /// Content padding
  final EdgeInsetsGeometry? contentPadding;

  /// Dense mode - reduced vertical padding
  final bool dense;

  /// Custom title color override
  final Color? titleColor;

  const EuListTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.contentPadding,
    this.dense = false,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final resolvedTitleColor =
        titleColor ??
        (isDarkMode ? EuDesignTokens.frostWhite : EuDesignTokens.obsidianBlack);

    final subtitleColor = isDarkMode
        ? Colors.white60
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.6);

    final iconColor = isDarkMode
        ? Colors.white70
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.7);

    // Automatically add chevron if onTap is set and no trailing widget
    final effectiveTrailing =
        trailing ??
        (showChevron || onTap != null
            ? Icon(
                Icons.chevron_right,
                size: EuDesignTokens.iconSizeMedium,
                color: iconColor.withValues(alpha: 0.5),
              )
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              contentPadding ??
              EdgeInsets.symmetric(
                horizontal: EuDesignTokens.space16,
                vertical: dense
                    ? EuDesignTokens.space8
                    : EuDesignTokens.space12,
              ),
          child: Row(
            children: [
              // Leading
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: iconColor,
                    size: EuDesignTokens.iconSizeLarge,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: EuDesignTokens.space12),
              ],

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: resolvedTitleColor,
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

              // Trailing
              if (effectiveTrailing != null) ...[
                const SizedBox(width: EuDesignTokens.space8),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.5,
                    ),
                    child: effectiveTrailing,
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

/// Simplified list tile for navigation items
class EuNavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const EuNavigationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return EuListTile(
      leading: Icon(icon, color: iconColor),
      title: title,
      onTap: onTap,
      showChevron: true,
    );
  }
}
