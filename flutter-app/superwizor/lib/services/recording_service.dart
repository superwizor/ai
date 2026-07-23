// RecordingService — wraps the `record` package with our domain semantics.
//
// Per D10 Plan C: native FLAC @ 16 kHz mono. iOS does not ship a
// public Opus encoder; the `record` package's iOS Opus path produces
// 0-byte files. FLAC works natively and is a Chirp 3-supported codec.
// `recorder.stop()` returns the path to a final .flac file ready for
// AES-GCM encryption by SecureAudioStorageService.
//
// State machine (docs/28 WS2 — interruption-aware):
//
//   idle ─start()→ recording ─pause()→ paused ─resume()→ recording
//                       │  \─stop()→ stopped (returns path, → idle)
//                       │
//                       └─OS interruption (phone call, alarm, Siri)→
//                            interrupted ─resume() verified→ recording
//                                       \─stop()→ stopped
//
// `interrupted` ≡ "paused by the OS, not by the user". The plugin's
// native side auto-pauses on AVAudioSession interruption / Android
// audio-focus loss and reports it on onStateChanged(); we subscribe and
// reconcile so the UI and the duration clock stay honest. Intent
// timestamps distinguish our own pause/resume/stop calls from
// OS-initiated ones.
//
// Resume after an interruption is VERIFIED (docs/28 WS3): the plugin's
// native resume() is `audioRecorder?.record()` with the Bool result
// discarded and no AVAudioSession reactivation, and its Dart-visible
// state flips to `record` unconditionally — so neither isRecording()
// nor the state stream proves capture restarted. We (1) reactivate the
// session via AudioSessionHelper, then (2) probe that the output file
// is actually growing before reporting success.
//
// Wakelock keeps the screen awake during recording so the OS doesn't
// dim the device and confuse the therapist about whether the app is
// still capturing. iOS BG audio mode (Info.plist UIBackgroundModes:
// audio) keeps the recorder alive when the app goes to background.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'reminder_service.dart';
import '../utils/debug_flags.dart';

import 'audio_session_helper.dart';
import 'recording_foreground_service.dart';


enum RecordingState { idle, recording, paused, interrupted, stopped, error }

class RecordingService {
  /// All injection points exist for unit tests only — production callers
  /// use the default constructor. [documentsDirProvider] and
  /// [wakelockSetter] wrap platform channels that throw
  /// MissingPluginException in a bare test binding.
  RecordingService({
    AudioRecorder? recorder,
    AudioRecorder Function()? recorderFactory,
    Future<Directory> Function()? documentsDirProvider,
    Future<void> Function(bool enabled)? wakelockSetter,
    this.captureProbeWindow = const Duration(milliseconds: 1200),
    this.autoResumePeriod = const Duration(seconds: 3),
  })  : _recorder = recorder ?? AudioRecorder(),
        _recorderFactory = recorderFactory ?? AudioRecorder.new,
        _documentsDir =
            documentsDirProvider ?? getApplicationDocumentsDirectory,
        _setWakelock = wakelockSetter ?? _defaultWakelock {
    _nativeSub = _recorder.onStateChanged().listen(
          _onNativeState,
          onError: (Object e) =>
              debugPrint('[recording] native state stream error: $e'),
        );
  }

