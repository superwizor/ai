// Exhaustive error classification tests for the upload pipeline's
// security-related error types.
//
// Covers:
//   - IntegrityViolation (F-03) → terminal
//   - HandshakeException (TLS) → retryable
//   - GrpcError security codes → terminal
//   - HTTP signed-URL expiration variants → signedUrlExpired
//   - Network errors during upload → retryable
//   - PendingUpload.toJson/fromJson F-13 signedUrl exclusion
//   - Unknown errors → retryable (conservative default)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:http/http.dart' as http;

import 'package:superwizor/services/secure_audio_storage_service.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_error.dart';

void main() {
  // ────────────────────────────────────────────────────────────────
  // IntegrityViolation (F-03)
  // ────────────────────────────────────────────────────────────────

  group('IntegrityViolation classification', () {
    test('chunk count mismatch → terminal', () {
      final r = classifyUploadError(
        IntegrityViolation('chunk count mismatch: expected 5, found 3'),
      );
      expect(r.kind, UploadErrorClass.terminal);
      expect(r.message, contains('chunk count mismatch'));
    });

    test('SHA-256 mismatch → terminal', () {
      final r = classifyUploadError(
        IntegrityViolation('SHA-256 mismatch on chunk 2'),
      );
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('HMAC mismatch → terminal', () {
      final r = classifyUploadError(
        IntegrityViolation('manifest HMAC mismatch — tampering detected'),
      );
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('foreign files → terminal', () {
      final r = classifyUploadError(
        IntegrityViolation(
            'foreign files detected in session directory: malware.bin'),
      );
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('missing key → terminal', () {
      final r = classifyUploadError(
        IntegrityViolation('cannot verify HMAC: no key for version 99'),
      );
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('IntegrityViolation toString includes message', () {
      const msg = 'test message';
      final e = IntegrityViolation(msg);
      expect(e.toString(), contains(msg));
      expect(e.message, msg);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // TLS / certificate errors
  // ────────────────────────────────────────────────────────────────

  group('TLS / certificate errors', () {
    test('HandshakeException → retryable (network layer)', () {
      final r = classifyUploadError(
        const HandshakeException(
            'Connection terminated during handshake'),
      );
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('SocketException → retryable', () {
      final r = classifyUploadError(
        const SocketException('Connection refused'),
      );
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('HttpException → retryable', () {
      final r = classifyUploadError(
        const HttpException('Connection reset by peer'),
      );
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('http.ClientException → retryable', () {
      final r = classifyUploadError(
        http.ClientException('Connection closed before full body was received'),
      );
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('TimeoutException → retryable', () {
      final r = classifyUploadError(
        TimeoutException('Connection timed out', const Duration(seconds: 30)),
      );
      expect(r.kind, UploadErrorClass.retryable);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // gRPC security-related codes
  // ────────────────────────────────────────────────────────────────

  group('gRPC security codes → terminal', () {
    test('permissionDenied → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.permissionDenied,
        'Permission denied',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('unauthenticated → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.unauthenticated,
        'Token expired',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('failedPrecondition → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.failedPrecondition,
        'Invalid content type',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('invalidArgument → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.invalidArgument,
        'Missing field',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('notFound → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.notFound,
        'Upload not found',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('alreadyExists → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.alreadyExists,
        'Duplicate',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('unimplemented → terminal', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.unimplemented,
        'Method not available',
      ));
      expect(r.kind, UploadErrorClass.terminal);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // gRPC transient codes → retryable
  // ────────────────────────────────────────────────────────────────

  group('gRPC transient codes → retryable', () {
    test('unavailable → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.unavailable,
        'Service unavailable',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('deadlineExceeded → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.deadlineExceeded,
        'Deadline exceeded',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('resourceExhausted → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.resourceExhausted,
        'Quota exceeded',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('internal → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.internal,
        'Internal error',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('unknown → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.unknown,
        'Unknown error',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('aborted → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.aborted,
        'Aborted',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('dataLoss → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.dataLoss,
        'Data loss',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('cancelled → retryable', () {
      final r = classifyUploadError(grpc.GrpcError.custom(
        grpc.StatusCode.cancelled,
        'Cancelled',
      ));
      expect(r.kind, UploadErrorClass.retryable);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // HTTP signed-URL errors
  // ────────────────────────────────────────────────────────────────

  group('HTTP signed-URL expiration', () {
    test('HTTP 403 → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(403, 'Forbidden'));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 401 → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(401, 'Unauthorized'));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 410 → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(410, 'Gone'));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 400 + ExpiredToken → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(
        400,
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Error><Code>ExpiredToken</Code></Error>',
      ));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 400 + SignatureDoesNotMatch → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(
        400,
        '<Error><Code>SignatureDoesNotMatch</Code></Error>',
      ));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 400 (other) → terminal', () {
      final r = classifyUploadError(httpStatusError(
        400,
        'Bad request: object size mismatch',
      ));
      expect(r.kind, UploadErrorClass.terminal,
          reason: 'Generic 400 (not token-related) should be terminal');
    });

    test('HTTP 500 → retryable', () {
      final r = classifyUploadError(httpStatusError(500, 'Internal'));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('HTTP 502 → retryable', () {
      final r = classifyUploadError(httpStatusError(502, 'Bad Gateway'));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('HTTP 503 → retryable', () {
      final r = classifyUploadError(
          httpStatusError(503, 'Service Unavailable'));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('HTTP 404 → terminal', () {
      final r = classifyUploadError(httpStatusError(404, 'Not Found'));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('HTTP 413 → terminal', () {
      final r = classifyUploadError(
          httpStatusError(413, 'Payload too large'));
      expect(r.kind, UploadErrorClass.terminal);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Default / unknown errors
  // ────────────────────────────────────────────────────────────────

  group('Default error handling', () {
    test('unknown Exception → retryable (conservative)', () {
      final r = classifyUploadError(Exception('something went wrong'));
      expect(r.kind, UploadErrorClass.retryable,
          reason: 'Unknown errors must default to retryable — '
              'failing permanently on a transient bug loses recordings');
    });

    test('StateError → retryable (conservative)', () {
      final r = classifyUploadError(StateError('bad state'));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('String error → retryable', () {
      final r = classifyUploadError('something broke');
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('FormatException → retryable', () {
      final r = classifyUploadError(const FormatException('bad json'));
      expect(r.kind, UploadErrorClass.retryable);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-13: PendingUpload signedUrl exclusion
  // ────────────────────────────────────────────────────────────────

  group('F-13 signedUrl not persisted', () {
    PendingUpload _makePendingUpload({String? signedUrl}) {
      return PendingUpload(
        localId: 'test-local-id',
        therapistId: 'therapist-1',
        patientFileId: 'patient-1',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.encryptedChunks,
        sourcePath: '/sessions/session-1/',
        contentType: 'audio/flac',
        sizeBytes: 1024000,
        chunkCount: 1,
        actualDurationSeconds: 600,
        needsServerSideConversion: false,
        phase: UploadPhase.created,
        idempotencyKey: 'idem-key-1',
        queuedAt: DateTime.utc(2026, 5, 28),
        nextAttemptAt: DateTime.utc(2026, 5, 28),
        uploadId: 'upload-123',
        signedUrl: signedUrl,
      );
    }

    test('signedUrl is excluded from toJson', () {
      final upload = _makePendingUpload(
        signedUrl: 'https://storage.googleapis.com/bucket/obj?X-Goog-Signature=abc',
      );
      final json = upload.toJson();
      expect(json.containsKey('signedUrl'), isFalse,
          reason: 'F-13: signedUrl must NOT be persisted to Hive — '
              'it leaks a credential if Hive box is compromised');
    });

    test('signedUrl is null after fromJson round-trip', () {
      final upload = _makePendingUpload(
        signedUrl: 'https://storage.googleapis.com/bucket/obj?signature=xyz',
      );
      final json = upload.toJson();
      final restored = PendingUpload.fromJson(json);
      expect(restored.signedUrl, isNull,
          reason: 'F-13: after deserialization signedUrl must be null — '
              'worker re-derives via CreateAudioUpload');
    });

    test('toJson → fromJson round-trip preserves all OTHER fields', () {
      final upload = _makePendingUpload();
      final json = upload.toJson();
      final restored = PendingUpload.fromJson(json);

      expect(restored.localId, upload.localId);
      expect(restored.therapistId, upload.therapistId);
      expect(restored.patientFileId, upload.patientFileId);
      expect(restored.patientLanguageCode, upload.patientLanguageCode);
      expect(restored.sourceKind, upload.sourceKind);
      expect(restored.sourcePath, upload.sourcePath);
      expect(restored.contentType, upload.contentType);
      expect(restored.sizeBytes, upload.sizeBytes);
      expect(restored.chunkCount, upload.chunkCount);
      expect(restored.actualDurationSeconds, upload.actualDurationSeconds);
      expect(restored.needsServerSideConversion, upload.needsServerSideConversion);
      expect(restored.phase, upload.phase);
      expect(restored.idempotencyKey, upload.idempotencyKey);
      expect(restored.uploadId, upload.uploadId);
      expect(restored.attemptCount, upload.attemptCount);
      expect(restored.queuedAt, upload.queuedAt);
      expect(restored.nextAttemptAt, upload.nextAttemptAt);
    });

    test('copyWith(clearUploadCredentials: true) clears signedUrl', () {
      final upload = _makePendingUpload(
        signedUrl: 'https://secret-url.com',
      );
      final cleared = upload.copyWith(clearUploadCredentials: true);
      expect(cleared.signedUrl, isNull);
      expect(cleared.uploadId, isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // httpStatusError factory
  // ────────────────────────────────────────────────────────────────

  group('httpStatusError factory', () {
    test('creates a classifiable error', () {
      final err = httpStatusError(500, 'Internal Server Error');
      final r = classifyUploadError(err);
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('default empty body', () {
      final err = httpStatusError(404);
      final r = classifyUploadError(err);
      expect(r.kind, UploadErrorClass.terminal);
    });
  });
}
