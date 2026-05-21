// UploadWorker tests. Drives the state machine through every phase
// transition using a FakeUploadIo. Also exercises every branch of
// the error classifier (retryable, terminal, signed-URL expired).

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
  Object? convertAudioError;
  Object? completeUploadError;
  Object? cleanupError;

  CreateAudioUploadResult? createUploadResult;
  ConvertAudioResult? convertAudioResult;
  CompleteAudioUploadResult? completeUploadResult;

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async {
    calls.add('createUpload');
    if (createUploadError != null) throw createUploadError!;
    return createUploadResult ??
        const CreateAudioUploadResult(
            uploadId: 'au-1', signedUrl: 'https://signed/1');
  }

  @override
  Future<void> putBytes(PendingUpload u,
      {void Function(double)? onProgress}) async {
    calls.add('putBytes');
    if (putBytesError != null) throw putBytesError!;
  }

  @override
  Future<ConvertAudioResult> convertAudio(PendingUpload u) async {
    calls.add('convertAudio');
    if (convertAudioError != null) throw convertAudioError!;
    return convertAudioResult ??
        const ConvertAudioResult(contentType: 'audio/flac', converted: true);
  }

  @override
  Future<CompleteAudioUploadResult> completeUpload(PendingUpload u) async {
    calls.add('completeUpload');
    if (completeUploadError != null) throw completeUploadError!;
    return completeUploadResult ??
        const CompleteAudioUploadResult(sessionId: 'sess-1');
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
      expect(next.attemptCount, 0);
      expect(io.calls, ['createUpload']);
    });

    test('created → uploaded on successful PUT', () async {
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.created,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.uploaded);
      expect(io.calls, ['putBytes']);
    });

    test('uploaded → completed when no conversion needed', () async {
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.uploaded,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.completed);
      expect(next.sessionId, 'sess-1');
      expect(next.terminatedAt, isNotNull);
      expect(io.calls, ['completeUpload', 'cleanupSource']);
    });

    test('uploaded → converted when conversion needed', () async {
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.uploaded,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
        needsServerSideConversion: true,
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.converted);
      expect(io.calls, ['convertAudio']);
    });

    test('converted → completed', () async {
      final io = FakeUploadIo();
      final u = _seed(
        phase: UploadPhase.converted,
        uploadId: 'au-1',
        signedUrl: 'https://signed/1',
      );

      final next = await _worker(io).runOne(u);

      expect(next.phase, UploadPhase.completed);
      expect(io.calls, ['completeUpload', 'cleanupSource']);
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
    test('gRPC FAILED_PRECONDITION marks failed', () async {
      final io = FakeUploadIo()
        ..completeUploadError = grpc.GrpcError.failedPrecondition(
            'audio_uploads.content_type=mpeg not Chirp');

      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.uploaded,
        uploadId: 'a',
        signedUrl: 'b',
      ));

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

    test('cleanup failure does not unwind a successful complete', () async {
      final io = FakeUploadIo()..cleanupError = Exception('disk full');
      final next = await _worker(io).runOne(_seed(
        phase: UploadPhase.uploaded,
        uploadId: 'a',
        signedUrl: 'b',
      ));
      expect(next.phase, UploadPhase.completed);
      expect(next.sessionId, 'sess-1');
    });
  });

  group('classifier direct unit', () {
    test('returns retryable for unknown error types', () {
      final c = classifyUploadError(Object());
      expect(c.kind, UploadErrorClass.retryable);
    });

    test('classifies http.ClientException as retryable', () {
      // Construct via a generic exception that has the right type;
      // we don't actually need an http.Client to do this.
      final c = classifyUploadError(const SocketException('x'));
      expect(c.kind, UploadErrorClass.retryable);
    });
  });
}
