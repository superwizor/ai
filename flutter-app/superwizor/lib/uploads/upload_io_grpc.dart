// GrpcUploadIo — production implementation of UploadIo.
//
// Wires the four ingestion-svc RPCs and the GCS PUT against the
// existing app singletons (gRPC clients, SecureAudioStorageService).
// All errors fall through unwrapped so the worker's classifier can
// see GrpcError / SocketException / our httpStatusError() helper
// without losing their identity.
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

import '../generated/ingestion/v1/ingestion.pb.dart' as ingestion_pb;
import '../generated/ingestion/v1/ingestion.pbgrpc.dart' as ingestion_grpc;
import '../services/secure_audio_storage_service.dart';
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
        _http = httpClient ?? http.Client();

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
      final bytes = await file.readAsBytes();
      debugPrint('[upload-io] PUT ${bytes.length}B → ${_redact(signedUrl)}');
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

  // ── step 3 ────────────────────────────────────────────────────

  @override
  Future<ConvertAudioResult> convertAudio(PendingUpload u) async {
    final uploadId = u.uploadId;
    if (uploadId == null) {
      throw StateError('GrpcUploadIo.convertAudio: uploadId is null');
    }
    final res = await _ingestion.convertAudio(
      ingestion_pb.ConvertAudioRequest(
        audioUploadId: uploadId,
        targetContentType: 'audio/flac',
      ),
    );
    return ConvertAudioResult(
      contentType: res.contentType,
      converted: res.converted,
    );
  }

  // ── step 4 ────────────────────────────────────────────────────

  @override
  Future<CompleteAudioUploadResult> completeUpload(PendingUpload u) async {
    final uploadId = u.uploadId;
    if (uploadId == null) {
      throw StateError('GrpcUploadIo.completeUpload: uploadId is null');
    }
    final res = await _ingestion.completeAudioUpload(
      ingestion_pb.CompleteAudioUploadRequest(
        uploadId: uploadId,
        actualDurationSeconds: u.actualDurationSeconds,
        actualSizeBytes: Int64(u.sizeBytes),
        chunkCount: u.chunkCount,
        reportLanguage: u.patientLanguageCode,
      ),
    );
    return CompleteAudioUploadResult(sessionId: res.sessionId);
  }

  // ── step 5 ────────────────────────────────────────────────────

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
      debugPrint('[upload-io] cleanupSource failed: $e');
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
