// GrpcUploadIo — production implementation of UploadIo.
//
// Wires the single ingestion-svc CreateAudioUpload RPC + the
// direct GCS PUT against the existing app singletons (gRPC client,
// SecureAudioStorageService). All errors fall through unwrapped so
// the worker's classifier can see GrpcError / SocketException /
// our httpStatusError() helper without losing their identity.
//
// Option F (feat/refactor-stt-architecture, 2026-05-25):
// `convertAudio` and `completeUpload` were removed once
// ingestion-svc started driving finalize asynchronously off a
// bucket notification. The client now terminates at PUT.
//
// Source materialisation differs by UploadSourceKind:
//
//   encryptedChunks — calls SecureAudioStorageService.decryptToTempFile
//     to produce a single plaintext file at upload time. Temp file is
//     deleted in a `finally` regardless of PUT outcome — we never
//     leave plaintext PHI on disk past one attempt.
//
//   plainFile — uploads sourcePath directly. We don't take ownership
//     of the file; cleanupSource is a no-op.
//
// Transfer resilience (docs/26 R2, fix/upload-stall-resilience):
// every HTTP call carries a timeout (a stalled mobile socket used to
// hang putBytes forever, freezing the runner's tick loop), chunk PUTs
// stream their body in slices so the progress bar moves *within* a
// chunk, and transient chunk failures retry in-attempt against the
// GCS-acked offset instead of punting every blip to the worker's
// exponential backoff.

import 'dart:io';
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../generated/ingestion/v1/ingestion.pb.dart' as ingestion_pb;
import '../generated/ingestion/v1/ingestion.pbgrpc.dart' as ingestion_grpc;
import '../services/audio_converter_service.dart';
import '../services/secure_audio_storage_service.dart';
import 'pending_upload.dart';
import 'upload_error.dart';
import 'upload_io.dart';

/// Content types Chirp 3 europe-central2 accepts directly. Anything
/// outside this set must be transcoded — on-device when we can, else
/// server-side via ingestion-svc's ffmpeg fallback. Mirrors
/// `_kChirpNativeContentTypes` in new_session_screen.dart and
/// IsChirpSupported in ingestion-svc/.../storage/converter.go.
const Set<String> _kChirpNativeContentTypes = {
  'audio/flac',
  'audio/wav',
  'audio/x-wav',
  'audio/ogg',
  'audio/opus',
  'audio/webm',
  'audio/amr',
  'audio/amr-wb',
};

class GrpcUploadIo implements UploadIo {
  GrpcUploadIo({
    required ingestion_grpc.IngestionServiceClient ingestion,
    required SecureAudioStorageService secureStorage,
    http.Client? httpClient,
    Duration Function(int stuckRound)? chunkRetryDelay,
    Duration Function(int transferBytes)? transferTimeout,
    int maxStuckRounds = 4,
  })  : _ingestion = ingestion,
        _secureStorage = secureStorage,
        _http = httpClient ?? http.Client(),
        _chunkRetryDelay = chunkRetryDelay ?? _defaultChunkRetryDelay,
        _transferTimeout = transferTimeout ?? _defaultTransferTimeout,
        _maxStuckRounds = maxStuckRounds;

  final ingestion_grpc.IngestionServiceClient _ingestion;
  final SecureAudioStorageService _secureStorage;
  final http.Client _http;

  /// Delay between in-attempt chunk retries, by consecutive rounds with
  /// zero offset advance. Injectable so tests don't sleep.
  final Duration Function(int stuckRound) _chunkRetryDelay;

  /// Timeout for a body-bearing PUT, scaled by payload size.
  final Duration Function(int transferBytes) _transferTimeout;

  /// Consecutive zero-progress rounds tolerated inside one putBytes call
  /// before escalating to the worker's (slower) retry schedule.
  final int _maxStuckRounds;

  /// 2 s, 4 s, 8 s, 16 s, 32 s — quick enough to ride out a Wi-Fi↔LTE
  /// handoff without surfacing an attempt failure to the UI.
  static Duration _defaultChunkRetryDelay(int stuckRound) =>
      Duration(seconds: 1 << (1 + stuckRound.clamp(0, 4)));

  /// 30 s grace + a 40 KiB/s throughput floor: an 8 MiB chunk gets
  /// ~4 min before a stalled socket is declared dead. Generous enough
  /// that a genuinely slow-but-moving uplink never trips it.
  static Duration _defaultTransferTimeout(int transferBytes) =>
      Duration(seconds: 30 + transferBytes ~/ (40 * 1024));

