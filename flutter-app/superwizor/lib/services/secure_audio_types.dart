// Shared types for the secure audio storage subsystem.
//
// These types are platform-independent and used by both the
// encryption service (mobile-only) and error classification
// (mobile + web).
//
// Extracted to avoid dart:io dependency in web builds.

/// Public-facing record describing a single encrypted chunk on disk.
class EncryptedChunk {
  final int seq;
  final String path;
  final int sizeBytes;

  const EncryptedChunk({
    required this.seq,
    required this.path,
    required this.sizeBytes,
  });
}

/// Thrown when the integrity manifest verification fails (F-03).
///
/// The upload pipeline (upload_error.dart error classifier)
/// should classify this as a terminal (non-retryable) error —
/// re-encrypting won't help if the on-disk chunks are corrupted.
class IntegrityViolation implements Exception {
  final String message;
  const IntegrityViolation(this.message);
  @override
  String toString() => 'IntegrityViolation: $message';
}
