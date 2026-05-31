// ReportRatingWidget — compact thumbs-up / thumbs-down control for the
// report screen, sitting next to the Copy button in the AppBar actions.
//
// Behavior:
//   - On mount: fetches existing rating via clinical-svc.GetReportRating.
//     NotFound is the common case (report not yet rated) and is silent.
//   - Tap thumbs-up: immediately upserts a positive rating via
//     clinical-svc.RateReport (rating="positive", source="in_app", no
//     issues, no notes). Single tap, no modal.
//   - Tap thumbs-down: opens a modal bottom sheet with the canonical
//     chip categories (see services/clinical-svc/.../ratings.go
//     allowedIssues — kept in sync here) + optional free-text note,
//     submit calls RateReport with rating="negative".
//   - Re-rating: tapping the *other* icon overwrites the prior rating
//     (the backend UPSERT is idempotency-key keyed, so each tap mints
//     a fresh key and replaces in place).
//
// The widget renders nothing useful until the auth-resolved therapist
// id is available — it's hidden behind `therapistIdProvider`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:uuid/uuid.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';
import 'preference_suggestion_banner.dart' show suggestionRefreshTickProvider;

/// Canonical chip category IDs. These must match
/// services/clinical-svc/internal/adapters/grpc/ratings.go::allowedIssues.
/// The backend rejects unknown values with InvalidArgument, so adding
/// a chip here without a server-side change will 400 the rating.
const List<String> _kCanonicalIssues = [
  'za_dlugi',
  'za_krotki',
  'zly_ton',
  'za_duzo_cytatow',
  'za_malo_cytatow',
  'niedokladna_interpretacja',
  'brakuje_mocnych_stron',
  'brakuje_kontekstu',
  'inne',
];

String _chipLabel(AppLocalizations t, String id) {
  switch (id) {
    case 'za_dlugi':
      return t.report_rating_chip_too_long;
    case 'za_krotki':
      return t.report_rating_chip_too_short;
    case 'zly_ton':
      return t.report_rating_chip_wrong_tone;
    case 'za_duzo_cytatow':
      return t.report_rating_chip_too_many_quotes;
    case 'za_malo_cytatow':
      return t.report_rating_chip_too_few_quotes;
    case 'niedokladna_interpretacja':
      return t.report_rating_chip_inaccurate_interpretation;
    case 'brakuje_mocnych_stron':
      return t.report_rating_chip_missing_strengths;
    case 'brakuje_kontekstu':
      return t.report_rating_chip_missing_context;
    case 'inne':
      return t.report_rating_chip_other;
    default:
      return id;
  }
}

class ReportRatingWidget extends ConsumerStatefulWidget {
  final String reportId;
  const ReportRatingWidget({super.key, required this.reportId});

  @override
  ConsumerState<ReportRatingWidget> createState() =>
      _ReportRatingWidgetState();
}