  /// The `bytes */total` offset probe carries no body — 30 s is plenty.
  static const Duration _offsetQueryTimeout = Duration(seconds: 30);

  // ── step 0b: on-device encryption (phase=encrypting only) ─────

  @override
  Future<EncryptResult> encryptSource(
    PendingUpload u, {
    void Function(double)? onProgress,
  }) async {
    // Live-recording rows carry sourcePath = <docs>/sessions/<sessionId>/
    // and the recorder wrote the raw FLAC at <sourcePath>/raw.flac (see
    // recording_service.dart). encryptRecording streams it into
    // chunk_*.enc in the same dir and securely deletes raw.flac.
    final sessionId = _sessionIdFromPath(u.sourcePath);
    final rawPath = p.join(u.sourcePath, 'raw.flac');
    final chunks = await _secureStorage.encryptRecording(
      rawPath: rawPath,
      sessionId: sessionId,
    );
    debugPrint('[upload-io] encrypted recording localId=${u.localId} '
        'chunks=${chunks.length}');
    return EncryptResult(
      sizeBytes: SecureAudioStorageService.estimateDecryptedSize(chunks),
      chunkCount: chunks.length,
    );
  }

  // ── step 0: on-device transcode (phase=converting only) ───────

  @override
  Future<ConvertResult> convertSource(
    PendingUpload u, {
    void Function(double)? onProgress,
  }) async {
    final src = File(u.sourcePath);
    final ext = p.extension(u.sourcePath).toLowerCase();
    final converter = AudioConverterService();

    // ── WAV → 16-bit PCM normalization ──
    // Chirp 3 rejects 32-bit float / 24-bit WAV. normalizeWav returns
    // the original file untouched when it's already 16-bit PCM, null
    // when it can't parse the header (upload as-is), or a fresh temp
    // file otherwise.
    if (ext == '.wav') {
      try {
        final normalized =
            await converter.normalizeWav(u.sourcePath, onProgress: onProgress);
        if (normalized != null && normalized.path != u.sourcePath) {
          final staged = await _adoptIntoStaging(
            produced: normalized,
            original: src,
            ext: '.wav',
          );
          return ConvertResult(
            sourcePath: staged.path,
            contentType: 'audio/wav',
            sizeBytes: await staged.length(),
            needsServerSideConversion: false,
          );
        }
      } catch (e, st) {
        debugPrint('[upload-io] WAV normalize failed, uploading original: $e\n$st');
      }
      // Already-16-bit, unparseable, or normalize threw — ship the
      // original WAV. It's Chirp-native, so no server fallback needed.
      return ConvertResult(
        sourcePath: u.sourcePath,
        contentType: 'audio/wav',
        sizeBytes: await src.length(),
        needsServerSideConversion: false,
      );
    }

    // ── M4A / MP4 / AAC → FLAC (iOS on-device) ──
    if (ext == '.m4a' || ext == '.mp4' || ext == '.aac') {
      if (Platform.isIOS) {
        try {
          final flac = await converter.convertM4aToFlac(
            u.sourcePath,
            onProgress: onProgress,
          );
          final staged = await _adoptIntoStaging(
            produced: flac,
            original: src,
            ext: '.flac',
          );
          debugPrint('[upload-io] M4A → FLAC OK: '
              '${(await staged.length() / 1024 / 1024).toStringAsFixed(1)} MB');
          return ConvertResult(
            sourcePath: staged.path,
            contentType: 'audio/flac',
            sizeBytes: await staged.length(),
            needsServerSideConversion: false,
          );
        } catch (e, st) {
          // Decode failure / corrupt input — fall through to server-side
          // ConvertAudio. Upload the original; ingestion-svc transcodes
          // it off the bucket notification. NO data loss.
          debugPrint('[upload-io] M4A → FLAC failed, server-side fallback: $e\n$st');
        }
      } else {
        debugPrint('[upload-io] non-iOS platform; server-side ConvertAudio for $ext');
      }
      return ConvertResult(
        sourcePath: u.sourcePath,
        contentType: ext == '.aac' ? 'audio/aac' : 'audio/mp4',
        sizeBytes: await src.length(),
        needsServerSideConversion: true,
      );
    }

    // Any other type that landed in the converting phase: ship as-is
    // and let the server decide (needsServerSide when not Chirp-native).
    final ct = u.contentType;
    return ConvertResult(
      sourcePath: u.sourcePath,
      contentType: ct,
      sizeBytes: await src.length(),
      needsServerSideConversion: !_kChirpNativeContentTypes.contains(ct),
    );
  }

