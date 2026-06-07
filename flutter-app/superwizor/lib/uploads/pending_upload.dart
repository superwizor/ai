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
  /// Needs on-device transcoding before anything else (iPhone M4A/MP4/
  /// AAC → FLAC, or WAV → 16-bit PCM normalization). The worker runs
  /// UploadIo.convertSource, rewrites the source descriptor (path,
  /// contentType, sizeBytes) in place, then advances to `pending`.
  ///
  /// CRITICAL — this phase is why the row is enqueued *before*
  /// conversion runs. Conversion used to happen inline on
  /// NewSessionScreen before any durable row existed, so backing out
  /// of the "Konwertuję" screen (or an app-kill / OS cache purge mid-
  /// convert) silently dropped the whole session. Now the durable row
  /// exists from the moment the user picks the file; conversion is a
  /// resumable worker step and the pill keeps tracking it even if the
  /// user leaves the screen. See docs/11_IPHONE_AUDIO_CONVERSION.md.
  converting,

  /// Live-recording path only: the raw FLAC the recorder wrote at
  /// `<docs>/sessions/<sessionId>/raw.flac` still needs encrypting into
  /// AES-256-GCM `chunk_*.enc` files before upload. The worker runs
  /// UploadIo.encryptSource, then advances to `pending`.
  ///
  /// Same durability rationale as `converting`: encryption used to run
  /// inline on RecordingScreen (a multi-step, multi-second operation on
  /// a 60-min recording) BEFORE any durable row existed, behind a bare
  /// spinner with no label — so "send to analysis" then leaving the
  /// screen could lose the whole session. Now the row is enqueued the
  /// instant recording stops; encryption is a resumable worker step and
  /// the kartoteka + pending-uploads pill track it. The raw FLAC lives
  /// in durable Documents storage, so an interrupted encrypt re-runs on
  /// the next tick.
  encrypting,

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

  /// Quota hold (feat/tokens-exhausted, 2026-05-30). CreateAudioUpload
  /// returned gRPC ResourceExhausted / QUOTA_EXHAUSTED — the org ran
  /// out of tokens. Unlike `failed` this is RESUMABLE, and unlike a
  /// retryable error we do NOT auto-retry: the audio is parked
  /// indefinitely until the therapist explicitly resends (after the
  /// plan renews / tops up) or cancels the session. Parking — not
  /// looping — is the contract: see [isParked]. The row survives
  /// restarts (it's just another phase persisted to Hive) and is
  /// exempt from the cold-start backoff reset and the max-age sweep.
  quotaBlocked,
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
  /// Populated at phase=created (Option E, 2026-05-25). Pre-Option-E
  /// servers don't return session_id in CreateAudioUploadResponse;
  /// against those, this stays NULL until phase=completed.
  final String? sessionId;

  // ── Resumable upload (docs/26) ────────────────────────────────
  /// GCS resumable session URI. When present the worker PUTs byte-range
  /// chunks here and resumes from the GCS-acked offset (queried live, so
  /// it survives app-kill) instead of restarting the whole object. Null →
  /// legacy single PUT to [signedUrl].
  final String? resumableSessionUri;
  final DateTime? resumableExpiresAt;
  /// Server-recommended chunk size in bytes; 0 → client default (8 MiB).
  final int resumableChunkSize;

  /// Live upload fraction (0..1) during the PUT. TRANSIENT — held in memory
  /// by the runner and overlaid onto emitted snapshots for the progress bar;
  /// deliberately NOT persisted to Hive (resume() recomputes the real offset
  /// after an app-kill, so a persisted value would be misleading).
  final double uploadProgress;

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
    this.resumableSessionUri,
    this.resumableExpiresAt,
    this.resumableChunkSize = 0,
    this.uploadProgress = 0.0,
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
    String? resumableSessionUri,
    DateTime? resumableExpiresAt,
    int? resumableChunkSize,
    double? uploadProgress,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? lastError,
    DateTime? terminatedAt,
    bool clearLastError = false,
    bool clearUploadCredentials = false,
    bool? needsServerSideConversion,
    // Source-descriptor rewrites — only the `converting` phase uses
    // these. The on-device transcode produces a NEW file (e.g. the
    // FLAC that replaces the picked M4A), so the worker must be able
    // to repoint sourcePath / contentType / sizeBytes at it once
    // convertSource returns. Every other transition leaves the
    // descriptor untouched (these stay null → fall through to `this`).
    String? sourcePath,
    String? contentType,
    int? sizeBytes,
    int? actualDurationSeconds,
    int? chunkCount,
  }) {
    return PendingUpload(
      localId: localId,
      therapistId: therapistId,
      patientFileId: patientFileId,
      patientLanguageCode: patientLanguageCode,
      sourceKind: sourceKind,
      sourcePath: sourcePath ?? this.sourcePath,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      chunkCount: chunkCount ?? this.chunkCount,
      actualDurationSeconds:
          actualDurationSeconds ?? this.actualDurationSeconds,
      needsServerSideConversion:
          needsServerSideConversion ?? this.needsServerSideConversion,
      phase: phase ?? this.phase,
      uploadId: clearUploadCredentials ? null : (uploadId ?? this.uploadId),
      signedUrl:
          clearUploadCredentials ? null : (signedUrl ?? this.signedUrl),
      sessionId: sessionId ?? this.sessionId,
      // A re-create (clearUploadCredentials) re-issues the resumable session
      // too — drop the stale URI so the worker doesn't PUT to a dead session.
      resumableSessionUri: clearUploadCredentials
          ? null
          : (resumableSessionUri ?? this.resumableSessionUri),
      resumableExpiresAt: clearUploadCredentials
          ? null
          : (resumableExpiresAt ?? this.resumableExpiresAt),
      resumableChunkSize: resumableChunkSize ?? this.resumableChunkSize,
      uploadProgress: uploadProgress ?? this.uploadProgress,
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

  /// Parked on a quota hold. Not terminal (the user can resend), but
  /// the runner must never auto-advance it — no ticks, no cold-start
  /// backoff reset, no max-age prune. Only an explicit resend
  /// (un-parks → pending) or cancel (removes the row) moves it.
  bool get isParked => phase == UploadPhase.quotaBlocked;

  bool get isDue =>
      !isTerminal &&
      !isParked &&
      nextAttemptAt.isBefore(DateTime.now().toUtc());
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
        'resumableSessionUri': resumableSessionUri,
        'resumableExpiresAt': resumableExpiresAt?.toUtc().toIso8601String(),
        'resumableChunkSize': resumableChunkSize,
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
        resumableSessionUri: j['resumableSessionUri'] as String?,
        resumableExpiresAt: (j['resumableExpiresAt'] as String?) == null
            ? null
            : DateTime.parse(j['resumableExpiresAt'] as String).toUtc(),
        resumableChunkSize: (j['resumableChunkSize'] as num?)?.toInt() ?? 0,
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
