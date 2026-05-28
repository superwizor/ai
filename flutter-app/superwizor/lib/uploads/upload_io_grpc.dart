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
// HTTP PUT streams the file in 256 KB chunks via http.StreamedRequest
// (F-01/F-12 fix, 2026-05). Previous implementation loaded the entire
// file into RAM via readAsBytes() — eliminated because:
//   1. F-01: plaintext bytes sitting in Dart heap until GC collected them
//   2. F-12: OOM risk on low-RAM devices with large imported sessions
// The onProgress callback fires per chunk for real upload progress.

import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../generated/ingestion/v1/ingestion.pb.dart' as ingestion_pb;
import '../generated/ingestion/v1/ingestion.pbgrpc.dart' as ingestion_grpc;
import '../services/secure_audio_storage_service.dart';
import 'certificate_pinner.dart';
import 'pending_upload.dart';
import 'upload_error.dart';
import 'upload_io.dart';

class GrpcUploadIo implements UploadIo {
  GrpcUploadIo({
    required ingestion_grpc.IngestionServiceClient ingestion,
    required SecureAudioStorageService secureStorage,
    http.Client? httpClient,
  })  : _ingestion = ingestion,
        _secureStorage = secureStorage,
        // F-09: Use a certificate-pinned HTTP client for GCS uploads.
        // Validates against Google Trust Services root CA fingerprints.
        _http = httpClient ?? createPinnedHttpClient();

  final ingestion_grpc.IngestionServiceClient _ingestion;
  final SecureAudioStorageService _secureStorage;
  final http.Client _http;

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
    );
  }

  // ── step 2 ────────────────────────────────────────────────────

  @override
  Future<void> putBytes(
    PendingUpload u, {
    void Function(double)? onProgress,
  }) async {
    final signedUrl = u.signedUrl;
    if (signedUrl == null) {
      // The worker guards against this, but defensive bytes.
      throw StateError('GrpcUploadIo.putBytes: signedUrl is null');
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
      // F-01/F-12 fix: Stream the file to GCS instead of loading it
      // entirely into RAM. Peak memory: ~256 KB (one read buffer)
      // instead of the full file size (1–30 MB typical, up to 200 MB
      // for long imported sessions). Eliminates:
      //   - F-01: plaintext data sitting in Dart heap until GC
      //   - F-12: OOM risk on low-RAM devices (older iPhones / Androids)
      final fileSize = await file.length();
      if (kDebugMode) debugPrint('[upload-io] PUT ${fileSize}B (streamed) → ${_redact(signedUrl)}');

      final request = http.StreamedRequest('PUT', Uri.parse(signedUrl));
      request.headers['Content-Type'] = u.contentType;
      request.headers['x-goog-meta-source'] = 'superwizor-mobile';
      request.contentLength = fileSize;

      // Pipe file → request body in 256 KB chunks. The http package
      // sends each chunk as it arrives — no full-file buffering.
      int bytesSent = 0;
      file.openRead().listen(
        (chunk) {
          request.sink.add(chunk);
          bytesSent += chunk.length;
          if (fileSize > 0) {
            onProgress?.call(bytesSent / fileSize);
          }
        },
        onDone: () => request.sink.close(),
        onError: (Object e) => request.sink.addError(e),
        cancelOnError: true,
      );

      final streamedResponse = await _http.send(request);
      final statusCode = streamedResponse.statusCode;

      // Drain the response body so the connection is released.
      final responseBody = await streamedResponse.stream.bytesToString();

      if (statusCode == 200 || statusCode == 204) {
        onProgress?.call(1.0);
        return;
      }
      throw httpStatusError(statusCode, responseBody);
    } finally {
      if (ownsFile) {
        try {
          if (await file.exists()) await file.delete();
        } catch (e) {
          if (kDebugMode) debugPrint('[upload-io] temp file delete failed: $e');
        }
      }
    }
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

      // plainFile: only delete files we own — those under the
      // `queued_uploads/<localId>/` staging dir that
      // new_session_screen copies the picked file into. User-picked
      // files outside that prefix are never ours to delete.
      final path = u.sourcePath;
      if (path.contains('${Platform.pathSeparator}queued_uploads'
              '${Platform.pathSeparator}${u.localId}${Platform.pathSeparator}')) {
        final dir = Directory(File(path).parent.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[upload-io] cleanupSource failed: $e');
      // Don't rethrow — terminal-success on the server is what matters.
    }
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
