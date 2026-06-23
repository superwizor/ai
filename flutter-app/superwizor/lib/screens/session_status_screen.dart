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
import 'package:intl/intl.dart';
import '../utils/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/services_provider.dart';
import '../providers/settings_provider.dart';
import '../services/live_activity_service.dart';
import '../services/recording_foreground_service.dart';
import '../services/session_state_listener.dart';
import '../theme/euphire_theme.dart';
import '../uploads/cancel_upload_action.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../models/session.dart';
import '../providers/patient_provider.dart';

import '../widgets/euphire_session_status_stepper.dart';
import 'home_screen.dart';
import 'transcript_screen.dart';

/// Error classification for the failure view — 3 buckets cover
/// all possible errors without per-error copy.
enum _ErrorBucket { upload, processing, unknown }

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
  AudioPlayer? _successPlayer;

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
      // Immediate check for sessions that are already terminal (e.g.
      // user tapped a FAILED card from kartoteka). Firestore won't
      // fire a new event for an already-written terminal status.
      _pollClinicalSvc();
      // Also check sessionsProvider — covers debug-sim injections
      // AND locally-cached sessions from a previous Firestore sync.
      _checkCachedSessionStatus();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fallbackTimer?.cancel();
    _failureDelayTimer?.cancel();
    _checkScaleAnim.dispose();
    _checkGlowAnim.dispose();
    _successPlayer?.dispose();
    super.dispose();
  }

  void _playSuccessSound() async {
    try {
      if (_successPlayer != null) {
        await _successPlayer!.stop();
        await _successPlayer!.dispose();
      }
      final newPlayer = AudioPlayer();
      _successPlayer = newPlayer;
      await newPlayer.play(AssetSource('sounds/SFX_succes.mp3'));
      newPlayer.onPlayerComplete.first.then((_) {
        if (mounted && _successPlayer == newPlayer) {
          newPlayer.dispose();
          _successPlayer = null;
        }
      }).catchError((_) {
        if (mounted && _successPlayer == newPlayer) {
          newPlayer.dispose();
          _successPlayer = null;
        }
      });
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  /// Synchronous check against the in-memory sessions cache (which
  /// includes debug-sim injected sessions). If the session is already
  /// in a terminal state, skip the async listener/poll wait.
  void _checkCachedSessionStatus() {
    final sid = _resolvedSessionId;
    if (sid == null || _routedAway || _failureShown) return;
    final sessionsMap = ref.read(sessionsProvider).value;
    if (sessionsMap == null) return;
    for (final sessions in sessionsMap.values) {
      for (final s in sessions) {
        if (s.id == sid) {
          if (s.status == SessionStatus.error && !_failureShown) {
            _failureShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _phase = SessionStepperPhase.failed);
              }
            });
          } else if (s.status == SessionStatus.completed && !_routedAway) {
            _routedAway = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _runSuccessCascade();
            });
          }
          return;
        }
      }
    }
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
        _lastRow?.uploadProgress != row.uploadProgress ||
        _lastRow?.lastError != row.lastError) {
      if (mounted) setState(() => _lastRow = row);
    } else {
      _lastRow = row;
    }

    // Failure surface: queue worker classified the upload as
    // terminal-failed. Route to the inline _buildFailureView via
    // _phase = failed (build() switches on it).
    if (row.phase == UploadPhase.failed &&
        !_failureShown &&
        !_routedAway) {
      _failureShown = true;
      _failureReason = row.lastError;
      if (mounted) setState(() => _phase = SessionStepperPhase.failed);
      return;
    }

    // Push Live Activity to uploading while the queue worker is active.
    // UploadPhase.created = signed URL obtained, PUT in progress.
    if (row.phase == UploadPhase.created &&
        ref.read(appSettingsProvider).liveActivitiesEnabled) {
      ref.read(liveActivityServiceProvider).update(
        status: LiveActivityStatus.uploading,
        elapsedSeconds: 0,
      );
    }
    // Android foreground notification: update to uploading status.
    if (row.phase == UploadPhase.created) {
      RecordingForegroundService.updateStatus(
        title: 'Wgrywanie nagrania...',
        body: 'Superwizor przesyła nagranie sesji na serwer.',
      );
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
    if (_failureShown || _routedAway) return; // Do not override terminal states!
    final phase = s.status.toStepperPhase();
    if (mounted) setState(() => _phase = phase);
    _resetFallbackTimer();

    // Push Live Activity updates for analyzing phase.
    if (ref.read(appSettingsProvider).liveActivitiesEnabled) {
      if (phase == SessionStepperPhase.analyzing) {
        ref.read(liveActivityServiceProvider).update(
          status: LiveActivityStatus.analyzing,
          elapsedSeconds: 0,
        );
      }
    }
    // Android foreground notification: update to analyzing status.
    if (phase == SessionStepperPhase.analyzing) {
      RecordingForegroundService.updateStatus(
        title: 'Analizowanie sesji...',
        body: 'AI przygotowuje raport kliniczny.',
      );
    }

    if (phase == SessionStepperPhase.done && !_routedAway) {
      _routedAway = true;
      // If a failure sheet is currently visible, dismiss it first
      _dismissFailureSheet();
      _runSuccessCascade();
    } else if (phase == SessionStepperPhase.failed && !_failureShown && !_routedAway) {
      // The inline _buildFailureView renders automatically via the
      // build() routing (phase == failed). No bottom sheet needed —
      // the inline view is persistent and can't be accidentally dismissed.
      _failureShown = true;
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
        if (mounted) setState(() => _phase = SessionStepperPhase.failed);
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
    AppHapticFeedback.heavyImpact();
    if (mounted) setState(() => _showCheck = true);
    _checkScaleAnim.forward();
    _checkGlowAnim.repeat(reverse: true);

    // Play success sound (respects user preference)
    if (ref.read(appSettingsProvider).soundEnabled) {
      _playSuccessSound();
    }

    // Push Live Activity to reportReady.
    if (ref.read(appSettingsProvider).liveActivitiesEnabled &&
        _resolvedSessionId != null) {
      ref.read(liveActivityServiceProvider).showReportReady(
        sessionId: _resolvedSessionId!,
      );
    }

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

    // Stop the Live Activity — the user is about to see the report.
    if (ref.read(appSettingsProvider).liveActivitiesEnabled) {
      ref.read(liveActivityServiceProvider).stop();
    }
    // Stop the Android foreground service — analysis is done.
    RecordingForegroundService.stop();

    final sid = _resolvedSessionId;
    if (sid != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => TranscriptScreen(sessionId: sid),
      ));
    }
  }

  /// Wait 5 seconds before showing a failure sheet — gives time for
  /// the pipeline to retry or for a newer upload to succeed.
  Timer? _failureDelayTimer;
  String? _failureReason;

  void _dismissFailureSheet() {
    _failureDelayTimer?.cancel();
    // Pop the failure sheet if it's currently shown (legacy path)
    if (_failureShown && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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

    // Resolve details for the top card
    final sessionsMap = ref.watch(sessionsProvider).value;
    Session? session;
    if (sessionsMap != null && _resolvedSessionId != null) {
      for (final list in sessionsMap.values) {
        for (final s in list) {
          if (s.id == _resolvedSessionId) {
            session = s;
            break;
          }
        }
        if (session != null) break;
      }
    }

    final patients = ref.watch(patientsProvider).value;
    final patientId = _lastRow?.patientFileId ?? session?.patientId;
    final patient = patients?.where((p) => p.id == patientId).firstOrNull;
    final patientName = patient != null ? '${patient.firstName} ${patient.lastName}' : 'Pacjent';

    final date = session?.date ?? _lastRow?.queuedAt.toLocal() ?? DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(date);
    final formattedDate = DateFormat('d MMMM yyyy', 'pl').format(date);

    final duration = session?.duration ?? Duration(seconds: _lastRow?.actualDurationSeconds ?? 0);
    final minutes = (duration.inSeconds / 60).toStringAsFixed(0);

    final sizeBytes = _lastRow?.sizeBytes ?? ((session?.fileSizeBytes != null && session!.fileSizeBytes > 0) ? session.fileSizeBytes : null);
    final formattedSize = sizeBytes != null ? '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB' : null;

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
                  ],
                ),
              ),

              // ── Recording Details Card ──
              if (!_showCheck) ...[
                _buildRecordingDetailsCard(
                  session,
                  patientName,
                  formattedTime,
                  formattedDate,
                  minutes,
                  formattedSize,
                ),
                const SizedBox(height: 8),
              ],

              // ── Main content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _showCheck
                      ? _buildSuccessView(t)
                      : _phase == SessionStepperPhase.failed
                          ? _buildFailureView(t)
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
                      if (_isQuotaBlocked || _phase == SessionStepperPhase.failed) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _onResendPressed,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(_isQuotaBlocked ? t.upload_resend : 'Spróbuj ponownie'),
                            style: FilledButton.styleFrom(
                              backgroundColor: EuphireColors.ember,
                              foregroundColor: EuphireColors.obsidianBlack,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
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
                      if (_phase == SessionStepperPhase.failed) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _onCancelPressed,
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            label: const Text('Usuń sesję'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EuphireColors.magma,
                              side: BorderSide(
                                color: EuphireColors.magma.withValues(alpha: 0.35),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
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
                              borderRadius: BorderRadius.circular(5),
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
        if (_lastRow != null && !_isQuotaBlocked && 
            (_lastRow!.phase == UploadPhase.created || 
             _lastRow!.phase == UploadPhase.pending ||
             _lastRow!.phase == UploadPhase.encrypting ||
             _lastRow!.phase == UploadPhase.converting))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _UploadProgressCard(upload: _lastRow!),
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
  /// Whether the trash icon (cancel) action is shown.
  ///
  /// Only while the audio is still WAITING LOCALLY — queued / mid-upload
  /// (pending, created) or parked on a quota hold. Once the bytes are in
  /// the bucket (phase >= uploaded) the server owns the analysis and there
  /// is nothing local to cancel from here, so the button is hidden.
  bool get _canCancel {
    final row = _lastRow;
    if (row == null) return false;
    switch (row.phase) {
      case UploadPhase.encrypting:
      case UploadPhase.converting:
      case UploadPhase.pending:
      case UploadPhase.created:
      case UploadPhase.failed:
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

  // ── Failure View ─────────────────────────────────────────────────
  // Three error buckets — the classifier maps every possible error
  // to exactly one bucket, so we never need per-error copy.
  //
  //   upload     – connection / timeout / local queue failure
  //   processing – server-side STT / LLM pipeline error
  //   unknown    – catch-all (shouldn't happen, but solid UX)


  _ErrorBucket _classifyError() {
    final row = _lastRow;
    // Queue-based: classify from the phase the failure occurred in.
    if (row != null) {
      switch (row.phase) {
        case UploadPhase.encrypting:
        case UploadPhase.converting:
        case UploadPhase.pending:
        case UploadPhase.created:
          return _ErrorBucket.upload;
        case UploadPhase.uploaded:
        case UploadPhase.converted:
        case UploadPhase.completed:
        case UploadPhase.failed:
        case UploadPhase.quotaBlocked:
          break; // fall through to heuristic
      }
      // Heuristic on lastError string for queue rows in ambiguous phases.
      final err = (row.lastError ?? '').toLowerCase();
      if (err.contains('network') ||
          err.contains('connection') ||
          err.contains('timeout') ||
          err.contains('socket') ||
          err.contains('dns') ||
          err.contains('tls') ||
          err.contains('ssl') ||
          err.contains('upload')) {
        return _ErrorBucket.upload;
      }
    }
    // Heuristic on _failureReason (set by queue snapshot or poll).
    final reason = (_failureReason ?? '').toLowerCase();
    if (reason.contains('network') ||
        reason.contains('connection') ||
        reason.contains('timeout') ||
        reason.contains('socket')) {
      return _ErrorBucket.upload;
    }
    // Server-side failure (Firestore-driven or poll-driven) → processing.
    if (_resolvedSessionId != null) {
      return _ErrorBucket.processing;
    }
    return _ErrorBucket.unknown;
  }

  Widget _buildFailureView(AppLocalizations t) {
    final bucket = _classifyError();

    // 3 templates — natural, calming, actionable.
    final (IconData icon, String title, String body) = switch (bucket) {
      _ErrorBucket.upload => (
          Icons.wifi_off_rounded,
          'Przesyłanie zatrzymane',
          'Wystąpił problem z połączeniem sieciowym.\n\n'
              'Nagranie jest bezpieczne na Twoim urządzeniu. '
              'System wznowi przesyłanie, gdy odzyskasz zasięg.',
        ),
      _ErrorBucket.processing => (
          Icons.sync_problem_rounded,
          'Przetwarzanie zatrzymane',
          'Proces tworzenia raportu napotkał trudność.\n\n'
              'Nagranie z sesji jest bezpieczne. Znajdziesz je w kartotece klienta. '
              'Spróbuj ponowić analizę za jakiś czas.',
        ),
      _ErrorBucket.unknown => (
          Icons.help_outline_rounded,
          'Przetwarzanie przerwane',
          'Nie udało się wygenerować raportu dla tej sesji.\n\n'
              'Twoje nagranie jest bezpieczne w kartotece klienta. '
              'Jeśli sytuacja się powtarza, daj nam znać.',
        ),
    };

    return Column(
      children: [
        const Spacer(flex: 2),
        // ── Icon ──
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: EuphireColors.ember.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: EuphireColors.ember.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 40,
              color: EuphireColors.ember.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 28),
        // ── Title ──
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: EuphireColors.frostWhite,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Body ──
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: EuphireColors.mist.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
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

  Widget _buildRecordingDetailsCard(
    Session? session,
    String patientName,
    String formattedTime,
    String formattedDate,
    String minutes,
    String? formattedSize,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: EuphireColors.ember.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  patientName,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Time & Date
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$formattedTime  •  $formattedDate',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              // Duration
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$minutes min',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              if (formattedSize != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.audiotrack_rounded,
                      size: 14,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedSize,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: EuphireColors.mist.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Upload Progress Card ─────────────────────────────────────────

class _UploadProgressCard extends StatelessWidget {
  const _UploadProgressCard({required this.upload});
  final PendingUpload upload;

  @override
  Widget build(BuildContext context) {
    final isUploading = upload.phase == UploadPhase.created;
    final mb = (upload.sizeBytes / 1024 / 1024).toStringAsFixed(1);
    final mins = (upload.actualDurationSeconds / 60).toStringAsFixed(0);
    // e.g. "audio/flac" -> "flac", or keep full "audio/flac" if preferred. The plan says "audio/flac".
    final cType = upload.contentType.isNotEmpty ? upload.contentType : 'audio';
    final time = DateFormat('HH:mm').format(upload.queuedAt.toLocal());

    return Container(
      decoration: EuphireColors.glassDecoration(
        surfaceOpacity: 0.05,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Icon(
                isUploading ? Icons.cloud_upload_rounded : Icons.schedule_rounded,
                color: EuphireColors.ember,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isUploading ? 'Przesyłanie na serwer' : 'W kolejce do przesłania',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ),
            ],
          ),
          
          if (isUploading) ...[
            const SizedBox(height: 20),
            // Progress Bar Row
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: upload.uploadProgress > 0
                          ? upload.uploadProgress.clamp(0.0, 1.0)
                          : null,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(EuphireColors.ember),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(upload.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EuphireColors.mist.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Details Sub-card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: EuphireColors.obsidianBlack.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.audiotrack_rounded,
                    size: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$mb MB  •  $mins min',
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 11,
                          color: EuphireColors.mist.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cType  •  $time',
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 11,
                          color: EuphireColors.mist.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Reassurance Text
          Text(
            'Możesz bezpiecznie opuścić ten ekran,\nsesja przetworzy się w tle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
