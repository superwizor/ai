import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Marketing and social media section
///
/// Contains:
/// - Share with friends button
/// - Social media icons
/// - Website link
class MarketingSection extends ConsumerWidget {
  const MarketingSection({super.key});

  // EUPHIRE social media links
  static const String _websiteUrl = 'https://euphire.pl/';
  static const String _facebookUrl = 'https://www.facebook.com/EUPHIRE/';
  static const String _instagramUrl = 'https://www.instagram.com/euphire_pl/';
  static const String _youtubeUrl = 'https://www.youtube.com/euphire';
  static const String _tiktokUrl = 'https://www.tiktok.com/@euphire7';

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        EuSnackbar.error(context, context.l10n.settingsUrlError(url));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;

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
            context.l10n.settingsMarketingHeader,
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
        ),

        // Share Button
        _ShareButton(onTap: () => Share.share(context.l10n.settingsShareText)),

        const SizedBox(height: EuDesignTokens.space16),

        // Website Button
        _WebsiteButton(onTap: () => _launchUrl(_websiteUrl, context)),

        const SizedBox(height: EuDesignTokens.space20),

        // Social Icons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIconButton(
              icon: FontAwesomeIcons.facebook,
              label: context.l10n.settingsFacebookLabel,
              url: _facebookUrl,
              onTap: (url) => _launchUrl(url, context),
            ),
            const SizedBox(width: EuDesignTokens.space16),
            _SocialIconButton(
              icon: FontAwesomeIcons.instagram,
              label: context.l10n.settingsInstagramLabel,
              url: _instagramUrl,
              onTap: (url) => _launchUrl(url, context),
            ),
            const SizedBox(width: EuDesignTokens.space16),
            _SocialIconButton(
              icon: FontAwesomeIcons.youtube,
              label: context.l10n.settingsYouTubeLabel,
              url: _youtubeUrl,
              onTap: (url) => _launchUrl(url, context),
            ),
            const SizedBox(width: EuDesignTokens.space16),
            _SocialIconButton(
              icon: FontAwesomeIcons.tiktok,
              label: context.l10n.settingsTikTokLabel,
              url: _tiktokUrl,
              onTap: (url) => _launchUrl(url, context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Share promo button
class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = EuDesignTokens.ember.withValues(
      alpha: isDarkMode ? 0.15 : 0.1,
    );
    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: EuDesignTokens.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.all(EuDesignTokens.space20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: EuDesignTokens.borderRadiusMedium,
            border: Border.all(
              color: EuDesignTokens.ember.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: EuDesignTokens.ember,
                size: 28,
              ),
              const SizedBox(width: EuDesignTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settingsSharePromoTitle,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      context.l10n.settingsSharePromoSubtitle,
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.share_rounded,
                size: 20,
                color: textColor.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Website button
class _WebsiteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _WebsiteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? EuDesignTokens.frostWhite.withValues(alpha: 0.05)
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.05);
    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: EuDesignTokens.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.all(EuDesignTokens.space16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: EuDesignTokens.borderRadiusMedium,
            border: Border.all(color: textColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.language_rounded,
                color: EuDesignTokens.ember,
                size: 24,
              ),
              const SizedBox(width: EuDesignTokens.space12),
              Expanded(
                child: Text(
                  context.l10n.settingsWebsiteLabel,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: textColor.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Social media icon button with Font Awesome icons
class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final void Function(String) onTap;

  const _SocialIconButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.7)
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.7);
    final bgColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : EuDesignTokens.obsidianBlack.withValues(alpha: 0.05);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}
