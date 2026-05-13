import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:go_router/go_router.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Legal information section
///
/// Contains links to:
/// - Terms of Service
/// - Privacy Policy
/// - Software Licenses
class LegalSection extends ConsumerWidget {
  const LegalSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EuSection(
      header: context.l10n.settingsLegalHeader,
      children: [
        EuListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: context.l10n.settingsTermsTitle,
          subtitle: context.l10n.settingsTermsSubtitle,
          onTap: () {
            context.push('/legal-terms');
          },
        ),
        EuListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: context.l10n.settingsPrivacyTitle,
          subtitle: context.l10n.settingsPrivacySubtitle,
          onTap: () {
            context.push('/legal-privacy');
          },
        ),
        EuListTile(
          leading: const Icon(Icons.description_outlined),
          title: context.l10n.settingsLicensesTitle,
          subtitle: context.l10n.settingsLicensesSubtitle,
          onTap: () {
            context.push('/licenses');
          },
        ),
      ],
    );
  }
}