  /// Moves a converter-produced temp file into the row's staging dir
  /// (the parent of the original picked file, i.e.
  /// `queued_uploads/<localId>/`) so the result is durable and gets
  /// swept by [cleanupSource]. Copies rather than renames because the
  /// temp dir and docs dir can live on different volumes (rename would
  /// throw cross-device). Deletes both the temp file and the now-
  /// redundant original. Returns the staged File.
  Future<File> _adoptIntoStaging({
    required File produced,
    required File original,
    required String ext,
  }) async {
    final stagingDir = original.parent;
    final dest = File(p.join(
      stagingDir.path,
      '${p.basenameWithoutExtension(original.path)}$ext',
    ));
    // Guard against dest == original (e.g. picked file already had the
    // target ext) — copy to a sibling name to avoid truncating the
    // source mid-copy.
    final target = dest.path == original.path
        ? File(p.join(stagingDir.path,
            '${p.basenameWithoutExtension(original.path)}_conv$ext'))
        : dest;
    await produced.copy(target.path);
    try {
      if (await produced.exists()) await produced.delete();
    } catch (e) {
      debugPrint('[upload-io] temp transcode file cleanup failed: $e');
    }
    if (target.path != original.path) {
      try {
        if (await original.exists()) await original.delete();
      } catch (e) {
        debugPrint('[upload-io] original cleanup failed: $e');
      }
    }
    return target;
  }

  // ── step 1 ────────────────────────────────────────────────────

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async {
    // Hard deadline (2026-07-23, sesja a5ce601f): this RPC fired in
    // airplane mode hung FOREVER (gRPC-dart issues no deadline by
    // default), and the un-completing await held the runner's
    // _tickInFlight — the whole queue froze silently for 2 h with zero
    // server traffic. TimeoutException classifies as retryable, so a
    // dead network now costs one 45 s attempt instead of the queue.
    final res = await _ingestion
        .createAudioUpload(
      ingestion_pb.CreateAudioUploadRequest(
        patientFileId: u.patientFileId,
        therapistId: u.therapistId,
        estimatedSizeBytes: Int64(u.sizeBytes),
        // Wall-clock capture time measured by RecordingService (clock
        // frozen while paused/interrupted, so it tracks real audio).
        // The server's decode probe stays authoritative; this feeds the
        // client-vs-decode anomaly cross-check that catches corrupt
        // FLAC headers from pause/resume cycles (session e22d25f3).
        // 0 for flows that don't measure (file import) — server ignores.
        estimatedDurationSeconds: u.actualDurationSeconds,
        contentType: u.contentType,
        clientPlatform: _platform(),
        // Same idempotencyKey across retries — server returns the
        // original audio_uploads row + a fresh signedUrl.
        idempotencyKey: u.idempotencyKey,
        reportLanguage: u.patientLanguageCode,
      ),
    )
        .timeout(const Duration(seconds: 45));
    return CreateAudioUploadResult(
      uploadId: res.uploadId,
      signedUrl: res.signedUrl,
      // Option E (2026-05-25): server now returns session_id at
      // upload-creation time. Empty string for legacy server
      // revisions, which the worker treats as "not known yet"
      // (existing semantics preserved for the migration window).
      sessionId: res.sessionId,
      // Resumable upload (docs/26). Empty when the server (or a legacy
      // revision) didn't issue a resumable session → single-PUT fallback.
      resumableSessionUri: res.resumableSessionUri,
      resumableExpiresAt: res.hasResumableSessionExpiresAt()
          ? res.resumableSessionExpiresAt.toDateTime()
          : null,
      resumableChunkSize: res.recommendedChunkSizeBytes.toInt(),
    );
  }

  // ── step 2 ────────────────────────────────────────────────────

