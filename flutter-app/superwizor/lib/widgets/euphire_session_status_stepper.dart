// EuphireSessionStatusStepper — Etap 4 / Task 4.1
//
// Maps Firestore session_states.status → 5-step UI per ADR-IMPL-012:
//   uploaded   → step 1 done
//   analyzing  → steps 1+2+3 done (backend SKIPS 'transcribing' in
//                  Phase 3 — we mark it complete on transition to
//                  analyzing)
//   done       → all 5 done
//   failed     → last step turns destructive (red); no Cascade.
//
// Listener gating (60s — D4) is handled by the parent view-model
// (SessionStatusViewModel) — this widget just renders state.
//
// Apple-quality design: connected line between steps, subtle glow on
// active step, obsidianBlack numbers on ember background (fixes the
// white-on-yellow visibility bug).

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

enum SessionStepperPhase { pending, uploading, uploaded, analyzing, done, failed }

extension SessionStepperPhaseFromStatus on String {
  SessionStepperPhase toStepperPhase() {
    switch (this) {
      case 'uploaded':
        return SessionStepperPhase.uploaded;
      case 'transcribing':
      case 'analyzing':
        return SessionStepperPhase.analyzing;
      case 'done':
      case 'completed':
        return SessionStepperPhase.done;
      case 'failed':
        return SessionStepperPhase.failed;
      default:
        return SessionStepperPhase.pending;
    }
  }
}

class EuphireSessionStatusStepper extends StatelessWidget {
  final SessionStepperPhase phase;

  /// When true, steps fade out with animation (used for success cascade).
  final bool collapsed;

  /// When true, the upload is parked on a quota hold (the org ran out
  /// of tokens). Step 1's label switches from the neutral "waiting in
  /// queue" to the meaningful "token pool exhausted — renew to resume"
  /// (feat/tokens-exhausted). Only meaningful while [phase] is pending.
  final bool quotaBlocked;

  /// Optional widget to display inside the active step (e.g. upload progress
  /// or details).
  final Widget? activeStepContent;

  const EuphireSessionStatusStepper({
    super.key,
    required this.phase,
    this.collapsed = false,
    this.quotaBlocked = false,
    this.activeStepContent,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Step 1 has two labels: while we are still queued (no session_id
    // returned yet — upload hasn't even been accepted, e.g. due to
    // QUOTA_EXHAUSTED retries) we say "audio waiting in upload queue".
    // Only after the server has accepted the upload (phase >= uploaded)
    // do we claim the audio is safe on our servers. Previously the
    // first label was always shown, which was misleading: a quota-
    // blocked upload sat under "Audio bezpieczne na naszych serwerach"
    // even though the file never reached us.
    final step1Text = switch (phase) {
        SessionStepperPhase.pending => quotaBlocked
            ? t.stepper_step1_quota_blocked
            : t.stepper_step1_queued,
        SessionStepperPhase.uploading => t.stepper_step1_uploading,
        _ => t.stepper_step1_uploaded,
    };
    final steps = [
      _Step(step1Text, _stateForStep(0), activeStepContent),
      _Step(t.stepper_step2_transcribing, _stateForStep(1)),
      // "Składamy informacje w czytelny raport" (finalizing) was merged
      // into the analysis step — step 3 now represents the whole
      // AI-processing phase, so the timeline reflects the real backend
      // state instead of showing a separate (misleading) finalizing step.
      _Step(t.stepper_step3_analyzing, _stateForStep(2)),
      _Step(t.stepper_step5_done, _stateForStep(3)),
    ];

    return AnimatedOpacity(
      opacity: collapsed ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: collapsed ? const Offset(0, -0.1) : Offset.zero,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < steps.length; i++)
              _StepRow(
                number: i + 1,
                text: steps[i].text,
                state: steps[i].state,
                isLast: i == steps.length - 1,
                nextState: i < steps.length - 1 ? steps[i + 1].state : null,
                content: steps[i].content,
              ),
          ],
        ),
      ),
    );
  }

  _StepState _stateForStep(int idx) {
    // Quota hold (feat/tokens-exhausted): the upload never started, so
    // nothing is processing. Step 1 shows a static "blocked" marker (no
    // spinner); the rest stay pending. This avoids the ember "active"
    // circle + CircularProgressIndicator that wrongly imply work is
    // underway.
    if (quotaBlocked) {
      return idx == 0 ? _StepState.blocked : _StepState.pending;
    }
    if (phase == SessionStepperPhase.failed) {
      if (idx < 3) return _StepState.done;
      return _StepState.failed;
    }
    final reached = switch (phase) {
      SessionStepperPhase.pending => -1,
      // uploading: step 1 is active (PUT in progress), nothing done yet.
      SessionStepperPhase.uploading => -1,
      SessionStepperPhase.uploaded => 0,
      // analyzing: audio + transcription marked done; the AI analysis step
      // (idx 2) is the ACTIVE processing step — there's no separate
      // finalizing step after it anymore.
      SessionStepperPhase.analyzing => 1,
      SessionStepperPhase.done => 3,
      SessionStepperPhase.failed => -1,
    };
    if (idx < reached) return _StepState.done;
    if (idx == reached) return _StepState.done;
    if (idx == reached + 1) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done, failed, blocked }

class _Step {
  final String text;
  final _StepState state;
  final Widget? content;
  const _Step(this.text, this.state, [this.content]);
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final _StepState state;
  final bool isLast;
  final _StepState? nextState;
  final Widget? content;

  const _StepRow({
    required this.number,
    required this.text,
    required this.state,
    required this.isLast,
    this.nextState,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;
    final isFailed = state == _StepState.failed;
    final isBlocked = state == _StepState.blocked;
    // Circle colors
    final circleColor = isFailed
        ? EuphireColors.magma
        : isDone || isActive || isBlocked
            ? EuphireColors.ember
            : Colors.white.withValues(alpha: 0.08);

    // Connector line: active if both current and next step are done/active
    final lineActive = isDone &&
        (nextState == _StepState.done || nextState == _StepState.active);

    // BUG FIX: Numbers must use obsidianBlack on ember background.
    // Previously used mist (light grey) which was invisible on yellow.
    final icon = isFailed
        ? const Icon(Icons.close_rounded, size: 16, color: EuphireColors.frostWhite)
        : isBlocked
            ? const Icon(Icons.account_balance_wallet_outlined,
                size: 15, color: EuphireColors.obsidianBlack)
            : isDone
                ? const Icon(Icons.check_rounded, size: 16, color: EuphireColors.obsidianBlack)
                : Text(
                '$number',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  // Active step (ember bg) → dark text. Pending (dark bg) → mist.
                  color: isActive
                      ? EuphireColors.obsidianBlack
                      : EuphireColors.mist,
                ),
              );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column: circle + connector line ──
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Circle with optional glow for active state
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: EuphireColors.ember.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: icon,
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: lineActive
                            ? EuphireColors.ember
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // ── Right column: text + spinner ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0.0 : 28.0,
                top: 5.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      color: isFailed
                          ? EuphireColors.magma
                          : isDone || isActive || isBlocked
                              ? EuphireColors.frostWhite
                              : EuphireColors.mist.withValues(alpha: 0.5),
                      fontWeight: isActive || isBlocked
                          ? FontWeight.w600
                          : isDone
                              ? FontWeight.w400
                              : FontWeight.w300,
                      height: 1.4,
                    ),
                  ),
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: content ??
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: const AlwaysStoppedAnimation(
                                  EuphireColors.ember),
                            ),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
