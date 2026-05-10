// SessionStatusScreen — Etap 4 (full screen for the stepper +
// Success Cascade after report.generated).
//
// Listens to:
//   1. Firestore `session_states/{sessionId}` (primary signal)
//   2. clinical-svc.GetSessionDetails (60s fallback poll — D4)
//
// On status="done":
//   - HapticFeedback.heavyImpact()
//   - play assets/sounds/SFX_succes.wav (best-effort — file may not
//     exist in early dev builds; we never block the cascade on it)
//   - show check icon (Material check; Lottie can be swapped in later)
//   - 2-second pause, then push TranscriptScreen with replacement

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/services_provider.dart';
import '../services/session_state_listener.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_session_status_stepper.dart';
import 'transcript_screen.dart';

class SessionStatusScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionStatusScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionStatusScreen> createState() =>
      _SessionStatusScreenState();
}

class _SessionStatusScreenState extends ConsumerState<SessionStatusScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<SessionState>? _sub;
  Timer? _fallbackTimer;
  SessionStepperPhase _phase = SessionStepperPhase.uploaded;
  bool _routedAway = false;
  bool _failureShown = false;
  late final AnimationController _checkAnim;
  bool _showCheck = false;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _startListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fallbackTimer?.cancel();
    _checkAnim.dispose();
    super.dispose();
  }

  void _startListeners() {
    _sub = ref
        .read(sessionStateListenerProvider)
        .watchSession(widget.sessionId)
        .listen(_onState);
    _resetFallbackTimer();
  }

  void _onState(SessionState s) {
    final phase = s.status.toStepperPhase();
    if (mounted) setState(() => _phase = phase);
    _resetFallbackTimer();

    if (phase == SessionStepperPhase.done && !_routedAway) {
      _routedAway = true;
      _runSuccessCascade();
    } else if (phase == SessionStepperPhase.failed && !_failureShown) {
      _failureShown = true;
      _showFailureSheet();
    }
  }

  void _resetFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 60), _pollClinicalSvc);
  }

  Future<void> _pollClinicalSvc() async {
    try {
      final clients = ref.read(grpcClientsProvider);
      final res = await clients.clinical.getSessionDetails(
        clinical_pb.GetSessionDetailsRequest(sessionId: widget.sessionId),
      );
      final status = res.session.status;
      if (status == 'COMPLETED' && !_routedAway) {
        _routedAway = true;
        _runSuccessCascade();
      } else if (status == 'FAILED' && !_failureShown) {
        _failureShown = true;
        _showFailureSheet();
      } else {
        _resetFallbackTimer();
      }
    } catch (_) {
      _resetFallbackTimer();
    }
  }

  Future<void> _runSuccessCascade() async {
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _showCheck = true);
    _checkAnim.forward();
    final player = AudioPlayer();
    try {
      await player.play(AssetSource('sounds/SFX_succes.mp3'));
    } catch (_) {/* asset may be missing in dev — best-effort */}
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => TranscriptScreen(sessionId: widget.sessionId),
    ));
    try {
      await player.dispose();
    } catch (_) {}
  }

  Future<void> _showFailureSheet() async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        header: t.session_failed_header,
        body: t.session_failed_body,
        primary: EuphireSheetAction(
          label: t.session_failed_primary,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Explicit back button. The backend pipeline is decoupled from
        // this screen — leaving it does NOT cancel the session; the
        // Firestore listener is per-screen but the worker keeps running
        // server-side. Therapist can always come back to the session
        // from the patient detail list. UX gain: never trap the user.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: t.common_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              EuphireHeader(
                title: t.session_loading,
                subtitle: _phase == SessionStepperPhase.done
                    ? t.stepper_step4_done
                    : null,
              ),
              const SizedBox(height: 48),
              EuphireSessionStatusStepper(phase: _phase),
              const Spacer(),
              if (_showCheck)
                Center(
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _checkAnim,
                      curve: Curves.elasticOut,
                    ),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: EuphireColors.ember,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 64, color: EuphireColors.obsidianBlack),
                    ),
                  ),
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
