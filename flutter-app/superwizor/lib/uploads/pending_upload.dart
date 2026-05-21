// PendingUpload — the durable record of one in-flight or queued
// audio upload. Survives app restarts via Hive (see UploadQueue);
// holds enough state to resume the 5-step ingestion pipeline from
// wherever it died.
//
// Two source shapes are supported, distinguished by [sourceKind]:
//
//   • encryptedChunks — live-recording path. The audio is on disk
//     as AES-256-GCM chunks under `<docs>/sessions/<sessionId>/`
//     (one chunk file per 1 MB, sealed by SecureAudioStorageService).
//     At upload time the worker decrypts all chunks to a single
//     temp file then PUTs it.
//
//   • plainFile — file-upload path. The user picked a file from
//     disk (or one of our client-side conversions produced one);
//     [sourcePath] points at it and the worker PUTs it directly.
//
// State machine (UploadPhase):
//
//   pending  ─CreateAudioUpload─► created  ─HTTP PUT─►  uploaded
//                                                          │
//                            ┌─────────────────────────────┘
//                            ▼
//                     needsConversion?
//                    ┌───────┴────────┐
//                   yes              no
//                    │                │
//                    ▼                ▼
//              ConvertAudio    CompleteAudioUpload
//                    │                │
//                    ▼                ▼
//                converted ─Complete─► completed (terminal-success)
//
// Failures route to `failed` (terminal-failure) only for
// non-retryable errors. Retryable errors stay in the current phase
// with attemptCount+1 and nextAttemptAt set by the worker's
// backoff policy.

import 'dart:convert';

enum UploadSourceKind {
  /// Encrypted chunks directory; needs decryption at upload time.
  encryptedChunks,

  /// Single plaintext file at sourcePath; uploaded as-is.
  plainFile,
}

enum UploadPhase {
  /// Newly queued. CreateAudioUpload has not been called.
  pending,

  /// CreateAudioUpload returned an uploadId + signedUrl. The signed
  /// URL is short-lived (typically 1h); on resume we may need to
  /// refresh by calling CreateAudioUpload again with the same
  /// idempotency key — server returns the existing uploadId + fresh URL.
  created,

  /// All bytes are on GCS. Next step is ConvertAudio (if needed) or
  /// CompleteAudioUpload (if Chirp-native).
  uploaded,

  /// Server-side ConvertAudio succeeded. Only reached when the
  /// original content_type wasn't Chirp-native (MP3, WMA, etc).
  converted,

  /// CompleteAudioUpload succeeded; the STT pipeline has been
  /// triggered. Terminal-success — the row is kept briefly so the
  /// UI can render "uploaded ✓" then removed.
  completed,

  /// Terminal-failure (non-retryable server error, max retries, or
  /// max-age sweep). The row remains until the user dismisses it
  /// from the queue list view so they can see the error and decide
  /// whether to retry manually or give up.
  failed,
}

class PendingUpload {
  /// Local UUID; the queue's primary key. Stable across retries so
  /// the UI can track one row through its phases.
  final String localId;

  // ── Audit / scoping ───────────────────────────────────────────
  final String therapistId;
  final String patientFileId;
  final String patientLanguageCode; // BCP47, e.g. 'pl-PL'

  // ── Source data ───────────────────────────────────────────────
  final UploadSourceKind sourceKind;
  /// For encryptedChunks: the per-session directory containing
  /// chunk_NNNNN.enc files (e.g. `<docs>/sessions/<sessionId>/`).
  /// For plainFile: the absolute path to the single file to upload.
  final String sourcePath;
  final String contentType; // MIME at upload time, e.g. 'audio/flac'
  final int sizeBytes; // plaintext size
  final int chunkCount; // 1 for plainFile; N for encryptedChunks
  final int actualDurationSeconds;
  final bool needsServerSideConversion;

  // ── Pipeline state ────────────────────────────────────────────
  final UploadPhase phase;
  final String? uploadId; // populated after CreateAudioUpload
  final String? signedUrl; // populated after CreateAudioUpload; may expire
  /// Session ID — used as the CreateAudioUpload idempotencyKey so
  /// a retry of step 1 returns the same uploadId + a fresh URL
  /// rather than creating a duplicate audio_uploads row.
  final String idempotencyKey;
  final String? sessionId; // populated after CompleteAudioUpload

  // ── Retry bookkeeping ─────────────────────────────────────────
  final int attemptCount;
  final DateTime queuedAt; // UTC
  final DateTime nextAttemptAt; // UTC; <= now means "due"
  final String? lastError;

  // ── Termination ───────────────────────────────────────────────
  /// Set when phase becomes completed or failed; used by the
  /// 7-day max-age sweeper.
  final DateTime? terminatedAt;

  const PendingUpload({
    required this.localId,
    required this.therapistId,
    required this.patientFileId,
    required this.patientLanguageCode,
    required this.sourceKind,
    required this.sourcePath,
    required this.contentType,
    required this.sizeBytes,
    required this.chunkCount,
    required this.actualDurationSeconds,
    required this.needsServerSideConversion,
    required this.phase,
    required this.idempotencyKey,
    required this.queuedAt,
    required this.nextAttemptAt,
    this.uploadId,
    this.signedUrl,
    this.sessionId,
    this.attemptCount = 0,
    this.lastError,
    this.terminatedAt,
  });

