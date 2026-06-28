// RecordingRecoveryService — startup scan for orphaned recordings
// (docs/28 WS1).
//
// An "orphan" is a `<docs>/sessions/<id>/` directory holding a
// manifest.json + raw.flac whose session never reached the durable
// upload queue — the signature of the app dying mid-recording (the
// classic case: therapist answers a phone call, the backgrounded app is
// killed by the OS). The scan runs once per cold launch after sign-in;
// hits are offered to the user as "Znaleziono przerwane nagranie" with
// send / later / delete actions.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_runner.dart';
import 'recording_manifest_store.dart';
import 'recording_service.dart';

class RecoverableRecording {
  final RecordingManifest manifest;
  final String flacPath;
  final int sizeBytes;

  /// Best-effort estimate for display + the `actualDurationSeconds`
  /// metadata hint. The authoritative duration is measured server-side
  /// from the audio during transcription.
  final Duration estimatedDuration;

  const RecoverableRecording({
    required this.manifest,
    required this.flacPath,
    required this.sizeBytes,
    required this.estimatedDuration,
  });
}

class RecordingRecoveryService {
  RecordingRecoveryService({
    required RecordingManifestStore store,
    required UploadQueueRunner runner,
    RecordingService? recordingService,
  }) : _store = store,
       _runner = runner,
       _recordingService = recordingService;

  final RecordingManifestStore _store;
  final UploadQueueRunner _runner;
  final RecordingService? _recordingService;

  /// Below this the file is not a meaningfully recoverable session
  /// (~15–20 s of 16 kHz mono FLAC) — likely a kill in the first
  /// seconds of capture. Such dirs are garbage-collected on sight.
  static const int minRecoverableBytes = 256 * 1024;

  /// PHI must not rot on disk: orphans (ours or another account's on a
  /// shared device) older than this are deleted by [sweep].
  static const Duration maxOrphanAge = Duration(days: 14);

  /// Conservative FLAC bitrate floor for the size-based duration bound —
  /// speech at 16 kHz mono FLAC runs ~10–18 KiB/s.
  static const int flacMinBytesPerSecond = 9000;

  /// Matches kMaxSessionDuration (recording_screen.dart D5 cap).
  static const Duration maxEstimatedDuration = Duration(minutes: 180);

  /// Returns recoverable orphans for [therapistId], oldest first.
  ///
  /// Skip rules (each logged when it fires):
  ///  1. a PendingUpload row with localId == sessionId exists (any phase)
  ///     — the queue already owns this recording;
  ///  2. the session is being recorded right now;
  ///  3. raw.flac missing or under [minRecoverableBytes] — dir deleted;
  ///  4. another therapist's recording — left alone for [sweep].
  Future<List<RecoverableRecording>> findOrphans(String therapistId) async {
    final manifests = await _store.scanAll();
    if (manifests.isEmpty) return const [];

    final queuedIds = _runner.snapshotNow().map((u) => u.localId).toSet();
    final activeId = _recordingService?.activeSessionId;
    final root = await _store.sessionsRoot();

    final out = <RecoverableRecording>[];
    for (final m in manifests) {
      if (queuedIds.contains(m.sessionId)) {
        debugPrint('[recovery] ${m.sessionId}: already in upload queue');
        continue;
      }
      if (m.sessionId == activeId) {
        debugPrint('[recovery] ${m.sessionId}: recording in progress');
        continue;
      }
      if (m.therapistId != therapistId) {
        debugPrint(
          '[recovery] ${m.sessionId}: other therapist — left for sweep',
        );
        continue;
      }

      final flacPath = p.join(root.path, m.sessionId, 'raw.flac');
      final flac = File(flacPath);
      int size = 0;
      DateTime? mtime;
      try {
        if (await flac.exists()) {
          size = await flac.length();
          mtime = (await flac.stat()).modified.toUtc();
        }
      } catch (e) {
        debugPrint('[recovery] ${m.sessionId}: stat failed: $e');
      }
      if (size < minRecoverableBytes) {
        debugPrint('[recovery] ${m.sessionId}: too small ($size B) — deleting');
        await _store.deleteSessionDir(m.sessionId);
        continue;
      }

      out.add(
        RecoverableRecording(
          manifest: m,
          flacPath: flacPath,
          sizeBytes: size,
          estimatedDuration: _estimateDuration(
            sizeBytes: size,
            startedAtUtc: m.startedAtUtc,
            lastWriteUtc: mtime,
          ),
        ),
      );
    }
    out.sort(
      (a, b) => a.manifest.startedAtUtc.compareTo(b.manifest.startedAtUtc),
    );
    return out;
  }

