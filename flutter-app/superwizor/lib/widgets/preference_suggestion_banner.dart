// PreferenceSuggestionBanner — surfaces a one-tap nudge when the
// suggestion engine (clinical-svc) detects ≥3 negative ratings on the
// same chip category in the last 5 reports.
//
// Lifecycle (3 events, all logged via clinical-svc.LogPreferenceSuggestion):
//   - shown:     fired ONCE when the banner first becomes visible.
//   - applied:   fired SERVER-SIDE by identity-svc.UpdateReportPreferences
//                when the user taps the Apply CTA — the client only
//                calls UpdateReportPreferences; the server cross-logs.
//   - dismissed: fired client-side when user taps Dismiss. Sets a
//                14-day cooldown for the (therapist, dimension) pair
//                so we don't re-nag.
//
// Visibility rules:
//   - Hidden if therapist not resolved (no auth context).
//   - Hidden if GetActiveSuggestion returns empty suggestion_id (the
//     engine's "no banner" signal — see proto comment).
//   - Hidden if the suggestion's to_value already equals the
//     therapist's current preference for that dimension (no-op nudge,
//     filtered client-side per backend contract — server doesn't have
//     access to identity-svc preferences when picking the nudge).
//
// Special case — `dimension == "section_emphasis"`:
//   The backend returns empty from/to values because section emphasis
//   is multi-select; there's no single canonical "next value" to
//   apply. The banner shows a deep-link CTA ("Open settings") instead
//   of one-tap apply.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../l10n/app_localizations.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import '../screens/menu_screen.dart';
import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';

/// Tick that bumps whenever something happens that may have created
/// a new active suggestion (most importantly: a new rating was
/// submitted). The banner watches this and refetches; the rating
/// widget increments it after a successful RateReport. Initial value
/// 0 — the banner loads once on mount even if the tick hasn't moved.
class SuggestionRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final suggestionRefreshTickProvider =
    NotifierProvider<SuggestionRefreshTickNotifier, int>(
  SuggestionRefreshTickNotifier.new,
);

// ────────────────────────────────────────────────────────────
// Local label helpers. Kept in-file (vs imported from
// report_preferences_section.dart) so the banner doesn't drag in
// the entire settings widget tree for two small switch statements.
// ────────────────────────────────────────────────────────────

String _dimensionLabel(AppLocalizations t, String dimension) {
  switch (dimension) {
    case 'length':
      return t.report_prefs_length_label;
    case 'tone':
      return t.report_prefs_tone_label;
    case 'quote_density':
      return t.report_prefs_quote_density_label;
    case 'diagnostic_language':
      return t.report_prefs_diagnostic_language_label;
    case 'hypothesis_hedging':
      return t.report_prefs_hypothesis_hedging_label;
    case 'strengths_framing':
      return t.report_prefs_strengths_framing_label;
    case 'section_emphasis':
      return t.report_prefs_section_emphasis_label;
    case 'free_text':
      return t.report_prefs_free_text_label;
    default:
      return dimension;
  }
}

String _valueLabel(AppLocalizations t, String dimension, String value) {
  // Best-effort: return localized label for known (dimension, value)
  // pairs; otherwise fall through to the raw value string so a future
  // server-side option (added before the client catches up) still
  // renders something readable instead of an empty button.
  switch (dimension) {
    case 'length':
      switch (value) {
        case 'brief':
          return t.report_prefs_length_brief;
        case 'standard':
          return t.report_prefs_length_standard;
        case 'detailed':
          return t.report_prefs_length_detailed;
      }
      break;
    case 'tone':
      switch (value) {
        case 'clinical_formal':
          return t.report_prefs_tone_clinical_formal;
        case 'empathic_warm':
          return t.report_prefs_tone_empathic_warm;
        case 'pragmatic_direct':
          return t.report_prefs_tone_pragmatic_direct;
        case 'academic_rigorous':
          return t.report_prefs_tone_academic_rigorous;
      }
      break;
    case 'quote_density':
      switch (value) {
        case 'few':
          return t.report_prefs_quote_density_few;
        case 'selective':
          return t.report_prefs_quote_density_selective;
        case 'many':
          return t.report_prefs_quote_density_many;
      }
      break;
    case 'hypothesis_hedging':
      switch (value) {
        case 'tentative':
          return t.report_prefs_hypothesis_hedging_tentative;
        case 'balanced':
          return t.report_prefs_hypothesis_hedging_balanced;
        case 'assertive':
          return t.report_prefs_hypothesis_hedging_assertive;
      }
      break;
    case 'strengths_framing':
      switch (value) {
        case 'problem_focused':
          return t.report_prefs_strengths_framing_problem_focused;
        case 'balanced':
          return t.report_prefs_strengths_framing_balanced;
        case 'strengths_first':
          return t.report_prefs_strengths_framing_strengths_first;
      }
      break;
    case 'diagnostic_language':
      switch (value) {
        case 'descriptive':
          return t.report_prefs_diagnostic_language_descriptive;
        case 'clinical_labels':
          return t.report_prefs_diagnostic_language_clinical_labels;
        case 'dsm_icd':
          return t.report_prefs_diagnostic_language_dsm_icd;
      }
      break;
  }
  return value;
}