class _ReportRatingWidgetState extends ConsumerState<ReportRatingWidget> {
  // Tri-state: null = unknown / not yet loaded / not rated;
  //            "positive" / "negative" = current persisted state.
  String? _currentRating;
  bool _loading = true;
  bool _submitting = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Defer to next frame so we can read providers safely.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await ref.read(grpcClientsProvider).clinical.getReportRating(
            clinical_pb.GetReportRatingRequest(
              reportId: widget.reportId,
              therapistId: therapistId,
            ),
          );
      if (!mounted) return;
      setState(() {
        _currentRating = res.rating;
        _loading = false;
      });
    } on grpc.GrpcError catch (e) {
      // NotFound is the "not rated yet" signal — silent.
      if (e.code != grpc.StatusCode.notFound) {
        debugPrint('ReportRatingWidget: getReportRating failed: $e');
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('ReportRatingWidget: getReportRating failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitPositive() async {
    final therapistId = ref.read(therapistIdProvider);
    if (therapistId == null || _submitting) return;

    // Toggle off: if already positive, just clear local state silently.
    // The backend doesn't support "unrating" — we only reset the UI.
    if (_currentRating == 'positive') {
      setState(() => _currentRating = null);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(grpcClientsProvider).clinical.rateReport(
            clinical_pb.RateReportRequest(
              reportId: widget.reportId,
              therapistId: therapistId,
              rating: 'positive',
              source: 'in_app',
              idempotencyKey: _uuid.v4(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _currentRating = 'positive';
        _submitting = false;
      });
      ref.read(suggestionRefreshTickProvider.notifier).bump();
      _toast(AppLocalizations.of(context).report_rating_saved_positive);
    } catch (e) {
      debugPrint('ReportRatingWidget: submitPositive failed: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(AppLocalizations.of(context).report_rating_save_error,
          isError: true);
    }
  }

  Future<void> _submitNegative({
    required List<String> issues,
    required String notes,
  }) async {
    final therapistId = ref.read(therapistIdProvider);
    if (therapistId == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(grpcClientsProvider).clinical.rateReport(
            clinical_pb.RateReportRequest(
              reportId: widget.reportId,
              therapistId: therapistId,
              rating: 'negative',
              issues: issues,
              notes: notes,
              source: 'in_app',
              idempotencyKey: _uuid.v4(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _currentRating = 'negative';
        _submitting = false;
      });
      // Trigger banner re-check — this is the primary path that
      // moves the suggestion engine over its threshold.
      ref.read(suggestionRefreshTickProvider.notifier).bump();
      _toast(AppLocalizations.of(context).report_rating_saved_negative);
    } catch (e) {
      debugPrint('ReportRatingWidget: submitNegative failed: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(AppLocalizations.of(context).report_rating_save_error,
          isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      EuphireToast.error(context, message: msg);
    } else {
      EuphireToast.success(context, message: msg);
    }
  }

  Future<void> _openNegativeSheet() async {
    final result = await showModalBottomSheet<_NegativeFormResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _NegativeRatingSheet(),
    );
    if (result != null && result.issues.isNotEmpty) {
      await _submitNegative(issues: result.issues, notes: result.notes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final therapistId = ref.watch(therapistIdProvider);
    // Hide while auth is resolving — adding rating UI before we have a
    // therapist id would error out on tap.
    if (therapistId == null) return const SizedBox.shrink();

    final t = AppLocalizations.of(context);
    final isPositive = _currentRating == 'positive';
    final isNegative = _currentRating == 'negative';
    final disabled = _loading || _submitting;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: t.report_rating_thumbs_up_tooltip,
          icon: Icon(
            isPositive ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: isPositive ? EuphireColors.ember : null,
          ),
          onPressed: disabled ? null : _submitPositive,
        ),
        IconButton(
          tooltip: t.report_rating_thumbs_down_tooltip,
          icon: Icon(
            isNegative ? Icons.thumb_down : Icons.thumb_down_outlined,
            color: isNegative ? EuphireColors.magma : null,
          ),
          onPressed: disabled ? null : _openNegativeSheet,
        ),
      ],
    );
  }
}

// ─── Negative-rating sheet ────────────────────────────────────

class _NegativeFormResult {
  final List<String> issues;
  final String notes;
  _NegativeFormResult(this.issues, this.notes);
}

class _NegativeRatingSheet extends StatefulWidget {
  const _NegativeRatingSheet();

  @override
  State<_NegativeRatingSheet> createState() => _NegativeRatingSheetState();
}

class _NegativeRatingSheetState extends State<_NegativeRatingSheet> {
  final Set<String> _selected = {};
  final _notesController = TextEditingController();
  static const _notesMaxLen = 200;

  @override
  void dispose() {
    _notesController.dispose();
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
        // Cap to ~90% of screen so the sheet can't push above the
        // status bar when the keyboard is open.
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Drag handle
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
              // Icon + title header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: EuphireColors.magma.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.feedback_outlined,
                      color: EuphireColors.magma.withValues(alpha: 0.9),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.report_rating_modal_title,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.report_rating_modal_subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: EuphireColors.mist,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kCanonicalIssues.map((id) {
                  final selected = _selected.contains(id);
                  return FilterChip(
                    label: Text(_chipLabel(t, id)),
                    selected: selected,
                    onSelected: (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (v) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      });
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    selectedColor: EuphireColors.magma.withValues(alpha: 0.30),
                    checkmarkColor: EuphireColors.frostWhite,
                    labelStyle: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: selected
                          ? EuphireColors.frostWhite
                          : EuphireColors.frostWhite,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: selected
                          ? EuphireColors.magma
                          : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 1.5 : 1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                t.report_rating_notes_label,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: EuphireColors.frostWhite),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLength: _notesMaxLen,
                maxLines: 3,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: t.report_rating_notes_hint,
                  hintStyle:
                      theme.textTheme.bodyMedium?.copyWith(color: EuphireColors.mist),
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
                    borderSide: const BorderSide(
                      color: EuphireColors.ember,
                    ),
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
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_NegativeFormResult(
                            _selected.toList(),
                            _notesController.text.trim(),
                          )),
                  child: Text(
                    t.report_rating_submit,
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
