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

import 'pending_upload.dart';

class CreateAudioUploadResult {
  final String uploadId;
  final String signedUrl;
  const CreateAudioUploadResult(
      {required this.uploadId, required this.signedUrl});
}

class ConvertAudioResult {
  /// Final content type after server-side conversion (e.g. "audio/flac").
  final String contentType;

  /// True if ffmpeg actually ran; false on no-op (already supported).
  final bool converted;
  const ConvertAudioResult(
      {required this.contentType, required this.converted});
}

class CompleteAudioUploadResult {
  final String sessionId;
  const CompleteAudioUploadResult({required this.sessionId});
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

  /// Step 3: ConvertAudio (only called when
  /// [u.needsServerSideConversion] is true). Idempotent — re-running
  /// after success is a server-side no-op.
  Future<ConvertAudioResult> convertAudio(PendingUpload u);

  /// Step 4: CompleteAudioUpload. Triggers STT pipeline.
  Future<CompleteAudioUploadResult> completeUpload(PendingUpload u);

  /// Step 5 (terminal-success only): wipe any on-disk source
  /// material the upload owns — encrypted chunks for the recording
  /// path. For plainFile this is a no-op (we never own the user's
  /// picked file).
  Future<void> cleanupSource(PendingUpload u);
}