  /// Convenience: a "just enqueued" upload waiting for its first
  /// attempt right now. Sets phase=pending, attemptCount=0, and
  /// nextAttemptAt=queuedAt so the runner picks it up immediately.
  factory PendingUpload.initial({
    required String localId,
    required String therapistId,
    required String patientFileId,
    required String patientLanguageCode,
    required UploadSourceKind sourceKind,
    required String sourcePath,
    required String contentType,
    required int sizeBytes,
    required int chunkCount,
    required int actualDurationSeconds,
    required bool needsServerSideConversion,
    required String idempotencyKey,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    return PendingUpload(
      localId: localId,
      therapistId: therapistId,
      patientFileId: patientFileId,
      patientLanguageCode: patientLanguageCode,
      sourceKind: sourceKind,
      sourcePath: sourcePath,
      contentType: contentType,
      sizeBytes: sizeBytes,
      chunkCount: chunkCount,
      actualDurationSeconds: actualDurationSeconds,
      needsServerSideConversion: needsServerSideConversion,
      phase: UploadPhase.pending,
      idempotencyKey: idempotencyKey,
      queuedAt: nowUtc,
      nextAttemptAt: nowUtc,
    );
  }

  PendingUpload copyWith({
    UploadPhase? phase,
    String? uploadId,
    String? signedUrl,
    String? sessionId,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? lastError,
    DateTime? terminatedAt,
    bool clearLastError = false,
    bool? needsServerSideConversion,
  }) {
    return PendingUpload(
      localId: localId,
      therapistId: therapistId,
      patientFileId: patientFileId,
      patientLanguageCode: patientLanguageCode,
      sourceKind: sourceKind,
      sourcePath: sourcePath,
      contentType: contentType,
      sizeBytes: sizeBytes,
      chunkCount: chunkCount,
      actualDurationSeconds: actualDurationSeconds,
      needsServerSideConversion:
          needsServerSideConversion ?? this.needsServerSideConversion,
      phase: phase ?? this.phase,
      uploadId: uploadId ?? this.uploadId,
      signedUrl: signedUrl ?? this.signedUrl,
      sessionId: sessionId ?? this.sessionId,
      idempotencyKey: idempotencyKey,
      queuedAt: queuedAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      terminatedAt: terminatedAt ?? this.terminatedAt,
    );
  }

  bool get isTerminal =>
      phase == UploadPhase.completed || phase == UploadPhase.failed;
  bool get isDue =>
      !isTerminal && nextAttemptAt.isBefore(DateTime.now().toUtc());
  bool isOlderThan(Duration d, DateTime now) =>
      now.toUtc().difference(queuedAt) > d;

  // ── JSON ──────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'localId': localId,
        'therapistId': therapistId,
        'patientFileId': patientFileId,
        'patientLanguageCode': patientLanguageCode,
        'sourceKind': sourceKind.name,
        'sourcePath': sourcePath,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'chunkCount': chunkCount,
        'actualDurationSeconds': actualDurationSeconds,
        'needsServerSideConversion': needsServerSideConversion,
        'phase': phase.name,
        'uploadId': uploadId,
        'signedUrl': signedUrl,
        'idempotencyKey': idempotencyKey,
        'sessionId': sessionId,
        'attemptCount': attemptCount,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'nextAttemptAt': nextAttemptAt.toUtc().toIso8601String(),
        'lastError': lastError,
        'terminatedAt': terminatedAt?.toUtc().toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory PendingUpload.fromJson(Map<String, dynamic> j) => PendingUpload(
        localId: j['localId'] as String,
        therapistId: j['therapistId'] as String,
        patientFileId: j['patientFileId'] as String,
        patientLanguageCode: j['patientLanguageCode'] as String? ?? '',
        sourceKind: _parseSourceKind(j['sourceKind']),
        sourcePath: j['sourcePath'] as String,
        contentType: j['contentType'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        chunkCount: (j['chunkCount'] as num?)?.toInt() ?? 1,
        actualDurationSeconds:
            (j['actualDurationSeconds'] as num?)?.toInt() ?? 0,
        needsServerSideConversion:
            j['needsServerSideConversion'] as bool? ?? false,
        phase: _parsePhase(j['phase']),
        uploadId: j['uploadId'] as String?,
        signedUrl: j['signedUrl'] as String?,
        idempotencyKey: j['idempotencyKey'] as String,
        sessionId: j['sessionId'] as String?,
        attemptCount: (j['attemptCount'] as num?)?.toInt() ?? 0,
        queuedAt: DateTime.parse(j['queuedAt'] as String).toUtc(),
        nextAttemptAt: DateTime.parse(j['nextAttemptAt'] as String).toUtc(),
        lastError: j['lastError'] as String?,
        terminatedAt: (j['terminatedAt'] as String?) == null
            ? null
            : DateTime.parse(j['terminatedAt'] as String).toUtc(),
      );

  static UploadPhase _parsePhase(Object? raw) {
    final s = raw?.toString();
    for (final p in UploadPhase.values) {
      if (p.name == s) return p;
    }
    return UploadPhase.pending;
  }

  static UploadSourceKind _parseSourceKind(Object? raw) {
    final s = raw?.toString();
    for (final k in UploadSourceKind.values) {
      if (k.name == s) return k;
    }
    return UploadSourceKind.plainFile;
  }
}