  @override
  Future<void> putBytes(
    PendingUpload u, {
    void Function(double)? onProgress,
  }) async {
    final signedUrl = u.signedUrl;
    final resumableUri = u.resumableSessionUri;
    final hasResumable = resumableUri != null && resumableUri.isNotEmpty;
    if (signedUrl == null && !hasResumable) {
      // The worker guards against this, but defensive bytes.
      throw StateError('GrpcUploadIo.putBytes: no upload target');
    }

    final File file;
    final bool ownsFile;
    if (u.sourceKind == UploadSourceKind.encryptedChunks) {
      // For encryptedChunks, sourcePath is the per-session directory.
      // SecureAudioStorageService keyed by the session ID embedded in
      // that path. We pass the basename which the service uses to
      // resolve <docs>/sessions/<sessionId>/.
      final sessionId = _sessionIdFromPath(u.sourcePath);
      file = await _secureStorage.decryptToTempFile(sessionId: sessionId);
      ownsFile = true;
    } else {
      file = File(u.sourcePath);
      ownsFile = false;
    }

    try {
      if (hasResumable) {
        await _putResumable(file, resumableUri, u, onProgress);
        return;
      }
      // ── Legacy single-PUT path (no resumable session) ──
      final bytes = await file.readAsBytes();
      debugPrint('[upload-io] PUT ${bytes.length}B → ${_redact(signedUrl!)}');
      final response = await _sendBody(
        Uri.parse(signedUrl),
        bytes,
        headers: {
          'Content-Type': u.contentType,
          'x-goog-meta-source': 'superwizor-mobile',
        },
        onSent: onProgress == null
            ? null
            : (sent) => onProgress(sent / bytes.length),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        onProgress?.call(1.0);
        return;
      }
      // Non-2xx — surface as httpStatusError so the classifier sees
      // the status code and decides retryable vs terminal vs
      // signedUrl-expired.
      throw httpStatusError(response.statusCode, response.body);
    } finally {
      if (ownsFile) {
        try {
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugPrint('[upload-io] temp file delete failed: $e');
        }
      }
    }
  }

  // ── Resumable upload (docs/26) ─────────────────────────────────
  //
  // GCS resumable protocol: PUT byte-range chunks to the session URI.
  // The GCS-acked offset is queried live (resume()), so a single putBytes
  // call uploads as many chunks as it can — surviving network drops AND
  // app-kill without restarting from byte 0 and without persisting the
  // offset locally.
  //
  // Failure handling (docs/26 R2): a transient chunk error retries
  // in-attempt — re-query the acked offset, wait a few seconds, carry
  // on. Only [_maxStuckRounds] consecutive rounds with ZERO offset
  // advance escalate to the worker; if bytes moved at any point in this
  // attempt the escalation is wrapped in [UploadProgressMadeError] so
  // the worker restarts its backoff ladder. Session-gone / terminal
  // statuses propagate immediately — retrying those locally is wasted.
  Future<void> _putResumable(
    File file,
    String sessionUri,
    PendingUpload u,
    void Function(double)? onProgress,
  ) async {
    final total = await file.length();
    if (total == 0) throw StateError('resumable: source file is empty');

    // Chunk size must be a multiple of 256 KiB (GCS requirement for
    // non-final chunks). Default 8 MiB.
    const quantum = 256 * 1024;
    final requested = u.resumableChunkSize > 0
        ? u.resumableChunkSize
        : 8 * 1024 * 1024;
    final chunkSize = (requested ~/ quantum) * quantum > 0
        ? (requested ~/ quantum) * quantum
        : 8 * 1024 * 1024;

    var offset = await _resumableQueryOffset(sessionUri, total);
    // Surface the resume position immediately — after an app-kill or a
    // failed attempt the bar would otherwise sit on a stale value until
    // the next full chunk lands.
    onProgress?.call(offset / total);
    if (offset >= total) return; // GCS already has the whole object

    final startOffset = offset;
    var stuckRounds = 0;

    final raf = await file.open(mode: FileMode.read);
    try {
      while (offset < total) {
        final end = math.min(offset + chunkSize, total);
        try {
          await raf.setPosition(offset);
          final body = await raf.read(end - offset);
          final resp = await _sendBody(
            Uri.parse(sessionUri),
            body,
            headers: {'Content-Range': 'bytes $offset-${end - 1}/$total'},
            onSent: onProgress == null
                ? null
                // Intra-chunk progress: socket-buffered bytes, slightly
                // ahead of GCS-acked — corrected on the next 308.
                : (sent) => onProgress((offset + sent) / total),
          );
          if (resp.statusCode == 200 || resp.statusCode == 201) {
            onProgress?.call(1.0); // final chunk → object finalized
            return;
          }
          if (resp.statusCode == 308) {
            final next = _parseResumeOffset(resp.headers, fallback: end);
            if (next > offset) stuckRounds = 0;
            offset = next;
            onProgress?.call(offset / total);
            continue;
          }
          if (resp.statusCode == 404 ||
              resp.statusCode == 410 ||
              resp.statusCode == 403) {
            // Session dead/expired — surface as 403 so the worker's
            // signedUrl-expired path drops back to pending and re-creates
            // (CreateAudioUpload re-issues a fresh resumable session).
            throw httpStatusError(
                403, 'resumable session gone: ${resp.statusCode}');
          }
          throw httpStatusError(resp.statusCode, resp.body);
        } catch (e) {
          // Non-retryable (session gone, genuine 4xx) → the worker owns
          // the next move; local retries would burn time for nothing.
          if (classifyUploadError(e).kind != UploadErrorClass.retryable) {
            rethrow;
          }
          // Transient — ask GCS what actually landed before deciding
          // whether this round counts as stuck.
          int acked;
          try {
            acked = await _resumableQueryOffset(sessionUri, total);
          } catch (_) {
            acked = offset; // probe failed too → stuck round
          }
          if (acked > offset) {
            offset = acked;
            onProgress?.call(offset / total);
            stuckRounds = 0;
          } else {
            stuckRounds++;
          }
          if (stuckRounds > _maxStuckRounds) {
            debugPrint('[upload-io] resumable stuck at $offset/$total '
                'after $stuckRounds zero-progress rounds: $e');
            if (offset > startOffset) throw UploadProgressMadeError(e);
            rethrow;
          }
          if (stuckRounds > 0) {
            await Future<void>.delayed(_chunkRetryDelay(stuckRounds - 1));
          }
        }
      }
      // Loop exit without a 200/201: the post-failure offset probe
      // reported all bytes held, i.e. GCS finalized the object.
      onProgress?.call(1.0);
    } finally {
      await raf.close();
    }
  }

