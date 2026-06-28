// RecordingScreen — Etap 3 (Sesja w toku).
//
// Flow:
//   1. user lands here from patient detail with `patientFileId` and
//      `therapistId`
//   2. ConsentService.hasConsent() second-line check; missing → show
//      "Brak zgody" sheet, pop back
//   3. Generate sessionId, start RecordingService (FLAC @ 16 kHz mono)
//   4. UI shows waveform + counter + instructions block
//   5. Stop button:
//        < 5 min → "Nagranie zbyt krótkie" sheet, recording continues
//        ≥ 5 min → "Zakończenie i analiza sesji" sheet (3 actions)
//   6. At 130 min → auto-pause + persist PENDING_UPLOAD + show
//      "Limit czasu" sheet
//   7. After confirmation: encrypt → request signed URL → PUT →
//      CompleteAudioUpload → pop with sessionId so caller can route
//      to status stepper screen

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../services/recording_manifest_store.dart';
import '../services/recording_service.dart';
import '../services/live_activity_service.dart';
import '../providers/settings_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/euphire_theme.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_recording_indicator.dart';
import 'session_status_screen.dart';
import '../analytics/analytics_collector.dart';

import '../widgets/minimized_recording_bar.dart';

// TODO(pre-prod): restore to Duration(minutes: 5) before TestFlight.
// Lowered to 30s for end-to-end smoke testing on real device — saves us
// ~5 min per pipeline test cycle. The < 5 min "Nagranie zbyt krótkie"
// sheet behavior is exercised separately in widget tests.
const Duration kMinSessionDuration = Duration(seconds: 30);
const Duration kMaxSessionDuration = Duration(minutes: 180); // D5 hard ceiling

class RecordingScreen extends ConsumerStatefulWidget {
  final String patientFileId;
  final String therapistId;
  final String patientAlias;
  final String reportLanguage;

  const RecordingScreen({
    super.key,
    required this.patientFileId,
    required this.therapistId,
    required this.patientAlias,
    required this.reportLanguage,
  });

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? _sessionId;
  Duration _displayDuration = Duration.zero;
  RecordingState _recState = RecordingState.idle;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<RecordingState>? _stateSub;
  bool _uploading = false;
  bool _maxLimitTriggered = false;
  // Number of "still recording" reminder intervals already fired this session,
  // so each interval boundary triggers exactly once.
  int _remindersFired = 0;
  // Guards double-taps on the post-interruption resume button while the
  // capture-verification probe (~1.2 s) runs.
  bool _resuming = false;
  // Live chunk count for the recording indicator. Encryption now runs in
  // the upload worker (not inline on finish), so this stays 0 — the
  // indicator just doesn't show a chunk tally. Kept for the widget API.
  final int _chunkCount = 0;
  ProviderSubscription<AppSettings>? _settingsSub;
  // True from screen entry until the recorder actually starts capturing.
  // During this phase the control panel (yellow mic button) is hidden
  // and the waveform area shows "Rozpoczynam nagrywanie…" — the user
  // never sees a fleeting idle state.
  bool _initializing = true;

  // ── Entrance animations ──
  // Staggered fade+slide for a premium, fluid screen entry.
  late final AnimationController _entranceController;
  late final AnimationController _headerController;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<double> _waveformScale;
  late final Animation<double> _waveformFade;

  RecordingService get _service => ref.read(recordingServiceProvider);
  late final RecordingScreenVisibleNotifier _visibleNotifier;

