// UploadQueueRunner tests — verify the orchestration layer:
//   • a fresh enqueue gets processed on next tick
//   • tick is a no-op when offline
//   • connectivity change to online triggers a tick
//   • snapshots stream emits on enqueue + on phase change
//   • dismiss / retryFailed work as advertised
//
// We inject a fake connectivity stream + a fake hasNetwork callback
// so the test never touches the real connectivity_plus plugin.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_io.dart';
import 'package:superwizor/uploads/upload_queue.dart';
import 'package:superwizor/uploads/upload_queue_runner.dart';
import 'package:superwizor/uploads/upload_worker.dart';

class _FakeIo implements UploadIo {
  int createCalls = 0;
  int putCalls = 0;
  int completeCalls = 0;
  Object? createUploadError;

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async {
    createCalls++;
    if (createUploadError != null) throw createUploadError!;
    return const CreateAudioUploadResult(
        uploadId: 'au-1', signedUrl: 'https://signed/1', sessionId: 'sess-1');
  }

  @override
  Future<void> putBytes(PendingUpload u,
      {void Function(double)? onProgress}) async {
    // Option F (2026-05-25): PUT-success is terminal-success now.
    // The legacy completeCalls counter doubles as "we reached
    // terminal-success" for tests that previously bumped it.
    putCalls++;
    completeCalls++;
  }

  @override
  Future<void> cleanupSource(PendingUpload u) async {}
}

PendingUpload _seed(String id) => PendingUpload.initial(
      localId: id,
      therapistId: 'th',
      patientFileId: 'pf',
      patientLanguageCode: 'pl-PL',
      sourceKind: UploadSourceKind.plainFile,
      sourcePath: '/$id',
      contentType: 'audio/flac',
      sizeBytes: 100,
      chunkCount: 1,
      actualDurationSeconds: 0,
      needsServerSideConversion: false,
      idempotencyKey: id,
      now: DateTime.utc(2026, 5, 20, 12),
    );

