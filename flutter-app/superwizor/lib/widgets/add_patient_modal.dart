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
import 'package:grpc/grpc.dart' as grpc;

import '../l10n/app_localizations.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../screens/legal_markdown_screen.dart';
import '../theme/euphire_theme.dart';
import 'euphire_action_sheet.dart';
import 'euphire_bottom_sheet.dart';
import 'euphire_button.dart';
import 'euphire_text_field.dart';
import 'modality_sheet.dart';
import '../constants/modalities.dart';

const String kCurrentDpaVersion = 'dpa-v1-2026-04';
const String kDpaAssetPath = 'assets/legal/DPA Superwizor AI.md';

class AddPatientModal extends ConsumerStatefulWidget {
  const AddPatientModal({super.key});

  @override
  ConsumerState<AddPatientModal> createState() => _AddPatientModalState();
}

class _AddPatientModalState extends ConsumerState<AddPatientModal> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _consentGiven = false;
  bool _saving = false;
  String _languageCode = 'pl-PL';
  late String _modalityCode;

  @override
  void initState() {
    super.initState();
    _modalityCode = ref.read(selectedModalityProvider);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String _modalityDisplayName(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'UNIV': return t.modality_integrative;
      case 'CBT': return t.modality_cbt;
      case 'PSYCHO': return t.modality_psychodynamic;
      case 'PPT': return t.modality_positive;
      case 'ST': return t.modality_schema;
      case 'SYS': return t.modality_systemic;
      case 'EFT': return t.modality_eft;
      case 'COACH': return t.modality_coaching;
      default: return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final canSave =
        !_saving && _firstNameController.text.trim().isNotEmpty && _consentGiven;

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
              controller: _firstNameController,
              labelText: t.addPatient_first_name_label,
            ),
            const SizedBox(height: 16),
            EuphireTextField(
              controller: _lastNameController,
              labelText: t.addPatient_last_name_label,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nurt terapeutyczny (Modalność)',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: EuphireColors.mist,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: EuphireColors.obsidianBlack.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EuphireColors.mist.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _modalityCode,
                  isExpanded: true,
                  dropdownColor: EuphireColors.nocturne,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    color: EuphireColors.frostWhite,
                    fontWeight: FontWeight.w500,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down, color: EuphireColors.ember),
                  items: kModalities.map((m) {
                    return DropdownMenuItem(
                      value: m.code,
                      child: Text(_modalityDisplayName(context, m.code)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _modalityCode = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Język raportu AI',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: EuphireColors.mist,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: EuphireColors.obsidianBlack.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EuphireColors.mist.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _languageCode,
                  isExpanded: true,
                  dropdownColor: EuphireColors.nocturne,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    color: EuphireColors.frostWhite,
                    fontWeight: FontWeight.w500,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down, color: EuphireColors.ember),
                  items: const [
                    DropdownMenuItem(
                      value: 'pl-PL',
                      child: Row(
                        children: [
                          Text('🇵🇱', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 12),
                          Text('Polski (PL)'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'en-US',
                      child: Row(
                        children: [
                          Text('🇬🇧', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 12),
                          Text('Angielski (ENG)'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _languageCode = v!),
                ),
              ),
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
    final title = AppLocalizations.of(context).settings_dpa;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalMarkdownScreen(assetPath: kDpaAssetPath, title: title),
    ));
  }

  Future<void> _onSave() async {
    final t = AppLocalizations.of(context);
    if (!_consentGiven) {
      _showNoConsentSheet(t);
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final alias = '$firstName $lastName'.trim();
    if (firstName.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Save patient via existing notifier (MVP — backend doesn't
      // accept consent_given_at yet; D9).
      final notifier = ref.read(patientsProvider.notifier);
      await notifier.addPatient(
        alias: alias,
        firstName: firstName,
        lastName: lastName,
        modalityCode: _modalityCode,
        languageCode: _languageCode,
      );

      // Find the newly-created patient to get its ID. The notifier
      // refetches after addPatient, so the newest patient is at the
      // top (or matches our alias).
      final list = ref.read(patientsProvider).whenOrNull(data: (d) => d) ??
          const [];
      final created = list.where(
        (p) => '${p.firstName} ${p.lastName}'.trim() == alias,
      ).firstOrNull ?? (list.isNotEmpty ? list.first : null);

      if (created != null) {
        // Local audit (D9 stub).
        await ref.read(consentServiceProvider).recordConsent(
              patientFileId: created.id,
              documentVersion: kCurrentDpaVersion,
            );
      }

      if (mounted) Navigator.of(context).pop();
    } on grpc.GrpcError catch (e) {
      if (mounted) {
        if (e.code == grpc.StatusCode.alreadyExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pacjent o nazwie "$alias" już istnieje. Wybierz inną.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Wystąpił błąd.')),
          );
        }
      }
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
