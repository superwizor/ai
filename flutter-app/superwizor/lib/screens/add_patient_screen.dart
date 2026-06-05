// AddPatientScreen — Full-screen 2-step wizard.
//
// Replaces the old AddPatientModal (bottom sheet) with a dedicated
// screen, eliminating the keyboard-occlusion bug. Uses CupertinoPageRoute
// for the premium slide-in-from-right transition.
//
// Krok 1: "Kim jest Twój klient?" — first name, last name/alias, email, language
// Krok 2: "Dopasuj do Twojej pracy" — modality, working alias, DPA consent

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;

import '../constants/modalities.dart';
import '../l10n/app_localizations.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../screens/legal_markdown_screen.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_form_widgets.dart';
import '../widgets/euphire_toast.dart';
import '../widgets/modality_sheet.dart';

const String _kCurrentDpaVersion = 'dpa-v1-2026-04';
const String _kDpaAssetPath = 'assets/legal/dpa.md';

class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // ── Step 1 fields ──
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _languageCode = 'pl-PL';
  bool _duplicateError = false;

  // ── Step 2 fields ──
  late String _modalityCode;
  final _aliasController = TextEditingController();
  bool _aliasManuallyEdited = false;
  bool _consentGiven = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _modalityCode = ref.read(selectedModalityProvider);
    _firstNameController.addListener(_onNameChanged);
    _lastNameController.addListener(_onNameChanged);
    _aliasController.addListener(_onAliasChanged);
  }

  void _onNameChanged() {
    if (_duplicateError) {
      setState(() => _duplicateError = false);
    }
    if (!_aliasManuallyEdited) {
      _syncAlias();
    }
    setState(() {});
  }

  void _onAliasChanged() {
    // Detect manual edits: if the current alias text differs from
    // what auto-sync would produce, flag as manually edited.
    final autoAlias = _buildAutoAlias();
    if (_aliasController.text != autoAlias && !_aliasManuallyEdited) {
      _aliasManuallyEdited = true;
    }
    // If the user clears the field completely, re-enable auto-sync.
    if (_aliasController.text.isEmpty && _aliasManuallyEdited) {
      _aliasManuallyEdited = false;
      _syncAlias();
    }
  }

  String _buildAutoAlias() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty && last.isEmpty) return '';
    if (last.isNotEmpty) {
      return '$first ${last[0]}.'.trim();
    }
    return first;
  }

  void _syncAlias() {
    final auto = _buildAutoAlias();
    _aliasController.value = TextEditingValue(
      text: auto,
      selection: TextSelection.collapsed(offset: auto.length),
    );
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onNameChanged);
    _lastNameController.removeListener(_onNameChanged);
    _aliasController.removeListener(_onAliasChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _aliasController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _modalityDisplayName(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'UNIV':
        return t.modality_integrative;
      case 'CBT':
        return t.modality_cbt;
      case 'PSYCHO':
        return t.modality_psychodynamic;
      case 'GESTALT':
        return t.modality_gestalt;
      case 'PPT':
        return t.modality_positive;
      case 'ST':
        return t.modality_schema;
      case 'SYS':
        return t.modality_systemic;
      case 'EFT':
        return t.modality_eft;
      case 'COACH':
        return t.modality_coaching;
      default:
        return code;
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // On step 2 with data, confirm discard
        if (_firstNameController.text.trim().isNotEmpty) {
          _showDiscardDialog(t);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: EuphireColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(t),
                _buildDotIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildStep1(t),
                      _buildStep2(t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── App Bar ──

  Widget _buildAppBar(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () {
              if (_currentPage == 1) {
                _goToPage(0);
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              size: 18,
              color: EuphireColors.mist,
            ),
            label: Text(
              _currentPage == 0 ? t.common_cancel : t.common_back,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: EuphireColors.mist.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dot Indicator ──

  Widget _buildDotIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (i) {
          final isActive = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? EuphireColors.ember
                  : EuphireColors.mist.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: "Kim jest Twój klient?" ──

  Widget _buildStep1(AppLocalizations t) {
    final canProceed = _firstNameController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // ── Header ──
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.addPatient_title,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.addPatient_step1_subtitle,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        color: EuphireColors.mist.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── First Name ──
          GlassTextField(
            controller: _firstNameController,
            label: t.addPatient_first_name_label,
            errorText: _duplicateError ? t.addPatient_duplicate_header : null,
            autofocus: true,
          ),
          const SizedBox(height: 12),

          // ── Last Name / Alias ──
          GlassTextField(
            controller: _lastNameController,
            label: t.addPatient_last_name_label,
            errorText: _duplicateError ? '' : null,
          ),
          const SizedBox(height: 12),

          // ── Email (optional) ──
          GlassTextField(
            controller: _emailController,
            label: t.addPatient_email_label,
            hint: t.addPatient_email_hint,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          // ── Language Dropdown ──
          FormSectionLabel(text: t.addPatient_language_label),
          const SizedBox(height: 8),
          GlassDropdown<String>(
            value: _languageCode,
            items: const [
              DropdownMenuItem(
                value: 'pl-PL',
                child: Row(
                  children: [
                    Text('🇵🇱', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Text('Polski'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'en-US',
                child: Row(
                  children: [
                    Text('🇬🇧', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Text('English'),
                  ],
                ),
              ),
            ],
            onChanged: (v) => setState(() => _languageCode = v!),
          ),
          const SizedBox(height: 32),

          // ── CTA: Dalej ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedOpacity(
              opacity: canProceed ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: EuphireButton(
                text: t.addPatient_step1_next,
                icon: Icons.arrow_forward_rounded,
                onPressed: canProceed ? () => _goToPage(1) : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 2: "Dopasuj do Twojej pracy" ──

  Widget _buildStep2(AppLocalizations t) {
    final canSave = !_saving && _consentGiven;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // ── Header ──
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
                  Icons.tune_rounded,
                  color: EuphireColors.ember,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.addPatient_step2_title,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.addPatient_step2_subtitle,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        color: EuphireColors.mist.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Modality Dropdown ──
          FormSectionLabel(text: t.addPatient_modality_label),
          const SizedBox(height: 8),
          GlassDropdown<String>(
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
          const SizedBox(height: 20),

          // ── Working Alias ──
          FormSectionLabel(text: t.addPatient_alias_label),
          const SizedBox(height: 8),
          GlassTextField(
            controller: _aliasController,
            label: t.addPatient_alias_label,
            hint: t.addPatient_alias_hint,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              t.addPatient_alias_hint,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: EuphireColors.mist.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Consent Checkbox ──
          ConsentCheckbox(
            value: _consentGiven,
            onChanged: (v) => setState(() => _consentGiven = v),
            labelText: t.addPatient_consent_label,
            linkLabel: t.addPatient_consent_link_label,
            onLinkTap: _openDpa,
          ),
          const SizedBox(height: 28),

          // ── CTA: Utwórz kartotekę ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedOpacity(
              opacity: canSave ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: EuphireButton(
                text: t.addPatient_save_primary,
                icon: Icons.check_rounded,
                isLoading: _saving,
                onPressed: canSave ? _onSave : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ──

  void _openDpa() {
    final title = AppLocalizations.of(context).settings_dpa;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          LegalMarkdownScreen(assetPath: _kDpaAssetPath, title: title),
    ));
  }

  void _showDiscardDialog(AppLocalizations t) {
    showEuphireBottomSheet(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.addPatient_discard_title,
        body: t.addPatient_discard_body,
        primary: EuphireSheetAction(
          label: t.addPatient_discard_stay,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        destructive: EuphireSheetAction(
          label: t.addPatient_discard_action,
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final t = AppLocalizations.of(context);
    if (!_consentGiven) {
      _showNoConsentSheet(t);
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final alias = _aliasController.text.trim().isNotEmpty
        ? _aliasController.text.trim()
        : '$firstName $lastName'.trim();
    if (firstName.isEmpty) return;

    // ── Client-side duplicate detection ──
    final existingPatients =
        ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? const [];
    final isDuplicate = existingPatients.any((p) {
      final existingName =
          '${p.firstName} ${p.lastName}'.trim().toLowerCase();
      return existingName == '$firstName $lastName'.trim().toLowerCase();
    });
    if (isDuplicate) {
      _goToPage(0);
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
      final created = list
              .where(
                (p) => '${p.firstName} ${p.lastName}'.trim() == '$firstName $lastName'.trim(),
              )
              .firstOrNull ??
          (list.isNotEmpty ? list.first : null);

      if (created != null) {
        await ref.read(consentServiceProvider).recordConsent(
              patientFileId: created.id,
              documentVersion: _kCurrentDpaVersion,
            );
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
    } on grpc.GrpcError catch (e) {
      if (mounted) {
        if (e.code == grpc.StatusCode.alreadyExists) {
          _goToPage(0);
          _showDuplicateSheet(t);
        } else {
          EuphireToast.error(context, message: e.message ?? 'Wystąpił błąd.');
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
