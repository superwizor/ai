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

/// Outcome of [UploadIo.convertSource]. Describes the file that should
/// now be uploaded — either the freshly transcoded one (success) or the
/// untouched original (fallback). The worker copies these fields onto
/// the PendingUpload via copyWith before advancing to phase=pending.
class ConvertResult {
  /// Absolute path to the file to upload from here on. On a successful
  /// on-device transcode this is the new FLAC/WAV inside the row's
  /// `queued_uploads/<localId>/` staging dir; on fallback it's the
  /// original picked file, unchanged.
  final String sourcePath;

  /// MIME type of [sourcePath] — 'audio/flac' after an M4A transcode,
  /// 'audio/wav' after normalization, or the original type on fallback.
  final String contentType;

  /// Size of [sourcePath] in bytes (re-measured after transcode).
  final int sizeBytes;

  /// True when client-side conversion could NOT produce a Chirp-native
  /// file (non-iOS platform, iOS decode failure, corrupt input). The
  /// original is uploaded as-is and ingestion-svc runs its ffmpeg
  /// fallback off the bucket notification before transcription. This is
  /// the no-data-loss escape hatch: we always end up with SOMETHING on
  /// GCS, even when on-device transcode can't run.
  final bool needsServerSideConversion;

  const ConvertResult({
    required this.sourcePath,
    required this.contentType,
    required this.sizeBytes,
    required this.needsServerSideConversion,
  });
}

/// Outcome of [UploadIo.encryptSource] — the metadata the worker stamps
/// onto the row after the raw recording is encrypted into chunks.
class EncryptResult {
  /// Plaintext (decrypted) size in bytes — equals the raw FLAC size.
  final int sizeBytes;

  /// Number of `chunk_*.enc` files produced.
  final int chunkCount;

  const EncryptResult({required this.sizeBytes, required this.chunkCount});
}

abstract class UploadIo {
  /// Step 0b (only for live-recording rows enqueued in phase=encrypting):
  /// encrypt the raw FLAC at `<u.sourcePath>/raw.flac` into AES-256-GCM
  /// `chunk_*.enc` files in the same session dir and securely delete the
  /// raw file. Returns the chunk count + plaintext size so the worker can
  /// stamp the row before advancing to phase=pending. Idempotent enough
  /// to retry: re-encrypting after a partial run overwrites the chunks.
  /// Throws on key/IO errors → worker classifies as retryable.
  Future<EncryptResult> encryptSource(
    PendingUpload u, {
    void Function(double progressFraction)? onProgress,
  });

  /// Step 0 (only for rows enqueued in phase=converting): transcode the
  /// source file on-device to a Chirp-native format. Writes output into
  /// the row's `queued_uploads/<localId>/` staging dir so it's durable
  /// across app restarts and swept by [cleanupSource]; deletes the
  /// original once the converted file lands.
  ///
  /// Never throws for an *expected* conversion failure (unsupported
  /// platform, undecodable input) — those return a [ConvertResult]
  /// pointing at the original file with needsServerSideConversion=true.
  /// May throw for genuinely transient/unexpected I/O errors, which the
  /// worker classifies as retryable (the row stays in `converting` and
  /// the next tick retries).
  Future<ConvertResult> convertSource(
    PendingUpload u, {
    void Function(double progressFraction)? onProgress,
  });

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
