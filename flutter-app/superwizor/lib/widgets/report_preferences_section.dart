// ReportPreferencesSection — settings card surfacing the 8 dimensions
// of identity.v1.ReportPreferences and the optional free-text.
//
// Drop-in section for the Settings (menu) screen. Layout matches the
// existing PREFERENCJE card: a section label + a card with one row per
// dimension. Tapping a row opens a picker bottom sheet; selecting an
// option persists immediately via identity-svc.UpdateReportPreferences.
//
// Backend contract (services/identity-svc/preferences.go):
//   - Each dimension is a free-form string ID with a canonical
//     allowlist enforced server-side.
//   - section_emphasis is a `repeated string` (multi-select).
//   - free_text is sanitized + capped at 500 chars.
//   - idempotency_key required; same key + diff payload → AlreadyExists.
//     We mint a fresh UUID per save so re-tries are clean.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:uuid/uuid.dart';

import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../l10n/app_localizations.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';

// ────────────────────────────────────────────────────────────
// Canonical option IDs. Kept in sync with the comments on
// identity.proto::ReportPreferences and the server-side allowlist in
// services/identity-svc/preferences.go.
// ────────────────────────────────────────────────────────────

const _kLengthOptions = ['brief', 'standard', 'detailed'];
const _kToneOptions = [
  'clinical_formal',
  'empathic_warm',
  'pragmatic_direct',
  'academic_rigorous',
];
const _kQuoteDensityOptions = ['few', 'selective', 'many'];
const _kDiagnosticLanguageOptions = [
  'descriptive',
  'clinical_labels',
  'dsm_icd',
];
const _kHypothesisHedgingOptions = ['tentative', 'balanced', 'assertive'];
const _kStrengthsFramingOptions = [
  'problem_focused',
  'balanced',
  'strengths_first',
];
const _kSectionEmphasisOptions = [
  'clinical_picture',
  'interventions',
  'case_formulation',
  'supervisory_recommendations',
  'homework_between_sessions',
  'cultural_context',
  'safety_and_risk',
];

const _kFreeTextMaxLen = 500;

String _lengthLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'brief':
      return t.report_prefs_length_brief;
    case 'standard':
      return t.report_prefs_length_standard;
    case 'detailed':
      return t.report_prefs_length_detailed;
    default:
      return t.report_prefs_value_not_set;
  }
}

String _toneLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'clinical_formal':
      return t.report_prefs_tone_clinical_formal;
    case 'empathic_warm':
      return t.report_prefs_tone_empathic_warm;
    case 'pragmatic_direct':
      return t.report_prefs_tone_pragmatic_direct;
    case 'academic_rigorous':
      return t.report_prefs_tone_academic_rigorous;
    default:
      return t.report_prefs_value_not_set;
  }
}

String _quoteDensityLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'few':
      return t.report_prefs_quote_density_few;
    case 'selective':
      return t.report_prefs_quote_density_selective;
    case 'many':
      return t.report_prefs_quote_density_many;
    default:
      return t.report_prefs_value_not_set;
  }
}

String _diagnosticLanguageLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'descriptive':
      return t.report_prefs_diagnostic_language_descriptive;
    case 'clinical_labels':
      return t.report_prefs_diagnostic_language_clinical_labels;
    case 'dsm_icd':
      return t.report_prefs_diagnostic_language_dsm_icd;
    default:
      return t.report_prefs_value_not_set;
  }
}

String _hypothesisHedgingLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'tentative':
      return t.report_prefs_hypothesis_hedging_tentative;
    case 'balanced':
      return t.report_prefs_hypothesis_hedging_balanced;
    case 'assertive':
      return t.report_prefs_hypothesis_hedging_assertive;
    default:
      return t.report_prefs_value_not_set;
  }
}

String _strengthsFramingLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'problem_focused':
      return t.report_prefs_strengths_framing_problem_focused;
    case 'balanced':
      return t.report_prefs_strengths_framing_balanced;
    case 'strengths_first':
      return t.report_prefs_strengths_framing_strengths_first;
    default:
      return t.report_prefs_value_not_set;
  }
}

