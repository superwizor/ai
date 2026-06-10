// UploadWorker — drives a single PendingUpload forward by one phase.
//
// The worker is intentionally stateless and pure-ish: each `runOne`
// call is "given the current upload state, do whatever the next step
// is, return the new state". The runner (upload_queue_provider.dart)
// owns ticking and persistence.
//
// Design rules:
//   • One phase advance per call. Even a fresh `pending` upload only
//     advances to `created` in one call — the runner immediately
//     calls runOne again for the next phase. This keeps individual
//     calls short (single-RPC granularity) so cancel / app-pause /
//     network-blip can interrupt cleanly between phases.
//   • All side effects go through [UploadIo]. The worker never
//     touches Hive, gRPC, HTTP, or the filesystem directly.
//   • All thrown errors are classified via [classifyUploadError]
//     and folded into the returned PendingUpload state — runOne
//     itself never throws (modulo bugs in our own code, which
//     would be programmer errors and should surface).
//
// Phase map after Option F (feat/refactor-stt-architecture, 2026-05-25),
// with the durable on-device transcode step (fix/app-audio-conversion):
//
//   encrypting ─encryptSource─┐
//   converting ─convertSource─┼─► pending ─CreateAudioUpload─► created
//                             │                                   │
//                             │                  HTTP PUT ────────┘
//                             │                      ▼
//                             └──────────────►   completed
//
// `converting` is the entry phase for files the client transcodes on
// device (iPhone M4A→FLAC, WAV→16-bit PCM). `encrypting` is the entry
// phase for live recordings (raw FLAC → AES-256-GCM chunks). Both used
// to run inline on a screen before any durable row existed — moved
// behind the queue so they survive navigation / app-kill mid-work.
// Sources that need no on-device prep are enqueued straight into
// `pending` as before.
//
// The previous `uploaded` and `converted` intermediate phases are
// terminated immediately at PUT success — the server's in-process
// pull subscriber owns transcode + chunking + status flip from
// here. Old Hive rows that landed in `uploaded` / `converted`
// before the upgrade are walked to `completed` on the next tick
// without re-uploading (the GCS PUT either succeeded or the row
// would still be in `created`).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'pending_upload.dart';
import 'upload_error.dart';
import 'upload_io.dart';

typedef BackoffPolicy = Duration Function(int attempt);

/// Default backoff: min(60s × 2^attempt, 30 min) with ±25% jitter.
/// attempt=0 → ~60s, attempt=4 → ~16 min, attempt≥5 → 30 min ± jitter.
/// After the runner gives up retrying (e.g. 7-day max-age sweep)
/// we want a single retry cadence of ~30 min — by then a transient
/// network outage has either resolved or it's a real problem.
Duration defaultBackoff(int attempt) {
  final base = math.min(60 * (1 << attempt.clamp(0, 5)), 30 * 60);
  // ±25% jitter so a fleet of clients can't synchronise their
  // retry storm against a server outage.
  final jitter = (base * 0.25 * (math.Random().nextDouble() * 2 - 1)).toInt();
  final secs = (base + jitter).clamp(1, 60 * 60);
  return Duration(seconds: secs);
}

class UploadWorker {
  UploadWorker({
    required UploadIo io,
    DateTime Function()? clock,
    BackoffPolicy? backoff,
    int? maxAttemptsForTerminalClassError,
    Duration? putRetryCap,
  })  : _io = io,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _backoff = backoff ?? defaultBackoff,
        _terminalRetryCap = maxAttemptsForTerminalClassError ?? 1,
        _putRetryCap = putRetryCap ?? const Duration(seconds: 90);

  final UploadIo _io;
  final DateTime Function() _clock;
  final BackoffPolicy _backoff;
  /// Even when an error classifies as "terminal" we tolerate one
  /// attempt — this is the budget. Set to 1 so we surface the
  /// first terminal error to the user immediately; tests can bump
  /// it to assert behavior on subsequent attempts.
  // ignore: unused_field
  final int _terminalRetryCap;

  /// Backoff ceiling for retryable errors in the `created` (GCS PUT)
  /// phase. The exponential ladder exists to protect the *server* from
  /// RPC retry storms; a PUT fails when the phone's own link is down,
  /// so there is nothing to protect and the resumable session makes a
  /// retry nearly free. Without the cap a 127 MB transfer over flaky
  /// cellular escalates toward 8–30 min of idle per blip.
  final Duration _putRetryCap;

