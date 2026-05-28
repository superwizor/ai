// PendingUpload model tests — serialization, state machine, and
// security-critical field handling.
//
// Covers:
//   - toJson / fromJson round-trip for all fields
//   - F-13 signedUrl exclusion from JSON
//   - Phase transitions and terminal detection
//   - Initial factory correctness
//   - copyWith semantics (especially credential clearing)
//   - Time-based operations (isOlderThan, isDue)
//   - Source kind parsing and default fallbacks
//   - JSON backward compatibility (missing fields)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:superwizor/uploads/pending_upload.dart';

void main() {
  // Helper to create a standard PendingUpload for tests
  PendingUpload _makeUpload({
    UploadPhase phase = UploadPhase.pending,
    String? signedUrl,
    String? uploadId,
    String? sessionId,
    int attemptCount = 0,
    DateTime? terminatedAt,
  }) {
    return PendingUpload(
      localId: 'local-001',
      therapistId: 'therapist-abc',
      patientFileId: 'patient-xyz',
      patientLanguageCode: 'pl-PL',
      sourceKind: UploadSourceKind.encryptedChunks,
      sourcePath: '/sessions/session-123/',
      contentType: 'audio/flac',
      sizeBytes: 2097152,
      chunkCount: 3,
      actualDurationSeconds: 900,
      needsServerSideConversion: false,
      phase: phase,
      idempotencyKey: 'idem-key-abc',
      queuedAt: DateTime.utc(2026, 5, 28, 10, 0),
      nextAttemptAt: DateTime.utc(2026, 5, 28, 10, 5),
      uploadId: uploadId,
      signedUrl: signedUrl,
      sessionId: sessionId,
      attemptCount: attemptCount,
      terminatedAt: terminatedAt,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // JSON serialization round-trip
  // ────────────────────────────────────────────────────────────────

  group('toJson / fromJson round-trip', () {
    test('all fields preserved (except signedUrl)', () {
      final upload = _makeUpload(
        phase: UploadPhase.created,
        uploadId: 'upload-123',
        sessionId: 'session-456',
        attemptCount: 3,
      );
      final json = upload.toJson();
      final restored = PendingUpload.fromJson(json);

      expect(restored.localId, 'local-001');
      expect(restored.therapistId, 'therapist-abc');
      expect(restored.patientFileId, 'patient-xyz');
      expect(restored.patientLanguageCode, 'pl-PL');
      expect(restored.sourceKind, UploadSourceKind.encryptedChunks);
      expect(restored.sourcePath, '/sessions/session-123/');
      expect(restored.contentType, 'audio/flac');
      expect(restored.sizeBytes, 2097152);
      expect(restored.chunkCount, 3);
      expect(restored.actualDurationSeconds, 900);
      expect(restored.needsServerSideConversion, false);
      expect(restored.phase, UploadPhase.created);
      expect(restored.idempotencyKey, 'idem-key-abc');
      expect(restored.uploadId, 'upload-123');
      expect(restored.sessionId, 'session-456');
      expect(restored.attemptCount, 3);
      expect(restored.queuedAt, DateTime.utc(2026, 5, 28, 10, 0));
      expect(restored.nextAttemptAt, DateTime.utc(2026, 5, 28, 10, 5));
    });

    test('toJson produces valid JSON string', () {
      final upload = _makeUpload();
      final jsonStr = upload.toJsonString();
      expect(() => jsonDecode(jsonStr), returnsNormally);
    });

    test('all UploadPhase values survive round-trip', () {
      for (final phase in UploadPhase.values) {
        final upload = _makeUpload(phase: phase);
        final json = upload.toJson();
        final restored = PendingUpload.fromJson(json);
        expect(restored.phase, phase,
            reason: 'Phase ${phase.name} must survive round-trip');
      }
    });

    test('both UploadSourceKind values survive round-trip', () {
      for (final kind in UploadSourceKind.values) {
        final upload = PendingUpload(
          localId: 'test',
          therapistId: 'test',
          patientFileId: 'test',
          patientLanguageCode: 'en-US',
          sourceKind: kind,
          sourcePath: '/test',
          contentType: 'audio/flac',
          sizeBytes: 100,
          chunkCount: 1,
          actualDurationSeconds: 60,
          needsServerSideConversion: false,
          phase: UploadPhase.pending,
          idempotencyKey: 'test',
          queuedAt: DateTime.utc(2026),
          nextAttemptAt: DateTime.utc(2026),
        );
        final json = upload.toJson();
        final restored = PendingUpload.fromJson(json);
        expect(restored.sourceKind, kind);
      }
    });

    test('terminatedAt survives round-trip when set', () {
      final now = DateTime.utc(2026, 5, 28, 15, 30);
      final upload = _makeUpload(terminatedAt: now);
      final json = upload.toJson();
      final restored = PendingUpload.fromJson(json);
      expect(restored.terminatedAt, now);
    });

    test('terminatedAt is null when not set', () {
      final upload = _makeUpload();
      final json = upload.toJson();
      final restored = PendingUpload.fromJson(json);
      expect(restored.terminatedAt, isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-13: signedUrl security
  // ────────────────────────────────────────────────────────────────

  group('F-13 signedUrl not persisted', () {
    test('signedUrl absent from toJson output', () {
      final upload = _makeUpload(
        signedUrl:
            'https://storage.googleapis.com/bucket/obj?X-Goog-Signature=SENSITIVE',
      );
      final json = upload.toJson();
      expect(json.containsKey('signedUrl'), isFalse,
          reason: 'signedUrl contains a credential — must never be persisted');
    });

    test('signedUrl null after fromJson (even if injected)', () {
      final json = _makeUpload().toJson();
      // Simulate old Hive rows that still had signedUrl
      json['signedUrl'] = 'https://leak.com/secret';
      final restored = PendingUpload.fromJson(json);
      expect(restored.signedUrl, isNull,
          reason: 'fromJson must ignore signedUrl even if present in JSON');
    });

    test('signedUrl accessible in-memory before serialization', () {
      final upload = _makeUpload(
        signedUrl: 'https://storage.googleapis.com/bucket/obj',
      );
      expect(upload.signedUrl, isNotNull,
          reason: 'signedUrl must be available in-memory for the current session');
    });
  });

  // ────────────────────────────────────────────────────────────────
  // PendingUpload.initial factory
  // ────────────────────────────────────────────────────────────────

  group('PendingUpload.initial factory', () {
    test('creates pending phase upload', () {
      final now = DateTime.utc(2026, 5, 28, 12, 0);
      final upload = PendingUpload.initial(
        localId: 'new-local',
        therapistId: 'therapist-1',
        patientFileId: 'patient-1',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.encryptedChunks,
        sourcePath: '/sessions/s1/',
        contentType: 'audio/flac',
        sizeBytes: 1024,
        chunkCount: 1,
        actualDurationSeconds: 300,
        needsServerSideConversion: false,
        idempotencyKey: 'idem-1',
        now: now,
      );

      expect(upload.phase, UploadPhase.pending);
      expect(upload.attemptCount, 0);
      expect(upload.queuedAt, now.toUtc());
      expect(upload.nextAttemptAt, now.toUtc(),
          reason: 'Initial upload should be due immediately');
    });

    test('queuedAt is normalized to UTC', () {
      final localTime = DateTime(2026, 5, 28, 14, 0); // local timezone
      final upload = PendingUpload.initial(
        localId: 'test',
        therapistId: 'test',
        patientFileId: 'test',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '/file.wav',
        contentType: 'audio/wav',
        sizeBytes: 100,
        chunkCount: 1,
        actualDurationSeconds: 60,
        needsServerSideConversion: true,
        idempotencyKey: 'idem',
        now: localTime,
      );

      expect(upload.queuedAt.isUtc, isTrue);
      expect(upload.nextAttemptAt.isUtc, isTrue);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // copyWith semantics
  // ────────────────────────────────────────────────────────────────

  group('copyWith', () {
    test('preserves all fields when no args passed', () {
      final original = _makeUpload(
        phase: UploadPhase.created,
        uploadId: 'upload-1',
        signedUrl: 'https://url.com',
        sessionId: 'session-1',
        attemptCount: 5,
      );
      final copy = original.copyWith();

      expect(copy.localId, original.localId);
      expect(copy.phase, original.phase);
      expect(copy.uploadId, original.uploadId);
      expect(copy.signedUrl, original.signedUrl);
      expect(copy.sessionId, original.sessionId);
      expect(copy.attemptCount, original.attemptCount);
    });

    test('clearUploadCredentials clears uploadId AND signedUrl', () {
      final upload = _makeUpload(
        uploadId: 'upload-123',
        signedUrl: 'https://secret.com',
      );
      final cleared = upload.copyWith(clearUploadCredentials: true);

      expect(cleared.uploadId, isNull);
      expect(cleared.signedUrl, isNull);
    });

    test('clearLastError nullifies lastError', () {
      final upload = PendingUpload(
        localId: 'test',
        therapistId: 'test',
        patientFileId: 'test',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '/test',
        contentType: 'audio/wav',
        sizeBytes: 100,
        chunkCount: 1,
        actualDurationSeconds: 60,
        needsServerSideConversion: false,
        phase: UploadPhase.pending,
        idempotencyKey: 'test',
        queuedAt: DateTime.utc(2026),
        nextAttemptAt: DateTime.utc(2026),
        lastError: 'some error',
      );
      final cleared = upload.copyWith(clearLastError: true);
      expect(cleared.lastError, isNull);
    });

    test('phase transition via copyWith', () {
      final upload = _makeUpload(phase: UploadPhase.pending);
      final transitioned = upload.copyWith(phase: UploadPhase.created);
      expect(transitioned.phase, UploadPhase.created);
      expect(upload.phase, UploadPhase.pending,
          reason: 'Original must be immutable');
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Terminal detection
  // ────────────────────────────────────────────────────────────────

  group('isTerminal', () {
    test('completed is terminal', () {
      expect(_makeUpload(phase: UploadPhase.completed).isTerminal, isTrue);
    });

    test('failed is terminal', () {
      expect(_makeUpload(phase: UploadPhase.failed).isTerminal, isTrue);
    });

    test('pending is not terminal', () {
      expect(_makeUpload(phase: UploadPhase.pending).isTerminal, isFalse);
    });

    test('created is not terminal', () {
      expect(_makeUpload(phase: UploadPhase.created).isTerminal, isFalse);
    });

    test('uploaded is not terminal', () {
      expect(_makeUpload(phase: UploadPhase.uploaded).isTerminal, isFalse);
    });

    test('converted is not terminal', () {
      expect(_makeUpload(phase: UploadPhase.converted).isTerminal, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Time-based operations
  // ────────────────────────────────────────────────────────────────

  group('Time-based operations', () {
    test('isOlderThan returns true for old uploads', () {
      final upload = PendingUpload(
        localId: 'old',
        therapistId: 'test',
        patientFileId: 'test',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '/test',
        contentType: 'audio/wav',
        sizeBytes: 100,
        chunkCount: 1,
        actualDurationSeconds: 60,
        needsServerSideConversion: false,
        phase: UploadPhase.pending,
        idempotencyKey: 'test',
        queuedAt: DateTime.utc(2026, 5, 1), // 27 days ago
        nextAttemptAt: DateTime.utc(2026, 5, 1),
      );

      final now = DateTime.utc(2026, 5, 28);
      expect(upload.isOlderThan(const Duration(days: 7), now), isTrue);
    });

    test('isOlderThan returns false for recent uploads', () {
      final now = DateTime.utc(2026, 5, 28, 12, 0);
      final upload = PendingUpload(
        localId: 'recent',
        therapistId: 'test',
        patientFileId: 'test',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '/test',
        contentType: 'audio/wav',
        sizeBytes: 100,
        chunkCount: 1,
        actualDurationSeconds: 60,
        needsServerSideConversion: false,
        phase: UploadPhase.pending,
        idempotencyKey: 'test',
        queuedAt: now.subtract(const Duration(hours: 1)),
        nextAttemptAt: now,
      );

      expect(upload.isOlderThan(const Duration(days: 7), now), isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Backward compatibility — missing JSON fields
  // ────────────────────────────────────────────────────────────────

  group('JSON backward compatibility', () {
    test('missing patientLanguageCode defaults to empty string', () {
      final json = _makeUpload().toJson();
      json.remove('patientLanguageCode');
      final restored = PendingUpload.fromJson(json);
      expect(restored.patientLanguageCode, '');
    });

    test('missing chunkCount defaults to 1', () {
      final json = _makeUpload().toJson();
      json.remove('chunkCount');
      final restored = PendingUpload.fromJson(json);
      expect(restored.chunkCount, 1);
    });

    test('missing actualDurationSeconds defaults to 0', () {
      final json = _makeUpload().toJson();
      json.remove('actualDurationSeconds');
      final restored = PendingUpload.fromJson(json);
      expect(restored.actualDurationSeconds, 0);
    });

    test('missing needsServerSideConversion defaults to false', () {
      final json = _makeUpload().toJson();
      json.remove('needsServerSideConversion');
      final restored = PendingUpload.fromJson(json);
      expect(restored.needsServerSideConversion, false);
    });

    test('missing attemptCount defaults to 0', () {
      final json = _makeUpload().toJson();
      json.remove('attemptCount');
      final restored = PendingUpload.fromJson(json);
      expect(restored.attemptCount, 0);
    });

    test('unknown phase string defaults to pending', () {
      final json = _makeUpload().toJson();
      json['phase'] = 'nonexistent_phase';
      final restored = PendingUpload.fromJson(json);
      expect(restored.phase, UploadPhase.pending);
    });

    test('unknown sourceKind defaults to plainFile', () {
      final json = _makeUpload().toJson();
      json['sourceKind'] = 'futureSourceKind';
      final restored = PendingUpload.fromJson(json);
      expect(restored.sourceKind, UploadSourceKind.plainFile);
    });
  });
}