/// Pick the current value of `dimension` from a ReportPreferences row.
/// Used to (a) suppress the banner when current == to_value (no-op
/// nudge), and (b) write the unchanged-fields back when applying.
String _currentValueForDimension(
    identity_pb.ReportPreferences prefs, String dimension) {
  switch (dimension) {
    case 'length':
      return prefs.length;
    case 'tone':
      return prefs.tone;
    case 'quote_density':
      return prefs.quoteDensity;
    case 'diagnostic_language':
      return prefs.diagnosticLanguage;
    case 'hypothesis_hedging':
      return prefs.hypothesisHedging;
    case 'strengths_framing':
      return prefs.strengthsFraming;
    default:
      return '';
  }
}

/// Returns a deep-copy of prefs with `dimension` set to `value`.
/// Used by the Apply CTA. section_emphasis is excluded — the banner
/// deep-links to settings for that case rather than auto-applying.
identity_pb.ReportPreferences _withDimension(
    identity_pb.ReportPreferences prefs, String dimension, String value) {
  final next = prefs.deepCopy();
  switch (dimension) {
    case 'length':
      next.length = value;
      break;
    case 'tone':
      next.tone = value;
      break;
    case 'quote_density':
      next.quoteDensity = value;
      break;
    case 'diagnostic_language':
      next.diagnosticLanguage = value;
      break;
    case 'hypothesis_hedging':
      next.hypothesisHedging = value;
      break;
    case 'strengths_framing':
      next.strengthsFraming = value;
      break;
    // No section_emphasis case — handled by deep-link path.
  }
  return next;
}

// ────────────────────────────────────────────────────────────
// Banner widget
// ────────────────────────────────────────────────────────────

class PreferenceSuggestionBanner extends ConsumerStatefulWidget {
  const PreferenceSuggestionBanner({super.key});

  @override
  ConsumerState<PreferenceSuggestionBanner> createState() =>
      _PreferenceSuggestionBannerState();
}

