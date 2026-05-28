// RecordingService — wraps the `record` package with our domain semantics.
//
// Per D10 Plan C: native FLAC @ 16 kHz mono. iOS does not ship a
// public Opus encoder; the `record` package's iOS Opus path produces
// 0-byte files. FLAC works natively and is a Chirp 3-supported codec.
// `recorder.stop()` returns the path to a final .flac file ready for
// AES-GCM encryption by SecureAudioStorageService.
//
// State machine:
//
//   idle ─start()→ recording ─pause()→ paused ─resume()→ recording
//                          \─stop()→ stopped (returns path, transitions to idle)
//
// Wakelock keeps the screen awake during recording so the OS doesn't
// dim the device and confuse the therapist about whether the app is
// still capturing. iOS BG audio mode (Info.plist UIBackgroundModes:
// audio) keeps the recorder alive when the app goes to background.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum RecordingState { idle, recording, paused, stopped, error }

class RecordingService {
  RecordingService();

  final AudioRecorder _recorder = AudioRecorder();

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

  Timer? _ticker;
  DateTime? _segmentStart;
  Duration _accumulated = Duration.zero;

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
  Future<void> start(String sessionId) async {
    if (_state != RecordingState.idle && _state != RecordingState.stopped) {
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

    final docs = await getApplicationDocumentsDirectory();
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
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.flac, // lossless; ignores bitRate
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        // F-11: noise suppression enabled alongside AGC. Without it,
        // AGC alone amplifies background noise in quiet rooms
        // (HVAC hum, street noise, ticking clocks), degrading STT
        // accuracy. Echo cancellation stays off — therapy sessions
        // don't play audio back, so there's nothing to cancel and
        // enabling it would add latency + potential artifacts.
        noiseSuppress: true,
      ),
      path: outPath,
    );

    await WakelockPlus.enable();

    _activeFilePath = outPath;
    _accumulated = Duration.zero;
    _segmentStart = DateTime.now();
    _setState(RecordingState.recording);
    _startTicker();
  }

  Future<void> pause() async {
    if (_state != RecordingState.recording) return;
    await _recorder.pause();
    if (_segmentStart != null) {
      _accumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
    _setState(RecordingState.paused);
  }

  Future<void> resume() async {
    if (_state != RecordingState.paused) return;
    await _recorder.resume();
    _segmentStart = DateTime.now();
    _setState(RecordingState.recording);
  }

  /// Stops the recorder. Returns the path to the finished FLAC file
  /// (or null if recording never actually started). Caller hands the
  /// file off to SecureAudioStorageService.encryptRecording().
  ///
  /// Resume-before-stop guard: on iOS, calling stop() while in paused
  /// state has been observed to produce a 0-byte file (the OGG writer
  /// loses the in-flight buffer because pause closes the file handle
  /// without flushing the trailing OGG page). We force a brief resume
  /// so the recorder can reach a clean stop point.
  Future<String?> stop() async {
    if (_state == RecordingState.idle || _state == RecordingState.stopped) {
      return null;
    }
    if (_state == RecordingState.paused) {
      try {
        await _recorder.resume();
        _segmentStart = DateTime.now();
        // Tiny dwell so the encoder writes its trailing frames cleanly.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // ignore — best-effort
      }
    }
    final returnedPath = await _recorder.stop();
    if (_segmentStart != null) {
      _accumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
    _ticker?.cancel();
    _ticker = null;
    await WakelockPlus.disable();
    _setState(RecordingState.stopped);
    final out = returnedPath ?? _activeFilePath;
    _activeFilePath = null;
    return out;
  }

  /// Cancels and deletes the in-progress recording (used by
  /// "Zakończ bez zapisu" / "Usuń to nagranie bezpowrotnie").
  Future<void> cancel() async {
    final path = await _recorder.stop();
    _ticker?.cancel();
    _ticker = null;
    _segmentStart = null;
    _accumulated = Duration.zero;
    await WakelockPlus.disable();
    _setState(RecordingState.idle);

    final target = path ?? _activeFilePath;
    if (target != null) {
      try {
        final f = File(target);
        if (await f.exists()) await f.delete();
      } catch (_) {/* best-effort */}
    }
    _activeFilePath = null;
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _recorder.dispose();
    if (!_stateController.isClosed) await _stateController.close();
    if (!_durationController.isClosed) await _durationController.close();
    if (!_amplitudeController.isClosed) await _amplitudeController.close();
  }

  // ---------- internals ----------

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
