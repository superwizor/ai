// UploadWorker tests. Drives the state machine through every phase
// transition using a FakeUploadIo. Also exercises every branch of
// the error classifier (retryable, terminal, signed-URL expired).
//
// Option F (feat/refactor-stt-architecture, 2026-05-25) shrank the
// state machine: PUT-success is now terminal-success and the
// `uploaded` / `converted` intermediate phases were retired. Tests
// keep coverage on the legacy phases too — pre-Option-F rows still
// in Hive must walk forward to `completed` on the first new tick.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_error.dart';
import 'package:superwizor/uploads/upload_io.dart';
import 'package:superwizor/uploads/upload_worker.dart';

class FakeUploadIo implements UploadIo {
  final List<String> calls = [];

  Object? createUploadError;
  Object? putBytesError;
  Object? cleanupError;
  Object? convertError;
  Object? encryptError;

  CreateAudioUploadResult? createUploadResult;
  ConvertResult? convertResult;
  EncryptResult? encryptResult;

  @override
  Future<EncryptResult> encryptSource(PendingUpload u,
      {void Function(double)? onProgress}) async {
    calls.add('encryptSource');
    if (encryptError != null) throw encryptError!;
    // Default: a 3-chunk encryption that refines the plaintext size.
    return encryptResult ?? const EncryptResult(sizeBytes: 7777, chunkCount: 3);
  }

  @override
  Future<ConvertResult> convertSource(PendingUpload u,
      {void Function(double)? onProgress}) async {
    calls.add('convertSource');
    if (convertError != null) throw convertError!;
    // Default: a successful M4A→FLAC transcode that repoints the
    // source at a new in-staging-dir file and clears server fallback.
    return convertResult ??
        const ConvertResult(
          sourcePath: '/staged/converted.flac',
          contentType: 'audio/flac',
          sizeBytes: 4242,
          needsServerSideConversion: false,
        );
  }

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async {
    calls.add('createUpload');
    if (createUploadError != null) throw createUploadError!;
    return createUploadResult ??
        const CreateAudioUploadResult(
            uploadId: 'au-1',
            signedUrl: 'https://signed/1',
            sessionId: 'sess-1');
  }

  @override
  Future<void> putBytes(PendingUpload u,
      {void Function(double)? onProgress}) async {
    calls.add('putBytes');
    if (putBytesError != null) throw putBytesError!;
  }

  @override
  Future<String?> materializeForOsHandOff(PendingUpload u) async =>
      u.sourceKind == UploadSourceKind.plainFile
          ? u.sourcePath
          : '${u.sourcePath}/upload.flac';

  @override
  Future<void> cleanupSource(PendingUpload u) async {
    calls.add('cleanupSource');
    if (cleanupError != null) throw cleanupError!;
  }

  @override
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async {
    calls.add('pruneOrphanedSources');
    return 0;
  }
}

PendingUpload _seed({
  UploadPhase phase = UploadPhase.pending,
  String? uploadId,
  String? signedUrl,
  bool needsServerSideConversion = false,
  int attemptCount = 0,
  DateTime? queuedAt,
  String sourcePath = '/x',
  String contentType = 'audio/flac',
}) {
  final now = queuedAt ?? DateTime.utc(2026, 5, 20, 12);
  return PendingUpload(
    localId: 'l',
    therapistId: 'th',
    patientFileId: 'pf',
    patientLanguageCode: 'pl-PL',
    sourceKind: UploadSourceKind.plainFile,
    sourcePath: sourcePath,
    contentType: contentType,
    sizeBytes: 100,
    chunkCount: 1,
    actualDurationSeconds: 0,
    needsServerSideConversion: needsServerSideConversion,
    phase: phase,
    idempotencyKey: 'idem',
    uploadId: uploadId,
    signedUrl: signedUrl,
    attemptCount: attemptCount,
    queuedAt: now,
    nextAttemptAt: now,
  );
}

UploadWorker _worker(FakeUploadIo io, {DateTime? clock}) => UploadWorker(
      io: io,
      clock: clock != null ? () => clock : null,
      backoff: (n) => Duration(seconds: n * 60),
    );

