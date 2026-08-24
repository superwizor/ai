// Regression coverage for classifyUploadError. Particularly the
// HTTP 400 + ExpiredToken branch (2026-05-22 — Marcin's 111.7 MB
// upload that got stuck because the classifier mapped 400 → terminal
// without inspecting the body).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:superwizor/uploads/upload_error.dart';

void main() {
  group('classifyUploadError — HTTP signed-URL errors', () {
    test('HTTP 403 → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(403, 'SignatureDoesNotMatch'));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 401 → signedUrlExpired', () {
      final r = classifyUploadError(httpStatusError(401, ''));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 410 → signedUrlExpired (resumable session)', () {
      final r = classifyUploadError(httpStatusError(410, 'Gone'));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 400 + ExpiredToken body → signedUrlExpired '
        '(regression for Marcin 2026-05-22)', () {
      const body = "<?xml version='1.0' encoding='UTF-8'?>"
          "<Error><Code>ExpiredToken</Code>"
          "<Message>Invalid argument.</Message>"
          "<Details>The provided token has expired.</Details></Error>";
      final r = classifyUploadError(httpStatusError(400, body));
      expect(r.kind, UploadErrorClass.signedUrlExpired,
          reason: 'GCS V4 signed URLs return 400 (not 403) on '
              'signature expiration. Pre-fix this fell into terminal '
              'and the user got stuck on "Ponów" forever.');
    });

    test('HTTP 400 + SignatureDoesNotMatch body → signedUrlExpired', () {
      const body = "<Error><Code>SignatureDoesNotMatch</Code></Error>";
      final r = classifyUploadError(httpStatusError(400, body));
      expect(r.kind, UploadErrorClass.signedUrlExpired);
    });

    test('HTTP 400 with unrelated body → terminal (genuine bad request)', () {
      // Object metadata mismatch, x-goog-content-length-range violated,
      // etc. — re-running CreateAudioUpload won't fix it.
      const body = "<Error><Code>InvalidArgument</Code>"
          "<Message>X-Goog-Content-Length-Range mismatch</Message></Error>";
      final r = classifyUploadError(httpStatusError(400, body));
      expect(r.kind, UploadErrorClass.terminal,
          reason: 'Non-ExpiredToken 400s must stay terminal — '
              'retrying with a fresh URL would hit the same error.');
    });

    test('HTTP 413 Payload Too Large → terminal', () {
      final r = classifyUploadError(httpStatusError(413, 'Too Large'));
      expect(r.kind, UploadErrorClass.terminal);
    });

    test('HTTP 500 → retryable', () {
      final r = classifyUploadError(httpStatusError(500, ''));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('HTTP 503 → retryable', () {
      final r = classifyUploadError(httpStatusError(503, ''));
      expect(r.kind, UploadErrorClass.retryable);
    });
  });

  group('classifyUploadError — gRPC', () {
    test('ResourceExhausted (QUOTA_EXHAUSTED) → quotaBlocked', () {
      // feat/tokens-exhausted: this used to be `retryable`, which made
      // CreateAudioUpload loop forever ("próba 7/4"). It must now park.
      final r = classifyUploadError(
          grpc.GrpcError.resourceExhausted('QUOTA_EXHAUSTED'));
      expect(r.kind, UploadErrorClass.quotaBlocked);
    });

    test('Unavailable → retryable (transient, still loops)', () {
      final r = classifyUploadError(grpc.GrpcError.unavailable('backend down'));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('DeadlineExceeded → retryable', () {
      final r =
          classifyUploadError(grpc.GrpcError.deadlineExceeded('slow link'));
      expect(r.kind, UploadErrorClass.retryable);
    });

    test('FailedPrecondition → terminal', () {
      final r = classifyUploadError(
          grpc.GrpcError.failedPrecondition('unsupported codec'));
      expect(r.kind, UploadErrorClass.terminal);
    });
  });

  group('classifyUploadError — filesystem', () {
    // Incydent 2026-08-24: wiersz z nieistniejącym plikiem kręcił
    // "Wznawianie… próba 26" w nieskończoność — PathNotFoundException
    // spadał do gałęzi retryable. Po naprawie ścieżki kontenera brak
    // pliku jest nieodwracalny.
    test('PathNotFoundException → terminal z markerem source_file_missing',
        () {
      final c = classifyUploadError(const PathNotFoundException(
        '/var/mobile/.../Documents/sessions/x/chunk_00001.enc',
        OSError('No such file or directory', 2),
        'Cannot retrieve length of file',
      ));
      expect(c.kind, UploadErrorClass.terminal);
      expect(c.message, contains('source_file_missing'));
    });

    test('inne FileSystemException zostają retryable (dysk pełny itp.)', () {
      final c = classifyUploadError(const FileSystemException(
          'writeFrom failed', '/tmp/x', OSError('No space left', 28)));
      expect(c.kind, UploadErrorClass.retryable);
    });
  });

}