  /// Advances [u] by one phase. Always returns a new PendingUpload
  /// reflecting the outcome; never throws.
  ///
  /// [onUploadProgress] is invoked during the GCS PUT (resumable path) with a
  /// 0..1 fraction so the runner can surface a live progress bar. Transient —
  /// the runner holds it in memory, not in Hive (resume() recomputes the
  /// offset after an app-kill).
  Future<PendingUpload> runOne(
    PendingUpload u, {
    void Function(double)? onUploadProgress,
  }) async {
    if (u.isTerminal || u.isParked) return u;

    debugPrint('[upload-worker] runOne localId=${u.localId} '
        'phase=${u.phase.name} attempt=${u.attemptCount} '
        'kind=${u.sourceKind.name}');

    try {
      final PendingUpload next;
      switch (u.phase) {
        case UploadPhase.encrypting:
          next = await _doEncrypt(u);
          break;
        case UploadPhase.converting:
          next = await _doConvert(u);
          break;
        case UploadPhase.pending:
          next = await _doCreate(u);
          break;
        case UploadPhase.created:
          next = await _doUpload(u, onUploadProgress: onUploadProgress);
          break;
        case UploadPhase.uploaded:
        case UploadPhase.converted:
          // Option F (2026-05-25): legacy in-flight rows that
          // landed in `uploaded` / `converted` BEFORE the upgrade
          // would otherwise stall here — there are no convert /
          // complete handlers anymore. Treat as success: the GCS
          // PUT did finish (the only way to leave `created`), and
          // the server-side subscriber will pick up the object
          // notification independently of us. Run the source
          // cleanup hook and terminate.
          next = await _doFinalize(u);
          break;
        case UploadPhase.completed:
        case UploadPhase.failed:
        case UploadPhase.quotaBlocked:
          // Unreachable in practice (the isTerminal||isParked guard at
          // the top returns first), but keeps the switch exhaustive.
          return u;
      }
      debugPrint('[upload-worker] runOne localId=${u.localId} '
          '→ phase=${next.phase.name} '
          '${next.lastError != null ? "error=${next.lastError}" : ""}');
      return next;
    } catch (e, st) {
      // Defensive — runOne is supposed to be exception-safe via the
      // per-step handlers below. If we land here something genuinely
      // unexpected happened. Treat as retryable so the next tick
      // re-tries; surfacing it as terminal could hide our own bugs.
      debugPrint('[upload-worker] runOne unexpected: $e\n$st');
      return _scheduleRetry(u, 'unexpected: $e');
    }
  }

  // ── Phase handlers ────────────────────────────────────────────

  /// phase=encrypting → encrypt the raw recording into chunks, stamp the
  /// chunk count + plaintext size, advance to phase=pending. Durable: the
  /// raw FLAC lives in Documents storage, so an interrupted encrypt
  /// re-runs on the next tick. Transient I/O / key errors classify as
  /// retryable and keep the row in `encrypting`.
  Future<PendingUpload> _doEncrypt(PendingUpload u) async {
    try {
      final r = await _io.encryptSource(u);
      return u.copyWith(
        phase: UploadPhase.pending,
        sizeBytes: r.sizeBytes,
        chunkCount: r.chunkCount,
        attemptCount: 0,
        nextAttemptAt: _clock(), // due immediately for the create step
        clearLastError: true,
      );
    } catch (e) {
      return _classify(u, e);
    }
  }

  /// phase=converting → run the on-device transcode, repoint the
  /// source descriptor at the result, advance to phase=pending so the
  /// next runOne starts CreateAudioUpload. The transcode itself is
  /// durable: the row already lives in Hive and the staged source file
  /// survives app restarts, so an interrupted conversion simply re-runs
  /// on the next tick. convertSource only throws for transient/
  /// unexpected I/O errors (expected failures fall back to the original
  /// file internally) — those classify as retryable and keep the row in
  /// `converting` for another attempt.
  Future<PendingUpload> _doConvert(PendingUpload u) async {
    try {
      final r = await _io.convertSource(u);
      return u.copyWith(
        phase: UploadPhase.pending,
        sourcePath: r.sourcePath,
        contentType: r.contentType,
        sizeBytes: r.sizeBytes,
        needsServerSideConversion: r.needsServerSideConversion,
        attemptCount: 0,
        nextAttemptAt: _clock(), // due immediately for the create step
        clearLastError: true,
      );
    } catch (e) {
      return _classify(u, e);
    }
  }

  Future<PendingUpload> _doCreate(PendingUpload u) async {
    try {
      final res = await _io.createUpload(u);
      // Option E (2026-05-25): server returns session_id from this
      // point onward. Capture it immediately so the patient sessions
      // screen can resolve the new row (status=PENDING_UPLOAD) the
      // very next time it pulls ListSessions. Under Option F this
      // is the canonical session_id; no follow-up RPC ever returns
      // a different one.
      final newSessionId =
          res.sessionId.isNotEmpty ? res.sessionId : u.sessionId;
      return u.copyWith(
        phase: UploadPhase.created,
        uploadId: res.uploadId,
        signedUrl: res.signedUrl,
        sessionId: newSessionId,
        // Resumable upload (docs/26): carry the session URI onto the row so
        // putBytes resumes against it. Empty → null (single-PUT fallback).
        resumableSessionUri:
            res.resumableSessionUri.isNotEmpty ? res.resumableSessionUri : null,
        resumableExpiresAt: res.resumableExpiresAt,
        resumableChunkSize: res.resumableChunkSize,
        attemptCount: 0,
        clearLastError: true,
      );
    } catch (e) {
      return _classify(u, e);
    }
  }