void main() {
  late Directory tmpDir;
  late Box<Map> rawBox;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('runner_test_');
    Hive.init(tmpDir.path);
    rawBox = await Hive.openBox<Map>(
        'runner_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  test('enqueueAndKick drives an upload to completed in one tick',
      () async {
    // Single tick walks the entire phase machine when nothing
    // schedules a backoff retry. Without this the periodic 60s
    // tick would pace each phase transition — see the loop in
    // UploadQueueRunner._tick.
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => true,
    );
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));

    final done = queue.getById('a')!;
    expect(done.phase, UploadPhase.completed);
    expect(done.sessionId, 'sess-1');
    expect(io.createCalls, 1);
    expect(io.putCalls, 1);
    expect(io.completeCalls, 1);

    await runner.dispose();
  });

  test('a retryable failure parks the row for a future tick', () async {
    // When the worker schedules a backoff (nextAttemptAt in the
    // future), the inner advance loop must bail so other rows can
    // be processed and so we don't busy-loop.
    final io = _FakeIo()..createUploadError = Exception('transient');
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(
        io: io,
        backoff: (_) => const Duration(minutes: 5),
      ),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => true,
    );
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));

    final row = queue.getById('a')!;
    expect(row.phase, UploadPhase.pending);
    expect(row.attemptCount, 1);
    expect(row.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue);
    expect(io.createCalls, 1, reason: 'no busy-loop on backoff');

    await runner.dispose();
  });

  test('start() pulls future nextAttemptAt back to now (cold-start reset)',
      () async {
    // Repro for the "Audio czeka w kolejce do uploadu" stuck-after-restart
    // bug. A row that hit QUOTA_EXHAUSTED in a previous app session gets
    // nextAttemptAt parked ~30 minutes ahead by exponential backoff. On
    // app cold-start we want it to try again immediately — the user has
    // probably fixed the underlying problem and is reopening the app
    // expecting action. If the same error recurs the worker re-applies
    // backoff, so this isn't a busy-loop.
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);

    // Seed the queue directly (not via the runner) so we can install
    // a stuck row before start() is called — mirroring the on-disk
    // state after a force-quit while the previous session was
    // back-off-parked.
    final stuck = _seed('a').copyWith(
      phase: UploadPhase.pending,
      attemptCount: 5,
      nextAttemptAt: DateTime.now().toUtc().add(const Duration(minutes: 25)),
      lastError: 'gRPC ResourceExhausted: QUOTA_EXHAUSTED',
    );
    await queue.enqueue(stuck);

    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => true,
    );

    await runner.start();

    // Worker should have processed the row exactly once — start()
    // reset the backoff window, _tick() picked it up, the upload
    // walked all the way to completed.
    expect(io.createCalls, 1,
        reason: 'cold-start reset should give the parked row one attempt');
    expect(queue.getById('a')!.phase, UploadPhase.completed);

    await runner.dispose();
  });

  test('resetBackoffsForColdStart + kick processes a parked row mid-life',
      () async {
    // Models the quota-recovery path: app is already running, admin
    // tops up tokens, billingQuotaCache fires its 0→>0 transition,
    // upload_queue_provider calls runner.resetBackoffsForColdStart()
    // followed by runner.kick(). The parked row should walk to
    // completed without needing an app restart.
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => true,
    );
    await runner.start();

    // Park a row in the future (simulating prior QUOTA_EXHAUSTED).
    final parked = _seed('a').copyWith(
      phase: UploadPhase.pending,
      attemptCount: 4,
      nextAttemptAt: DateTime.now().toUtc().add(const Duration(minutes: 25)),
      lastError: 'gRPC ResourceExhausted: QUOTA_EXHAUSTED',
    );
    await queue.enqueue(parked);
    expect(io.createCalls, 0, reason: 'parked row not yet due');

    // Quota recovers — provider would call these two methods.
    await runner.resetBackoffsForColdStart();
    await runner.kick();

    expect(queue.getById('a')!.phase, UploadPhase.completed);
    expect(io.createCalls, 1);

    await runner.dispose();
  });

  test('resetBackoffsForColdStart preserves terminal rows + attemptCount',
      () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final far = DateTime.now().toUtc().add(const Duration(hours: 1));

    final parked = _seed('a').copyWith(
      phase: UploadPhase.pending,
      attemptCount: 3,
      nextAttemptAt: far,
    );
    final failed = _seed('b').copyWith(
      phase: UploadPhase.failed,
      attemptCount: 1,
      nextAttemptAt: far,
      terminatedAt: DateTime.now().toUtc(),
    );
    await queue.enqueue(parked);
    await queue.enqueue(failed);

    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: _FakeIo()),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => false, // skip the tick side-effect
    );

    await runner.resetBackoffsForColdStart();

    final after = queue.getById('a')!;
    expect(after.nextAttemptAt.isAfter(DateTime.now().toUtc()), isFalse,
        reason: 'non-terminal parked row should be due now');
    expect(after.attemptCount, 3,
        reason: 'attemptCount preserved — fresh attempt, not clean slate');

    final stillFailed = queue.getById('b')!;
    expect(stillFailed.nextAttemptAt, far,
        reason: 'terminal failed rows are left alone');

    await runner.dispose();
  });

  test('tick is a no-op when hasNetwork() returns false', () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => false,
    );
    await runner.start();
    await runner.enqueueAndKick(_seed('a'));

    expect(io.createCalls, 0, reason: 'offline → no network calls');
    expect(queue.getById('a')!.phase, UploadPhase.pending);

    await runner.dispose();
  });

  test('connectivity restore kicks a tick', () async {
    final io = _FakeIo();
    final connCtrl =
        StreamController<List<ConnectivityResult>>.broadcast();
    var online = false;

    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: connCtrl.stream,
      hasNetwork: () async => online,
    );

    await runner.start();
    await runner.enqueueAndKick(_seed('a'));
    expect(io.createCalls, 0, reason: 'offline at enqueue time');

    online = true;
    connCtrl.add([ConnectivityResult.wifi]);

    // Wait up to 200ms for the connectivity event to propagate
    // through the listener and trigger _tick.
    final stopAt = DateTime.now().add(const Duration(milliseconds: 200));
    while (io.createCalls == 0 && DateTime.now().isBefore(stopAt)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(io.createCalls, greaterThan(0),
        reason: 'connectivity restore should trigger a tick');

    await runner.dispose();
    await connCtrl.close();
  });

  test('snapshots stream emits on enqueue and on phase change', () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => true,
    );

    final emissions = <int>[];
    final sub = runner.snapshots.listen((s) => emissions.add(s.length));

    await runner.start(); // emits initial empty snapshot
    await runner.enqueueAndKick(_seed('a')); // emits after enqueue + tick

    // Settle pending microtasks so the broadcast stream flushes.
    await Future<void>.delayed(Duration.zero);

    expect(emissions, contains(0),
        reason: 'start() emits the current (empty) snapshot');
    expect(emissions, contains(1),
        reason: 'enqueue emits a list with one row');

    await sub.cancel();
    await runner.dispose();
  });

  test('retryFailed flips a failed row back to pending', () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: _FakeIo(), backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => false, // stay offline so retry doesn't auto-resolve
    );
    await runner.start();

    final failed = _seed('x').copyWith(
      phase: UploadPhase.failed,
      lastError: 'boom',
      terminatedAt: DateTime.utc(2026, 5, 20),
      attemptCount: 4,
    );
    await queue.enqueue(failed);

    await runner.retryFailed('x');

    final reset = queue.getById('x')!;
    expect(reset.phase, UploadPhase.pending);
    expect(reset.attemptCount, 0);
    expect(reset.lastError, isNull);

    await runner.dispose();
  });

  test('dismiss removes the row', () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: _FakeIo()),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => false,
    );
    await runner.start();
    await queue.enqueue(_seed('a'));

    await runner.dismiss('a');
    expect(queue.getById('a'), isNull);

    await runner.dispose();
  });
}