  /// One body-bearing PUT with streamed intra-body progress and a
  /// size-scaled timeout. [onSent] receives cumulative bytes handed to
  /// the socket (dart:io applies backpressure when piping the slice
  /// stream, so this tracks real transmission closely).
  Future<http.Response> _sendBody(
    Uri url,
    Uint8List body, {
    Map<String, String> headers = const {},
    void Function(int sentBytes)? onSent,
  }) {
    final req = _ProgressedBytesRequest(url, body, onSent: onSent);
    req.headers.addAll(headers);
    Future<http.Response> roundTrip() async {
      final streamed = await _http.send(req);
      return http.Response.fromStream(streamed);
    }

    return roundTrip().timeout(_transferTimeout(body.length));
  }

  /// Queries the GCS resumable session for how many bytes it already holds.
  /// `Content-Range: bytes */total` with an empty body. Returns the next
  /// byte offset to send (0 if nothing held, total if already complete).
  Future<int> _resumableQueryOffset(String sessionUri, int total) async {
    final resp = await _http
        .put(
          Uri.parse(sessionUri),
          headers: {'Content-Range': 'bytes */$total', 'Content-Length': '0'},
          body: const <int>[],
        )
        .timeout(_offsetQueryTimeout);
    if (resp.statusCode == 200 || resp.statusCode == 201) return total;
    if (resp.statusCode == 308) {
      return _parseResumeOffset(resp.headers, fallback: 0);
    }
    if (resp.statusCode == 404 ||
        resp.statusCode == 410 ||
        resp.statusCode == 403) {
      throw httpStatusError(403, 'resumable session gone: ${resp.statusCode}');
    }
    throw httpStatusError(resp.statusCode, resp.body);
  }

  /// Parses GCS's `Range: bytes=0-K` (bytes 0..K inclusive are held) into the
  /// next offset to send (K+1). Returns [fallback] when no Range header.
  int _parseResumeOffset(Map<String, String> headers, {required int fallback}) {
    final range = headers['range'] ?? headers['Range'];
    if (range == null) return fallback;
    final m = RegExp(r'bytes=0-(\d+)').firstMatch(range);
    if (m == null) return fallback;
    return int.parse(m.group(1)!) + 1;
  }

  // ── step 3 ────────────────────────────────────────────────────

