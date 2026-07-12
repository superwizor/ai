// AddPatientScreen — Full-screen 3-step wizard.
//
// Replaces the old AddPatientModal (bottom sheet) with a dedicated
// screen, eliminating the keyboard-occlusion bug. Uses CupertinoPageRoute
// for the premium slide-in-from-right transition.
//
// Krok 1: "Kim jest Twój klient?" — first name, last name, email, language
// Krok 2: "Dopasuj do Twojej pracy" — modality (expanded), DPA consent, save
// Krok 3: "Spersonalizuj oznaczenie" — optional avatar label + color (post-creation)

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;

import '../utils/haptics.dart';

import '../constants/modalities.dart';
import '../l10n/app_localizations.dart';
import '../providers/patient_avatar_provider.dart';
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

  final _scrollController1 = ScrollController();
  final _scrollController2 = ScrollController();
  final _scrollController3 = ScrollController();
  final _scrollController4 = ScrollController();

  // ── Step 1 fields ──
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  String _languageCode = 'pl-PL';
  bool _duplicateError = false;

  // ── Step 2 fields ──
  late String _modalityCode;
  bool _consentGiven = false;
  bool _saving = false;

  // ── Step 3 fields (avatar customization) ──
  final _avatarLabelController = TextEditingController();
  int _selectedColorIndex = 0;
  String? _createdPatientId; // set after successful save

  @override
  void initState() {
    super.initState();
    _modalityCode = ref.read(selectedModalityProvider);
    _firstNameController.addListener(_onNameChanged);
    _lastNameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (_duplicateError) {
      setState(() => _duplicateError = false);
    }
    setState(() {});
  }

  String _buildAutoAlias() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty && last.isEmpty) return '';
    if (last.isNotEmpty) {
      return '$first ${last.characters.first}.'.trim();
    }
    return first;
  }

  @override
  void dispose() {
    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    _scrollController4.dispose();
    _firstNameController.removeListener(_onNameChanged);
    _lastNameController.removeListener(_onNameChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _avatarLabelController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String get _avatarPreviewLabel {
    final custom = _avatarLabelController.text.trim();
    if (custom.isNotEmpty) return custom;
    return _defaultInitials;
  }

  String get _defaultInitials {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    if (f.isEmpty && l.isEmpty) return '?';
    final first = f.isNotEmpty ? f.characters.first.toUpperCase() : '';
    final last = l.isNotEmpty ? l.characters.first.toUpperCase() : '';
    return '$first$last'.trim();
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
        if (_currentPage == 3) {
          // On step 4, just go back means "skip"
          Navigator.of(context).pop();
        } else if (_firstNameController.text.trim().isNotEmpty) {
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
            // Web/desktop: cap the wizard to the same centered column width as
            // the "Twoje kartoteki" list (home_screen, 760). Self-gating — on
            // phones (width < 760) the ConstrainedBox is a no-op, so the native
            // app is unchanged.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
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
                          _buildStep3(t),
                          _buildStep4(t),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
              if (_currentPage == 3) {
                // Step 4 is post-creation; back = done
                Navigator.of(context).pop();
              } else if (_currentPage > 0) {
                _goToPage(_currentPage - 1);
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
              _currentPage == 0
                  ? t.common_cancel
                  : _currentPage == 3
                  ? t.common_done
                  : t.common_back,
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
        children: List.generate(4, (i) {
          final isActive = i == _currentPage;
          final isCompleted = i < _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? EuphireColors.ember
                  : isCompleted
                  ? EuphireColors.ember.withValues(alpha: 0.5)
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

    return Column(
      children: [
        Expanded(
          child: RawScrollbar(
            controller: _scrollController1,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(10),
            thumbColor: EuphireColors.mist.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              controller: _scrollController1,
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
                                color: EuphireColors.mist.withValues(
                                  alpha: 0.7,
                                ),
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
                    errorText: _duplicateError
                        ? t.addPatient_duplicate_header
                        : null,
                    autofocus: true,
                    maxLength: 50,
                    focusNode: _firstNameFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _lastNameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),

                  // ── Last Name ──
                  GlassTextField(
                    controller: _lastNameController,
                    label: t.addPatient_last_name_label,
                    errorText: _duplicateError ? '' : null,
                    maxLength: 50,
                    focusNode: _lastNameFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_firstNameController.text.trim().isNotEmpty) {
                        _goToPage(1);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // ── Sticky Bottom CTA: Dalej ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedOpacity(
              opacity: canProceed ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: EuphireButton(
                text: t.addPatient_step1_next,
                icon: Icons.arrow_forward_rounded,
                iconOnRight: true,
                onPressed: canProceed ? () => _goToPage(1) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: "Dodatkowe dane" ──

  Widget _buildStep2(AppLocalizations t) {
    return Column(
      children: [
        Expanded(
          child: RawScrollbar(
            controller: _scrollController2,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(10),
            thumbColor: EuphireColors.mist.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              controller: _scrollController2,
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
                          Icons.contact_mail_rounded,
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
                              t.addPatient_additional_data_title,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: EuphireColors.frostWhite,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.addPatient_email_required_error,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                color: EuphireColors.mist.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Email (optional) ──
                  GlassTextField(
                    controller: _emailController,
                    label: t.addPatient_email_label,
                    hint: t.addPatient_email_hint,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocus,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      _goToPage(2);
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Language Dropdown ──
                  FormSectionLabel(text: t.addPatient_language_label),
                  const SizedBox(height: 8),
                  GlassDropdown<String>(
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // ── Sticky Bottom CTA: Dalej ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: EuphireButton(
              text: t.addPatient_step1_next,
              icon: Icons.arrow_forward_rounded,
              iconOnRight: true,
              onPressed: () => _goToPage(2),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 3: "Dopasuj do Twojej pracy" — Modality + Consent ──

  Widget _buildStep3(AppLocalizations t) {
    final canSave = !_saving && _consentGiven;

    return Column(
      children: [
        Expanded(
          child: RawScrollbar(
            controller: _scrollController3,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(10),
            thumbColor: EuphireColors.mist.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              controller: _scrollController3,
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
                                color: EuphireColors.mist.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Modality Selection (expanded list) ──
                  FormSectionLabel(text: t.addPatient_modality_label),
                  const SizedBox(height: 12),
                  ...kModalities.map((m) {
                    final isSelected = m.code == _modalityCode;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          AppHapticFeedback.selectionClick();
                          setState(() => _modalityCode = m.code);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? EuphireColors.ember.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? EuphireColors.ember.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                m.icon,
                                size: 20,
                                color: isSelected
                                    ? EuphireColors.ember
                                    : EuphireColors.mist.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _modalityDisplayName(context, m.code),
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? EuphireColors.frostWhite
                                        : EuphireColors.mist,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: EuphireColors.ember,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Consent Checkbox ──
                  ConsentCheckbox(
                    value: _consentGiven,
                    onChanged: (v) => setState(() => _consentGiven = v),
                    labelText: t.addPatient_consent_label,
                    linkLabel: t.addPatient_consent_link_label,
                    onLinkTap: _openDpa,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // ── Sticky Bottom CTA: Utwórz kartotekę ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: SizedBox(
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
        ),
      ],
    );
  }

  // ── Step 4: "Spersonalizuj oznaczenie" — Optional avatar customization ──

  Widget _buildStep4(AppLocalizations t) {
    return Column(
      children: [
        Expanded(
          child: RawScrollbar(
            controller: _scrollController3,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(10),
            thumbColor: EuphireColors.mist.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              controller: _scrollController3,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Live preview avatar ──
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AvatarColors.fromIndex(_selectedColorIndex),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AvatarColors.fromIndex(
                            _selectedColorIndex,
                          ).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _avatarPreviewLabel,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Title ──
                  Text(
                    t.addPatient_customize_label_title,
                    style: const TextStyle(
                      fontFamily: 'Merriweather',
                      fontStyle: FontStyle.italic,
                      fontSize: 20,
                      color: EuphireColors.frostWhite,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.addPatient_alias_instruction,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: EuphireColors.mist.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // ── Label input ──
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _avatarLabelController,
                      textAlign: TextAlign.center,
                      maxLength: null,
                      inputFormatters: [_GraphemeClusterLengthFormatter(2)],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                        letterSpacing: 3,
                      ),
                      decoration: InputDecoration(
                        hintText: _defaultInitials,
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: EuphireColors.mist.withValues(alpha: 0.25),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: EuphireColors.ember,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.addPatient_avatar_format_hint,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: EuphireColors.mist.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Color grid ──
                  Text(
                    t.addPatient_background_color,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 12,
                    children: List.generate(AvatarColors.palette.length, (i) {
                      final isSelected = i == _selectedColorIndex;
                      return GestureDetector(
                        onTap: () {
                          AppHapticFeedback.selectionClick();
                          setState(() => _selectedColorIndex = i);
                          _saveAvatarConfig();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 44 : 38,
                          height: isSelected ? 44 : 38,
                          decoration: BoxDecoration(
                            color: AvatarColors.palette[i],
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: EuphireColors.ember,
                                    width: 2.5,
                                  )
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: EuphireColors.ember.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: EuphireColors.frostWhite,
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // ── Sticky Bottom Buttons (Gotowe + Pomiń) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: EuphireButton(
                  text: t.common_done,
                  icon: Icons.check_rounded,
                  onPressed: () {
                    _saveAvatarConfig();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  t.addPatient_skip_for_now,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EuphireColors.mist.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Actions ──

  void _openDpa() {
    final title = AppLocalizations.of(context).settings_dpa;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LegalMarkdownScreen(assetPath: _kDpaAssetPath, title: title),
      ),
    );
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

  void _saveAvatarConfig() {
    final patientId = _createdPatientId;
    if (patientId == null) return;
    final avatarLabel = _avatarLabelController.text.trim();
    final isDefault = avatarLabel.isEmpty || avatarLabel == _defaultInitials;
    final config = PatientAvatarConfig(
      customLabel: isDefault ? null : avatarLabel,
      colorIndex: _selectedColorIndex,
    );
    ref.read(patientAvatarProvider.notifier).setConfig(patientId, config);
  }

  Future<void> _onSave() async {
    final t = AppLocalizations.of(context);
    if (!_consentGiven) {
      _showNoConsentSheet(t);
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final alias = _buildAutoAlias();
    if (firstName.isEmpty) return;

    // ── Client-side duplicate detection ──
    final existingPatients =
        ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? const [];
    final isDuplicate = existingPatients.any((p) {
      final existingName = '${p.firstName} ${p.lastName}'.trim().toLowerCase();
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
        alias: alias.isNotEmpty ? alias : firstName,
        firstName: firstName,
        lastName: lastName,
        modalityCode: _modalityCode,
        languageCode: _languageCode,
        email: _emailController.text.trim(),
      );

      final list =
          ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? const [];
      final created =
          list
              .where(
                (p) =>
                    '${p.firstName} ${p.lastName}'.trim() ==
                    '$firstName $lastName'.trim(),
              )
              .firstOrNull ??
          (list.isNotEmpty ? list.first : null);

      if (created != null) {
        await ref
            .read(consentServiceProvider)
            .recordConsent(
              patientFileId: created.id,
              documentVersion: _kCurrentDpaVersion,
            );
        _createdPatientId = created.id;
      }

      if (mounted) {
        AppHapticFeedback.mediumImpact();
        // Navigate to Step 4 (avatar customization)
        _goToPage(3);
      }
    } on grpc.GrpcError catch (e) {
      if (mounted) {
        if (e.code == grpc.StatusCode.alreadyExists) {
          _goToPage(0);
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

/// A [TextInputFormatter] that limits input by grapheme cluster count rather
/// than UTF-16 code-unit count.  This allows emoji characters (which are
/// multi-code-unit) to be treated as a single "character" toward [maxLength].
class _GraphemeClusterLengthFormatter extends TextInputFormatter {
  final int maxLength;
  const _GraphemeClusterLengthFormatter(this.maxLength);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clusters = newValue.text.characters;
    if (clusters.length <= maxLength) return newValue;

    final truncated = clusters.take(maxLength).toString();
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}
