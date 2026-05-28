// SessionStatusScreen — Etap 4 (full screen for the stepper +
// Success Cascade after report.generated).
//
// Listens to:
//   1. Firestore `session_states/{sessionId}` (primary signal)
//   2. clinical-svc.GetSessionDetails (60s fallback poll — D4)
//
// On status="done":
//   - Stepper collapses (animated slide-up + fade)
//   - Header text collapses
//   - Large success icon scales in (center of screen)
//   - HapticFeedback.heavyImpact()
//   - play assets/sounds/SFX_succes.mp3 (best-effort)
//   - 3-second pause, then push TranscriptScreen with replacement
//
// Apple-quality design:
//   - "Bezpieczna analiza w toku." header (Montserrat, ember)
//   - Subtitle: "Opracowujemy..." (Montserrat, mist, smaller)
//   - Connected-line stepper with glowing active step
//   - Bottom button: "Wróć do kartotek" with folder icon

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
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_session_status_stepper.dart';
import 'home_screen.dart';
import 'transcript_screen.dart';

class SessionStatusScreen extends ConsumerStatefulWidget {
  /// The server-side session UUID. Optional — when launched via
  /// the upload queue (new_session / recording screens), the
  /// sessionId is not known up front and arrives once
  /// CompleteAudioUpload succeeds inside the worker. In that case
  /// pass [localId] instead; this screen watches the queue row
  /// and transparently switches over to the sessionId-driven
  /// listeners when it lands.
  final String? sessionId;

  /// The upload queue's local row ID. When provided, the screen
  /// renders upload-phase progress from the queue until
  /// [PendingUpload.sessionId] is populated, then switches to the
  /// server-side processing listeners (Firestore + clinical-svc).
  final String? localId;

  const SessionStatusScreen({
    super.key,
    this.sessionId,
    this.localId,
  }) : assert(sessionId != null || localId != null,
            'Either sessionId or localId must be provided');

  @override
  ConsumerState<SessionStatusScreen> createState() =>
      _SessionStatusScreenState();
}

