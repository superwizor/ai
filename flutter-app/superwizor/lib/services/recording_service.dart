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
    Future<Directory> Function()? documentsDirProvider,
    Future<void> Function(bool enabled)? wakelockSetter,
    this.captureProbeWindow = const Duration(milliseconds: 1200),
  })  : _recorder = recorder ?? AudioRecorder(),
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

  final AudioRecorder _recorder;
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

  // Intent timestamps: armed right before we drive the recorder ourselves,
  // consumed by the matching native event so it isn't misread as an
  // OS-initiated transition. Stale intents (event never delivered, e.g.
  // pause() on an already-paused recorder is a native no-op) expire.
  final Map<RecordState, DateTime> _intents = {};
  static const Duration _intentTtl = Duration(seconds: 2);

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
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.flac, // lossless; ignores bitRate
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: outPath,
    );

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
    _segmentStart = DateTime.now();
    _setState(RecordingState.recording);
    _startTicker();
  }

  Future<void> pause() async {
    if (_state != RecordingState.recording) return;
    _arm(RecordState.pause);
    await _recorder.pause();
    _foldSegment();
    _setState(RecordingState.paused);
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
    final fromInterruption = _state == RecordingState.interrupted;

    if (!kIsWeb && Platform.isIOS) {
      final reactivated = await AudioSessionHelper.reactivate();
      if (!reactivated && fromInterruption) {
        // The session is still owned by another audio user (call not
        // fully torn down). Fail fast; the user can retry.
        debugPrint('[recording] resume blocked: session reactivation failed');
        return false;
      }
    }

    _arm(RecordState.record);
    try {
      await _recorder.resume();
    } catch (e) {
      debugPrint('[recording] resume failed: $e');
      return false;
    }

    if (fromInterruption) {
      final capturing = await _verifyCapture();
      if (!capturing) {
        debugPrint('[recording] resume NOT capturing — staying interrupted');
        _setState(RecordingState.interrupted);
        return false;
      }
    }

    _segmentStart = DateTime.now();
    _setState(RecordingState.recording);
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
    _ticker?.cancel();
    _ticker = null;
    await _setWakelock(false);
    await RecordingForegroundService.stop();
    _setState(RecordingState.stopped);
    final out = returnedPath ?? _activeFilePath;
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
    _ticker?.cancel();
    _ticker = null;
    _segmentStart = null;
    _accumulated = Duration.zero;
    await _setWakelock(false);
    await RecordingForegroundService.stop();
    _setState(RecordingState.idle);

    final target = path ?? _activeFilePath;
    if (target != null) {
      try {
        final f = File(target);
        if (await f.exists()) await f.delete();
      } catch (_) {/* best-effort */}
    }
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