void main() {
  group('encrypting phase (fix/recording-send-to-analysis)', () {
    test('encrypting → pending stamps chunkCount + plaintext size', () async {
      // Live-recording durability fix: a row enqueued in `encrypting`
      // runs the on-device AES encryption via encryptSource, then
      // advances to `pending` ready for CreateAudioUpload.
      final io = FakeUploadIo()
        ..encryptResult = const EncryptResult(sizeBytes: 16_000_000, chunkCount: 16);
      final clock = DateTime.utc(2026, 5, 20, 12);
      final u = _seed(
        phase: UploadPhase.encrypting,
        sourcePath: '/docs/sessions/sess-1',
        contentType: 'audio/flac',
      );

      final next = await _worker(io, clock: clock).runOne(u);

      expect(next.phase, UploadPhase.pending);
      expect(next.sizeBytes, 16_000_000, reason: 'refined from chunk metadata');
      expect(next.chunkCount, 16);
      expect(next.sourcePath, '/docs/sessions/sess-1',
          reason: 'encrypted chunks live in the same session dir');
      expect(next.attemptCount, 0);
      expect(next.nextAttemptAt, clock, reason: 'due immediately for create');
      expect(io.calls, ['encryptSource']);
    });

    test('encrypting walks all the way to completed', () async {
      final io = FakeUploadIo()
        ..encryptResult = const EncryptResult(sizeBytes: 16_000_000, chunkCount: 16);
      final worker = _worker(io);
      var u = _seed(
        phase: UploadPhase.encrypting,
        sourcePath: '/docs/sessions/sess-1',
      );

      u = await worker.runOne(u); // encrypting → pending
      expect(u.phase, UploadPhase.pending);
      u = await worker.runOne(u); // pending → created
      expect(u.phase, UploadPhase.created);
      u = await worker.runOne(u); // created → completed
      expect(u.phase, UploadPhase.completed);
      expect(io.calls, ['encryptSource', 'createUpload', 'putBytes', 'cleanupSource']);
    });

    test('transient encrypt error keeps the row in encrypting and retries',
        () async {
      final io = FakeUploadIo()
        ..encryptError = const SocketException('keychain busy');
      final clock = DateTime.utc(2026, 5, 20, 12);
      final u = _seed(
        phase: UploadPhase.encrypting,
        sourcePath: '/docs/sessions/sess-1',
      );

      final next = await _worker(io, clock: clock).runOne(u);

      expect(next.phase, UploadPhase.encrypting,
          reason: 'retryable error stays in the current phase');
      expect(next.attemptCount, 1);
      expect(next.nextAttemptAt.isAfter(clock), isTrue);
    });
  });

  group('converting phase (fix/app-audio-conversion)', () {
    test('converting → pending repoints source at the transcoded file',
        () async {
      // The durability fix: a row enqueued in `converting` runs the
      // on-device transcode via convertSource, then advances to
      // `pending` with the source descriptor repointed at the FLAC.
      final io = FakeUploadIo()
        ..convertResult = const ConvertResult(
          sourcePath: '/staged/l/recording.flac',
          contentType: 'audio/flac',
          sizeBytes: 9000,
          needsServerSideConversion: false,
        );
      final clock = DateTime.utc(2026, 5, 20, 12);
      final u = _seed(
        phase: UploadPhase.converting,
        sourcePath: '/staged/l/recording.m4a',
        contentType: 'audio/mp4',
      );

      final next = await _worker(io, clock: clock).runOne(u);

      expect(next.phase, UploadPhase.pending,
          reason: 'after transcode the row is ready for CreateAudioUpload');
      expect(next.sourcePath, '/staged/l/recording.flac');
      expect(next.contentType, 'audio/flac');
      expect(next.sizeBytes, 9000);
      expect(next.needsServerSideConversion, isFalse);
      expect(next.attemptCount, 0);
      expect(next.nextAttemptAt, clock, reason: 'due immediately for create');
      expect(io.calls, ['convertSource']);
    });

    test('converting → pending keeps original + server fallback on '
        'decode failure', () async {
      // iOS decode failure / non-iOS: convertSource returns the
      // ORIGINAL file with needsServerSideConversion=true. The session
      // is NOT lost — we still upload, and ingestion-svc transcodes.
      final io = FakeUploadIo()
        ..convertResult = const ConvertResult(
          sourcePath: '/staged/l/recording.m4a',
          contentType: 'audio/mp4',
          sizeBytes: 100,
          needsServerSideConversion: true,
        );
      final u = _seed(
        phase: UploadPhase.converting,
        sourcePath: '/staged/l/recording.m4a',
        contentType: 'audio/mp4',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.pending);
      expect(next.sourcePath, '/staged/l/recording.m4a',
          reason: 'original file uploaded as-is');
      expect(next.contentType, 'audio/mp4');
      expect(next.needsServerSideConversion, isTrue,
          reason: 'server runs ffmpeg off the bucket notification');
    });

    test('converting walks all the way to completed in successive runOnes',
        () async {
      // End-to-end through the new entry phase: convert → create → PUT.
      final io = FakeUploadIo()
        ..convertResult = const ConvertResult(
          sourcePath: '/staged/l/recording.flac',
          contentType: 'audio/flac',
          sizeBytes: 9000,
          needsServerSideConversion: false,
        );
      final worker = _worker(io);
      var u = _seed(
        phase: UploadPhase.converting,
        sourcePath: '/staged/l/recording.m4a',
        contentType: 'audio/mp4',
      );

      u = await worker.runOne(u); // converting → pending
      expect(u.phase, UploadPhase.pending);
      u = await worker.runOne(u); // pending → created
      expect(u.phase, UploadPhase.created);
      u = await worker.runOne(u); // created → completed (Option F)
      expect(u.phase, UploadPhase.completed);
      expect(io.calls, ['convertSource', 'createUpload', 'putBytes', 'cleanupSource']);
    });

    test('transient convert error keeps the row in converting and retries',
        () async {
      // A genuinely unexpected I/O error (NOT an expected decode
      // fallback, which convertSource swallows) must keep the durable
      // row alive in `converting` so the next tick retries — never
      // drop it.
      final io = FakeUploadIo()
        ..convertError = const SocketException('disk hiccup');
      final clock = DateTime.utc(2026, 5, 20, 12);
      final u = _seed(
        phase: UploadPhase.converting,
        sourcePath: '/staged/l/recording.m4a',
        contentType: 'audio/mp4',
      );

      final next = await _worker(io, clock: clock).runOne(u);

      expect(next.phase, UploadPhase.converting,
          reason: 'retryable error stays in the current phase');
      expect(next.attemptCount, 1);
      expect(next.nextAttemptAt.isAfter(clock), isTrue);
    });
  });

  group('happy paths', () {
    test('pending → created on successful CreateAudioUpload', () async {
      final io = FakeUploadIo();
      final u = _seed();

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.created);
      expect(next.uploadId, 'au-1');
      expect(next.signedUrl, 'https://signed/1');
      expect(next.sessionId, 'sess-1',
          reason: 'Option E: session_id captured at create');
      expect(next.attemptCount, 0);
      expect(io.calls, ['createUpload']);
    });

    test('created → completed (terminal) on successful PUT', () async {
      // Option F: PUT-success is terminal-success. No follow-up RPC.
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.created,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.completed);
      expect(next.terminatedAt, isNotNull);
      expect(io.calls, ['putBytes', 'cleanupSource']);
    });

    test('legacy `uploaded` phase walks to completed (post-upgrade)',
        () async {
      // A pre-Option-F build of the app left this row in Hive.
      // After upgrade, the next tick must terminate it cleanly —
      // there's no completeUpload RPC to call anymore, the server
      // is independently finalizing via the bucket notification.
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.uploaded,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.completed);
      expect(next.terminatedAt, isNotNull);
      expect(io.calls, ['cleanupSource'],
          reason: 'no RPC calls; only the source cleanup hook fires');
    });

    test('legacy `converted` phase also walks to completed', () async {
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.converted,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.completed);
      expect(io.calls, ['cleanupSource']);
    });

    test('terminal phases are no-ops', () async {
      final io = FakeUploadIo();
      for (final p in [UploadPhase.completed, UploadPhase.failed]) {
        final u = _seed(phase: p);
        final next = await _worker(io).runOne(u);
        expect(next.phase, p);
      }
      expect(io.calls, isEmpty);
    });
  });

  group('error classification → retry', () {
    test('gRPC UNAVAILABLE schedules retry with backoff', () async {
      final io = FakeUploadIo()
        ..createUploadError = grpc.GrpcError.unavailable('server down');
      final clock = DateTime.utc(2026, 5, 20, 12);

      final next = await _worker(io, clock: clock).runOne(_seed());

      expect(next.phase, UploadPhase.pending,
          reason: 'retryable errors stay in current phase');
      expect(next.attemptCount, 1);
      expect(next.nextAttemptAt.isAfter(clock), isTrue);
      expect(next.lastError, contains('UNAVAILABLE'));
    });

    test('gRPC RESOURCE_EXHAUSTED parks the row (no auto-retry)', () async {
      // feat/tokens-exhausted: QUOTA_EXHAUSTED must NOT loop. The row
      // parks in quotaBlocked and stays put until an explicit resend.
      final io = FakeUploadIo()
        ..createUploadError =
            grpc.GrpcError.resourceExhausted('QUOTA_EXHAUSTED');
      final clock = DateTime.utc(2026, 5, 20, 12);

      final next = await _worker(io, clock: clock).runOne(_seed());

      expect(next.phase, UploadPhase.quotaBlocked);
      expect(next.isParked, isTrue);
      expect(next.attemptCount, 1);
      expect(next.nextAttemptAt, clock,
          reason: 'parking must not push nextAttemptAt into the future — '
              'the row is skipped by phase, not by time');
      expect(next.terminatedAt, isNull,
          reason: 'parked is resumable, not terminal');
      expect(next.lastError, contains('QUOTA_EXHAUSTED'));
    });

    test('quotaBlocked phase is a parked no-op', () async {
      final io = FakeUploadIo();
      final next =
          await _worker(io).runOne(_seed(phase: UploadPhase.quotaBlocked));
      expect(next.phase, UploadPhase.quotaBlocked);
      expect(io.calls, isEmpty);
    });

    test('socket exception is retryable', () async {
      final io = FakeUploadIo()
        ..putBytesError = const SocketException('no network');
      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
      ));
      expect(next.phase, UploadPhase.created);
      expect(next.attemptCount, 1);
    });

    test('HTTP 500 is retryable', () async {
      final io = FakeUploadIo()
        ..putBytesError = httpStatusError(500, 'oops');
      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
      ));
      expect(next.phase, UploadPhase.created);
      expect(next.lastError, contains('500'));
    });

    test('backoff grows with attempt count', () async {
      final clock = DateTime.utc(2026, 5, 20, 12);
      final io = FakeUploadIo()
        ..createUploadError = grpc.GrpcError.unavailable();

      var u = _seed(attemptCount: 3);
      u = await _worker(io, clock: clock).runOne(u);

      // Our test backoff is (n * 60s) seconds, attempt becomes 4.
      expect(u.attemptCount, 4);
      expect(u.nextAttemptAt.difference(clock),
          const Duration(seconds: 4 * 60));
    });
  });

  group('upload-phase retry tuning (fix/upload-stall-resilience)', () {
    test('created-phase backoff is capped at putRetryCap', () async {
      // 6th attempt → test backoff says 360 s, but a GCS PUT failure
      // means the phone's link is down — nothing server-side to protect,
      // so the wait is capped (default 90 s) and the connectivity
      // listener / periodic tick picks the row up quickly.
      final clock = DateTime.utc(2026, 5, 20, 12);
      final io = FakeUploadIo()
        ..putBytesError = const SocketException('no network');

      final next = await _worker(io, clock: clock).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
        attemptCount: 5,
      ));

      expect(next.attemptCount, 6);
      expect(next.nextAttemptAt.difference(clock),
          const Duration(seconds: 90));
    });

    test('cap does not apply to the RPC (pending) phase', () async {
      final clock = DateTime.utc(2026, 5, 20, 12);
      final io = FakeUploadIo()
        ..createUploadError = grpc.GrpcError.unavailable();

      final next =
          await _worker(io, clock: clock).runOne(_seed(attemptCount: 5));

      expect(next.nextAttemptAt.difference(clock),
          const Duration(seconds: 6 * 60),
          reason: 'server-protection backoff stays exponential for RPCs');
    });

    test('UploadProgressMadeError resets the attempt ladder', () async {
      // The attempt failed but moved the GCS offset first — backoff
      // escalation is for attempts stuck at the same byte, so the
      // worker restarts the ladder (attemptCount 5 → 0 → +1 = 1).
      final clock = DateTime.utc(2026, 5, 20, 12);
      final io = FakeUploadIo()
        ..putBytesError = const UploadProgressMadeError(
            SocketException('drop after progress'));

      final next = await _worker(io, clock: clock).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
        attemptCount: 5,
      ));

      expect(next.phase, UploadPhase.created);
      expect(next.attemptCount, 1);
      expect(next.nextAttemptAt.difference(clock),
          const Duration(seconds: 60),
          reason: 'retry scheduled from the bottom of the ladder');
      expect(next.lastError, contains('drop after progress'));
    });

    test('wrapped error still classifies by its cause', () async {
      // Progress + session death: the signedUrlExpired routing must
      // survive the wrapper so the row re-creates instead of retrying
      // a dead session.
      final io = FakeUploadIo()
        ..putBytesError =
            UploadProgressMadeError(httpStatusError(403, 'session gone'));

      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
        attemptCount: 4,
      ));

      expect(next.phase, UploadPhase.pending);
      expect(next.uploadId, isNull, reason: 'credentials cleared');
      expect(next.attemptCount, 1, reason: 'progress reset applies here too');
    });
  });

  group('error classification → terminal', () {
    test('gRPC FAILED_PRECONDITION on create marks failed', () async {
      final io = FakeUploadIo()
        ..createUploadError =
            grpc.GrpcError.failedPrecondition('quota exhausted');

      final next = await _worker(io).runOne(_seed());

      expect(next.phase, UploadPhase.failed);
      expect(next.terminatedAt, isNotNull);
      expect(next.lastError, contains('FAILED_PRECONDITION'));
    });

    test('gRPC INVALID_ARGUMENT is terminal', () async {
      final io = FakeUploadIo()
        ..createUploadError = grpc.GrpcError.invalidArgument('bad');
      final next = await _worker(io).runOne(_seed());
      expect(next.phase, UploadPhase.failed);
    });

    test('gRPC PERMISSION_DENIED is terminal', () async {
      final io = FakeUploadIo()
        ..createUploadError = grpc.GrpcError.permissionDenied('no');
      final next = await _worker(io).runOne(_seed());
      expect(next.phase, UploadPhase.failed);
    });

    test('HTTP 400 PUT is terminal', () async {
      final io = FakeUploadIo()..putBytesError = httpStatusError(400, 'bad');
      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
      ));
      expect(next.phase, UploadPhase.failed);
    });
  });

  group('signed URL expiry', () {
    test('HTTP 403 bounces back to pending with cleared credentials',
        () async {
      final io = FakeUploadIo()
        ..putBytesError = httpStatusError(403, 'SignatureDoesNotMatch');
      final clock = DateTime.utc(2026, 5, 20, 12);

      final next = await _worker(io, clock: clock).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'au-1',
        signedUrl: 'https://expired',
      ));

      expect(next.phase, UploadPhase.pending,
          reason: 'so next tick re-runs CreateAudioUpload');
      expect(next.uploadId, isNull);
      expect(next.signedUrl, isNull);
      expect(next.attemptCount, 1);
      expect(next.nextAttemptAt, clock,
          reason: 'expired-url retry is due immediately');
    });

    test('HTTP 410 also classifies as signedUrlExpired', () async {
      final io = FakeUploadIo()..putBytesError = httpStatusError(410, 'gone');
      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
      ));
      expect(next.phase, UploadPhase.pending);
      expect(next.uploadId, isNull);
    });
  });

  group('defensive invariants', () {
    test('created phase without uploadId drops back to pending', () async {
      final io = FakeUploadIo();
      final u = _seed(phase: UploadPhase.created); // no uploadId/signedUrl
      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.pending);
      expect(next.lastError, contains('invariant'));
      expect(io.calls, isEmpty);
    });

    test('cleanup failure does not unwind a successful PUT', () async {
      final io = FakeUploadIo()..cleanupError = Exception('disk full');
      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.created,
        uploadId: 'a',
        signedUrl: 'b',
      ));
      expect(next.phase, UploadPhase.completed);
    });
  });

  group('classifier direct unit', () {
    test('returns retryable for unknown error types', () {
      final c = classifyUploadError(Object());
      expect(c.kind, UploadErrorClass.retryable);
    });

    test('classifies http.ClientException as retryable', () {
      final c = classifyUploadError(const SocketException('x'));
      expect(c.kind, UploadErrorClass.retryable);
    });
  });
}
