// AddPatientModal — Redesigned (UI-optymalizacja-menu-kartoteka)
//
// Changes from v1:
//   - Icon + title header for visual anchor
//   - All Montserrat (reduced font count)
//   - LIGHTER dropdown surfaces (White 10-15%) — "to co na wierzchu jaśniejsze"
//   - Optional email field for patient contact
//   - Shorter, punchier labels & CTA copy
//   - Consent checkbox tightened
//   - Overall glassmorphism-consistent styling

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;

import '../utils/haptics.dart';

import '../l10n/app_localizations.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../screens/legal_markdown_screen.dart';
import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';
import 'euphire_action_sheet.dart';
import 'euphire_bottom_sheet.dart';
import 'euphire_button.dart';
import 'modality_sheet.dart';
import '../constants/modalities.dart';

const String kCurrentDpaVersion = 'dpa-v1-2026-04';
const String kDpaAssetPath = 'assets/legal/dpa.md';

class AddPatientModal extends ConsumerStatefulWidget {
  const AddPatientModal({super.key});

  @override
  ConsumerState<AddPatientModal> createState() => _AddPatientModalState();
}

class _AddPatientModalState extends ConsumerState<AddPatientModal> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _consentGiven = false;
  bool _saving = false;
  bool _duplicateError = false;
  String _languageCode = 'pl-PL';
  late String _modalityCode;

  @override
  void initState() {
    super.initState();
    _modalityCode = ref.read(selectedModalityProvider);
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_duplicateError) _duplicateError = false;
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onFieldChanged);
    _lastNameController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _modalityDisplayName(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'UNIV': return t.modality_integrative;
      case 'CBT': return t.modality_cbt;
      case 'PSYCHO': return t.modality_psychodynamic;
      case 'GESTALT': return t.modality_gestalt;
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
    final t = AppLocalizations.of(context);
    final canSave =
        !_saving && _firstNameController.text.trim().isNotEmpty && _consentGiven;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: EuphireColors.mist.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Header: Icon + Title + Subtitle ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: EuphireColors.ember.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: EuphireColors.ember,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    t.addPatient_title,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── First Name ──
            _GlassTextField(
              controller: _firstNameController,
              label: t.addPatient_first_name_label,
              errorText: _duplicateError ? t.addPatient_duplicate_header : null,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // ── Last Name / Alias ──
            _GlassTextField(
              controller: _lastNameController,
              label: t.addPatient_last_name_label,
              errorText: _duplicateError ? '' : null,
            ),
            const SizedBox(height: 12),

            // ── Email (optional) ──
            _GlassTextField(
              controller: _emailController,
              label: t.addPatient_email_label,
              hint: t.addPatient_email_hint,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // ── Modality Dropdown ──
            _SectionLabel(text: t.addPatient_modality_label),
            const SizedBox(height: 8),
            _GlassDropdown<String>(
              value: _modalityCode,
              items: kModalities.map((m) {
                return DropdownMenuItem(
                  value: m.code,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 18, color: EuphireColors.mist),
                      const SizedBox(width: 10),
                      Text(_modalityDisplayName(context, m.code)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _modalityCode = v!),
            ),
            const SizedBox(height: 16),

            // ── Language Dropdown ──
            _SectionLabel(text: t.addPatient_language_label),
            const SizedBox(height: 8),
            _GlassDropdown<String>(
              value: _languageCode,
              items: [
                DropdownMenuItem(
                  value: 'pl-PL',
                  child: Row(
                    children: [
                      const Text('🇵🇱', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(t.language_pl_name),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'en-US',
                  child: Row(
                    children: [
                      const Text('🇬🇧', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(t.language_en_name),
                    ],
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _languageCode = v!),
            ),
            const SizedBox(height: 20),

            // ── Consent Checkbox ──
            _ConsentCheckbox(
              value: _consentGiven,
              onChanged: (v) => setState(() => _consentGiven = v),
              labelText: t.addPatient_consent_label,
              linkLabel: t.addPatient_consent_link_label,
              onLinkTap: _openDpa,
            ),
            const SizedBox(height: 24),

            // ── Primary CTA ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: EuphireButton(
                text: t.addPatient_save_primary,
                icon: Icons.add_rounded,
                isLoading: _saving,
                onPressed: canSave ? _onSave : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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

    // ── Client-side duplicate detection ──
    final existingPatients =
        ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? const [];
    final isDuplicate = existingPatients.any((p) {
      final existingName =
          '${p.firstName} ${p.lastName}'.trim().toLowerCase();
      return existingName == alias.toLowerCase();
    });
    if (isDuplicate) {
      _showDuplicateSheet(t);
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(patientsProvider.notifier);
      await notifier.addPatient(
        alias: alias,
        firstName: firstName,
        lastName: lastName,
        modalityCode: _modalityCode,
        languageCode: _languageCode,
        email: _emailController.text.trim(),
      );

      final list = ref.read(patientsProvider).whenOrNull(data: (d) => d) ??
          const [];
      final created = list.where(
        (p) => '${p.firstName} ${p.lastName}'.trim() == alias,
      ).firstOrNull ?? (list.isNotEmpty ? list.first : null);

      if (created != null) {
        await ref.read(consentServiceProvider).recordConsent(
              patientFileId: created.id,
              documentVersion: kCurrentDpaVersion,
            );
      }


      if (mounted) {
        AppHapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
    } on grpc.GrpcError catch (e) {
      if (mounted) {
        if (e.code == grpc.StatusCode.alreadyExists) {
          _showDuplicateSheet(t);
        } else {
          EuphireToast.error(context, message: e.message ?? t.common_error);
        }
      }
    } catch (e) {
      if (mounted) {
        EuphireToast.error(context, message: e.toString());
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

  void _showDuplicateSheet(AppLocalizations t) {
    setState(() => _duplicateError = true);
    showEuphireBottomSheet(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.addPatient_duplicate_header,
        body: t.addPatient_duplicate_body,
        primary: EuphireSheetAction(
          label: t.addPatient_duplicate_primary,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

// ─── Glass-styled text field (lighter surface) ──────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final TextInputType keyboardType;
  final bool autofocus;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: EuphireColors.frostWhite,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint ?? label,
        hintStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: EuphireColors.mist.withValues(alpha: 0.45),
        ),
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: EuphireColors.mist.withValues(alpha: 0.7),
          height: 1.1,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: EuphireColors.ember.withValues(alpha: 0.9),
          height: 1.1,
        ),
        errorText: errorText,
        filled: true,
        // LIGHTER than background — "to co na wierzchu jaśniejsze"
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: EuphireColors.ember,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: EuphireColors.magma,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Glass-styled dropdown (lighter surface) ────────────────────────

class _GlassDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _GlassDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // LIGHTER surface — glass effect, not dark hole
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          // Dropdown popup also lighter
          dropdownColor: const Color(0xFF1A3A3F),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 15,
            color: EuphireColors.frostWhite,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: EuphireColors.ember,
            size: 22,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Section label (all Montserrat) ─────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: EuphireColors.mist.withValues(alpha: 0.8),
      ),
    );
  }
}

// ─── Consent Checkbox ───────────────────────────────────────────────

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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: value ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? EuphireColors.ember.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: EuphireColors.ember,
                  checkColor: EuphireColors.obsidianBlack,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: '$labelText '),
                    TextSpan(
                      text: linkLabel,
                      style: const TextStyle(
                        color: EuphireColors.ember,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
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