String _sectionLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'clinical_picture':
      return t.report_prefs_section_clinical_picture;
    case 'interventions':
      return t.report_prefs_section_interventions;
    case 'case_formulation':
      return t.report_prefs_section_case_formulation;
    case 'supervisory_recommendations':
      return t.report_prefs_section_supervisory_recommendations;
    case 'homework_between_sessions':
      return t.report_prefs_section_homework_between_sessions;
    case 'cultural_context':
      return t.report_prefs_section_cultural_context;
    case 'safety_and_risk':
      return t.report_prefs_section_safety_and_risk;
    default:
      return id;
  }
}

// ────────────────────────────────────────────────────────────
// ReportPreferencesSection
// ────────────────────────────────────────────────────────────

class ReportPreferencesSection extends ConsumerStatefulWidget {
  const ReportPreferencesSection({super.key});

  @override
  ConsumerState<ReportPreferencesSection> createState() =>
      _ReportPreferencesSectionState();
}

class _ReportPreferencesSectionState
    extends ConsumerState<ReportPreferencesSection> {
  identity_pb.ReportPreferences? _prefs;
  bool _loading = true;
  String? _loadError;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) {
      return;
    }
    try {
      final res =
          await ref.read(grpcClientsProvider).identity.getReportPreferences(
                identity_pb.GetReportPreferencesRequest(
                  therapistId: therapistId,
                ),
              );
      if (!mounted) return;
      setState(() {
        _prefs = res;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ReportPreferencesSection: getReportPreferences failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is grpc.GrpcError ? e.message : e.toString();
      });
    }
  }

  Future<void> _save(identity_pb.ReportPreferences next) async {
    final therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) return;
    final t = AppLocalizations.of(context);
    // Optimistic in-memory update — backend round-trip below confirms.
    setState(() => _prefs = next);
    try {
      final res =
          await ref.read(grpcClientsProvider).identity.updateReportPreferences(
                identity_pb.UpdateReportPreferencesRequest(
                  therapistId: therapistId,
                  preferences: next,
                  idempotencyKey: _uuid.v4(),
                ),
              );
      if (!mounted) return;
      setState(() => _prefs = res);
      EuphireToast.success(context, message: t.report_prefs_saved);
    } catch (e) {
      debugPrint('ReportPreferencesSection: updateReportPreferences failed: $e');
      if (!mounted) return;
      EuphireToast.error(context, message: t.report_prefs_save_error);
      // Roll back to last known good — re-fetch is the cheapest way.
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final therapistId = ref.watch(therapistIdProvider);

    // Listen to changes in therapistId to trigger loading when it resolves.
    ref.listen<String?>(therapistIdProvider, (previous, next) {
      if (next != null && next != previous) {
        _load();
      }
    });

    // Hide entirely if auth not resolved — no useful state to show.
    if (therapistId == null) return const SizedBox.shrink();

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _SectionLabel(t.settings_section_report_preferences),
          ],
        ),
      );
    }

    if (_loadError != null && _prefs == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(t.settings_section_report_preferences),
          _SettingsCard(children: [
            _Row(
              icon: Icons.error_outline,
              iconColor: EuphireColors.magma,
              title: t.report_prefs_load_error,
              subtitle: _loadError,
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
                child: Text(AppLocalizations.of(context).common_retry),
              ),
            ),
          ]),
        ],
      );
    }

    final prefs = _prefs ?? identity_pb.ReportPreferences();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(t.settings_section_report_preferences),
        _SettingsCard(children: [
          _Row(
            icon: Icons.straighten,
            title: t.report_prefs_length_label,
            subtitle: prefs.length.isEmpty
                ? t.report_prefs_value_not_set
                : _lengthLabel(t, prefs.length),
            onTap: () => _openSinglePicker(
              title: t.report_prefs_length_label,
              options: _kLengthOptions,
              current: prefs.length,
              labelFor: (id) => _lengthLabel(t, id),
              onPicked: (id) => _save(prefs.deepCopy()..length = id),
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.tune,
            title: t.report_prefs_tone_label,
            subtitle: prefs.tone.isEmpty
                ? t.report_prefs_value_not_set
                : _toneLabel(t, prefs.tone),
            onTap: () => _openSinglePicker(
              title: t.report_prefs_tone_label,
              options: _kToneOptions,
              current: prefs.tone,
              labelFor: (id) => _toneLabel(t, id),
              onPicked: (id) => _save(prefs.deepCopy()..tone = id),
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.format_quote,
            title: t.report_prefs_quote_density_label,
            subtitle: prefs.quoteDensity.isEmpty
                ? t.report_prefs_value_not_set
                : _quoteDensityLabel(t, prefs.quoteDensity),
            onTap: () => _openSinglePicker(
              title: t.report_prefs_quote_density_label,
              options: _kQuoteDensityOptions,
              current: prefs.quoteDensity,
              labelFor: (id) => _quoteDensityLabel(t, id),
              onPicked: (id) => _save(prefs.deepCopy()..quoteDensity = id),
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.medical_information_outlined,
            title: t.report_prefs_diagnostic_language_label,
            subtitle: prefs.diagnosticLanguage.isEmpty
                ? t.report_prefs_value_not_set
                : _diagnosticLanguageLabel(t, prefs.diagnosticLanguage),
            onTap: () => _openSinglePicker(
              title: t.report_prefs_diagnostic_language_label,
              options: _kDiagnosticLanguageOptions,
              current: prefs.diagnosticLanguage,
              labelFor: (id) => _diagnosticLanguageLabel(t, id),
              onPicked: (id) =>
                  _save(prefs.deepCopy()..diagnosticLanguage = id),
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.psychology_outlined,
            title: t.report_prefs_hypothesis_hedging_label,
            subtitle: prefs.hypothesisHedging.isEmpty
                ? t.report_prefs_value_not_set
                : _hypothesisHedgingLabel(t, prefs.hypothesisHedging),
            onTap: () => _openSinglePicker(
              title: t.report_prefs_hypothesis_hedging_label,
              options: _kHypothesisHedgingOptions,
              current: prefs.hypothesisHedging,
              labelFor: (id) => _hypothesisHedgingLabel(t, id),
              onPicked: (id) =>
                  _save(prefs.deepCopy()..hypothesisHedging = id),
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.favorite_border,
            title: t.report_prefs_strengths_framing_label,
            subtitle: prefs.strengthsFraming.isEmpty
                ? t.report_prefs_value_not_set
                : _strengthsFramingLabel(t, prefs.strengthsFraming),
            onTap: () => _openSinglePicker(
              title: t.report_prefs_strengths_framing_label,
              options: _kStrengthsFramingOptions,
              current: prefs.strengthsFraming,
              labelFor: (id) => _strengthsFramingLabel(t, id),
              onPicked: (id) =>
                  _save(prefs.deepCopy()..strengthsFraming = id),
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.list_alt,
            title: t.report_prefs_section_emphasis_label,
            subtitle: prefs.sectionEmphasis.isEmpty
                ? t.report_prefs_value_not_set
                : prefs.sectionEmphasis
                    .map((s) => _sectionLabel(t, s))
                    .join(', '),
            onTap: () => _openMultiPicker(
              title: t.report_prefs_section_emphasis_label,
              subtitle: t.report_prefs_section_emphasis_subtitle,
              options: _kSectionEmphasisOptions,
              current: prefs.sectionEmphasis.toList(),
              labelFor: (id) => _sectionLabel(t, id),
              onSaved: (picked) {
                final next = prefs.deepCopy()..sectionEmphasis.clear();
                next.sectionEmphasis.addAll(picked);
                _save(next);
              },
            ),
          ),
          _Divider(),
          _Row(
            icon: Icons.edit_note,
            title: t.report_prefs_free_text_label,
            subtitle: prefs.freeText.isEmpty
                ? t.report_prefs_value_not_set
                : prefs.freeText,
            multiLineSubtitle: true,
            onTap: () => _openFreeTextEditor(prefs),
          ),
        ]),
      ],
    );
  }

  Future<void> _openSinglePicker({
    required String title,
    required List<String> options,
    required String current,
    required String Function(String) labelFor,
    required void Function(String) onPicked,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SinglePickerSheet(
        title: title,
        options: options,
        current: current,
        labelFor: labelFor,
      ),
    );
    if (picked != null && picked != current) onPicked(picked);
  }

  Future<void> _openMultiPicker({
    required String title,
    required String subtitle,
    required List<String> options,
    required List<String> current,
    required String Function(String) labelFor,
    required void Function(List<String>) onSaved,
  }) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MultiPickerSheet(
        title: title,
        subtitle: subtitle,
        options: options,
        current: current,
        labelFor: labelFor,
      ),
    );
    if (picked != null) onSaved(picked);
  }

  Future<void> _openFreeTextEditor(identity_pb.ReportPreferences prefs) async {
    final updated = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FreeTextSheet(initial: prefs.freeText),
    );
    if (updated != null && updated != prefs.freeText) {
      _save(prefs.deepCopy()..freeText = updated);
    }
  }
}

