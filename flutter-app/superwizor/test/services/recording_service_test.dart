// RecordingService interruption semantics (docs/28 WS2/WS3).
//
// The fake recorder mimics the verified behavior of record_ios 1.2.0 /
// record_android 1.5.1: native pause/stop events arrive on the
// onStateChanged stream, an OS interruption pauses WITHOUT any app
// intent, and resume() flips the plugin state optimistically whether or
// not capture actually restarted (the real plugin discards
// AVAudioRecorder.record()'s Bool) — which is exactly why the service
// verifies resumes with a file-growth probe.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:superwizor/services/recording_service.dart';

class _FakeRecorder extends Fake implements AudioRecorder {
  final _stateCtrl = StreamController<RecordState>.broadcast();

  bool permission = true;
  bool nativePaused = false;
  String? lastPath;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;

  /// When set, resume() appends bytes to [lastPath] shortly after being
  /// called — simulating capture genuinely restarting so the service's
  /// file-growth probe sees movement.
  bool growFileOnResume = false;

  void emitNative(RecordState s) => _stateCtrl.add(s);

  @override
  Stream<RecordState> onStateChanged() => _stateCtrl.stream;

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCalls++;
    lastPath = path;
    nativePaused = false;
    await File(path).writeAsBytes(List.filled(1024, 7));
    emitNative(RecordState.record);
    // Segment-per-resume (2026-07-23): an interruption-resume now
    // restarts capture via start() into a fresh file, so "capture
    // genuinely works again" must grow the NEW file too — same switch
    // as the resume() growth below.
    if (growFileOnResume) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 30))
          .then((_) async {
        await File(path)
            .writeAsBytes(List.filled(512, 9), mode: FileMode.append);
      }));
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    nativePaused = true;
    emitNative(RecordState.pause);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    // Plugin behavior: state flips to `record` UNCONDITIONALLY — even
    // when the underlying recorder failed to restart.
    nativePaused = false;
    emitNative(RecordState.record);
    if (growFileOnResume && lastPath != null) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 30))
          .then((_) async {
        await File(lastPath!)
            .writeAsBytes(List.filled(512, 9), mode: FileMode.append);
      }));
    }
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    emitNative(RecordState.stop);
    return lastPath;
  }

  @override
  Future<bool> isPaused() async => nativePaused;

  @override
  Future<bool> isRecording() async => lastPath != null && !nativePaused && stopCalls == 0;

  @override
  Future<Amplitude> getAmplitude() async =>
      Amplitude(current: -20, max: -10);

  /// Liczy recykle rekordera (dispose + fabryka). Fake jest reużywany
  /// przez fabrykę w testach, więc dispose NIE zamyka strumienia —
  /// zamknięcie robi dopiero closeForTest() w tearDown.
  int disposeCalls = 0;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  Future<void> closeForTest() => _stateCtrl.close();
}

