// End-to-end state-transition tests for the upload queue subsystem.
//
// These tests treat UploadQueueRunner + UploadWorker + UploadIo as a
// single unit and walk the row through every meaningful state
// transition that production hits. Where a transition depends on
// external state (Firestore session_states, gRPC server errors), we
// inject a fake.
//
// Transitions covered:
//   pending → created → uploaded → completed                 (Chirp-native, plainFile)
//   pending → created → uploaded → converted → completed      (server-side conversion)
//   pending → created (transient err) → pending (backoff)     (retryable)
//   pending → created → uploaded (403) → pending (URL refresh)
//   completed + sessionId → Firestore 'done' → row removed
//   completed + sessionId → Firestore 'failed' → row removed
//   completed + sessionId → Firestore 'analyzing' → row stays
//   onAnalysisComplete called exactly once per terminal transition

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:hive/hive.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_error.dart';
import 'package:superwizor/uploads/upload_io.dart';
import 'package:superwizor/uploads/upload_queue.dart';
import 'package:superwizor/uploads/upload_queue_runner.dart';
import 'package:superwizor/uploads/upload_worker.dart';

class _FakeIo implements UploadIo {
  int createCalls = 0;
  int putCalls = 0;
  // Option F (2026-05-25): convert + complete RPCs are gone. The
  // worker terminates at PUT. completeCalls is incremented from
  // inside putBytes for tests that previously asserted on it as a
  // "did we reach terminal-success" signal.
  int completeCalls = 0;
  Object? createUploadError;
  Object? putBytesError;
  /// When true, [putBytesError] is NOT cleared after the first throw —
  /// models a resumable session that is permanently dead (403/410 on every
  /// PUT), which is what makes the signedUrlExpired class loop.
  bool putBytesErrorSticky = false;

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async {
    createCalls++;
    if (createUploadError != null) throw createUploadError!;
    return CreateAudioUploadResult(
        uploadId: 'au-${u.localId}',
        signedUrl: 'https://signed/${u.localId}',
        sessionId: 'sess-${u.localId}');
  }