// ────────────────────────────────────────────────────────────
// Sub-widgets (visual clones of the menu_screen private rows;
// duplicated here so this section is drop-in self-contained).
// ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: EuphireColors.frostWhite.withValues(alpha: 0.55),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.06),
      indent: 52,
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool multiLineSubtitle;

  const _Row({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.multiLineSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icColor = iconColor ?? EuphireColors.mist;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: EuphireColors.ember.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: icColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: EuphireColors.frostWhite,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: multiLineSubtitle ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: EuphireColors.mist.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!]
            else
              Icon(Icons.chevron_right,
                  color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Single-select picker sheet ───────────────────────────────

class _SinglePickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String current;
  final String Function(String) labelFor;

  const _SinglePickerSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: EuphireColors.evergreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            ...options.map((id) {
              final isSelected = id == current;
              return InkWell(
                onTap: () => Navigator.of(context).pop(id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          labelFor(id),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isSelected
                                ? EuphireColors.ember
                                : EuphireColors.frostWhite,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check,
                            color: EuphireColors.ember, size: 22),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Multi-select picker sheet (section_emphasis) ─────────────

class _MultiPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final List<String> current;
  final String Function(String) labelFor;

  const _MultiPickerSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.current,
    required this.labelFor,
  });

  @override
  State<_MultiPickerSheet> createState() => _MultiPickerSheetState();
}

class _MultiPickerSheetState extends State<_MultiPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: EuphireColors.evergreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: EuphireColors.mist,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.options.map((id) {
              final isSelected = _selected.contains(id);
              return InkWell(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selected.remove(id);
                  } else {
                    _selected.add(id);
                  }
                }),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected
                            ? EuphireColors.ember
                            : EuphireColors.mist,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.labelFor(id),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: EuphireColors.frostWhite,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuphireColors.ember,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(_selected.toList()),
                child: Text(
                  t.report_prefs_save,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Free-text editor sheet ───────────────────────────────────

class _FreeTextSheet extends StatefulWidget {
  final String initial;
  const _FreeTextSheet({required this.initial});

  @override
  State<_FreeTextSheet> createState() => _FreeTextSheetState();
}

class _FreeTextSheetState extends State<_FreeTextSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mediaInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: mediaInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: EuphireColors.evergreen,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SafeArea(
          top: false,
          // Tap outside the TextField → dismiss keyboard. Multi-line
          // input has no "Done" key on iOS, so we provide an explicit
          // dismiss area.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                t.report_prefs_free_text_label,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                t.report_prefs_free_text_subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: EuphireColors.mist,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLength: _kFreeTextMaxLen,
                maxLines: 6,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: t.report_prefs_free_text_hint,
                  hintStyle: theme.textTheme.bodyMedium
                      ?.copyWith(color: EuphireColors.mist),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: EuphireColors.ember),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuphireColors.ember,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.text.trim()),
                  child: Text(
                    t.report_prefs_save,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
