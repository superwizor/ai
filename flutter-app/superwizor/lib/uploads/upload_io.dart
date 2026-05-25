// UploadIo — the side-effect surface the UploadWorker calls through.
//
// Lives behind an interface so the worker's state-machine logic
// (backoff, retry classification, phase transitions) can be unit-
// tested with a fake. The production implementation lives in
// upload_io_grpc.dart and wires the existing ingestion gRPC client,
// http package, and SecureAudioStorageService.
//
// Errors thrown by these methods are caught by the worker and
// classified via the static helpers in upload_error.dart — so
// implementations can throw freely (GrpcError, HttpException,
// SocketException, etc.) and the worker decides retry vs. terminal.
//
// Option F (feat/refactor-stt-architecture, 2026-05-25): the
// surface shrank from five operations to three. `convertAudio`
// and `completeUpload` were removed once ingestion-svc started
// driving finalize asynchronously off a GCS bucket notification;
// the client now terminates at HTTP PUT success and lets the
// server take it from there. See
// `docs/15_HYBRID_EVENTARC_FINALIZATION.md` for the design.

import 'pending_upload.dart';

class CreateAudioUploadResult {
  final String uploadId;
  final String signedUrl;
  /// Option E (2026-05-25): the server allocates the session row at
  /// CreateAudioUpload time, so the response carries session_id from
  /// this point onward. Under Option F (2026-05-25) this is the
  /// session_id the client surfaces to the UI forever — there's no
  /// follow-up RPC that could return a different one.
  final String sessionId;
  const CreateAudioUploadResult({
    required this.uploadId,
    required this.signedUrl,
    this.sessionId = '',
  });
}

abstract class UploadIo {
  /// Step 1: CreateAudioUpload. May be called multiple times for the
  /// same [u] — the server is idempotent on (idempotencyKey,
  /// therapistId), returning the same uploadId + a fresh signedUrl.
  /// This is how the worker recovers from an expired signedUrl.
  Future<CreateAudioUploadResult> createUpload(PendingUpload u);

  /// Step 2: HTTP PUT to the signed URL. For encryptedChunks
  /// sources this implementation is expected to decrypt to a temp
  /// file first; for plainFile it streams [u.sourcePath] directly.
  Future<void> putBytes(
    PendingUpload u, {
    void Function(double progressFraction)? onProgress,
  });

  /// Step 3 (terminal-success only): wipe any on-disk source
  /// material the upload owns — encrypted chunks for the recording
  /// path. For plainFile this is a no-op (we never own the user's
  /// picked file).
  Future<void> cleanupSource(PendingUpload u);
}