  @override
  void initState() {
    super.initState();
    _visibleNotifier = ref.read(recordingScreenVisibleProvider.notifier);
    WidgetsBinding.instance.addObserver(this);

    // ── Entrance animation setup ──
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Header: fade in + slide down
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          ),
        );
    // Waveform: scale up from 0.85 + fade in
    _waveformFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _waveformScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    // Start the entrance animation immediately.
    _entranceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleNotifier.setVisible(true);
      ref
          .read(analyticsCollectorProvider)
          .track(
            "screen.viewed",
            properties: {"screen_name": "RecordingScreen"},
          );

      // React to Live Activity toggle changes mid-session: if the user
      // enables LA while a recording is active, start it immediately;
      // if they disable it, stop it.
      // NOTE: ref.listenManual (not ref.listen) because this runs in
      // postFrameCallback, outside the build() method. ref.listen throws
      // in Riverpod 3.x when called outside build().
      _settingsSub = ref.listenManual<AppSettings>(appSettingsProvider, (
        prev,
        next,
      ) {
        final wasOn = prev?.liveActivitiesEnabled ?? false;
        final isOn = next.liveActivitiesEnabled;
        if (wasOn == isOn) return;

        final la = ref.read(liveActivityServiceProvider);
        final svc = _service;
        final isActive =
            svc.state == RecordingState.recording ||
            svc.state == RecordingState.paused ||
            svc.state == RecordingState.interrupted;

        if (isOn && isActive) {
          // Start LA for the in-progress session
          la.start(
            patientAlias: widget.patientAlias,
            elapsedSeconds: svc.currentDuration.inSeconds,
          );
          debugPrint('[recording] LA started mid-session (toggle on)');
        } else if (!isOn) {
          la.stop();
          debugPrint('[recording] LA stopped mid-session (toggle off)');
        }
      });

      // Defer heavy work (consent check, permission, recorder start)
      // until the page transition finishes. This prevents all
      // platform-channel calls from competing with the route
      // slide-in animation for main-thread time.
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        void onTransitionEnd(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            route.animation!.removeStatusListener(onTransitionEnd);
            if (!mounted) return;
            _verifyConsentAndStart();
          }
        }

        if (route.animation!.isCompleted) {
          // Already completed (e.g. pushReplacement with no animation)
          _verifyConsentAndStart();
        } else {
          route.animation!.addStatusListener(onTransitionEnd);
        }
      } else {
        // No route animation (shouldn't happen, but safety net)
        _verifyConsentAndStart();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _headerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _durSub?.cancel();
    _stateSub?.cancel();
    _settingsSub?.close();
    Future.microtask(() {
      _visibleNotifier.setVisible(false);
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The native pause event for an interruption that fired while the
    // Flutter isolate was suspended (therapist answering a call) may
    // never be delivered — ask the plugin directly on every return to
    // foreground so the UI can't keep claiming "recording" while the
    // OS holds the recorder paused. docs/28 WS2.
    if (state == AppLifecycleState.resumed) {
      _service.reconcileWithNative();

      // Check if this RecordingScreen is still the top route.
      // When the user returns via the Live Activity widget tap, the
      // Navigator may have reset to root (HomeScreen) — in that case
      // recordingScreenVisible must be false so the minimized bar
      // appears as a return path.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isTop = ModalRoute.of(context)?.isCurrent ?? false;
        _visibleNotifier.setVisible(isTop);
      });
    }
  }

  Future<void> _verifyConsentAndStart() async {
    debugPrint('[recording] _verifyConsentAndStart() CALLED');
    // If the service is already recording/paused/interrupted, just attach to it!
    if (_service.state == RecordingState.recording ||
        _service.state == RecordingState.paused ||
        _service.state == RecordingState.interrupted) {
      debugPrint('[recording] already active (${_service.state}), attaching');
      _sessionId = _service.activeSessionId;
      setState(() {
        _displayDuration = _service.currentDuration;
        _recState = _service.state;
        _initializing = false;
      });
      _headerController.value = 1.0;

      _durSub = _service.durationStream.listen(_onDurationTick);
      _stateSub = _service.stateStream.listen((s) {
        if (!mounted) return;
        setState(() => _recState = s);
      });
      return;
    }

    // ── Consent gate ──
    // LOCAL FIRST (instant, <5ms). Consent can only be granted, never
    // revoked, so a cached “true” is always valid. This skips the
    // gRPC round-trip (200–3000ms) for every repeat recording.
    // Backend is only consulted when local cache is empty — which
    // happens after a fresh install or reinstall (Hive is wiped).
    debugPrint('[recording] checking local consent first...');
    final localConsent = await ref
        .read(consentServiceProvider)
        .hasConsent(patientFileId: widget.patientFileId);
    debugPrint('[recording] localConsent=$localConsent');
    if (localConsent) {
      debugPrint('[recording] local consent=true → calling _start()');
      await _start();
      return;
    }

    // No local consent — backend check (handles reinstall case where
    // Hive cache was wiped but backend already has consent).
    bool backendSaysConsent = false;
    try {
      debugPrint(
        '[recording] no local consent, calling getPatientFile gRPC...',
      );
      final patient = await ref
          .read(grpcClientsProvider)
          .clinical
          .getPatientFile(
            clinical_pb.GetPatientFileRequest(
              patientFileId: widget.patientFileId,
            ),
          )
          .timeout(const Duration(seconds: 3));
      backendSaysConsent = patient.hasRecordingConsent;
      debugPrint('[recording] gRPC ok, backendSaysConsent=$backendSaysConsent');
    } catch (e) {
      // Backend unreachable or timed out — fall through to consent sheet.
      // Conservative: an offline therapist who already captured
      // consent shouldn’t be blocked from recording.
      debugPrint('[recording] gRPC getPatientFile FAILED: $e');
    }
    if (backendSaysConsent) {
      debugPrint('[recording] backend consent=true → calling _start()');
      await _start();
      return;
    }

    if (!mounted) return;
    final t = AppLocalizations.of(context);
    debugPrint('[recording] NO consent → showing consent sheet');
    final granted = await showEuphireBottomSheet<bool>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_consent_missing_header,
        body: t.recording_consent_missing_body,
        primary: EuphireSheetAction(
          label: t.recording_consent_grant,
          onPressed: () async {
            try {
              await ref
                  .read(consentServiceProvider)
                  .recordConsent(
                    patientFileId: widget.patientFileId,
                    documentVersion: 'v1.0',
                  );
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            } catch (e) {
              if (ctx.mounted) Navigator.of(ctx).pop(false);
            }
          },
        ),
        secondary: EuphireSheetAction(
          label: t.common_cancel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
    );
    if (granted != true && mounted) {
      Navigator.of(context).pop();
    } else if (granted == true && mounted) {
      await _start();
    }
    return;
  }

  /// Pre-flight permission check before kicking off the recorder.
  /// Returns true on granted, false if the user declined (caller pops).
  ///
  /// On iOS 26+ `permission_handler` sometimes returns stale
  /// `permanentlyDenied` BEFORE iOS sees the request — meaning the
  /// OS-native dialog never fires and the per-app Microphone toggle
  /// in Settings never appears. We bypass that by calling the
  /// `record` package's `hasPermission()` directly (it routes to
  /// `AVAudioApplication.requestRecordPermission`, which is the
  /// canonical iOS native call). `permission_handler` is only used
  /// as a fallback when the native call says no, so we can still
  /// detect denial and show "Open Settings" with a recovery path.
  Future<bool> _ensureMicPermission() async {
    final recorder = AudioRecorder();
    try {
      final granted = await recorder.hasPermission();
      debugPrint('[recording] native mic permission: granted=$granted');
      if (granted) return true;
    } finally {
      await recorder.dispose();
    }

    // Native call returned false. Fall back to permission_handler so
    // we can distinguish "user just tapped Don't Allow" (recoverable
    // via Settings) from "first-time refusal" (already shown the OS
    // dialog above).
    final fallback = await Permission.microphone.request();
    debugPrint('[recording] permission_handler fallback: $fallback');
    if (fallback.isGranted) return true;

    if (!mounted) return false;
    await _showMicDeniedSheet();
    if (!mounted) return false;
    Navigator.of(context).pop();
    return false;
  }

  Future<void> _showMicDeniedSheet() async {
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_mic_denied_header,
        body: t.recording_mic_denied_body,
        primary: EuphireSheetAction(
          label: t.recording_mic_denied_open_settings,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await openAppSettings();
          },
        ),
        secondary: EuphireSheetAction(
          label: t.recording_mic_denied_cancel,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _start() async {
    // Captured before the first await so we don’t reach across an async
    // gap for context; feeds the Android FGS notification (docs/28 WS5).
    final t = AppLocalizations.of(context);
    final ok = await _ensureMicPermission();
    if (!ok) return;

    // Yield one frame after the permission check so the UI can
    // render smoothly before the heavy AVAudioSession + encoder
    // setup inside _service.start() blocks the main thread.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      _sessionId = const Uuid().v4();
      await _service.start(
        _sessionId!,
        patientFileId: widget.patientFileId,
        therapistId: widget.therapistId,
        patientAlias: widget.patientAlias,
        reportLanguage: widget.reportLanguage,
        fgsTitle: t.recording_fgs_notification_title,
        fgsBody: t.recording_fgs_notification_body,
      );

      // ── Recorder is live — update UI IMMEDIATELY ──
      // Stream listeners first so the very first duration/state tick
      // is not lost, then setState to flip _initializing off and
      // show recording controls. Everything below this setState is
      // non-critical and must NOT block the UI update.
      _durSub = _service.durationStream.listen(_onDurationTick);
      _stateSub = _service.stateStream.listen((s) {
        if (!mounted) return;
        if (s == RecordingState.interrupted &&
            _recState != RecordingState.interrupted) {
          ref
              .read(analyticsCollectorProvider)
              .track(
                "recording.interrupted",
                properties: {"at_seconds": _service.currentDuration.inSeconds},
              );
        }
        setState(() => _recState = s);
        // Mirror state to native widget.
        final laOn = ref.read(appSettingsProvider).liveActivitiesEnabled;
        if (laOn || Platform.isAndroid) {
          final la = ref.read(liveActivityServiceProvider);
          final elapsed = _service.currentDuration.inSeconds;
          switch (s) {
            case RecordingState.recording:
              la.update(
                status: LiveActivityStatus.recording,
                elapsedSeconds: elapsed,
              );
            case RecordingState.paused:
              la.update(
                status: LiveActivityStatus.paused,
                elapsedSeconds: elapsed,
              );
            case RecordingState.interrupted:
              la.update(
                status: LiveActivityStatus.paused,
                elapsedSeconds: elapsed,
              );
            default:
              break;
          }
        }
      });
      // Initialization complete — recorder is live, show controls.
      setState(() {
        _initializing = false;
        _recState = _service.state;
      });

      // Haptic feedback when the recording actually begins.
      HapticFeedback.lightImpact();

      // Animate header with a slight delay so it emerges at the very end.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _headerController.forward();
      });

      // ── Non-critical work below: fire-and-forget ──
      // None of this blocks the recording UI update.
      ref.read(analyticsCollectorProvider).track("recording.started");

      final laEnabled = ref.read(appSettingsProvider).liveActivitiesEnabled;
      if (laEnabled || Platform.isAndroid) {
        ref
            .read(liveActivityServiceProvider)
            .start(patientAlias: widget.patientAlias, elapsedSeconds: 0);
      }

      // Durable manifest next to raw.flac (docs/28 WS1): from this moment
      // an app-kill at ANY point leaves enough on disk for the orphan-
      // recovery scan to offer the partial recording on next launch.
      // Best-effort, never blocks the recording UI.
      unawaited(
        ref
            .read(recordingManifestStoreProvider)
            .write(
              RecordingManifest(
                sessionId: _sessionId!,
                therapistId: widget.therapistId,
                patientFileId: widget.patientFileId,
                patientAlias: widget.patientAlias,
                patientLanguageCode: widget.reportLanguage,
                startedAtUtc: DateTime.now().toUtc(),
              ),
            )
            .catchError((e) {
              debugPrint('[recording] manifest write failed (non-fatal): $e');
            }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      _headerController.forward();
      final t = AppLocalizations.of(context);
      await showEuphireBottomSheet<void>(
        context: context,
        builder: (ctx) => EuphireActionSheet(
          header: t.recording_mic_error_header,
          body: e.toString(),
          primary: EuphireSheetAction(
            label: 'OK',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _showDiscardConfirmationSheet() async {
    if (!mounted) return false;
    final t = AppLocalizations.of(context);
    final doubleConfirm = await showEuphireBottomSheet<bool>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_discard_confirm_header,
        body: t.recording_discard_confirm_body,
        topIcon: Icons.warning_rounded,
        primary: EuphireSheetAction(
          label: t.recording_discard_confirm_cancel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        destructive: EuphireSheetAction(
          label: t.recording_discard_confirm_action,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
    return doubleConfirm == true;
  }

  Future<bool> _confirmDiscardOnBack() async {
    if (_recState == RecordingState.idle ||
        _recState == RecordingState.stopped ||
        _recState == RecordingState.error) {
      return true; // nothing to discard
    }
    final t = AppLocalizations.of(context);
    final result = await showEuphireBottomSheet<String>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_minimize_confirm_header,
        body: t.recording_minimize_confirm_body,
        primary: EuphireSheetAction(
          label: t.recording_minimize_action,
          onPressed: () => Navigator.of(ctx).pop('minimize'),
        ),
        secondary: EuphireSheetAction(
          label: t.recording_minimize_resume,
          onPressed: () => Navigator.of(ctx).pop('stay'),
        ),
        destructive: EuphireSheetAction(
          label: t.recording_minimize_discard,
          onPressed: () => Navigator.of(ctx).pop('discard'),
        ),
      ),
    );
    if (result == 'minimize') {
      // Show first-time Live Activities toast if the feature is off
      // and the user hasn't seen the prompt yet.
      final settings = ref.read(appSettingsProvider);
      if (!settings.liveActivitiesEnabled &&
          !settings.hasSeenLiveActivitiesPrompt) {
        ref.read(appSettingsProvider.notifier).markLiveActivitiesPromptSeen();
        if (mounted) {
          final t = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t.live_activity_minimize_toast,
                style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
              ),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0A2326),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
      return true;
    } else if (result == 'discard') {
      final confirmed = await _showDiscardConfirmationSheet();
      if (confirmed) {
        final dur = _service.currentDuration.inSeconds;
        await _service.cancel();
        await _deleteManifest();
        ref
            .read(analyticsCollectorProvider)
            .track(
              "recording.cancelled",
              properties: {"duration_seconds": dur},
            );
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteManifest() async {
    final id = _sessionId;
    if (id != null) {
      await ref.read(recordingManifestStoreProvider).delete(id);
    }
  }

  /// Resume tap — both the control panel and the interruption banner.
  /// RecordingService.resume() VERIFIES capture restarted after an
  /// interruption (docs/28 WS3); on failure we tell the user loudly and
  /// offer the safe exits instead of pretending to record.
  Future<void> _onResumeTap() async {
    if (_resuming) return;
    setState(() => _resuming = true);
    final wasInterrupted = _recState == RecordingState.interrupted;
    final gapSeconds = _service.currentDuration.inSeconds;
    bool ok;
    try {
      ok = await _service.resume();
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
    if (ok) {
      if (wasInterrupted) {
        ref
            .read(analyticsCollectorProvider)
            .track(
              "recording.interruption_resumed",
              properties: {"at_seconds": gapSeconds},
            );
      }
      return;
    }
    if (!wasInterrupted || !mounted) return;
    ref
        .read(analyticsCollectorProvider)
        .track("recording.interruption_resume_failed");
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_resume_failed_header,
        body: t.recording_resume_failed_body,
        primary: EuphireSheetAction(
          label: t.recording_resume_failed_finish,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _finishAndUpload();
          },
        ),
        secondary: EuphireSheetAction(
          label: t.recording_resume_failed_retry,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _onResumeTap();
          },
        ),
      ),
    );
  }

  // ---------- stop / pause logic per Etap 3 ----------

  Future<void> _onStopPressed() async {
    debugPrint('[recording] _onStopPressed dur=${_service.currentDuration}');
    final t = AppLocalizations.of(context);
    final dur = _service.currentDuration;
    if (dur < kMinSessionDuration) {
      // Stop button doesn't actually stop — recording continues.
      await showEuphireBottomSheet<void>(
        context: context,
        builder: (ctx) => EuphireActionSheet(
          header: t.recording_too_short_header,
          body: t.recording_too_short_body,
          primary: EuphireSheetAction(
            label: t.recording_too_short_primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          destructive: EuphireSheetAction(
            label: t.recording_too_short_destructive,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _discardAndPop();
            },
          ),
        ),
      );
      return;
    }

    // ≥ 5 min → pause and confirm.
    await _service.pause();
    await _showConfirmEndSheet();
  }

  Future<void> _showConfirmEndSheet() async {
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        topIcon: Icons.cloud_upload_outlined,
        header: t.recording_confirm_end_header,
        body: t.recording_confirm_end_body,
        primary: EuphireSheetAction(
          label: t.recording_confirm_end_primary,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _finishAndUpload();
          },
        ),
        secondary: EuphireSheetAction(
          label: t.recording_confirm_end_secondary,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _onResumeTap();
          },
        ),
        destructive: EuphireSheetAction(
          label: t.recording_confirm_end_destructive,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _discardAndPop();
          },
        ),
      ),
    );
  }

  /// Single handler for every duration tick (start + resume paths share it):
  /// updates the clock, fires the periodic "still recording" reminder, and
  /// auto-pauses at the configurable limit. The 4 h guard ignores clock jumps.
  void _onDurationTick(Duration d) {
    if (!mounted) return;
    setState(() => _displayDuration = d);

    final s = ref.read(appSettingsProvider);

    // ── Periodic "still recording" reminder ──
    final interval = s.reminderIntervalMinutes;
    if (interval > 0 && d.inMinutes > 0) {
      final fired = d.inMinutes ~/ interval;
      if (fired > _remindersFired) {
        _remindersFired = fired;
        _fireReminder(s, d);
      }
    }

    // ── Configurable auto-pause ──
    final autoPause = Duration(minutes: s.autoPauseMinutes);
    if (!_maxLimitTriggered && d >= autoPause && d < const Duration(hours: 4)) {
      _maxLimitTriggered = true;
      debugPrint('[recording] auto-pause at $d (limit ${s.autoPauseMinutes}m)');
      _onMaxDurationReached();
    } else if (d >= const Duration(hours: 4)) {
      debugPrint(
        '[recording] WARNING insane duration $d ignored — clock jump?',
      );
    }
  }

  /// Reminds the therapist the session is still recording. Default = haptic +
  /// a brief visual toast (won't pollute the audio). An audible bell is opt-in
  /// (it IS captured by the mic) and disabled by default.
  void _fireReminder(AppSettings s, Duration d) {
    if (s.hapticsEnabled) {
      HapticFeedback.heavyImpact();
    }
    if (s.reminderSound) {
      // Opt-in: plays through the speaker, so it lands in the recording.
      try {
        AudioPlayer().play(AssetSource('sounds/Dźwięk zakończenia sesji.mp3'));
      } catch (_) {
        /* best-effort */
      }
    }
    if (mounted) {
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(t.recording_reminder_toast(_formatDuration(d))),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onMaxDurationReached() async {
    debugPrint(
      '[recording] _onMaxDurationReached dur=${_service.currentDuration}',
    );
    await _service.pause();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        topIcon: Icons.cloud_upload_outlined,
        header: t.recording_max_duration_header,
        body: t.recording_max_duration_body,
        primary: EuphireSheetAction(
          label: t.recording_max_duration_primary,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _finishAndUpload();
          },
        ),
        destructive: EuphireSheetAction(
          label: t.recording_max_duration_destructive,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _discardAndPop();
          },
        ),
      ),
    );
  }

  Future<void> _discardAndPop() async {
    final confirmed = await _showDiscardConfirmationSheet();
    if (!confirmed) return;

    final dur = _service.currentDuration.inSeconds;
    await _service.cancel();
    await _deleteManifest();
    // Dismiss native widget.
    if (ref.read(appSettingsProvider).liveActivitiesEnabled ||
        Platform.isAndroid) {
      ref.read(liveActivityServiceProvider).stop();
    }
    ref
        .read(analyticsCollectorProvider)
        .track("recording.cancelled", properties: {"duration_seconds": dur});
    if (mounted) Navigator.of(context).pop();
  }

  // ---------- finish + upload ----------

  Future<void> _finishAndUpload() async {
    debugPrint(
      '[recording] _finishAndUpload entered; '
      'currentDuration=${_service.currentDuration} '
      'displayDuration=$_displayDuration recState=$_recState',
    );

    // Defensive: refuse to upload absurdly short recordings. The legitimate
    // flow takes you through "Zakończenie i analiza sesji" sheet which
    // requires ≥ 5 min via _onStopPressed, OR the 130-min auto-cap. If we
    // get here with < 30s, something has misfired (stale state, double
    // tap on a hidden control, race after permission denial). Better to
    // bail loudly than ship a 0-byte audio to the backend.
    final realDuration = _service.currentDuration;
    if (realDuration < const Duration(seconds: 5)) {
      debugPrint(
        '[recording] _finishAndUpload aborted: duration too short ($realDuration)',
      );
      if (mounted) {
        final t = AppLocalizations.of(context);
        setState(() => _uploading = false);
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: t.recording_too_short_header,
            body: t.recording_too_short_abort_body(realDuration.toString()),
            primary: EuphireSheetAction(
              label: 'OK',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    final sessionId = _sessionId ?? const Uuid().v4();
    try {
      // Captured duration BEFORE stop() resets the service. Source of
      // truth, not the UI stream copy — and post-WS2 it excludes
      // interruption gaps (the clock stops while the OS holds the
      // recorder paused), so the backend hint is honest.
      final capturedDuration = _service.currentDuration;
      final rawPath = await _service.stop();
      if (rawPath == null) throw StateError('no recording produced');
      final rawSize = await File(rawPath).length();
      ref
          .read(analyticsCollectorProvider)
          .track(
            "recording.stopped",
            properties: {"duration_seconds": capturedDuration.inSeconds},
          );
      // Transition native widget to uploading state.
      if (ref.read(appSettingsProvider).liveActivitiesEnabled ||
          Platform.isAndroid) {
        ref
            .read(liveActivityServiceProvider)
            .update(
              status: LiveActivityStatus.uploading,
              elapsedSeconds: capturedDuration.inSeconds,
            );
      }
      debugPrint('[recording] stopped, raw=$rawPath size=${rawSize}B');
      if (rawSize == 0) {
        throw StateError(
          'recording file is empty (0 bytes) — iOS encoder failed to flush',
        );
      }

      // The raw FLAC is already on durable disk at
      // <docs>/sessions/<sessionId>/raw.flac (recording_service). Enqueue
      // it durably FIRST (before any heavy work) so leaving the screen /
      // app-kill can never lose the recording; the worker owns the rest.
      final docs = await getApplicationDocumentsDirectory();
      final sessionDir = p.join(docs.path, 'sessions', sessionId);

      final runner = await ref.read(uploadQueueRunnerProvider.future);
      if (runner == null) {
        throw StateError('Upload queue not available — user not signed in?');
      }

      // Option D — skip on-device encryption when we can upload now.
      // The AES-GCM chunk encryption only exists to protect PHI sitting
      // at rest in the queue while OFFLINE. When online (the common case
      // for someone who just finished recording in the app), upload the
      // raw FLAC directly over TLS as a plainFile — no CPU-heavy encrypt
      // pass at all, so navigation never janks. When offline, fall back
      // to the durable encrypted-chunks path (phase=encrypting), whose
      // AES now runs in a background isolate (Option A) so even that
      // doesn't freeze the UI.
      final conn = await Connectivity().checkConnectivity();
      final online = conn.any((r) => r != ConnectivityResult.none);

      // An OS interruption (phone call) during recording can leave the
      // single FLAC with a corrupt STREAMINFO + non-monotonic frame DTS
      // even though it resumed and finished cleanly (the recorder's
      // state is `recording` here, so we rely on the sticky flag). Upload
      // such files as `audio/x-flac` so ingestion-svc routes them through
      // its lossless ffmpeg re-encode (rewrites a clean, finalized header
      // and a monotonic timeline) before STT — the same mechanism the
      // orphan-recovery path uses for unfinalized recordings.
      final hadInterruption = _service.hadInterruption;

      final PendingUpload pending;
      if (online) {
        pending = PendingUpload.initial(
          localId: sessionId, // recordings: reuse session UUID as localId
          therapistId: widget.therapistId,
          patientFileId: widget.patientFileId,
          patientLanguageCode: widget.reportLanguage,
          sourceKind: UploadSourceKind.plainFile,
          sourcePath: rawPath, // <sessionDir>/raw.flac — PUT directly
          contentType: hadInterruption ? 'audio/x-flac' : 'audio/flac',
          sizeBytes: rawSize,
          chunkCount: 1,
          actualDurationSeconds: capturedDuration.inSeconds,
          needsServerSideConversion: hadInterruption,
          idempotencyKey: sessionId,
          now: DateTime.now().toUtc(),
        );
      } else {
        // NOTE: the offline path encrypts the FLAC into chunks on-device,
        // so the server cannot re-encode it; an interrupted offline
        // recording isn't covered here. ingestion-svc's duration probe is
        // the safety net for the online path; full coverage for the
        // offline path needs the segmented-recording follow-up (PROGRESS).
        pending = PendingUpload.initial(
          localId: sessionId,
          therapistId: widget.therapistId,
          patientFileId: widget.patientFileId,
          patientLanguageCode: widget.reportLanguage,
          sourceKind: UploadSourceKind.encryptedChunks,
          sourcePath: sessionDir,
          contentType: 'audio/flac',
          // Plaintext size ≈ raw FLAC size; the worker refines both this
          // and chunkCount from the real chunk metadata after encrypting.
          sizeBytes: rawSize,
          chunkCount: 1,
          actualDurationSeconds: capturedDuration.inSeconds,
          needsServerSideConversion: false,
          idempotencyKey: sessionId,
          now: DateTime.now().toUtc(),
        ).copyWith(phase: UploadPhase.encrypting);
      }

      // Persist durably WITHOUT awaiting a tick. The row is in Hive
      // before this returns, so leaving the screen / app-kill can no
      // longer lose the recording.
      await runner.enqueue(pending);

      // Durability ownership just transferred to the queue row — drop
      // the recording manifest so the orphan-recovery scan never
      // double-offers this session (docs/28 WS1). Order matters: a kill
      // between enqueue and delete leaves BOTH owners, which recovery
      // resolves via its already-queued skip rule; the reverse order
      // would leave neither.
      await _deleteManifest();

      // Invalidate patient + session caches so the new session shows
      // up in the kartoteka once the server confirms.
      ref.invalidate(patientsProvider);
      ref.invalidate(sessionsProvider);

      // Kick the worker in the background so encryption + upload start
      // immediately — fire-and-forget so navigation isn't blocked.
      unawaited(runner.kick());

      if (!mounted) return;
      // Push the status screen so the user keeps the familiar
      // processing → upload → analysis visual flow. SessionStatusScreen
      // watches the queue row by localId until CreateAudioUpload returns
      // a sessionId, then hands off to the Firestore / clinical-svc
      // listeners.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionStatusScreen(localId: sessionId),
        ),
      );
    } catch (e, st) {
      debugPrint('[recording] _finishAndUpload FAILED: $e\n$st');
      if (mounted) {
        final t = AppLocalizations.of(context);
        setState(() => _uploading = false);
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: t.recording_upload_error_header,
            body: e.toString(),
            primary: EuphireSheetAction(
              label: 'OK',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    // Web build: recording APIs (`package:record` + MediaRecorder
    // policies) need a microphone gesture per-tab and aren't part of
    // the Slice 5 scope. docs/18 §8.3 calls out that the recording
    // screen is replaced on web with a "use the iPhone app" CTA — we
    // do that here as the foundational guard. Patients still get
    // their session on iOS; clinicians read the resulting transcript
    // + report on web.
    if (kIsWeb) {
      return _WebRecordingFallback(patientAlias: widget.patientAlias);
    }

    final t = AppLocalizations.of(context);
    final dateLabel = DateFormat('d MMMM y', 'pl_PL').format(DateTime.now());

    return PopScope(
      // Block automatic back-gesture/system-back when actively recording —
      // we always want the discard-confirmation sheet between the user
      // and a thrown-away session.
      canPop:
          _recState == RecordingState.idle ||
          _recState == RecordingState.stopped ||
          _recState == RecordingState.error,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardOnBack();
        if (!shouldPop) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: t.common_back,
              onPressed: () async {
                final shouldPop = await _confirmDiscardOnBack();
                if (!shouldPop) return;
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),

            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: EuphireColors.mist),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => _InstructionsBlock(),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Header: staggered fade + slide ──
                            SlideTransition(
                              position: _headerSlide,
                              child: FadeTransition(
                                opacity: _headerFade,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      dateLabel.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'RobotoMono',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: EuphireColors.frostWhite
                                            .withValues(alpha: 0.5),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.patientAlias,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: EuphireColors.frostWhite,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final t = AppLocalizations.of(context);
                                        final patients =
                                            ref
                                                .watch(patientsProvider)
                                                .whenOrNull(data: (d) => d) ??
                                            [];
                                        final patient = patients
                                            .where(
                                              (p) =>
                                                  p.id == widget.patientFileId,
                                            )
                                            .firstOrNull;
                                        final sessionNumber =
                                            (patient?.sessionCount ?? 0) + 1;
                                        return Text(
                                          '${t.clientDetails_session_title} #$sessionNumber',
                                          style: const TextStyle(
                                            fontFamily: 'Merriweather',
                                            fontSize: 18,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w600,
                                            color: EuphireColors.ember,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 24,
                            ), // Breathing room under header when spacers shrink
                            const Spacer(),
                            if (_recState == RecordingState.interrupted) ...[
                              _InterruptionBanner(
                                resuming: _resuming,
                                onResume: _onResumeTap,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // ── Waveform: staggered scale + fade ──
                            ScaleTransition(
                              scale: _waveformScale,
                              child: FadeTransition(
                                opacity: _waveformFade,
                                child: RepaintBoundary(
                                  child: EuphireRecordingIndicator(
                                    isRecording:
                                        _recState == RecordingState.recording,
                                    isInitializing: _initializing,
                                    formattedDuration: _formatDuration(
                                      _displayDuration,
                                    ),
                                    chunkCount: _chunkCount,
                                    amplitudeStream: _service.amplitudeStream,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(flex: 2),
                            // ── Control panel: smooth fade-in when recording starts ──
                            AnimatedOpacity(
                              opacity: _initializing ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Auto-pause countdown — centered, just above
                                  // the "Zakończenie nagrywania sesji" button.
                                  if (_recState == RecordingState.recording)
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final mins = ref
                                            .watch(appSettingsProvider)
                                            .autoPauseMinutes;
                                        final remaining =
                                            Duration(minutes: mins) -
                                            _displayDuration;
                                        if (remaining <= Duration.zero) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).recording_autopause_remaining(
                                              _formatDuration(remaining),
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'RobotoMono',
                                              fontSize: 13,
                                              color: EuphireColors.frostWhite
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  _ControlPanel(
                                    state: _recState,
                                    onStart: _start,
                                    onStop: _onStopPressed,
                                  ),
                                  const SizedBox(height: 16),
                                  if (_uploading) ...[
                                    const SizedBox(height: 16),
                                    Column(
                                      children: [
                                        const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          t.recording_saving,
                                          style: TextStyle(
                                            fontFamily: 'Merriweather',
                                            fontSize: 13,
                                            color: EuphireColors.frostWhite
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// Warning card shown while the OS holds the recorder paused
/// (phone call / alarm / audio-focus loss — docs/28 WS2). The duration
/// counter freezes alongside it; everything captured so far is intact.
class _InterruptionBanner extends StatelessWidget {
  final bool resuming;
  final Future<void> Function() onResume;

  const _InterruptionBanner({required this.resuming, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EuphireColors.ember.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EuphireColors.ember, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_paused_rounded,
                color: EuphireColors.ember,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.recording_interrupted_banner_title,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.recording_interrupted_banner_body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: resuming ? null : onResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: EuphireColors.ember,
                foregroundColor: EuphireColors.frostWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: resuming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EuphireColors.frostWhite,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t.recording_interrupted_resume,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final RecordingState state;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  const _ControlPanel({
    required this.state,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (state == RecordingState.idle || state == RecordingState.error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(
            icon: Icons.mic_rounded,
            color: EuphireColors.ember,
            onPressed: onStart,
            isPrimary: true,
          ),
        ],
      );
    }
    // Pause removed per UX: recording runs until auto-pause or explicit stop.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          icon: Icons.stop_rounded,
          color: EuphireColors.magma,
          onPressed: onStop,
          isPrimary: true,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Future<void> Function() onPressed;
  final bool isPrimary;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(48),
      child: Container(
        width: isPrimary ? 84 : 64,
        height: isPrimary ? 84 : 64,
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: isPrimary ? null : Border.all(color: color, width: 2),
        ),
        child: Icon(
          icon,
          color: isPrimary ? EuphireColors.frostWhite : color,
          size: isPrimary ? 40 : 32,
        ),
      ),
    );
  }
}

class _InstructionsBlock extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final items = [
      t.recording_instruction_1,
      t.recording_instruction_2,
      t.recording_instruction_3,
      t.recording_instruction_4,
      t.recording_instruction_5,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 28),

                // Info icon — subtle white, not attention-grabbing
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.frostWhite.withValues(alpha: 0.08),
                    border: Border.all(
                      color: EuphireColors.frostWhite.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: EuphireColors.frostWhite,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),

                // Title — Merriweather italic, like logout sheet
                Text(
                  t.recording_instructions_title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    color: EuphireColors.frostWhite,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle — explains why these tips matter
                Text(
                  t.recording_instructions_subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: EuphireColors.mist,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Tips list
                for (int i = 0; i < items.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: 12),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: EuphireColors.ember,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            items[i],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: EuphireColors.frostWhite.withValues(
                                alpha: 0.85,
                              ),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Live Activities info card ───────────────────────
                // Only show when the feature is disabled — once enabled
                // from here or from Settings, this card disappears.
                if (!settings.liveActivitiesEnabled) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: EuphireColors.ember.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: EuphireColors.ember.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stay_current_portrait_outlined,
                              color: EuphireColors.ember,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.live_activity_info_title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: EuphireColors.frostWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.live_activity_info_body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: EuphireColors.mist,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              final la = ref.read(liveActivityServiceProvider);
                              final systemEnabled = await la.isSystemEnabled();
                              if (!systemEnabled && context.mounted) {
                                final openSettings =
                                    await showEuphireBottomSheet<bool>(
                                      context: context,
                                      builder: (ctx) => EuphireActionSheet(
                                        header:
                                            t.live_activity_permission_title,
                                        body: t.live_activity_permission_body,
                                        primary: EuphireSheetAction(
                                          label: t
                                              .live_activity_permission_open_settings,
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                        ),
                                        secondary: EuphireSheetAction(
                                          label:
                                              t.live_activity_permission_cancel,
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                        ),
                                      ),
                                    );
                                if (openSettings == true) {
                                  await la.openSystemSettings();
                                }
                                return;
                              }
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .toggleLiveActivities(true);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EuphireColors.ember,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                t.live_activity_info_enable,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Dismiss button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.frostWhite.withValues(
                        alpha: 0.1,
                      ),
                      foregroundColor: EuphireColors.frostWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      t.common_understand,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Glue: EuphireButton import to suppress unused warning if a future
// CTA gets re-introduced.
// ignore: unused_element
const _kKeepImportEuphireButton = EuphireButton;

/// Web-only fallback shown in place of the iOS recording UI.
///
/// docs/18 §8.3 explicitly excludes the recording flow from Flutter
/// Web: browser-side `MediaRecorder` would need per-tab mic gestures,
/// FLAC encoding pipeline + chunk persistence isn't IndexedDB-friendly,
/// and the clinical use-case (a therapist mid-session) is iOS-native
/// anyway. The web build still navigates here when a user clicks
/// "Start session"; we just render the placeholder instead of trying
/// to fire the recording APIs that don't exist in the browser.
class _WebRecordingFallback extends StatelessWidget {
  final String patientAlias;
  const _WebRecordingFallback({required this.patientAlias});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: EuphireColors.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: EuphireColors.frostWhite),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.recording_ios_only_title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${t.recording_ios_only_body_part1(patientAlias)}'
                    '${t.recording_ios_only_body_part2}'
                    '${t.recording_ios_only_body_part3}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.recording_btn_back),
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