class _PreferenceSuggestionBannerState
    extends ConsumerState<PreferenceSuggestionBanner> {
  clinical_pb.PreferenceSuggestion? _suggestion;
  identity_pb.ReportPreferences? _prefs;
  // The candidate we're actually rendering. Picked from
  // _suggestion.alternatives by skipping no-ops (current pref ==
  // toValue). When all candidates are no-ops, _activeCandidate stays
  // null and the banner hides. Re-computed in _selectActiveCandidate
  // after every load and every dismiss-and-retry within the same
  // suggestion response (dismissing alternative N reveals
  // alternative N+1).
  clinical_pb.PreferenceSuggestionCandidate? _activeCandidate;
  // Indices of alternatives the user has dismissed within this
  // suggestion response. Cleared when a fresh _load() runs (new
  // suggestion_id, fresh slate). Lets one dismiss → next alternative
  // → another dismiss → next, all without a server round-trip.
  final Set<int> _dismissedAlternativeIndices = <int>{};
  bool _loading = true;
  bool _busy = false;
  bool _shownLogged = false;
  bool _hiddenLocally = false; // user fully dismissed the banner in this session
  // Snapshot of the last suggestionRefreshTickProvider value the
  // widget has actually fetched against. When this falls behind the
  // current tick, build() re-fires _load() and clears _hiddenLocally
  // (the user has rated something new, so a fresh banner may be
  // warranted).
  int _lastFetchedTick = -1;
  final _uuid = const Uuid();

  Future<void> _load() async {
    final therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Fetch suggestion + current prefs in parallel — both are
      // needed before we can decide visibility.
      final results = await Future.wait([
        ref.read(grpcClientsProvider).clinical.getActiveSuggestion(
              clinical_pb.GetActiveSuggestionRequest(therapistId: therapistId),
            ),
        ref.read(grpcClientsProvider).identity.getReportPreferences(
              identity_pb.GetReportPreferencesRequest(therapistId: therapistId),
            ),
      ]);
      if (!mounted) return;
      setState(() {
        _suggestion = results[0] as clinical_pb.PreferenceSuggestion;
        _prefs = results[1] as identity_pb.ReportPreferences;
        _loading = false;
        // New suggestion response = fresh dismiss state.
        _dismissedAlternativeIndices.clear();
        _activeCandidate = _pickActiveCandidate();
      });
    } catch (e) {
      // Banner is a nice-to-have surface; never block the host
      // screen on an RPC error. Hide silently.
      debugPrint('PreferenceSuggestionBanner: load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Walk alternatives in rank order, return the first one that
  /// isn't a no-op against the therapist's current prefs and hasn't
  /// already been dismissed in this session. Falls back to the
  /// legacy top-level fields when alternatives is empty (an old
  /// server response). Returns null when nothing actionable remains.
  clinical_pb.PreferenceSuggestionCandidate? _pickActiveCandidate() {
    final s = _suggestion;
    if (s == null || s.suggestionId.isEmpty) return null;

    bool isActionable(String dimension, String toValue) {
      // section_emphasis: no canonical to_value (multi-select); banner
      // shows a deep-link CTA regardless of pref state.
      if (dimension == 'section_emphasis') return true;
      if (toValue.isEmpty) return false;
      final prefs = _prefs;
      if (prefs == null) return true; // can't filter without prefs
      return _currentValueForDimension(prefs, dimension) != toValue;
    }

    if (s.alternatives.isNotEmpty) {
      for (var i = 0; i < s.alternatives.length; i++) {
        if (_dismissedAlternativeIndices.contains(i)) continue;
        final c = s.alternatives[i];
        if (isActionable(c.dimension, c.toValue)) return c;
      }
      return null;
    }
    // Legacy fallback — server didn't return alternatives (old build).
    if (!isActionable(s.dimension, s.toValue)) return null;
    return clinical_pb.PreferenceSuggestionCandidate(
      dimension: s.dimension,
      fromValue: s.fromValue,
      toValue: s.toValue,
      reasonLabel: s.reasonLabel,
      triggerCount: s.triggerCount,
    );
  }

  /// Returns the rank-index of [_activeCandidate] in
  /// [_suggestion.alternatives], or -1 if not found (legacy path).
  int _activeCandidateIndex() {
    final s = _suggestion;
    final c = _activeCandidate;
    if (s == null || c == null) return -1;
    for (var i = 0; i < s.alternatives.length; i++) {
      if (!_dismissedAlternativeIndices.contains(i) &&
          s.alternatives[i].dimension == c.dimension &&
          s.alternatives[i].toValue == c.toValue) {
        return i;
      }
    }
    return -1;
  }

  bool _shouldShow() {
    if (_hiddenLocally) return false;
    if (_loading) return false;
    return _activeCandidate != null;
  }

  Future<void> _logEvent(String action) async {
    final therapistId = ref.read(therapistIdProvider);
    final s = _suggestion;
    final c = _activeCandidate;
    if (therapistId == null || s == null || c == null) return;
    try {
      await ref.read(grpcClientsProvider).clinical.logPreferenceSuggestion(
            clinical_pb.LogPreferenceSuggestionRequest(
              therapistId: therapistId,
              suggestionId: s.suggestionId,
              // Log the dimension/values that were actually rendered —
              // critical for cooldown semantics (dismiss is keyed by
              // dimension, and we want to cool down whatever the user
              // saw, not necessarily the top-ranked chip).
              dimension: c.dimension,
              fromValue: c.fromValue,
              toValue: c.toValue,
              triggerCount: c.triggerCount,
              action: action,
            ),
          );
    } catch (e) {
      // Telemetry is fire-and-forget; never block the user.
      debugPrint(
          'PreferenceSuggestionBanner: logPreferenceSuggestion($action) failed: $e');
    }
  }

  Future<void> _apply() async {
    final therapistId = ref.read(therapistIdProvider);
    final s = _suggestion;
    final c = _activeCandidate;
    final prefs = _prefs;
    if (therapistId == null || s == null || c == null || prefs == null || _busy) {
      return;
    }

    // section_emphasis: deep-link to settings rather than auto-apply.
    if (c.dimension == 'section_emphasis') {
      // Log a 'dismissed' so we don't keep re-nagging in the lookback
      // window after the user clicked into settings. (Server fires
      // 'applied' separately if/when they actually pick something.)
      await _logEvent('dismissed');
      if (!mounted) return;
      setState(() => _hiddenLocally = true);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MenuScreen()),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final next = _withDimension(prefs, c.dimension, c.toValue);
      await ref.read(grpcClientsProvider).identity.updateReportPreferences(
            identity_pb.UpdateReportPreferencesRequest(
              therapistId: therapistId,
              preferences: next,
              idempotencyKey: _uuid.v4(),
            ),
          );
      // Note: identity-svc fires the "applied" log row internally —
      // we do NOT double-log here. (See proto comment on
      // LogPreferenceSuggestionRequest.action.)
      if (!mounted) return;
      setState(() {
        _hiddenLocally = true;
        _busy = false;
      });
      EuphireToast.success(context, message: AppLocalizations.of(context).suggestion_banner_applied_toast);
    } catch (e) {
      debugPrint('PreferenceSuggestionBanner: apply failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      EuphireToast.error(context, message: AppLocalizations.of(context).suggestion_banner_apply_error);
    }
  }

  Future<void> _dismiss() async {
    if (_busy || _activeCandidate == null) return;
    setState(() => _busy = true);
    // Log the dismiss for the current candidate so the server-side
    // 14-day cooldown for *that dimension* kicks in.
    await _logEvent('dismissed');
    if (!mounted) return;

    // Try advancing to the next alternative within the same suggestion
    // response — saves a server round-trip and a re-shown event when
    // the user is iterating through dimensions they want to ignore.
    final dismissedIdx = _activeCandidateIndex();
    if (dismissedIdx >= 0) {
      _dismissedAlternativeIndices.add(dismissedIdx);
    }
    final next = _pickActiveCandidate();
    setState(() {
      _activeCandidate = next;
      _busy = false;
      if (next == null) {
        // All alternatives exhausted → fully hide for this session.
        _hiddenLocally = true;
      } else {
        // New candidate is being shown — re-emit the "shown" event.
        _shownLogged = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch therapistIdProvider so the widget rebuilds when auth
    // finishes resolving (currentUserProvider is a FutureProvider
    // backed by an identity-svc RPC — at app startup, the banner
    // mounts BEFORE that resolves).
    final therapistId = ref.watch(therapistIdProvider);

    // Watch the refresh tick. The rating widget increments this on
    // every successful RateReport so the banner can refetch and
    // surface a newly-triggered suggestion without the user having to
    // restart the app. Initial fetch is also driven through this path
    // (current tick != -1).
    final tick = ref.watch(suggestionRefreshTickProvider);

    if (therapistId != null && tick != _lastFetchedTick) {
      _lastFetchedTick = tick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Clear per-session dismissal so a new banner can appear after
        // the user rated more reports. Server-side cooldown still
        // protects against re-nagging the *same dimension* within 14
        // days — see preference_suggestions_log.
        _hiddenLocally = false;
        _shownLogged = false;
        _load();
      });
    }

    if (!_shouldShow()) return const SizedBox.shrink();

    final t = AppLocalizations.of(context);
    final c = _activeCandidate!;
    final theme = Theme.of(context);

    // Fire "shown" once per *active candidate*. When the user dismisses
    // and the banner falls through to the next alternative, _shownLogged
    // is reset to false so a fresh "shown" event fires for that
    // candidate's dimension. Telemetry stays accurate per banner view.
    if (!_shownLogged) {
      _shownLogged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logEvent('shown');
      });
    }

    final isSectionEmphasis = c.dimension == 'section_emphasis';
    final body = isSectionEmphasis
        ? t.suggestion_banner_body_section_emphasis(
            c.reasonLabel, c.triggerCount)
        : t.suggestion_banner_body(
            c.reasonLabel,
            c.triggerCount,
            _dimensionLabel(t, c.dimension),
            _valueLabel(t, c.dimension, c.toValue),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        decoration: BoxDecoration(
          color: EuphireColors.ember.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EuphireColors.ember.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: EuphireColors.ember, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.suggestion_banner_header,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: EuphireColors.ember,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Inline dismiss "X" — secondary affordance for users
                // who don't want to read the body.
                IconButton(
                  tooltip: t.suggestion_banner_dismiss,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.close,
                      color: EuphireColors.mist.withValues(alpha: 0.7)),
                  onPressed: _busy ? null : _dismiss,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 4),
              child: Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: EuphireColors.frostWhite.withValues(alpha: 0.92),
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 22, right: 0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EuphireColors.ember,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _busy ? null : _apply,
                      child: Text(
                        isSectionEmphasis
                            ? t.suggestion_banner_open_settings
                            : t.suggestion_banner_apply,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EuphireColors.frostWhite,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _busy ? null : _dismiss,
                      child: Text(
                        t.suggestion_banner_dismiss,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
