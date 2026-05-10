// EuphireSessionStatusStepper — Etap 4 / Task 4.1
//
// Maps Firestore session_states.status → 4-step UI per ADR-IMPL-012:
//   uploaded   → step 1 done
//   analyzing  → steps 1+2+3 done (backend SKIPS 'transcribing' in
//                  Phase 3 — we mark it complete on transition to
//                  analyzing)
//   done       → all 4 done
//   failed     → last step turns destructive (red); no Cascade.
//
// Listener gating (60s — D4) is handled by the parent view-model
// (SessionStatusViewModel) — this widget just renders state.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

enum SessionStepperPhase { pending, uploaded, analyzing, done, failed }

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

  const EuphireSessionStatusStepper({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final steps = [
      _Step(t.stepper_step1_uploaded, _stateForStep(0)),
      _Step(t.stepper_step2_transcribing, _stateForStep(1)),
      _Step(t.stepper_step3_analyzing, _stateForStep(2)),
      _Step(t.stepper_step4_done, _stateForStep(3)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepRow(
            number: i + 1,
            text: steps[i].text,
            state: steps[i].state,
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Container(
                width: 2,
                height: 24,
                color: steps[i].state == _StepState.done
                    ? EuphireColors.ember
                    : EuphireColors.nocturne,
              ),
            ),
        ],
      ],
    );
  }

  _StepState _stateForStep(int idx) {
    if (phase == SessionStepperPhase.failed) {
      // 0..3 — first three should reflect last known good state; the
      // last one becomes destructive. Treat as done up to whatever
      // was reached (we don't know exactly), so mark first 3 as done
      // and #4 as failed for clearer signal.
      if (idx < 3) return _StepState.done;
      return _StepState.failed;
    }
    final reached = switch (phase) {
      SessionStepperPhase.pending => -1,
      SessionStepperPhase.uploaded => 0,
      SessionStepperPhase.analyzing => 2, // backend skips 'transcribing'
      SessionStepperPhase.done => 3,
      SessionStepperPhase.failed => -1,
    };
    if (idx < reached) return _StepState.done;
    if (idx == reached) return _StepState.done;
    if (idx == reached + 1) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done, failed }

class _Step {
  final String text;
  final _StepState state;
  const _Step(this.text, this.state);
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final _StepState state;

  const _StepRow({
    required this.number,
    required this.text,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;
    final isFailed = state == _StepState.failed;

    final color = isFailed
        ? EuphireColors.magma
        : isDone
            ? EuphireColors.ember
            : isActive
                ? EuphireColors.ember
                : EuphireColors.nocturne;

    final icon = isFailed
        ? const Icon(Icons.close, size: 18, color: EuphireColors.frostWhite)
        : isDone
            ? const Icon(Icons.check, size: 18, color: EuphireColors.obsidianBlack)
            : Text('$number',
                style: const TextStyle(
                  color: EuphireColors.mist,
                  fontWeight: FontWeight.w600,
                ));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: EuphireColors.ember, width: 2)
                : null,
          ),
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isFailed
                  ? EuphireColors.magma
                  : (isDone || isActive)
                      ? EuphireColors.frostWhite
                      : EuphireColors.mist,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (isActive)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(EuphireColors.ember),
            ),
          ),
      ],
    );
  }
}
