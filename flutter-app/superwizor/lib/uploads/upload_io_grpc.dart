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
// HTTP PUT loads the whole file into memory (same as the legacy
// UploadService — for 1–30 MB FLAC on iPhone it's fine). A streaming
// PUT with progress is a follow-up; the worker already accepts an
// onProgress callback in the interface so the wiring is ready.

import 'dart:io';

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
  })  : _ingestion = ingestion,
        _secureStorage = secureStorage,
        _http = httpClient ?? http.Client();

  final ingestion_grpc.IngestionServiceClient _ingestion;
  final SecureAudioStorageService _secureStorage;
  final http.Client _http;

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
    final res = await _ingestion.createAudioUpload(
      ingestion_pb.CreateAudioUploadRequest(
        patientFileId: u.patientFileId,
        therapistId: u.therapistId,
        estimatedSizeBytes: Int64(u.sizeBytes),
        contentType: u.contentType,
        clientPlatform: _platform(),
        // Same idempotencyKey across retries — server returns the
        // original audio_uploads row + a fresh signedUrl.
        idempotencyKey: u.idempotencyKey,
        reportLanguage: u.patientLanguageCode,
      ),
    );
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
      final response = await _http.put(
        Uri.parse(signedUrl),
        headers: {
          'Content-Type': u.contentType,
          'x-goog-meta-source': 'superwizor-mobile',
        },
        body: bytes,
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
  // call uploads as many chunks as it can; on any failure it throws
  // (retryable) and the worker's next attempt resume()s from the offset
  // GCS holds — surviving network drops AND app-kill without restarting
  // from byte 0 and without persisting the offset locally.
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
    if (offset >= total) {
      onProgress?.call(1.0); // GCS already has the whole object
      return;
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      while (offset < total) {
        final end = (offset + chunkSize < total) ? offset + chunkSize : total;
        final len = end - offset;
        await raf.setPosition(offset);
        final body = await raf.read(len);
        final resp = await _http.put(
          Uri.parse(sessionUri),
          headers: {
            'Content-Length': '$len',
            'Content-Range': 'bytes $offset-${end - 1}/$total',
          },
          body: body,
        );
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          onProgress?.call(1.0); // final chunk → object finalized exactly once
          return;
        }
        if (resp.statusCode == 308) {
          offset = _parseResumeOffset(resp.headers, fallback: end);
          onProgress?.call(offset / total);
          continue;
        }
        if (resp.statusCode == 404 ||
            resp.statusCode == 410 ||
            resp.statusCode == 403) {
          // Session dead/expired — surface as 403 so the worker's
          // signedUrl-expired path drops back to pending and re-creates
          // (CreateAudioUpload re-issues a fresh resumable session).
          throw httpStatusError(403, 'resumable session gone: ${resp.statusCode}');
        }
        // 5xx / other — retryable. Throw; the next attempt resume()s.
        throw httpStatusError(resp.statusCode, resp.body);
      }
    } finally {
      await raf.close();
    }
  }

  /// Queries the GCS resumable session for how many bytes it already holds.
  /// `Content-Range: bytes */total` with an empty body. Returns the next
  /// byte offset to send (0 if nothing held, total if already complete).
  Future<int> _resumableQueryOffset(String sessionUri, int total) async {
    final resp = await _http.put(
      Uri.parse(sessionUri),
      headers: {'Content-Range': 'bytes */$total', 'Content-Length': '0'},
      body: const <int>[],
    );
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
