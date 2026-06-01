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
import '../uploads/cancel_upload_action.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_session_status_stepper.dart';
import 'home_screen_v2.dart';
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
        debugPrint('[session-status] dismiss queue row failed: $e');
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
                    // Bin = cancel processing (feat/tokens-exhausted).
                    // Shown while the session is still cancellable
                    // (pre-completion): either a local queue row exists
                    // or we resolved a server session_id. Confirm →
                    // CancelSession (CANCELLED_BY_USER + token release)
                    // → leave this screen.
                    if (!_showCheck && _canCancel)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onCancelPressed,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: EuphireColors.magma.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: EuphireColors.magma.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cancel_outlined, size: 18, color: EuphireColors.magma),
                                const SizedBox(width: 6),
                                const Text(
                                  'Usuń z analizy',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: EuphireColors.magma,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

              // ── Bottom buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: AnimatedOpacity(
                  opacity: _showCheck ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quota hold → explicit "Wyślij ponownie". Auto-retry
                      // is off; this is the only way to re-attempt once the
                      // plan tops up. Filled style so it reads as the
                      // primary action, above the secondary "back" link.
                      if (_isQuotaBlocked) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _onResendPressed,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(t.upload_resend),
                            style: FilledButton.styleFrom(
                              backgroundColor: EuphireColors.ember,
                              foregroundColor: EuphireColors.obsidianBlack,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _navigateBackToRecords,
                          icon: const Icon(Icons.folder_open_rounded, size: 20),
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
                    ],
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
          quotaBlocked: _lastRow?.phase == UploadPhase.quotaBlocked,
        ),
        const SizedBox(height: 16),
        // ── Queue-state diagnostic ──
        // Only shown while we're in the upload phase (sessionId hasn't
        // materialised yet) AND not quota-blocked (the stepper step-1
        // label already says "Pula tokenów wyczerpana", so the mono
        // diagnostic would just duplicate it).
        if (_lastRow != null && _resolvedSessionId == null && !_isQuotaBlocked)
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
        // Resend lives in the bottom button area (below) so it never
        // overlaps "Wróć do kartotek". The raw gRPC last-error text used
        // to render here (dev-style) — removed; the stepper label + the
        // bottom resend button carry the meaning now.
        const Spacer(),
      ],
    );
  }

  /// The session_id we can cancel, if any: a resolved server session
  /// or the one the local queue row already captured. May be null for a
  /// quota-blocked upload (CreateAudioUpload errored before returning a
  /// session_id) — in that case we still cancel by dropping the local
  /// queue row via [_onCancelPressed].
  String? get _cancelableSessionId =>
      _resolvedSessionId ?? _lastRow?.sessionId;

  /// Whether the bin (cancel) action is available. True whenever there's
  /// something to cancel — a local queue row (drop it) and/or a server
  /// session (CancelSession). Not gated on a session_id, so quota-blocked
  /// rows (no session_id) still get the bin.
  /// Whether the "Usuń z analizy" control is shown.
  ///
  /// Only while the audio is still WAITING LOCALLY — queued / mid-upload
  /// (pending, created) or parked on a quota hold. Once the bytes are in
  /// the bucket (phase >= uploaded) the server owns the analysis and there
  /// is nothing local to cancel from here, so the button is hidden.
  bool get _canCancel {
    final row = _lastRow;
    if (row == null) return false;
    switch (row.phase) {
      case UploadPhase.pending:
      case UploadPhase.created:
      case UploadPhase.quotaBlocked:
        return true;
      default:
        return false;
    }
  }

  bool get _isQuotaBlocked => _lastRow?.phase == UploadPhase.quotaBlocked;

  /// Bin-icon handler — confirm + CancelSession + leave the screen.
  Future<void> _onCancelPressed() async {
    final cancelled = await confirmAndCancelUpload(
      context,
      ref,
      patientFileId: _lastRow?.patientFileId,
      sessionId: _cancelableSessionId,
      localId: widget.localId ?? _lastRow?.localId,
    );
    if (cancelled && mounted) {
      _routedAway = true;
      Navigator.of(context).maybePop();
    }
  }

  /// Un-park a quota-blocked upload (explicit resend). No-op if the
  /// row isn't parked.
  Future<void> _onResendPressed() async {
    final localId = widget.localId ?? _lastRow?.localId;
    if (localId == null) return;
    final runner = await ref.read(uploadQueueRunnerProvider.future);
    await runner?.resend(localId);
  }

  String _queuePhaseLabel(PendingUpload u) {
    final t = AppLocalizations.of(context);
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
      case UploadPhase.quotaBlocked:
        return t.quota_blocked_queue_label;
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
