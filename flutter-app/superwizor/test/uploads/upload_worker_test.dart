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

  CreateAudioUploadResult? createUploadResult;

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
  Future<void> cleanupSource(PendingUpload u) async {
    calls.add('cleanupSource');
    if (cleanupError != null) throw cleanupError!;
  }
}

PendingUpload _seed({
  UploadPhase phase = UploadPhase.pending,
  String? uploadId,
  String? signedUrl,
  bool needsServerSideConversion = false,
  int attemptCount = 0,
  DateTime? queuedAt,
}) {
  final now = queuedAt ?? DateTime.utc(2026, 5, 20, 12);
  return PendingUpload(
    localId: 'l',
    therapistId: 'th',
    patientFileId: 'pf',
    patientLanguageCode: 'pl-PL',
    sourceKind: UploadSourceKind.plainFile,
    sourcePath: '/x',
    contentType: 'audio/flac',
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