  static Future<void> _defaultWakelock(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();

  AudioRecorder _recorder;
  final AudioRecorder Function() _recorderFactory;

  /// Consecutive failed capture probes within the CURRENT interruption
  /// episode. At [_recycleThreshold] the native recorder gets fully
  /// disposed and recreated — live repro 2026-07-23: after one
  /// successful segment rotation, a SECOND phone call left record_ios
  /// in a state where every start() "succeeded" but captured nothing
  /// (probe fail #20+); only a fresh AVAudioRecorder instance recovers.
  int _consecutiveProbeFails = 0;
  static const _recycleThreshold = 3;

  Future<void> _recycleRecorder() async {
    debugPrint('[recording] recycling native recorder after '
        '$_consecutiveProbeFails failed probes');
    resumeDiag.value = 'R: recorder recycle';
    await _nativeSub?.cancel();
    try {
      await _recorder.dispose();
    } catch (e) {
      debugPrint('[recording] recorder dispose: $e');
    }
    _recorder = _recorderFactory();
    _nativeSub = _recorder.onStateChanged().listen(
          _onNativeState,
          onError: (Object e) =>
              debugPrint('[recording] native state stream error: $e'),
        );
  }
  final Future<Directory> Function() _documentsDir;
  final Future<void> Function(bool enabled) _setWakelock;

  /// How long the post-interruption resume probe watches the output file
  /// for growth before declaring the resume failed. 16 kHz mono FLAC
  /// writes ~10–18 KiB/s, flushed well within this window.
  final Duration captureProbeWindow;

  StreamSubscription<RecordState>? _nativeSub;

  final _stateController = StreamController<RecordingState>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  String? _activeFilePath;

  /// Finalized recording segments, oldest first (segment-per-resume,
  /// 2026-07-23). Index 0 is always the original raw.flac. A resume
  /// after an OS interruption STOPS the recorder (clean finalization —
  /// valid STREAMINFO, no frame-number reset) and starts a fresh file
  /// instead of natively resuming into the same one; stop() concats
  /// everything back into raw.flac. Root cause: session a1b09d6c
  /// (2026-07-22) — the in-place resume left a never-finalized header
  /// and silently LOST 10 of 16 minutes of audio.
  final List<String> _segmentPaths = [];
  String? get activeFilePath => _activeFilePath;

  /// Session currently being captured. The orphan-recovery scanner
  /// (docs/28 WS1) skips this id so an in-progress recording is never
  /// offered as a "found" orphan.
  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  String? _patientFileId;
  String? get patientFileId => _patientFileId;

  String? _therapistId;
  String? get therapistId => _therapistId;

  String? _patientAlias;
  String? get patientAlias => _patientAlias;

  String? _reportLanguage;
  String? get reportLanguage => _reportLanguage;

  Timer? _ticker;
  DateTime? _segmentStart;
  Duration _accumulated = Duration.zero;

  int _currentReminderInterval = 0;
  bool _soundEnabled = false;
  bool _hapticsEnabled = false;

  /// Latches true the moment an OS interruption (phone call, alarm, Siri,
  /// audio-focus loss) pauses the recorder, and STAYS true even after a
  /// successful resume. The `record` plugin's native pause/resume on a
  /// single FLAC file can leave a corrupt STREAMINFO + non-monotonic
  /// frame timestamps (the resumed recording plays back fine but the
  /// header under-reports length). Callers read this at upload time to
  /// route the file through the server's lossless re-encode (upload as
  /// `audio/x-flac`, same path as orphan recovery) which rewrites a clean
  /// header. Sticky-by-design: the recording usually finishes in the
  /// `recording` state, so the live state no longer shows the interruption.
  /// Reset on every start().
  bool _hadInterruption = false;
  bool get hadInterruption => _hadInterruption;

  /// Latches true after ANY native pause/resume cycle — user pause
  /// included, not just OS interruptions. Every resume appends a fresh
  /// FLAC sub-stream to the single output file and the final header
  /// describes only the last segment (session e22d25f3: header said
  /// 13 min, file held 73 min — uploaded as clean `audio/flac` because
  /// the user-initiated Stop→"Wróć do nagrywania" cycle never set
  /// `_hadInterruption`). Reset on every start().
  bool _hadResumeCycle = false;

  /// True when the finished file must go through the server-side
  /// lossless re-encode (upload as `audio/x-flac`) because its header
  /// can't be trusted: any pause/resume cycle OR an OS interruption.
  /// Upload decisions must read THIS flag; `hadInterruption` stays for
  /// interruption-specific UX only.
  bool get needsReencode => _hadResumeCycle || _hadInterruption;

  // Intent timestamps: armed right before we drive the recorder ourselves,
  // consumed by the matching native event so it isn't misread as an
  // OS-initiated transition. Stale intents (event never delivered, e.g.
  // pause() on an already-paused recorder is a native no-op) expire.
  final Map<RecordState, DateTime> _intents = {};
  static const Duration _intentTtl = Duration(seconds: 2);

  // ── Auto-resume after OS interruption (feedback 2026-07-22) ──
  // iOS-only in practice: a mere incoming RING revokes the audio
  // session and pauses the recorder even when the call is never
  // answered and the ringer is muted (Android never pauses since we
  // start with AudioInterruptionMode.none — see start()). Instead of
  // waiting for the therapist, we retry the VERIFIED resume() on a
  // timer while the state is `interrupted`: during a call the attempt
  // fails fast (session reactivation rejected; probe otherwise) and we
  // stay interrupted; the first attempt after the OS releases the mic
  // succeeds and recording continues on its own. Manual resume/stop
  // keep working throughout — the loop is cancelled on any state exit.
  // The only full protection on iOS is Focus/DND (no interruption
  // fires at all) — surfaced in the recording-screen instructions.
  final Duration autoResumePeriod; // injectable for tests; 3 s in prod

  /// TEMP diag (auto-resume, 2026-07-23): last resume-attempt outcome,
  /// rendered by the interruption note so a screenshot pinpoints the
  /// failing gate on-device. Remove before TestFlight.
  final ValueNotifier<String> resumeDiag = ValueNotifier<String>('');
  static const _maxAutoResumeAttempts = 200; // ~10 min, then manual only
  Timer? _autoResumeTimer;
  int _autoResumeAttempts = 0;
  bool _resumeInFlight = false;

  void _startAutoResumeLoop() {
    if (_autoResumeTimer != null) return; // keep attempt count across retries
    _autoResumeAttempts = 0;
    _autoResumeTimer =
        Timer.periodic(autoResumePeriod, (_) => _autoResumeTick());
  }

  void _cancelAutoResumeLoop() {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = null;
  }

  Future<void> _autoResumeTick() async {
    if (_state != RecordingState.interrupted) {
      _cancelAutoResumeLoop();
      return;
    }
    if (_resumeInFlight) return;
    _autoResumeAttempts++;
    if (_autoResumeAttempts > _maxAutoResumeAttempts) {
      debugPrint('[recording] auto-resume gave up after '
          '$_maxAutoResumeAttempts attempts — manual resume only');
      _cancelAutoResumeLoop();
      return;
    }
    final ok = await resume();
    if (ok) {
      debugPrint('[recording] auto-resume succeeded '
          '(attempt $_autoResumeAttempts)');
    }
  }

  /// Path for the next rotation segment: `<sessionDir>/raw_seg<N>.flac`
  /// next to the original raw.flac. Null when no recording is active.
  String? _nextSegmentPath() {
    if (_segmentPaths.isEmpty) return null;
    final base = _segmentPaths.first;
    final dir = p.dirname(base);
    return p.join(dir, 'raw_seg${_segmentPaths.length}.flac');
  }

  /// Byte-concatenates all finalized segments (plus [lastPath] if it's
  /// not already tracked) into the FIRST segment (the original
  /// raw.flac) and deletes the appended files. The result is a
  /// multi-substream FLAC — exactly the shape the server's
  /// audio/x-flac re-encode already repairs — but with every
  /// sub-stream carrying a FINALIZED header.
  Future<String> _concatSegments(String? lastPath) async {
    final ordered = List<String>.from(_segmentPaths);
    if (lastPath != null && !ordered.contains(lastPath)) {
      ordered.add(lastPath);
    }
    final base = ordered.first;
    if (ordered.length > 1) {
      final sink = await File(base).open(mode: FileMode.append);
      try {
        for (final path in ordered.skip(1)) {
          final f = File(path);
          if (!await f.exists()) continue;
          await sink.writeFrom(await f.readAsBytes());
          try {
            await f.delete();
          } catch (_) {/* best-effort */}
        }
      } finally {
        await sink.close();
      }
    }
    _segmentPaths.clear();
    return base;
  }

  /// Shared recorder configuration — used by start() and by the
  /// segment rotation after an OS interruption.
  RecordConfig _recordConfig() => RecordConfig(
        encoder: AudioEncoder.flac, // lossless; ignores bitRate
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        // Incoming-call policy (feedback 2026-07-22, silenced-ring
        // session loss):
        //  - Android `none`: the plugin skips the audio-focus request
        //    entirely, so a ringing (or even answered) call never pauses
        //    capture — the mic keeps working through a ring, and during
        //    an answered call the system feeds silence. Zero session
        //    loss; the therapist's own room audio is what we record.
        //  - iOS `pause`: the system revokes the mic on interruption
        //    regardless of this flag; `none` would just hide the pause
        //    and rot the file silently. Keep the explicit pause and let
        //    the auto-resume loop recover the moment the OS returns the
        //    session.
        audioInterruption: !kIsWeb && Platform.isAndroid
            ? AudioInterruptionMode.none
            : AudioInterruptionMode.pause,
      );

  void _arm(RecordState s) => _intents[s] = DateTime.now();
  bool _consumeIntent(RecordState s) {
    final t = _intents.remove(s);
    return t != null && DateTime.now().difference(t) < _intentTtl;
  }

  Duration get currentDuration {
    final base = _accumulated;
    if (_state == RecordingState.recording && _segmentStart != null) {
      return base + DateTime.now().difference(_segmentStart!);
    }
    return base;
  }

  /// Called by `services_provider` when the AppSettings change mid-session.
  void updateSettings(int reminderIntervalMinutes, bool soundEnabled, bool hapticsEnabled) {
    _currentReminderInterval = reminderIntervalMinutes;
    _soundEnabled = soundEnabled;
    _hapticsEnabled = hapticsEnabled;
    if (_state == RecordingState.recording) {
      unawaited(ReminderService.update(
        intervalMinutes: reminderIntervalMinutes,
        intervalSeconds: DebugFlags.debugReminderIntervalSeconds,
        soundEnabled: soundEnabled,
        hapticsEnabled: hapticsEnabled,
      ));
    }
  }

  /// Begins a fresh recording for [sessionId]. The FLAC file lands at
  /// `<docs>/sessions/<sessionId>/raw.flac`. Throws if a recording is
  /// already in progress.
  ///
  /// [fgsTitle]/[fgsBody] are the localized strings for the Android
  /// recording foreground-service notification (docs/28 WS5); the screen
  /// passes them from the l10n pipeline. Ignored on iOS/web.
  Future<void> start(
    String sessionId, {
    String patientFileId = '',
    String therapistId = '',
    String patientAlias = '',
    String reportLanguage = '',
    String? fgsTitle,
    String? fgsBody,
  }) async {
    if (_state != RecordingState.idle &&
        _state != RecordingState.stopped &&
        _state != RecordingState.error) {
      throw StateError('already recording (state=$_state)');
    }

    // Two-step permission check — `record` package's native check fires
    // the iOS prompt reliably (calls AVAudioApplication.requestRecordPermission
    // directly). `permission_handler`'s wrapper sometimes returns stale
    // `permanentlyDenied` on iOS 26+ before iOS even sees the request,
    // which breaks first-time grants. We use the native path first;
    // permission_handler is only consulted if the native call says no
    // (so we still know whether to show "Open Settings").
    final hasMic = await _recorder.hasPermission();
    if (!hasMic) {
      final fallback = await Permission.microphone.request();
      if (!fallback.isGranted) {
        _setState(RecordingState.error);
        throw StateError('microphone permission not granted');
      }
    }

    final docs = await _documentsDir();
    final dir = Directory(p.join(docs.path, 'sessions', sessionId));
    await dir.create(recursive: true);
    final outPath = p.join(dir.path, 'raw.flac');

    // Plan C from D10: FLAC, NOT Opus. iOS does not ship a public Opus
    // encoder, and the `record` package's iOS Opus path produces 0-byte
    // files with `AudioFileObject.cpp:1170 write past end` warnings —
    // verified on iPhone 15 / iOS 26.2.1. FLAC works natively and is
    // also a Chirp 3-supported codec.
    //
    // 16 kHz mono is the STT sweet spot:
    //   - smaller file (~16 MB / 60 min vs 270 MB at 48 kHz)
    //   - matches Chirp 3's native sample rate; no upstream resampling
    //   - voice content sits below 8 kHz, no quality loss
    _arm(RecordState.record);
    await _recorder.start(_recordConfig(), path: outPath);
    _segmentPaths
      ..clear()
      ..add(outPath);

    await _setWakelock(true);
    // Keep the process alive if the app is backgrounded mid-recording
    // (phone call). Best-effort, Android-only; never blocks recording.
    await RecordingForegroundService.start(title: fgsTitle, body: fgsBody);

    _activeFilePath = outPath;
    _activeSessionId = sessionId;
    _patientFileId = patientFileId;
    _therapistId = therapistId;
    _patientAlias = patientAlias;
    _reportLanguage = reportLanguage;
    _accumulated = Duration.zero;
    _hadInterruption = false;
    _hadResumeCycle = false;
    _segmentStart = DateTime.now();
    _setState(RecordingState.recording);
    
    // _currentReminderInterval is already set by updateSettings()
    // via services_provider's fireImmediately listener. Don't overwrite
    // it here — the old parameter default was 0, which caused the
    // native ReminderManager to silently skip all reminders.
    
    debugPrint('[recording] 📤 ReminderService.start() — intervalMin=$_currentReminderInterval, intervalSec=${DebugFlags.debugReminderIntervalSeconds}, sound=$_soundEnabled, haptics=$_hapticsEnabled');

    unawaited(ReminderService.start(
      intervalMinutes: _currentReminderInterval,
      intervalSeconds: DebugFlags.debugReminderIntervalSeconds,
      soundEnabled: _soundEnabled,
      hapticsEnabled: _hapticsEnabled,
      elapsedMillis: 0,
    ));

    _startTicker();
  }

  Future<void> pause() async {
    if (_state != RecordingState.recording) return;
    _arm(RecordState.pause);
    await _recorder.pause();
    _foldSegment();
    _setState(RecordingState.paused);
    unawaited(ReminderService.pause(elapsedMillis: _accumulated.inMilliseconds));
  }

  /// Resumes a paused or interrupted recording. Returns true iff capture
  /// verifiably restarted.
  ///
  /// Normal user pause→resume keeps the legacy fast path (the audio
  /// session never deactivated, so the plugin resume is reliable). After
  /// an OS interruption we (1) reactivate the AVAudioSession — a phone
  /// call deactivates it and the plugin's resume never does — and
  /// (2) verify bytes are actually reaching the output file before
  /// reporting success. On failure the state stays `interrupted` so the
  /// caller can surface a "finish and send" path; the audio captured so
  /// far is intact either way.
  Future<bool> resume() async {
    if (_state != RecordingState.paused &&
        _state != RecordingState.interrupted) {
      return false;
    }
    // Re-entrancy gate: the auto-resume timer and a manual tap can race;
    // two overlapping native resume() calls would double-arm intents.
    if (_resumeInFlight) return false;
    _resumeInFlight = true;
    try {
      return await _resumeInner();
    } finally {
      _resumeInFlight = false;
    }
  }

  Future<bool> _resumeInner() async {
    final fromInterruption = _state == RecordingState.interrupted;

    if (!kIsWeb && Platform.isIOS) {
      final reactivated = await AudioSessionHelper.reactivate();
      if (!reactivated && fromInterruption) {
        // The session is still owned by another audio user (call not
        // fully torn down). Fail fast; the user can retry.
        resumeDiag.value = 'A: reactivate=false (#$_autoResumeAttempts)';
        debugPrint('[recording] resume blocked: session reactivation failed');
        return false;
      }
    }

    if (fromInterruption) {
      // Segment rotation (2026-07-23): resuming INTO the interrupted
      // file is what corrupted session a1b09d6c (never-finalized
      // STREAMINFO, frame-number resets, 10 of 16 minutes lost).
      // Instead: cleanly STOP the recorder — the audio session is
      // active again here, so finalization writes a valid header for
      // everything captured so far — and START a fresh segment file.
      // stop() concatenates the segments back into raw.flac.
      try {
        _arm(RecordState.stop);
        await _recorder.stop();
      } catch (e) {
        // Retry-tolerant: a second rotation attempt after a failed one
        // lands here with the recorder already stopped.
        resumeDiag.value = 'B: stop err (#$_autoResumeAttempts)';
        debugPrint('[recording] segment finalize stop: $e');
      }
      final next = _nextSegmentPath();
      if (next == null) return false;
      _arm(RecordState.record);
      try {
        await _recorder.start(_recordConfig(), path: next);
      } catch (e) {
        resumeDiag.value =
            'C: start err (#$_autoResumeAttempts): ${e.toString().substring(0, e.toString().length > 60 ? 60 : e.toString().length)}';
        debugPrint('[recording] segment restart failed: $e');
        return false;
      }
      _activeFilePath = next;
      if (!_segmentPaths.contains(next)) _segmentPaths.add(next);
      // Concatenated segments = multi-substream FLAC — same re-encode
      // contract as before.
      _hadResumeCycle = true;

      final capturing = await _verifyCapture();
      if (!capturing) {
        resumeDiag.value = 'D: probe fail (#$_autoResumeAttempts)';
        debugPrint('[recording] resume NOT capturing — staying interrupted');
        // Roll the dead segment back so retry loops don't accumulate
        // header-only junk files between attempts.
        try {
          _arm(RecordState.stop);
          await _recorder.stop();
        } catch (_) {/* recorder may already be dead */}
        _segmentPaths.remove(next);
        try {
          final f = File(next);
          if (await f.exists()) await f.delete();
        } catch (_) {/* best-effort */}
        if (_segmentPaths.isNotEmpty) _activeFilePath = _segmentPaths.last;
        _consecutiveProbeFails++;
        if (_consecutiveProbeFails >= _recycleThreshold) {
          await _recycleRecorder();
          _consecutiveProbeFails = 0;
        }
        _setState(RecordingState.interrupted);
        return false;
      }
      _consecutiveProbeFails = 0;
    } else {
      // User pause → resume: the session never deactivated, the plugin
      // resume is reliable and keeps the single-file fast path.
      _arm(RecordState.record);
      try {
        await _recorder.resume();
      } catch (e) {
        debugPrint('[recording] resume failed: $e');
        return false;
      }
      // The native recorder just appended a new FLAC sub-stream to the
      // same file — its header can no longer be trusted at upload time.
      _hadResumeCycle = true;
    }

    resumeDiag.value = 'OK (#$_autoResumeAttempts)';
    _segmentStart = DateTime.now();
    _setState(RecordingState.recording);
    unawaited(ReminderService.resume(
      intervalMinutes: _currentReminderInterval,
      intervalSeconds: DebugFlags.debugReminderIntervalSeconds,
      soundEnabled: _soundEnabled,
      hapticsEnabled: _hapticsEnabled,
      elapsedMillis: _accumulated.inMilliseconds,
    ));
    return true;
  }

  /// Stops the recorder. Returns the path to the finished FLAC file
  /// (or null if recording never actually started). Caller hands the
  /// file off to SecureAudioStorageService.encryptRecording().
  ///
  /// Resume-before-stop guard: on iOS, calling stop() while in paused
  /// state has been observed to produce a 0-byte file on the OGG path
  /// (pause closes the file handle without flushing the trailing page);
  /// AVAudioRecorder/FLAC finalizes cleanly, but the brief resume is
  /// kept as cheap insurance. Post-interruption the audio session must
  /// be reactivated first or the resume silently no-ops.
  Future<String?> stop() async {
    if (_state == RecordingState.idle || _state == RecordingState.stopped) {
      return null;
    }
    if (_state == RecordingState.paused ||
        _state == RecordingState.interrupted) {
      try {
        if (!kIsWeb && Platform.isIOS) {
          await AudioSessionHelper.reactivate();
        }
        _arm(RecordState.record);
        await _recorder.resume();
        // Resume-before-stop appends a sub-stream too — same header
        // corruption risk as a user resume.
        _hadResumeCycle = true;
        _segmentStart = DateTime.now();
        // Tiny dwell so the encoder writes its trailing frames cleanly.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // ignore — best-effort; AVAudioRecorder.stop() still finalizes
        // the pre-pause content.
      }
    }
    _arm(RecordState.stop);
    final returnedPath = await _recorder.stop();
    _foldSegment();
    unawaited(ReminderService.stop());
    _ticker?.cancel();
    _ticker = null;
    await _setWakelock(false);
    await RecordingForegroundService.stop();
    _setState(RecordingState.stopped);
    // Segment-per-resume: stitch rotation segments back into raw.flac
    // so every downstream consumer (encryption, upload, recovery) keeps
    // seeing a single file.
    final out = _segmentPaths.length > 1
        ? await _concatSegments(returnedPath ?? _activeFilePath)
        : (returnedPath ?? _activeFilePath);
    _segmentPaths.clear();
    _activeFilePath = null;
    _activeSessionId = null;
    _patientFileId = null;
    _therapistId = null;
    _patientAlias = null;
    _reportLanguage = null;
    return out;
  }

  /// Cancels and deletes the in-progress recording (used by
  /// "Zakończ bez zapisu" / "Usuń to nagranie bezpowrotnie").
  Future<void> cancel() async {
    _arm(RecordState.stop);
    final path = await _recorder.stop();
    unawaited(ReminderService.stop());
    _ticker?.cancel();
    _ticker = null;
    _segmentStart = null;
    _accumulated = Duration.zero;
    await _setWakelock(false);
    await RecordingForegroundService.stop();
    _setState(RecordingState.idle);

    final target = path ?? _activeFilePath;
    for (final doomed in {
      ?target,
      ..._segmentPaths,
    }) {
      try {
        final f = File(doomed);
        if (await f.exists()) await f.delete();
      } catch (_) {/* best-effort */}
    }
    _segmentPaths.clear();
    _activeFilePath = null;
    _activeSessionId = null;
    _patientFileId = null;
    _therapistId = null;
    _patientAlias = null;
    _reportLanguage = null;
  }

  /// Re-checks the native recorder state and fixes a desynced Dart state.
  /// Called by the screen's lifecycle observer on app-resume: the pause
  /// event for an interruption that fired while the Flutter isolate was
  /// suspended (therapist answering a call) may never be delivered, so we
  /// ask the plugin directly. Note the plugin's isRecording() is
  /// `state != stop` — paused counts as "recording" — so isPaused() is
  /// the meaningful probe here.
  Future<void> reconcileWithNative() async {
    if (_state != RecordingState.recording) return;
    try {
      final paused = await _recorder.isPaused();
      if (paused) {
        debugPrint('[recording] reconcile: native paused while Dart thought '
            'recording — marking interrupted');
        _foldSegment();
        _hadInterruption = true;
        _setState(RecordingState.interrupted);
        return;
      }
      // If the native recorder is neither recording nor paused, it has
      // stopped entirely (OS kill, plugin crash). Dart still thinks we're
      // recording → zombie timer. Mark as error so the UI reacts.
      final recording = await _recorder.isRecording();
      if (!recording) {
        debugPrint('[recording] reconcile: native stopped while Dart thought '
            'recording — marking error (zombie timer)');
        _foldSegment();
        _ticker?.cancel();
        _ticker = null;
        unawaited(RecordingForegroundService.stop());
        _setState(RecordingState.error);
      }
    } catch (e) {
      debugPrint('[recording] reconcile failed: $e');
    }
  }

  /// Manually forces a state update for debugging/simulation.
  void debugForceState(RecordingState s) {
    if (kDebugMode) {
      if (s == RecordingState.interrupted) {
        _foldSegment();
        _hadInterruption = true;
      } else if (s == RecordingState.recording) {
        _segmentStart = DateTime.now();
      }
      _setState(s);
    }
  }

  Future<void> dispose() async {
    _cancelAutoResumeLoop();
    await _nativeSub?.cancel();
    _ticker?.cancel();
    await _recorder.dispose();
    if (!_stateController.isClosed) await _stateController.close();
    if (!_durationController.isClosed) await _durationController.close();
    if (!_amplitudeController.isClosed) await _amplitudeController.close();
  }

  // ---------- internals ----------

  /// Folds the running segment into the accumulated duration. Idempotent.
  void _foldSegment() {
    if (_segmentStart != null) {
      _accumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
  }

  /// Native state events drive interruption detection (docs/28 WS2).
  /// Self-caused transitions arrive with an armed intent and are
  /// swallowed; everything else is the OS talking.
  void _onNativeState(RecordState s) {
    switch (s) {
      case RecordState.pause:
        if (_consumeIntent(RecordState.pause)) return;
        if (_state == RecordingState.recording) {
          debugPrint('[recording] OS interruption — native pause '
              'without app intent (call / alarm / focus loss)');
          _foldSegment();
          _hadInterruption = true;
          _setState(RecordingState.interrupted);
        }
      case RecordState.record:
        if (_consumeIntent(RecordState.record)) return;
        if (_state == RecordingState.paused ||
            _state == RecordingState.interrupted) {
          // External resume (future plugin auto-resume behavior).
          debugPrint('[recording] external resume reported by native side');
          _segmentStart ??= DateTime.now();
          _setState(RecordingState.recording);
        }
      case RecordState.stop:
        if (_consumeIntent(RecordState.stop)) return;
        if (_state == RecordingState.recording ||
            _state == RecordingState.paused ||
            _state == RecordingState.interrupted) {
          // Unexpected native stop (plugin interruption failure path,
          // session teardown). Keep _activeFilePath: the bytes on disk
          // are finalized by the native stop and remain recoverable —
          // immediately via the screen's error path or on next launch
          // via the orphan-recovery scan.
          debugPrint('[recording] UNEXPECTED native stop — state=$_state');
          _foldSegment();
          _ticker?.cancel();
          _ticker = null;
          // Recording is over (failed) — tear down the foreground service
          // so it doesn't linger as a phantom "recording" notification.
          unawaited(RecordingForegroundService.stop());
          _setState(RecordingState.error);
        }
    }
  }

  /// True iff the output file grew during [captureProbeWindow] — i.e.
  /// the encoder is demonstrably writing audio. This is the only signal
  /// that survives the plugin's optimistic state tracking (its resume()
  /// flips to `record` even when AVAudioRecorder.record() returned false).
  Future<bool> _verifyCapture() async {
    final path = _activeFilePath;
    if (path == null) return false;
    try {
      final f = File(path);
      final before = await f.length();
      await Future<void>.delayed(captureProbeWindow);
      final after = await f.length();
      return after > before;
    } catch (e) {
      debugPrint('[recording] capture probe failed: $e');
      return false;
    }
  }

  void _setState(RecordingState s) {
    _state = s;
    // The auto-resume loop lives exactly as long as the interrupted
    // state — every entry starts it, every exit cancels it.
    if (s == RecordingState.interrupted) {
      _startAutoResumeLoop();
    } else {
      _cancelAutoResumeLoop();
    }
    if (!_stateController.isClosed) _stateController.add(s);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (_state != RecordingState.recording) return;
      if (!_durationController.isClosed) {
        _durationController.add(currentDuration);
      }
      try {
        final amp = await _recorder.getAmplitude();
        if (!_amplitudeController.isClosed) {
          // amp.current is dBFS (negative, silence = -∞ / -160).
          //
          // Noise gate + linear scaling.
          //   Gate at -42 dB: sweet-spot — fridge/fan noise (~-35 dBFS
          //   after macOS AGC) produces tiny bars (0.18), while normal
          //   conversational speech (-15 dB) fills bars nicely (0.68).
          //   No power curve — linear gives maximum mid-range sensitivity.
          //
          //   Mapping (gate -42, max -2, range 40 dB) + pow(x, 0.7) boost:
          //     fridge  (-35 dB) → 0.18 → 0.28  (tiny bars)
          //     soft    (-25 dB) → 0.43 → 0.54  (clearly visible)
          //     normal  (-15 dB) → 0.68 → 0.75  (fills nicely)
          //     loud    (-5 dB)  → 0.93 → 0.95  (nearly full)
          //   The pow(0.7) boost is safe here because noise is gated
          //   to zero — unlike the original pre-gate pow(0.7) which
          //   inflated noise from 0.5 to 0.62.
          const double gateDb = -42.0;
          const double maxDb = -2.0;
          final double db = amp.current.clamp(-96.0, 0.0);
          if (db <= gateDb) {
            _amplitudeController.add(0.0);
          } else {
            final normalized = ((db - gateDb) / (maxDb - gateDb)).clamp(0.0, 1.0);
            _amplitudeController.add(math.pow(normalized, 0.7).toDouble());
          }
        }
      } catch (_) {/* amplitude is best-effort */}
    });
  }
}
