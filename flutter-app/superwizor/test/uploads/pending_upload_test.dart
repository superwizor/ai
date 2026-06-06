// PendingUpload round-trip tests. Locks the JSON shape so a stale
// row from an older app version doesn't blow up fromJson, and so
// adding a field forces explicit toJson/fromJson coverage.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/uploads/pending_upload.dart';

PendingUpload _sample() => PendingUpload(
      localId: 'local-1',
      therapistId: 'th-1',
      patientFileId: 'pf-1',
      patientLanguageCode: 'pl-PL',
      sourceKind: UploadSourceKind.encryptedChunks,
      sourcePath: '/var/.../sessions/s-1',
      contentType: 'audio/flac',
      sizeBytes: 1234567,
      chunkCount: 3,
      actualDurationSeconds: 1800,
      needsServerSideConversion: false,
      phase: UploadPhase.created,
      idempotencyKey: 'idem-1',
      uploadId: 'au-1',
      signedUrl: 'https://example.com/signed',
      sessionId: null,
      resumableSessionUri: 'https://storage.googleapis.com/upload/...session',
      resumableExpiresAt: DateTime.utc(2026, 5, 27, 19, 0, 0),
      resumableChunkSize: 8 * 1024 * 1024,
      attemptCount: 2,
      queuedAt: DateTime.utc(2026, 5, 20, 19, 0, 0),
      nextAttemptAt: DateTime.utc(2026, 5, 20, 19, 5, 0),
      lastError: 'gRPC UNAVAILABLE',
    );

void main() {
  group('PendingUpload', () {
    test('JSON round-trip preserves all fields', () {
      final original = _sample();
      final encoded = jsonEncode(original.toJson());
      final decoded =
          PendingUpload.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.localId, original.localId);
      expect(decoded.therapistId, original.therapistId);
      expect(decoded.sourceKind, UploadSourceKind.encryptedChunks);
      expect(decoded.phase, UploadPhase.created);
      expect(decoded.uploadId, 'au-1');
      expect(decoded.signedUrl, 'https://example.com/signed');
      expect(decoded.attemptCount, 2);
      expect(decoded.queuedAt.toUtc(), original.queuedAt.toUtc());
      expect(decoded.nextAttemptAt.toUtc(), original.nextAttemptAt.toUtc());
      expect(decoded.lastError, 'gRPC UNAVAILABLE');
      // Resumable upload (docs/26) fields round-trip.
      expect(decoded.resumableSessionUri, original.resumableSessionUri);
      expect(decoded.resumableExpiresAt?.toUtc(),
          original.resumableExpiresAt?.toUtc());
      expect(decoded.resumableChunkSize, 8 * 1024 * 1024);
      expect((jsonDecode(encoded) as Map).length, 24,
          reason:
              'field-count guard — add toJson/fromJson coverage for new fields');
    });

    test('initial() sets phase=pending and due-now nextAttemptAt', () {
      final now = DateTime.utc(2026, 5, 20, 12, 0, 0);
      final u = PendingUpload.initial(
        localId: 'l',
        therapistId: 't',
        patientFileId: 'p',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '/x',
        contentType: 'audio/flac',
        sizeBytes: 1,
        chunkCount: 1,
        actualDurationSeconds: 0,
        needsServerSideConversion: false,
        idempotencyKey: 'idem',
        now: now,
      );
      expect(u.phase, UploadPhase.pending);
      expect(u.attemptCount, 0);
      expect(u.queuedAt.toUtc(), now.toUtc());
      expect(u.nextAttemptAt.toUtc(), now.toUtc());
    });

    test('copyWith preserves untouched fields', () {
      final u = _sample().copyWith(phase: UploadPhase.uploaded);
      expect(u.phase, UploadPhase.uploaded);
      expect(u.uploadId, 'au-1');
      expect(u.signedUrl, 'https://example.com/signed');
      expect(u.attemptCount, 2);
    });

    test('copyWith(clearLastError: true) wipes the error message', () {
      final u = _sample().copyWith(clearLastError: true);
      expect(u.lastError, isNull);
    });

    test('isTerminal true only for completed and failed', () {
      for (final p in UploadPhase.values) {
        final u = _sample().copyWith(phase: p);
        expect(
          u.isTerminal,
          p == UploadPhase.completed || p == UploadPhase.failed,
          reason: 'phase=$p',
        );
      }
    });

    test('isOlderThan respects queuedAt vs now', () {
      final u = _sample(); // queuedAt = 2026-05-20T19:00:00Z
      expect(u.isOlderThan(const Duration(days: 1),
          DateTime.utc(2026, 5, 22, 0, 0, 0)), isTrue);
      expect(u.isOlderThan(const Duration(days: 30),
          DateTime.utc(2026, 5, 22, 0, 0, 0)), isFalse);
    });

    test('unknown phase / sourceKind strings degrade gracefully', () {
      final j = _sample().toJson();
      j['phase'] = 'bogus_phase_added_in_v2';
      j['sourceKind'] = 'bogus_source_kind';
      final decoded = PendingUpload.fromJson(j);
      expect(decoded.phase, UploadPhase.pending,
          reason: 'unknown phase strings fall back to pending');
      expect(decoded.sourceKind, UploadSourceKind.plainFile,
          reason: 'unknown source-kind falls back to plainFile');
    });
  });
}
