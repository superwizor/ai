import 'package:flutter/material.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// EUPHIRE styled section container (Apple Settings-style)
///
/// Groups related items with optional header and footer text.
///
/// Example:
/// ```dart
/// EuSection(
///   header: 'Ustawienia gry',
///   children: [
///     EuListTile(title: 'Dźwięki', trailing: EuToggle(...)),
///     EuListTile(title: 'Wibracje', trailing: EuToggle(...)),
///   ],
/// )
/// ```
class EuSection extends StatelessWidget {
  /// Section header text (displayed above)
  final String? header;

  /// Section footer/description text (displayed below)
  final String? footer;

  /// Section content (typically list of EuListTile widgets)
  final List<Widget> children;

  /// Divider between items
  final bool showDividers;

  /// Padding inside the section card
  final EdgeInsetsGeometry? contentPadding;

  const EuSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.showDividers = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final headerColor = isDarkMode
        ? Colors.white60
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.6);

    final footerColor = isDarkMode
        ? Colors.white38
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.45);

    final bgColor = isDarkMode ? EuDesignTokens.evergreen : Colors.white;

    final borderColor = isDarkMode
        ? EuDesignTokens.glassBorderDark
        : EuDesignTokens.glassBorderLight;

    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: EuDesignTokens.space16,
              bottom: EuDesignTokens.space8,
            ),
            child: Text(
              header!.toUpperCase(),
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: headerColor,
                letterSpacing: 1.5,
              ),
            ),
          ),

        // Content Card
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: EuDesignTokens.borderRadiusMedium,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: EuDesignTokens.borderRadiusMedium,
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  Padding(
                    padding: contentPadding ?? EdgeInsets.zero,
                    child: children[i],
                  ),
                  if (showDividers && i < children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: dividerColor,
                      indent: EuDesignTokens.space16,
                    ),
                ],
              ],
            ),
          ),
        ),

        // Footer
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: EuDesignTokens.space16,
              top: EuDesignTokens.space8,
              right: EuDesignTokens.space16,
            ),
            child: Text(
              footer!,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 12,
                color: footerColor,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple section header (without card container)
class EuSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const EuSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EuDesignTokens.space16,
        vertical: EuDesignTokens.space8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white60
                  : EuDesignTokens.obsidianBlack.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