class _SessionStatusScreenState extends ConsumerState<SessionStatusScreen>
    with TickerProviderStateMixin {
  StreamSubscription<SessionState>? _sub;
  Timer? _fallbackTimer;
  SessionStepperPhase _phase = SessionStepperPhase.pending;
  bool _routedAway = false;
  bool _failureShown = false;
  /// Resolved sessionId — either passed in via widget.sessionId, or
  /// observed on the queue row after CompleteAudioUpload succeeds.
  /// Null while we're still in the upload phase.
  String? _resolvedSessionId;
  /// Snapshot of the last queue row we saw (when launched via
  /// localId). Used to render a small diagnostic label so the user
  /// — and us — can see exactly which phase the worker is in.
  PendingUpload? _lastRow;

  // ── Success Cascade controllers ──
  late final AnimationController _checkScaleAnim;
  late final AnimationController _checkGlowAnim;
  bool _showCheck = false;
  bool _collapsed = false; // drives stepper + header collapse

  @override
  void initState() {
    super.initState();
    _checkScaleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkGlowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Eager-resolve sessionId for the legacy entry point (when caller
    // already has one from a prior synchronous upload). For the
    // queue-based entry point we resolve it lazily as the worker
    // advances; see _onQueueSnapshot.
    if (widget.sessionId != null) {
      _resolvedSessionId = widget.sessionId;
      _startListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fallbackTimer?.cancel();
    _failureDelayTimer?.cancel();
    _checkScaleAnim.dispose();
    _checkGlowAnim.dispose();
    super.dispose();
  }

  void _startListeners() {
    final sid = _resolvedSessionId;
    if (sid == null) return; // queue-mode: not ready yet
    _sub = ref
        .read(sessionStateListenerProvider)
        .watchSession(sid)
        .listen(_onState);
    _resetFallbackTimer();
  }

  /// Called from the build() Consumer when the queue snapshot
  /// changes. Drives the stepper phase from upload state and, the
  /// moment CompleteAudioUpload returns, hands off to the
  /// sessionId-driven listeners.
  void _onQueueSnapshot(List<PendingUpload> rows) {
    final localId = widget.localId;
    if (localId == null) return;

    final row = rows.cast<PendingUpload?>().firstWhere(
          (u) => u?.localId == localId,
          orElse: () => null,
        );
    if (row == null) return;

    // Update the diagnostic label.
    if (_lastRow?.phase != row.phase ||
        _lastRow?.attemptCount != row.attemptCount ||
        _lastRow?.lastError != row.lastError) {
      if (mounted) setState(() => _lastRow = row);
    } else {
      _lastRow = row;
    }

    // Failure surface: queue worker classified the upload as
    // terminal-failed. Show the existing failure sheet with the
    // worker's lastError so the user sees what actually happened.
    if (row.phase == UploadPhase.failed &&
        !_failureShown &&
        !_routedAway) {
      _failureShown = true;
      _scheduleFailureSheet(reason: row.lastError);
      return;
    }

    // SessionId materialised — CompleteAudioUpload just succeeded.
    // Hand off to the server-side processing listeners. The
    // queue runner now subscribes to Firestore session_states for
    // this row and will refresh patient + session caches itself
    // when analysis terminates (see upload_queue_provider.dart).
    final newSid = row.sessionId;
    if (newSid != null && _resolvedSessionId == null) {
      _resolvedSessionId = newSid;
      if (mounted) {
        setState(() => _phase = SessionStepperPhase.uploaded);
      }
      _startListeners();
    }
  }

  void _onState(SessionState s) {
    final phase = s.status.toStepperPhase();
    if (mounted) setState(() => _phase = phase);
    _resetFallbackTimer();

    if (phase == SessionStepperPhase.done && !_routedAway) {
      _routedAway = true;
      // If a failure sheet is currently visible, dismiss it first
      _dismissFailureSheet();
      _runSuccessCascade();
    } else if (phase == SessionStepperPhase.failed && !_failureShown && !_routedAway) {
      // Delay showing failure to allow for pipeline retries.
      // Pub/Sub can retry a failed message while a new (valid) upload
      // is being processed — showing the error immediately would flash
      // a false failure.
      _failureShown = true;
      _scheduleFailureSheet();
    }
  }

  void _resetFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 60), _pollClinicalSvc);
  }

  Future<void> _pollClinicalSvc() async {
    final sid = _resolvedSessionId;
    if (sid == null) {
      // Still in upload phase; queue snapshots will drive us once
      // the server-side session_id arrives. Reschedule a no-op tick.
      _resetFallbackTimer();
      return;
    }
    try {
      final clients = ref.read(grpcClientsProvider);
      final res = await clients.clinical.getSessionDetails(
        clinical_pb.GetSessionDetailsRequest(sessionId: sid),
      );
      final status = res.session.status;
      if (status == 'COMPLETED' && !_routedAway) {
        _routedAway = true;
        _dismissFailureSheet();
        _runSuccessCascade();
      } else if (status == 'FAILED' && !_failureShown && !_routedAway) {
        _failureShown = true;
        _scheduleFailureSheet();
      } else {
        _resetFallbackTimer();
      }
    } catch (_) {
      _resetFallbackTimer();
    }
  }

  Future<void> _runSuccessCascade() async {
    // Phase 1: Collapse the stepper & header (animated)
    if (mounted) setState(() => _collapsed = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Phase 2: Show the big success icon
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _showCheck = true);
    _checkScaleAnim.forward();
    _checkGlowAnim.repeat(reverse: true);

    // Play success sound (best-effort)
    final player = AudioPlayer();
    try {
      await player.play(AssetSource('sounds/SFX_succes.mp3'));
    } catch (_) {/* asset may be missing in dev — best-effort */}

    // Phase 3: Wait and navigate
    await Future<void>.delayed(const Duration(seconds: 3));

    // Dismiss the queue row before navigating — server-side analysis
    // is fully done, so the pill on home should disappear. We do
    // this here (rather than relying on the queue's own GC) so the
    // pill state is in lock-step with the user-visible state.
    final localId = widget.localId;
    if (localId != null) {
      try {
        final runner = await ref.read(uploadQueueRunnerProvider.future);
        await runner?.dismiss(localId);
      } catch (e) {
        if (kDebugMode) debugPrint('[session-status] dismiss queue row failed: $e');
      }
    }

    if (!mounted) return;
    final sid = _resolvedSessionId;
    if (sid != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => TranscriptScreen(sessionId: sid),
      ));
    }
    try {
      await player.dispose();
    } catch (_) {}
  }

  /// Wait 5 seconds before showing a failure sheet — gives time for
  /// the pipeline to retry or for a newer upload to succeed.
  Timer? _failureDelayTimer;
  String? _failureReason;

  void _scheduleFailureSheet({String? reason}) {
    _failureReason = reason;
    _failureDelayTimer?.cancel();
    _failureDelayTimer = Timer(const Duration(seconds: 5), () {
      if (_routedAway) return; // success arrived in the meantime
      _showFailureSheet();
    });
  }

  void _dismissFailureSheet() {
    _failureDelayTimer?.cancel();
    // Pop the failure sheet if it's currently shown
    if (_failureShown && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showFailureSheet() async {
    if (!mounted || _routedAway) return;
    final t = AppLocalizations.of(context);
    final reason = _failureReason;
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: true, // Allow user to dismiss and wait
      builder: (ctx) => EuphireActionSheet(
        header: t.session_failed_header,
        body: reason != null && reason.isNotEmpty
            ? '${t.session_failed_body}\n\n$reason'
            : t.session_failed_body,
        primary: EuphireSheetAction(
          label: t.session_failed_primary,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _navigateBackToRecords() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    // When launched in queue-mode, react to every queue snapshot so
    // we can advance the stepper phase and pick up sessionId the
    // moment CompleteAudioUpload returns.
    if (widget.localId != null) {
      ref.listen<AsyncValue<List<PendingUpload>>>(
        pendingUploadsStreamProvider,
        (prev, next) => next.whenData(_onQueueSnapshot),
      );
      // listen() only fires on changes — drive the initial snapshot
      // ourselves so the screen reflects the current row state on
      // first paint (in case the worker already advanced past
      // `pending` before this screen mounted).
      ref
          .read(pendingUploadsStreamProvider)
          .whenData(_onQueueSnapshot);
    }

    return Scaffold(
      backgroundColor: EuphireColors.evergreen,
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar area ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      color: EuphireColors.frostWhite,
                      tooltip: t.common_back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // ── Main content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _showCheck
                      ? _buildSuccessView(t)
                      : _buildProcessingView(t),
                ),
              ),

              // ── Bottom button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: AnimatedOpacity(
                  opacity: _showCheck ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _navigateBackToRecords,
                      icon: const Icon(
                        Icons.folder_open_rounded,
                        size: 20,
                      ),
                      label: Text(t.session_status_back_to_records),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EuphireColors.mist,
                        side: BorderSide(
                          color: EuphireColors.mist.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingView(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // ── Header: "Bezpieczna analiza w toku." ──
        AnimatedOpacity(
          opacity: _collapsed ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedSlide(
            offset: _collapsed ? const Offset(0, -0.15) : Offset.zero,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.session_status_title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.ember,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.session_status_subtitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        // ── Stepper ──
        EuphireSessionStatusStepper(
          phase: _phase,
          collapsed: _collapsed,
        ),
        const SizedBox(height: 16),
        // ── Queue-state diagnostic ──
        // Only shown while we're in the upload phase (sessionId
        // hasn't materialised yet). Helps the user — and us in dev
        // — see exactly which phase the queue is in.
        if (_lastRow != null && _resolvedSessionId == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _queuePhaseLabel(_lastRow!),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        // The raw gRPC last-error text used to render here (red,
        // dev-style). For quota-exhausted submits QuotaExhaustedDialog
        // already surfaces the right message; for everything else the
        // queue-phase line above plus the retry counter is enough.
        // Surfacing raw status codes / framework error strings to the
        // therapist was noisy and confusing — kept in PendingUpload
        // for our own diagnostics but no longer rendered.
        const Spacer(),
      ],
    );
  }

  String _queuePhaseLabel(PendingUpload u) {
    final attempt = u.attemptCount > 0 ? ' • próba ${u.attemptCount + 1}' : '';
    switch (u.phase) {
      case UploadPhase.pending:
        return 'W kolejce$attempt';
      case UploadPhase.created:
        return 'Przesyłam plik na serwer...$attempt';
      case UploadPhase.uploaded:
        return 'Plik na serwerze, finalizuję...$attempt';
      case UploadPhase.converted:
        return 'Konwersja gotowa, finalizuję...$attempt';
      case UploadPhase.completed:
        return 'Wgrane';
      case UploadPhase.failed:
        return 'Błąd';
    }
  }

  Widget _buildSuccessView(AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Animated success icon ──
          AnimatedBuilder(
            animation: _checkGlowAnim,
            builder: (context, child) {
              final glowOpacity = 0.15 + (_checkGlowAnim.value * 0.2);
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: _checkScaleAnim,
                  curve: Curves.elasticOut,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: EuphireColors.ember,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: EuphireColors.ember.withValues(alpha: glowOpacity),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 64,
                    color: EuphireColors.obsidianBlack,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // ── Success text ──
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _checkScaleAnim,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
            ),
            child: Column(
              children: [
                Text(
                  t.session_status_success,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.stepper_step5_done,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