  Future<PendingUpload> _doUpload(
    PendingUpload u, {
    void Function(double)? onUploadProgress,
  }) async {
    if (u.uploadId == null || u.signedUrl == null) {
      // Defensive — phase=created should always have these. If they're
      // gone, drop back to pending so the next tick re-creates.
      return u.copyWith(
        phase: UploadPhase.pending,
        lastError: 'invariant: uploadId/signedUrl missing in created phase',
      );
    }
    try {
      await _io.putBytes(u, onProgress: onUploadProgress);
      // Option F (2026-05-25): success at PUT is terminal-success
      // from the client's POV. The bucket notification + in-process
      // subscriber on ingestion-svc owns transcode / chunking /
      // status-flip from here. Clean up source material and mark
      // completed in the same step — no follow-up RPC, no
      // intermediate `uploaded` phase the runner has to advance
      // past.
      await _cleanupQuiet(u);
      return u.copyWith(
        phase: UploadPhase.completed,
        terminatedAt: _clock(),
        clearLastError: true,
      );
    } catch (e) {
      // The attempt failed but advanced the GCS resumable offset first
      // — the network works, just not reliably. Restart the backoff
      // ladder so the next try comes quickly; escalation is reserved
      // for attempts stuck at the same byte.
      if (e is UploadProgressMadeError) {
        return _classify(u.copyWith(attemptCount: 0), e.cause);
      }
      return _classify(u, e);
    }
  }

  /// Walk a legacy in-flight row (phase=uploaded or phase=converted,
  /// produced by a pre-Option-F build of the app) to phase=completed.
  /// The GCS PUT already landed; the server is independently driving
  /// finalize via the bucket notification.
  Future<PendingUpload> _doFinalize(PendingUpload u) async {
    await _cleanupQuiet(u);
    return u.copyWith(
      phase: UploadPhase.completed,
      terminatedAt: _clock(),
      clearLastError: true,
    );
  }

  // Source-cleanup is fire-and-forget. If purge fails (rare; disk full
  // while deleting?) we don't unwind — the row is already success.
  Future<void> _cleanupQuiet(PendingUpload u) async {
    try {
      await _io.cleanupSource(u);
    } catch (e) {
      debugPrint('[upload-worker] cleanupSource failed (ignored): $e');
    }
  }

  /// Public source-cleanup entry for the runner to call when a row is
  /// *discarded* (user dismiss / cancel) rather than completed. Same
  /// fire-and-forget semantics as the internal terminal-success cleanup
  /// and idempotent against an already-purged source, so it's safe even
  /// for a row whose PUT already cleaned up.
  Future<void> cleanupSource(PendingUpload u) => _cleanupQuiet(u);

  /// Startup hygiene delegate — see [UploadIo.pruneOrphanedSources].
  /// Never throws; returns 0 on failure.
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async {
    try {
      return await _io.pruneOrphanedSources(
        liveLocalIds: liveLocalIds,
        maxAge: maxAge,
      );
    } catch (e) {
      debugPrint('[upload-worker] pruneOrphanedSources failed (ignored): $e');
      return 0;
    }
  }

  // ── Error → retry classification ─────────────────────────────

  PendingUpload _classify(PendingUpload u, Object error) {
    final cls = classifyUploadError(error);
    switch (cls.kind) {
      case UploadErrorClass.terminal:
        return u.copyWith(
          phase: UploadPhase.failed,
          lastError: cls.message,
          terminatedAt: _clock(),
          attemptCount: u.attemptCount + 1,
        );

      case UploadErrorClass.signedUrlExpired:
        // Drop the expired credentials and bounce back to pending so
        // the next tick re-runs CreateAudioUpload with the same
        // idempotencyKey — server returns the original uploadId and
        // a fresh signedUrl.
        return u.copyWith(
          phase: UploadPhase.pending,
          clearUploadCredentials: true,
          attemptCount: u.attemptCount + 1,
          nextAttemptAt: _clock(), // due immediately
          lastError: cls.message,
        );

      case UploadErrorClass.quotaBlocked:
        // Park the row: no tokens, so no point retrying. We do NOT
        // bump nextAttemptAt into the future (the runner ignores
        // parked rows regardless via isParked) and we do NOT set
        // terminatedAt (the upload isn't dead — the user can resend
        // once the plan tops up). attemptCount is bumped so the UI
        // can still show how many tries it took to hit the wall.
        return u.copyWith(
          phase: UploadPhase.quotaBlocked,
          lastError: cls.message,
          attemptCount: u.attemptCount + 1,
        );

      case UploadErrorClass.retryable:
        return _scheduleRetry(u, cls.message);
    }
  }

  PendingUpload _scheduleRetry(PendingUpload u, String error) {
    final nextAttempt = u.attemptCount + 1;
    var delay = _backoff(nextAttempt);
    if (u.phase == UploadPhase.created && delay > _putRetryCap) {
      delay = _putRetryCap; // see _putRetryCap doc
    }
    final now = _clock();
    return u.copyWith(
      attemptCount: nextAttempt,
      nextAttemptAt: now.add(delay),
      lastError: error,
    );
  }
}