  /// Wall-clock (start → last byte flushed) cross-checked against a
  /// bitrate ceiling: a kill long after the interruption leaves mtime ≈
  /// interruption time, but if the recorder sat paused before dying the
  /// wall clock overshoots — the size bound caps the lie. Clamped to the
  /// app's hard session cap.
  Duration _estimateDuration({
    required int sizeBytes,
    required DateTime startedAtUtc,
    DateTime? lastWriteUtc,
  }) {
    final sizeBound = Duration(seconds: sizeBytes ~/ flacMinBytesPerSecond);
    Duration est = sizeBound;
    if (lastWriteUtc != null && lastWriteUtc.isAfter(startedAtUtc)) {
      final wallClock = lastWriteUtc.difference(startedAtUtc);
      est = Duration(
        seconds: math.min(wallClock.inSeconds, sizeBound.inSeconds),
      );
    }
    if (est > maxEstimatedDuration) est = maxEstimatedDuration;
    return est;
  }

  /// Hands the orphan to the durable upload queue (same plainFile shape
  /// as the online stop-path in RecordingScreen._finishAndUpload) and
  /// deletes the manifest — ownership transfers to the queue row.
  /// sessionId doubles as the idempotency key, so a recovery retried
  /// after a mid-enqueue kill cannot create a duplicate server row.
  ///
  /// Content-type is `audio/x-flac`, NOT `audio/flac` — deliberately
  /// (docs/28 R1). A recording killed mid-capture leaves an *unfinalized*
  /// FLAC: its STREAMINFO header has `total_samples = 0` and no stream
  /// MD5, which Chirp 3 may reject. The server transcodes any source
  /// whose content-type is not in `IsChirpSupported` (ingestion-svc
  /// converter.go) — and `audio/x-flac` (a legitimate alternative FLAC
  /// MIME) is not in that list, so the bytes route through the server's
  /// lossless ffmpeg re-encode, which rewrites a clean, finalized FLAC
  /// header. The server's content-type→extension map defaults unknown
  /// types to `.flac`, so ffmpeg still demuxes the real FLAC bytes
  /// correctly (a mislabel like `audio/mp4` would set a `.m4a` object
  /// path and break ffmpeg's demuxer). A converter unit test locks the
  /// `IsChirpSupported("audio/x-flac") == false` coupling.
  static const String _recoveryContentType = 'audio/x-flac';

  Future<PendingUpload> recover(RecoverableRecording r) async {
    final m = r.manifest;
    final pending = PendingUpload.initial(
      localId: m.sessionId,
      therapistId: m.therapistId,
      patientFileId: m.patientFileId,
      patientLanguageCode: m.patientLanguageCode,
      sourceKind: UploadSourceKind.plainFile,
      sourcePath: r.flacPath,
      contentType: _recoveryContentType,
      sizeBytes: r.sizeBytes,
      chunkCount: 1,
      actualDurationSeconds: r.estimatedDuration.inSeconds,
      // Local-intent flag for observability; the actual server trigger is
      // the content-type above (the flag itself is never sent on the RPC).
      needsServerSideConversion: true,
      idempotencyKey: m.sessionId,
      now: DateTime.now().toUtc(),
    );
    await _runner.enqueue(pending);
    await _store.delete(m.sessionId);
    unawaited(_runner.kick());
    return pending;
  }

  /// Permanently deletes the orphaned recording.
  Future<void> discard(RecoverableRecording r) =>
      _store.deleteSessionDir(r.manifest.sessionId);

  /// Retention housekeeping, run before [findOrphans] on every scan:
  /// deletes orphan dirs older than [maxOrphanAge] regardless of owner.
  /// Sessions owned by the queue or currently recording are exempt.
  Future<void> sweep() async {
    final manifests = await _store.scanAll();
    if (manifests.isEmpty) return;
    final queuedIds = _runner.snapshotNow().map((u) => u.localId).toSet();
    final activeId = _recordingService?.activeSessionId;
    final cutoff = DateTime.now().toUtc().subtract(maxOrphanAge);
    for (final m in manifests) {
      if (queuedIds.contains(m.sessionId)) continue;
      if (m.sessionId == activeId) continue;
      if (m.startedAtUtc.isBefore(cutoff)) {
        debugPrint(
          '[recovery] sweeping expired orphan ${m.sessionId} '
          '(started ${m.startedAtUtc})',
        );
        await _store.deleteSessionDir(m.sessionId);
      }
    }
  }
}
