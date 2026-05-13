import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Support section with help links
///
/// Contains:
/// - Instructions link
/// - Feedback/bug report link
class SupportSection extends ConsumerWidget {
  const SupportSection({super.key});

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        EuSnackbar.error(context, context.l10n.settingsUrlError(url));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EuSection(
      header: context.l10n.settingsSupportHeader,
      children: [
        EuListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: context.l10n.settingsInstructionsTitle,
          subtitle: context.l10n.settingsInstructionsSubtitle,
          onTap: () {
            context.push('/instructions');
          },
        ),
        EuListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: context.l10n.settingsFeedbackTitle,
          subtitle: context.l10n.settingsFeedbackSubtitle,
          onTap: () => _launchUrl('mailto:kontakt@euphire.pl', context),
        ),
      ],
    );
  }
}