  @override
  Future<void> putBytes(PendingUpload u,
      {void Function(double)? onProgress}) async {
    putCalls++;
    if (putBytesError != null) {
      final err = putBytesError!;
      if (!putBytesErrorSticky) {
        putBytesError = null; // one-shot — clear so subsequent attempts succeed
      }
      throw err;
    }
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
  Future<void> cleanupSource(PendingUpload u) async {}

  @override
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async =>
      0;
}

PendingUpload _seed(String id, {bool needsConversion = false}) =>
    PendingUpload.initial(
      localId: id,
      therapistId: 'th-1',
      patientFileId: 'pf-1',
      patientLanguageCode: 'pl-PL',
      sourceKind: UploadSourceKind.plainFile,
      sourcePath: '/$id',
      contentType: needsConversion ? 'audio/mpeg' : 'audio/flac',
      sizeBytes: 100,
      chunkCount: 1,
      actualDurationSeconds: 0,
      needsServerSideConversion: needsConversion,
      idempotencyKey: id,
      // Real "now" — the queue's pruneStale sweep (run every tick)
      // force-fails rows older than its 7-day maxAge, so a hard-coded
      // past date silently rots once the wall clock passes seed+7d.
      now: DateTime.now().toUtc(),
    );

UploadQueueRunner _runner({
  required UploadQueue queue,
  required _FakeIo io,
  Stream<String> Function(String)? sessionStatusStream,
  Future<void> Function(PendingUpload)? onUploadComplete,
  Future<void> Function(PendingUpload)? onAnalysisComplete,
  Duration Function(int)? backoff,
}) =>
    UploadQueueRunner(
      queue: queue,
      worker: UploadWorker(
        io: io,
        backoff: backoff ?? (_) => const Duration(minutes: 5),
      ),
      periodicInterval: const Duration(hours: 1),
      connectivityStream: const Stream.empty(),
      hasNetwork: () async => true,
      sessionStatusStream: sessionStatusStream,
      onUploadComplete: onUploadComplete,
      onAnalysisComplete: onAnalysisComplete,
    );

void main() {
  late Directory tmpDir;
  late Box<Map> rawBox;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('state_transitions_');
    Hive.init(tmpDir.path);
    rawBox = await Hive.openBox<Map>(
        'state_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  group('happy paths', () {
    test('Chirp-native: pending → created → completed in one tick (Option F)',
        () async {
      final queue = UploadQueue(hiveBox: rawBox);
      final io = _FakeIo();
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('a'));

      final row = queue.getById('a')!;
      expect(row.phase, UploadPhase.completed);
      expect(row.sessionId, 'sess-a',
          reason: 'session_id captured from CreateAudioUploadResponse');
      expect(io.createCalls, 1);
      expect(io.putCalls, 1);
      expect(io.completeCalls, 1,
          reason:
              'Option F: putBytes bumps the same counter — PUT-success is terminal-success');

      await runner.dispose();
    });

    test(
        'needs server-side conversion: client still terminates at PUT (server handles it)',
        () async {
      // Option F (2026-05-25): the client uploads the original codec
      // and stops. The server-side subscriber transcodes if needed —
      // there is no longer a client RPC for that.
      final queue = UploadQueue(hiveBox: rawBox);
      final io = _FakeIo();
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('b', needsConversion: true));

      final row = queue.getById('b')!;
      expect(row.phase, UploadPhase.completed);
      expect(io.completeCalls, 1);

      await runner.dispose();
    });
  });

  group('transient failures', () {
    test('retryable error keeps row in current phase with bumped attempt',
        () async {
      final io = _FakeIo()
        ..createUploadError = grpc.GrpcError.unavailable('flaky');
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: io,
        backoff: (_) => const Duration(minutes: 5),
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('c'));

      final row = queue.getById('c')!;
      expect(row.phase, UploadPhase.pending);
      expect(row.attemptCount, 1);
      expect(row.lastError, contains('UNAVAILABLE'));
      expect(row.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue);

      await runner.dispose();
    });

    test('signed URL expiry: 403 PUT → row goes back to pending, creds cleared',
        () async {
      final queue = UploadQueue(hiveBox: rawBox);
      final io = _FakeIo()
        ..putBytesError = httpStatusError(403, 'SignatureExpired');
      // backoff doesn't matter — signedUrlExpired schedules nextAttemptAt=now.
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('d'));

      // After one tick: pending → created (PUT fails 403) → back to
      // pending with creds cleared, attemptCount=1, due immediately.
      // The inner advance loop also re-runs createUpload + putBytes
      // since the row is due now and putBytesError was one-shot.
      final row = queue.getById('d')!;
      // End state: full success since putBytesError was a one-shot.
      expect(row.phase, UploadPhase.completed);
      expect(io.createCalls, greaterThanOrEqualTo(2),
          reason: 'createUpload re-ran after signed URL refresh');
      expect(io.putCalls, greaterThanOrEqualTo(2),
          reason: 'PUT retried after URL refresh');

      await runner.dispose();
    });

    test('permanently dead resumable session: phase-hop budget stops the loop',
        () async {
      // Regression (2026-07-29): signedUrlExpired sets phase=pending AND
      // nextAttemptAt=now, so the runner's only backoff exit is
      // structurally unreachable. With a STICKY 403 the inner advance loop
      // used to spin create → PUT → 403 → create forever inside one tick,
      // starving every other queued row. The per-tick hop budget must cut
      // it off and hand the row a real backoff.
      final queue = UploadQueue(hiveBox: rawBox);
      final io = _FakeIo()
        ..putBytesError = httpStatusError(403, 'SignatureExpired')
        ..putBytesErrorSticky = true;
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('budget'));

      final row = queue.getById('budget')!;
      expect(row.phase, UploadPhase.pending,
          reason: 'still retryable — the row is not failed, just deferred');
      expect(row.lastError, 'upload.phase_hop_budget_exceeded');
      expect(row.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue,
          reason: 'budget exhaustion must schedule a FUTURE attempt, '
              'otherwise the next tick spins again');
      // 6 hops ≈ 3 create+PUT laps. The exact number matters less than the
      // bound: without the budget these counters grow without limit.
      expect(io.putCalls, lessThanOrEqualTo(4));
      expect(io.createCalls, lessThanOrEqualTo(4));

      await runner.dispose();
    });
  });

  group('terminal failures', () {
    test('FAILED_PRECONDITION → row marked failed, terminatedAt set',
        () async {
      final io = _FakeIo()
        ..createUploadError = grpc.GrpcError.failedPrecondition(
            'audio_uploads.content_type=mpeg not Chirp');
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('e'));

      final row = queue.getById('e')!;
      expect(row.phase, UploadPhase.failed);
      expect(row.terminatedAt, isNotNull);
      expect(row.lastError, contains('FAILED_PRECONDITION'));

      await runner.dispose();
    });
  });

  group('onUploadComplete (kartoteka refresh on upload finish)', () {
    test('fires exactly once when row first hits phase=completed', () async {
      var calls = 0;
      PendingUpload? lastRowSeen;
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: _FakeIo(),
        onUploadComplete: (row) async {
          calls++;
          lastRowSeen = row;
        },
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('uc1'));
      expect(calls, 1);
      expect(lastRowSeen?.localId, 'uc1');
      expect(lastRowSeen?.phase, UploadPhase.completed);

      // A second tick must NOT refire the callback for the same row.
      await runner.kick();
      expect(calls, 1, reason: 'no duplicate fire on subsequent ticks');

      await runner.dispose();
    });

    test('does not fire on terminal-failed transition', () async {
      var calls = 0;
      final io = _FakeIo()
        ..createUploadError =
            grpc.GrpcError.failedPrecondition('nope');
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: io,
        onUploadComplete: (_) async => calls++,
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('uc2'));
      expect(queue.getById('uc2')!.phase, UploadPhase.failed);
      expect(calls, 0,
          reason: 'failure path must not trigger upload-complete');

      await runner.dispose();
    });

    test('upload-complete failure does not abort the row', () async {
      // If the cache refresh blows up the row should still settle at
      // phase=completed — the kartoteka being stale is a soft failure.
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: _FakeIo(),
        onUploadComplete: (_) async => throw Exception('refresh boom'),
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('uc3'));
      expect(queue.getById('uc3')!.phase, UploadPhase.completed);

      await runner.dispose();
    });
  });

  group('post-upload Firestore-driven analysis', () {
    test("status='done' removes the row and invokes onAnalysisComplete",
        () async {
      final analysisStatuses = StreamController<String>.broadcast();
      var onCompleteCalls = 0;
      PendingUpload? lastRowSeen;

      final queue = UploadQueue(hiveBox: rawBox);
      final io = _FakeIo();
      final runner = _runner(
        queue: queue,
        io: io,
        sessionStatusStream: (_) => analysisStatuses.stream,
        onAnalysisComplete: (row) async {
          onCompleteCalls++;
          lastRowSeen = row;
        },
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('f'));
      // Upload finished; row sits at completed waiting for analysis.
      expect(queue.getById('f')!.phase, UploadPhase.completed);

      // Server-side mirror reports 'analyzing' first — should NOT
      // remove the row.
      analysisStatuses.add('analyzing');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.getById('f'), isNotNull,
          reason: "'analyzing' must not terminate the row");
      expect(onCompleteCalls, 0);

      // Then 'done' — runner refreshes caches + drops the row.
      analysisStatuses.add('done');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.getById('f'), isNull,
          reason: "'done' must remove the row");
      expect(onCompleteCalls, 1);
      expect(lastRowSeen?.localId, 'f');

      await runner.dispose();
      await analysisStatuses.close();
    });

    test("status='failed' also terminates the row", () async {
      final analysisStatuses = StreamController<String>.broadcast();
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: _FakeIo(),
        sessionStatusStream: (_) => analysisStatuses.stream,
        onAnalysisComplete: (_) async {},
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('g'));

      analysisStatuses.add('failed');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.getById('g'), isNull);

      await runner.dispose();
      await analysisStatuses.close();
    });

    test('one subscription per row — opening twice is a no-op', () async {
      final analysisStatuses = StreamController<String>.broadcast();
      var subscribeCount = 0;
      Stream<String> wrap(String _) {
        subscribeCount++;
        return analysisStatuses.stream;
      }

      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: _FakeIo(),
        sessionStatusStream: wrap,
        onAnalysisComplete: (_) async {},
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('h'));
      // A second kick should not open a second subscription for h.
      await runner.kick();
      await runner.kick();
      expect(subscribeCount, 1);

      await runner.dispose();
      await analysisStatuses.close();
    });

    test('subscription torn down on dispose', () async {
      final analysisStatuses = StreamController<String>.broadcast();
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: _FakeIo(),
        sessionStatusStream: (_) => analysisStatuses.stream,
        onAnalysisComplete: (_) async {},
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('i'));
      expect(analysisStatuses.hasListener, isTrue);
      await runner.dispose();
      expect(analysisStatuses.hasListener, isFalse,
          reason: 'dispose() cancels analysis subscriptions');
      await analysisStatuses.close();
    });

    test('onAnalysisComplete failure does not block row removal', () async {
      final analysisStatuses = StreamController<String>.broadcast();
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(
        queue: queue,
        io: _FakeIo(),
        sessionStatusStream: (_) => analysisStatuses.stream,
        onAnalysisComplete: (_) async => throw Exception('cache refresh boom'),
      );
      await runner.start();
      await runner.enqueueAndKick(_seed('j'));

      analysisStatuses.add('done');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.getById('j'), isNull,
          reason: 'row removal happens regardless of callback error');

      await runner.dispose();
      await analysisStatuses.close();
    });
  });

  group('dismiss / retryFailed', () {
    test('dismiss removes the row and emits a snapshot', () async {
      final queue = UploadQueue(hiveBox: rawBox);
      final io = _FakeIo();
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('k'));
      expect(queue.getById('k'), isNotNull);

      await runner.dismiss('k');
      expect(queue.getById('k'), isNull);

      await runner.dispose();
    });

    test('retryFailed flips phase=failed → pending, clears bookkeeping',
        () async {
      final io = _FakeIo()
        ..createUploadError = grpc.GrpcError.failedPrecondition('nope');
      final queue = UploadQueue(hiveBox: rawBox);
      final runner = _runner(queue: queue, io: io);
      await runner.start();
      await runner.enqueueAndKick(_seed('l'));
      expect(queue.getById('l')!.phase, UploadPhase.failed);

      // Clear the error and retry.
      io.createUploadError = null;
      await runner.retryFailed('l');

      final row = queue.getById('l')!;
      expect(row.phase, UploadPhase.completed,
          reason: 'retry kicks the runner; row walks to completion');
      expect(row.attemptCount, 0);
      expect(row.lastError, isNull);

      await runner.dispose();
    });
  });
}