  @override
  Future<void> cleanupSource(PendingUpload u) async {
    try {
      if (u.sourceKind == UploadSourceKind.encryptedChunks) {
        final sessionId = _sessionIdFromPath(u.sourcePath);
        await _secureStorage.purgeSession(sessionId);
        return;
      }

      final sep = Platform.pathSeparator;
      final path = u.sourcePath;

      // Online recording fast-path (Option D): a plainFile whose source
      // is the raw FLAC under `sessions/<localId>/raw.flac`. We own that
      // whole session dir — secure-purge it just like the encrypted-
      // chunks path would, so no plaintext recording lingers on disk.
      if (path.contains('${sep}sessions$sep${u.localId}$sep')) {
        await _secureStorage.purgeSession(u.localId);
        return;
      }

      // File-upload path: only delete files we own — those under the
      // `queued_uploads/<localId>/` staging dir that new_session_screen
      // copies the picked file into. User-picked files outside that
      // prefix are never ours to delete.
      if (path.contains('${sep}queued_uploads$sep${u.localId}$sep')) {
        final dir = Directory(File(path).parent.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('[upload-io] cleanupSource failed: $e');
      // Don't rethrow — terminal-success on the server is what matters.
    }
  }

  @override
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async {
    var removed = 0;
    try {
      final base = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      // Both roots key their per-upload subdir by the queue row's
      // localId (recordings → `sessions/<id>/`, staged file-uploads →
      // `queued_uploads/<id>/`). A subdir whose id has no live row is a
      // leftover from a dismissed/failed/crashed upload.
      for (final root in const ['sessions', 'queued_uploads']) {
        final dir = Directory(p.join(base.path, root));
        if (!await dir.exists()) continue;
        await for (final entry in dir.list(followLinks: false)) {
          if (entry is! Directory) continue;
          final id = p.basename(entry.path);
          if (liveLocalIds.contains(id)) continue; // still owned by a row
          DateTime modified;
          try {
            modified = (await entry.stat()).modified;
          } catch (_) {
            continue; // can't stat — leave it for the next sweep
          }
          if (now.difference(modified) < maxAge) continue; // too fresh
          try {
            if (root == 'sessions') {
              // Secure-wipe — these dirs may hold plaintext raw.flac or
              // encrypted chunks of PHI.
              await _secureStorage.purgeSession(id);
            } else {
              await entry.delete(recursive: true);
            }
            removed++;
            debugPrint('[upload-io] pruned orphaned source $root/$id '
                '(age ${now.difference(modified).inDays}d)');
          } catch (e) {
            debugPrint('[upload-io] prune failed for ${entry.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[upload-io] pruneOrphanedSources failed: $e');
    }
    return removed;
  }

  // ── helpers ───────────────────────────────────────────────────

  String _platform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    return 'desktop';
  }

  /// SecureAudioStorageService keys everything by sessionId. The
  /// encryptedChunks PendingUpload carries the directory path as
  /// sourcePath; the trailing segment is the sessionId.
  String _sessionIdFromPath(String dirPath) {
    final parts = dirPath.split(Platform.pathSeparator);
    final cleaned = parts.where((s) => s.isNotEmpty).toList();
    return cleaned.isEmpty ? '' : cleaned.last;
  }

  /// Truncates the signed-URL query string in logs — they're
  /// short-lived but still embed an HMAC signature we shouldn't
  /// echo in production console output.
  String _redact(String url) {
    final q = url.indexOf('?');
    return q < 0 ? url : '${url.substring(0, q)}?<redacted>';
  }
}

/// A PUT whose body streams in 64 KiB slices, reporting cumulative bytes
/// after each slice is pulled by the consumer. dart:io pipes the stream
/// into the socket with backpressure, so [onSent] approximates real
/// transmission — close enough for a progress bar, and corrected against
/// the GCS-acked offset on every 308. Content-Length is fixed (no
/// chunked transfer-encoding — GCS signed PUTs reject it).
class _ProgressedBytesRequest extends http.BaseRequest {
  _ProgressedBytesRequest(Uri url, this._body, {this.onSent})
      : super('PUT', url) {
    contentLength = _body.length;
  }

  final Uint8List _body;
  final void Function(int sentBytes)? onSent;

  static const int _sliceSize = 64 * 1024;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_slices());
  }

  Stream<List<int>> _slices() async* {
    for (var i = 0; i < _body.length; i += _sliceSize) {
      final end = math.min(i + _sliceSize, _body.length);
      yield Uint8List.sublistView(_body, i, end);
      onSent?.call(end);
    }
  }
}
