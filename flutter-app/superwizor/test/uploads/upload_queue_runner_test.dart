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
  Object? putError;
  final List<String> cleanedLocalIds = [];
  Set<String>? lastPruneLiveIds;
  int pruneCalls = 0;

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
    if (putError != null) throw putError!;
    // Simulate a mid-upload progress tick (resumable chunked PUT) so tests
    // can assert the runner overlays it onto the emitted snapshot.
    onProgress?.call(0.5);
    // Option F (2026-05-25): PUT-success is terminal-success now.
    // The legacy completeCalls counter doubles as "we reached
    // terminal-success" for tests that previously bumped it.
    putCalls++;
    completeCalls++;
  }

  @override
  Future<ConvertResult> convertSource(PendingUpload u,
          {void Function(double)? onProgress}) async =>
      ConvertResult(
        sourcePath: u.sourcePath,
        contentType: u.contentType,
        sizeBytes: u.sizeBytes,
        needsServerSideConversion: u.needsServerSideConversion,
      );

  @override
  Future<EncryptResult> encryptSource(PendingUpload u,
          {void Function(double)? onProgress}) async =>
      EncryptResult(sizeBytes: u.sizeBytes, chunkCount: u.chunkCount);

  @override
  Future<String?> materializeForOsHandOff(PendingUpload u) async =>
      u.sourceKind == UploadSourceKind.plainFile
          ? u.sourcePath
          : '${u.sourcePath}/upload.flac';

  @override
  Future<void> cleanupSource(PendingUpload u) async {
    cleanedLocalIds.add(u.localId);
  }

  @override
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async {
    pruneCalls++;
    lastPruneLiveIds = liveLocalIds;
    return 0;
  }
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
      // Real "now" (not a fixed date): the runner's cold-start backoff
      // reset uses DateTime.now() directly, and the queue's pruneStale
      // sweep on every tick force-fails rows older than its 7-day
      // maxAge. A hard-coded past date silently rots — once the wall
      // clock passes seed+7d, every seeded row is pruned to `failed`
      // before the test can drive it, so keep the seed fresh.
      now: DateTime.now().toUtc(),
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

  test('upload progress is overlaid onto emitted snapshots during the PUT',
      () async {
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

    final progressSeen = <double>[];
    final sub = runner.snapshots.listen((rows) {
      for (final r in rows) {
        if (r.uploadProgress > 0) progressSeen.add(r.uploadProgress);
      }
    });

    await runner.enqueueAndKick(_seed('a'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(progressSeen, contains(0.5),
        reason: 'putBytes onProgress(0.5) must surface on a snapshot row');
    // Transient — never persisted; cleared once the row leaves phase=created.
    expect(queue.getById('a')!.uploadProgress, 0.0);

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

  test('dismiss() wipes the row source before removing the row', () async {
    // #2: a user-discarded upload must take its on-disk source with it,
    // not wait for the 7-day orphan sweep. dismiss() runs cleanupSource
    // for the row and only then drops the Hive entry.
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => false, // keep the row parked, don't auto-run
    );
    await runner.start();
    io.cleanedLocalIds.clear(); // ignore any start-up activity

    // Seed a row directly so it's present but not yet uploaded.
    await queue.enqueue(_seed('victim'));
    expect(queue.getById('victim'), isNotNull);

    await runner.dismiss('victim');

    expect(io.cleanedLocalIds, contains('victim'),
        reason: 'source cleanup must run on dismiss');
    expect(queue.getById('victim'), isNull,
        reason: 'row removed after cleanup');

    await runner.dispose();
  });

  test('start() runs an orphan-source prune seeded with live localIds',
      () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    // A pre-existing row before start(): its localId must be reported as
    // "live" so the sweep never reaps an active upload's source.
    await queue.enqueue(_seed('live-1'));

    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => false,
    );
    await runner.start();
    // The prune is unawaited inside start(); let the microtask drain.
    await Future<void>.delayed(Duration.zero);

    expect(io.pruneCalls, greaterThanOrEqualTo(1));
    expect(io.lastPruneLiveIds, contains('live-1'),
        reason: 'active rows are protected from the orphan sweep');

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

  test('connectivity restore pulls a scheduled backoff retry to now',
      () async {
    // fix/upload-stall-resilience: a row that failed while the network
    // was down carries nextAttemptAt minutes in the future. When the
    // link returns, dueNow() would skip it and the user would stare at
    // a frozen upload until the backoff elapsed — the connectivity
    // handler must reset the schedule first (cold-start semantics).
    final io = _FakeIo()..createUploadError = const SocketException('down');
    final connCtrl = StreamController<List<ConnectivityResult>>.broadcast();

    final queue = UploadQueue(hiveBox: rawBox);
    final runner = UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(
        io: io,
        backoff: (_) => const Duration(minutes: 30),
      ),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: connCtrl.stream,
      hasNetwork: () async => true,
    );

    await runner.start();
    await runner.enqueueAndKick(_seed('a'));
    final parked = queue.getById('a')!;
    expect(parked.phase, UploadPhase.pending);
    expect(parked.attemptCount, 1);
    expect(parked.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue,
        reason: 'failure scheduled a 30-min backoff');

    io.createUploadError = null; // network is healthy again
    connCtrl.add([ConnectivityResult.wifi]);

    final stopAt = DateTime.now().add(const Duration(milliseconds: 300));
    while (queue.getById('a')!.phase != UploadPhase.completed &&
        DateTime.now().isBefore(stopAt)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(queue.getById('a')!.phase, UploadPhase.completed,
        reason: 'the 30-min schedule must not outlive the outage');

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

  group('FIFO per kartoteka (2026-08-24)', () {
    PendingUpload seedAt(String id, {String pf = 'pf', int plusSec = 0}) =>
        PendingUpload.initial(
          localId: id,
          therapistId: 'th',
          patientFileId: pf,
          patientLanguageCode: 'pl-PL',
          sourceKind: UploadSourceKind.plainFile,
          sourcePath: '/$id',
          contentType: 'audio/flac',
          sizeBytes: 100,
          chunkCount: 1,
          actualDurationSeconds: 0,
          needsServerSideConversion: false,
          idempotencyKey: id,
          now: DateTime.now().toUtc().add(Duration(seconds: plusSec)),
        );

    test('młodszy wiersz tej samej kartoteki czeka na starszy', () async {
      final io = _FakeIo();
      // Starszy: create pada błędem sieciowym → wiersz zostaje aktywny
      // z backoffem. Młodszy nie ma prawa ruszyć przed nim.
      io.createUploadError = const SocketException('brak sieci');
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = UploadQueueRunner(
        queue: queue,
        worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
        periodicInterval: const Duration(hours: 1),
        connectivityStream: const Stream.empty(),
        hasNetwork: () async => true,
      );
      await queue.enqueue(seedAt('a-starszy'));
      await queue.enqueue(seedAt('b-mlodszy', plusSec: 1));
      await runner.start();

      // Młodszy nie wykonał ŻADNEGO ruchu (wszystkie próby create to
      // starszy — budżet przejść w ticku ponawia go do wyczerpania).
      expect(queue.getById('b-mlodszy')!.phase, UploadPhase.pending);
      expect(queue.getById('b-mlodszy')!.attemptCount, 0);

      // Starszy terminalny → młodszy rusza w następnym ticku.
      io.createUploadError = null;
      await queue.update(queue.getById('a-starszy')!.copyWith(
            phase: UploadPhase.failed,
            terminatedAt: DateTime.now().toUtc(),
          ));
      await runner.kick();
      expect(queue.getById('b-mlodszy')!.phase, UploadPhase.completed);
      await runner.dispose();
    });

    test('inna kartoteka nie blokuje', () async {
      final io = _FakeIo();
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = UploadQueueRunner(
        queue: queue,
        worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
        periodicInterval: const Duration(hours: 1),
        connectivityStream: const Stream.empty(),
        hasNetwork: () async => true,
      );
      await queue.enqueue(seedAt('c-pf1'));
      await queue.enqueue(seedAt('d-pf2', pf: 'pf-inna', plusSec: 1));
      await runner.start();
      expect(queue.getById('c-pf1')!.phase, UploadPhase.completed);
      expect(queue.getById('d-pf2')!.phase, UploadPhase.completed);
      await runner.dispose();
    });
  });


  group('odzysk brakującego źródła (2026-08-24)', () {
    test('plainFile bez pliku, chunki .enc obok → wiersz przepięty i kończy',
        () async {
      final dir = await Directory.systemTemp.createTemp('odzysk');
      final sesja = Directory('${dir.path}/sessions/s1');
      await sesja.create(recursive: true);
      // raw.flac NIE istnieje; obok komplet chunków.
      await File('${sesja.path}/chunk_00000.enc').writeAsBytes([1, 2, 3]);
      await File('${sesja.path}/chunk_00001.enc').writeAsBytes([4, 5]);

      final io = _FakeIo();
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = UploadQueueRunner(
        queue: queue,
        worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
        periodicInterval: const Duration(hours: 1),
        connectivityStream: const Stream.empty(),
        hasNetwork: () async => true,
      );
      await queue.enqueue(PendingUpload.initial(
        localId: 's1',
        therapistId: 'th',
        patientFileId: 'pf',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '${sesja.path}/raw.flac',
        contentType: 'audio/x-flac',
        sizeBytes: 100,
        chunkCount: 1,
        actualDurationSeconds: 0,
        needsServerSideConversion: true,
        idempotencyKey: 's1',
        now: DateTime.now().toUtc(),
      ));
      await runner.start();

      final po = queue.getById('s1')!;
      expect(po.sourceKind, UploadSourceKind.encryptedChunks,
          reason: 'sonda ma przepiąć wiersz na chunki zamiast dać mu paść');
      expect(po.sourcePath, sesja.path);
      expect(po.chunkCount, 2);
      expect(po.phase, UploadPhase.completed);
      await runner.dispose();
    });

    test('plainFile bez pliku i bez artefaktów → terminal, nie pętla', () async {
      final dir = await Directory.systemTemp.createTemp('odzysk2');
      final sesja = Directory('${dir.path}/sessions/s2');
      await sesja.create(recursive: true);

      final io = _FakeIo();
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = UploadQueueRunner(
        queue: queue,
        worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
        periodicInterval: const Duration(hours: 1),
        connectivityStream: const Stream.empty(),
        hasNetwork: () async => true,
      );
      // PUT rzuci prawdziwym PathNotFoundException dopiero w realnym IO —
      // fake symuluje to jawnie.
      io.putError = const PathNotFoundException(
          '/x/raw.flac', OSError('No such file', 2));
      await queue.enqueue(PendingUpload.initial(
        localId: 's2',
        therapistId: 'th',
        patientFileId: 'pf',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '${sesja.path}/raw.flac',
        contentType: 'audio/flac',
        sizeBytes: 100,
        chunkCount: 1,
        actualDurationSeconds: 0,
        needsServerSideConversion: false,
        idempotencyKey: 's2',
        now: DateTime.now().toUtc(),
      ));
      await runner.start();

      final po = queue.getById('s2')!;
      expect(po.phase, UploadPhase.failed,
          reason: 'brak pliku i artefaktów = terminal (klasyfikator), '
              'nie wieczne Wznawianie');
      expect(po.lastError, contains('source_file_missing'));
      await runner.dispose();
    });
  });

}