void main() {
  // ReminderService (native reminder rework) fires MethodChannel calls
  // from start/pause/resume — in tests they need a binding plus a mock
  // channel handler, or every unawaited call crashes the test zone.
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('ai.superwizor/reminder_service'),
    (call) async => null,
  );

  late Directory tmp;
  late _FakeRecorder recorder;
  late RecordingService service;

  Future<void> pump([int ms = 20]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('recording_test_');
    recorder = _FakeRecorder();
    service = RecordingService(
      recorder: recorder,
      recorderFactory: () => recorder,
      documentsDirProvider: () async => tmp,
      wakelockSetter: (_) async {},
      captureProbeWindow: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    await service.dispose();
    await recorder.closeForTest();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('start records and exposes the active session', () async {
    await service.start('s1');
    expect(service.state, RecordingState.recording);
    expect(service.activeSessionId, 's1');
    expect(service.activeFilePath, endsWith('sessions/s1/raw.flac'));
  });

  test('OS interruption (native pause, no intent) → interrupted, clock frozen',
      () async {
    await service.start('s1');
    await pump(60);

    recorder.emitNative(RecordState.pause); // phone call — no app intent
    await pump();

    expect(service.state, RecordingState.interrupted);
    final atInterruption = service.currentDuration;
    expect(atInterruption.inMilliseconds, greaterThan(0));

    await pump(120); // the "call" goes on; clock must not move
    expect(service.currentDuration, atInterruption);
  });

  test('user pause is NOT an interruption', () async {
    await service.start('s1');
    await service.pause();
    await pump();
    expect(service.state, RecordingState.paused);
  });

  test('verified resume succeeds when bytes flow again', () async {
    await service.start('s1');
    recorder.emitNative(RecordState.pause);
    await pump();
    expect(service.state, RecordingState.interrupted);

    recorder.growFileOnResume = true;
    final ok = await service.resume();

    expect(ok, isTrue);
    expect(service.state, RecordingState.recording);
    await pump(60);
    expect(service.currentDuration.inMilliseconds, greaterThan(0));
  });

  test('resume that captures nothing fails loudly and stays interrupted',
      () async {
    await service.start('s1');
    recorder.emitNative(RecordState.pause);
    await pump();

    recorder.growFileOnResume = false; // plugin lies; file never grows
    final ok = await service.resume();

    expect(ok, isFalse);
    expect(service.state, RecordingState.interrupted);
    // Plain-resume path (2026-07-23 reversal): native resume + probe.
    expect(recorder.resumeCalls, 1);
  });

  test('resume from a normal user pause skips the probe (fast path)',
      () async {
    await service.start('s1');
    await service.pause();
    await pump();

    final sw = Stopwatch()..start();
    final ok = await service.resume();
    sw.stop();

    expect(ok, isTrue);
    expect(service.state, RecordingState.recording);
    // No 100 ms probe window on the user-pause path.
    expect(sw.elapsedMilliseconds, lessThan(80));
  });

  test('unexpected native stop → error, file path retained for recovery',
      () async {
    await service.start('s1');
    final path = service.activeFilePath;
    await pump();

    recorder.emitNative(RecordState.stop); // session teardown, no intent
    await pump();

    expect(service.state, RecordingState.error);
    expect(service.activeFilePath, path);
  });

  test('stop() from interrupted finalizes and returns the path', () async {
    await service.start('s1');
    recorder.emitNative(RecordState.pause);
    await pump();
    expect(service.state, RecordingState.interrupted);

    final path = await service.stop();

    expect(path, endsWith('sessions/s1/raw.flac'));
    expect(service.state, RecordingState.stopped);
    expect(service.activeSessionId, isNull);
  });

  test('reconcileWithNative flips a stale recording state', () async {
    await service.start('s1');
    await pump(40);
    // Interruption happened while the isolate was suspended: the native
    // side is paused but the pause event was never delivered.
    recorder.nativePaused = true;

    await service.reconcileWithNative();

    expect(service.state, RecordingState.interrupted);
    final frozen = service.currentDuration;
    await pump(80);
    expect(service.currentDuration, frozen);
  });

  test('hadInterruption is false for a clean recording', () async {
    await service.start('s1');
    await pump(40);
    expect(service.hadInterruption, isFalse);
    await service.stop();
    expect(service.hadInterruption, isFalse);
  });

  test('hadInterruption latches on OS interruption and survives resume+stop',
      () async {
    await service.start('s1');
    recorder.emitNative(RecordState.pause); // phone call
    await pump();
    expect(service.hadInterruption, isTrue);

    // Resume cleanly and finish in the `recording` state — the live state
    // no longer shows the interruption, but the sticky flag must persist
    // so the upload still routes through the server re-encode.
    recorder.growFileOnResume = true;
    final ok = await service.resume();
    expect(ok, isTrue);
    expect(service.state, RecordingState.recording);
    expect(service.hadInterruption, isTrue);

    await service.stop();
    expect(service.hadInterruption, isTrue);
  });

  test('hadInterruption latches via reconcileWithNative', () async {
    await service.start('s1');
    await pump(40);
    recorder.nativePaused = true;
    await service.reconcileWithNative();
    expect(service.hadInterruption, isTrue);
  });

  test('start() resets hadInterruption for the next recording', () async {
    await service.start('s1');
    recorder.emitNative(RecordState.pause);
    await pump();
    expect(service.hadInterruption, isTrue);
    await service.stop();

    await service.start('s2');
    expect(service.hadInterruption, isFalse);
  });

  test('start is allowed again after error state', () async {
    await service.start('s1');
    recorder.emitNative(RecordState.stop);
    await pump();
    expect(service.state, RecordingState.error);

    await service.start('s2');
    expect(service.state, RecordingState.recording);
    expect(service.activeSessionId, 's2');
  });

  // ── Regression: zombie timer when native recorder dies silently ──
  // Bug: reconcileWithNative only checked isPaused(), missing the case
  // where the native recorder stopped entirely (OS kill, plugin crash).
  // Dart kept showing the timer while nothing was recording.

  test('reconcileWithNative detects dead recorder (not paused, not recording) → error',
      () async {
    await service.start('s1');
    await pump(40);

    // Simulate: native recorder died silently — not paused, not recording.
    // This happens when the OS kills the recorder or the plugin crashes
    // without delivering a RecordState.stop event.
    recorder.nativePaused = false;
    // Force stopCalls > 0 so isRecording() returns false.
    recorder.stopCalls = 1;

    await service.reconcileWithNative();

    expect(service.state, RecordingState.error,
        reason: 'Dead recorder must trigger error, not stay as recording');
  });

  test('reconcileWithNative does nothing when native recorder is alive',
      () async {
    await service.start('s1');
    await pump(40);

    // Native is alive and recording — reconcile must not change state.
    recorder.nativePaused = false;

    await service.reconcileWithNative();

    expect(service.state, RecordingState.recording,
        reason: 'Healthy recorder must stay in recording state');
  });

  test('cancel() transitions to idle and cleans up', () async {
    await service.start('s1');
    await pump(40);

    await service.cancel();

    expect(service.state, RecordingState.idle);
    expect(service.activeSessionId, isNull);
    expect(service.activeFilePath, isNull);
  });

  group('needsReencode (session e22d25f3 regression)', () {
    test('plain start→stop: no re-encode needed', () async {
      await service.start('s1');
      await pump(60);
      await service.stop();
      expect(service.needsReencode, isFalse);
    });

    test('user pause→resume latches needsReencode without an interruption',
        () async {
      await service.start('s1');
      await pump(60);
      await service.pause();
      await pump();
      final resumed = await service.resume();
      expect(resumed, isTrue);
      await pump();
      await service.stop();
      // The e22d25f3 gap: hadInterruption stayed false on a user
      // pause/resume, so the corrupt file uploaded as clean audio/flac.
      expect(service.hadInterruption, isFalse);
      expect(service.needsReencode, isTrue);
    });

    test('stop from paused (resume-before-stop guard) latches needsReencode',
        () async {
      await service.start('s1');
      await pump(60);
      await service.pause();
      await pump();
      await service.stop();
      expect(service.needsReencode, isTrue);
    });

    test('OS interruption also implies needsReencode', () async {
      await service.start('s1');
      await pump(60);
      recorder.emitNative(RecordState.pause); // no armed intent → OS pause
      await pump(60);
      expect(service.hadInterruption, isTrue);
      expect(service.needsReencode, isTrue);
    });

    test(
        'auto-resume: interruption retries resume() and recovers once '
        'capture works again (feedback 2026-07-22)', () async {
      final auto = RecordingService(
        recorder: recorder,
        recorderFactory: () => recorder,
        documentsDirProvider: () async => tmp,
        wakelockSetter: (_) async {},
        captureProbeWindow: const Duration(milliseconds: 100),
        autoResumePeriod: const Duration(milliseconds: 150),
      );
      addTearDown(() => auto.dispose());

      await auto.start('s1');
      await pump(60);

      // Incoming ring: OS pauses; capture still blocked → probe fails.
      recorder.growFileOnResume = false;
      recorder.emitNative(RecordState.pause);
      await pump(60);
      expect(auto.state, RecordingState.interrupted);

      // A couple of loop ticks while the OS holds the mic.
      await pump(400);
      expect(auto.state, RecordingState.interrupted,
          reason: 'blocked resume must not fake a recording state');
      expect(recorder.resumeCalls, greaterThanOrEqualTo(1),
          reason: 'auto-resume retries native resume()');

      // Call over — mic is back; next tick should recover on its own.
      recorder.growFileOnResume = true;
      await pump(500);
      expect(auto.state, RecordingState.recording,
          reason: 'auto-resume should recover without user action');
      expect(auto.hadInterruption, isTrue);
      expect(auto.needsReencode, isTrue);
    });

    test('auto-resume loop stops on user stop()', () async {
      final auto = RecordingService(
        recorder: recorder,
        recorderFactory: () => recorder,
        documentsDirProvider: () async => tmp,
        wakelockSetter: (_) async {},
        captureProbeWindow: const Duration(milliseconds: 100),
        autoResumePeriod: const Duration(milliseconds: 150),
      );
      addTearDown(() => auto.dispose());

      await auto.start('s1');
      await pump(60);
      recorder.growFileOnResume = false;
      recorder.emitNative(RecordState.pause);
      await pump(60);
      expect(auto.state, RecordingState.interrupted);

      final path = await auto.stop();
      expect(path, isNotNull);
      final callsAtStop = recorder.resumeCalls;
      await pump(500);
      expect(recorder.resumeCalls, callsAtStop,
          reason: 'no auto-resume attempts after stop()');
    });

    test('start() resets the latch from a previous session', () async {
      await service.start('s1');
      await pump(60);
      await service.pause();
      await pump();
      await service.resume();
      await pump();
      await service.stop();
      expect(service.needsReencode, isTrue);

      await service.start('s2');
      expect(service.needsReencode, isFalse);
      await service.stop();
    });
  });
}
