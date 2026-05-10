// AddPatientModal — Etap 2 / Task 2.2
//
// Pola:
//   - Alias / pseudonim pacjenta
//   - Nurt sesji (z profilu — domyślny; w MVP po prostu CBT fallback
//     dopóki TherapistSetupScreen nie zapisze profilu)
//   - Język sesji (PL only — D7)
//   - **Checkbox zgody RODO/DPA (D8)** — wymagany; bez niego primary
//     button jest disabled. Próba bypassu pokazuje "Brak zgody"
//     bottom sheet (D9 → LocalConsentService).
// Po zapisie pacjenta wołamy `ConsentService.recordConsent()` z
// `documentVersion: 'dpa-v1-2026-04'` zanim Navigator.pop.

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../screens/legal_pdf_screen.dart';
import '../theme/euphire_theme.dart';
import 'euphire_action_sheet.dart';
import 'euphire_bottom_sheet.dart';
import 'euphire_button.dart';
import 'euphire_text_field.dart';

const String kCurrentDpaVersion = 'dpa-v1-2026-04';
const String kDpaAssetPath = 'assets/legal/DPA Superwizor AI.pdf';

class AddPatientModal extends ConsumerStatefulWidget {
  const AddPatientModal({super.key});

  @override
  ConsumerState<AddPatientModal> createState() => _AddPatientModalState();
}

class _AddPatientModalState extends ConsumerState<AddPatientModal> {
  final _aliasController = TextEditingController();
  bool _consentGiven = false;
  bool _saving = false;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final canSave =
        !_saving && _aliasController.text.trim().isNotEmpty && _consentGiven;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.addPatient_title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            EuphireTextField(
              controller: _aliasController,
              labelText: t.addPatient_alias_label,
            ),
            const SizedBox(height: 24),
            _ConsentCheckbox(
              value: _consentGiven,
              onChanged: (v) => setState(() => _consentGiven = v),
              labelText: t.addPatient_consent_label,
              linkLabel: t.addPatient_consent_link_label,
              onLinkTap: _openDpa,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: EuphireButton(
                text: t.addPatient_save_primary,
                isLoading: _saving,
                onPressed: canSave ? _onSave : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openDpa() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LegalPdfScreen(assetPath: kDpaAssetPath),
    ));
  }

  Future<void> _onSave() async {
    final t = AppLocalizations.of(context);
    if (!_consentGiven) {
      _showNoConsentSheet(t);
      return;
    }
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Save patient via existing notifier (MVP — backend doesn't
      // accept consent_given_at yet; D9). The notifier currently
      // splits alias into firstName/lastName; pass alias as one piece.
      final notifier = ref.read(patientsProvider.notifier);
      await notifier.addPatient(alias, '');

      // Find the newly-created patient to get its ID. The notifier
      // refetches after addPatient, so the newest patient is at the
      // top (or matches our alias).
      final list = ref.read(patientsProvider).whenOrNull(data: (d) => d) ??
          const [];
      final created = list.where(
        (p) => '${p.firstName} ${p.lastName}'.trim() == alias.trim(),
      ).firstOrNull ?? (list.isNotEmpty ? list.first : null);

      if (created != null) {
        // Local audit (D9 stub).
        await ref.read(consentServiceProvider).recordConsent(
              patientFileId: created.id,
              documentVersion: kCurrentDpaVersion,
            );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showNoConsentSheet(AppLocalizations t) {
    showEuphireBottomSheet(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.addPatient_no_consent_header,
        body: t.addPatient_no_consent_body,
        primary: EuphireSheetAction(
          label: t.addPatient_no_consent_primary,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

class _ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String labelText;
  final String linkLabel;
  final VoidCallback onLinkTap;

  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.labelText,
    required this.linkLabel,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: EuphireColors.ember,
                checkColor: EuphireColors.obsidianBlack,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(text: '$labelText '),
                    TextSpan(
                      text: linkLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: EuphireColors.ember,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onLinkTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
