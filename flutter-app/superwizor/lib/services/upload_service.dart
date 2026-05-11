// UploadService — pulls encrypted chunks off disk via
// SecureAudioStorageService, decrypts them into a single temp file,
// PUTs the file to the signed URL returned by ingestion-svc.
//
// MVP simple-PUT: load the temp file fully into memory and PUT it.
// For 30s-30min recordings (1-30 MB FLAC) this is fine on iPhone.
// Long-session streaming is a Phase 4 follow-up — a true streaming
// PUT requires careful StreamedRequest orchestration that the http
// package doesn't make easy.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'secure_audio_storage_service.dart';

class UploadService {
  UploadService(this._storage);

  final SecureAudioStorageService _storage;

  static const _maxRetries = 3;
  static const _retryBaseDelayMs = 1000;
  // Plan D — LINEAR16 WAV @ 16 kHz mono. Switched from FLAC because
  // record_darwin's FLAC path on iOS 26.2.1 silently produces 32-bit
  // IEEE Float WAV which Chirp 3 rejects (`code=3 unsupported
  // encoding`). AudioEncoder.wav is reliable: kAudioFormatLinearPCM
  // with AVLinearPCMIsFloatKey=false → real LINEAR16. Backend STT
  // auto-decode handles it natively.
  static const _contentType = 'audio/wav';

  /// Decrypts chunks for [sessionId] and PUTs the result to [signedUrl].
  /// Returns true on success. Always cleans up the temp file; caller
  /// is responsible for purging encrypted chunks via
  /// [SecureAudioStorageService.purgeSession] only after backend
  /// `CompleteAudioUpload` confirms persistence.
  Future<bool> uploadEncryptedSession({
    required String sessionId,
    required String signedUrl,
  }) async {
    final temp = await _storage.decryptToTempFile(sessionId: sessionId);
    try {
      return await _putWithRetry(signedUrl: signedUrl, file: temp);
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {/* best-effort */}
    }
  }

  Future<bool> _putWithRetry({
    required String signedUrl,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    debugPrint('[upload] PUT ${bytes.length} bytes → $signedUrl');

    Object? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.put(
          Uri.parse(signedUrl),
          headers: {
            'Content-Type': _contentType,
            'x-goog-meta-source': 'superwizor-mobile',
          },
          body: bytes,
        );

        debugPrint(
            '[upload] attempt $attempt → status=${response.statusCode} '
            'bodyLen=${response.body.length}');

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          // Non-retryable — surface the actual GCS error so we can
          // diagnose signed-URL or content-type mismatches loudly.
          throw HttpException(
            'GCS rejected upload (${response.statusCode}): ${response.body}',
            uri: Uri.parse(signedUrl),
          );
        }

        // 5xx — retryable; fall through to backoff.
        lastError = HttpException(
          'GCS 5xx (${response.statusCode}): ${response.body}',
          uri: Uri.parse(signedUrl),
        );
      } catch (e) {
        lastError = e;
        debugPrint('[upload] attempt $attempt threw: $e');
        if (e is HttpException && e.message.contains('rejected upload')) {
          rethrow; // 4xx — no point retrying
        }
        // network error or 5xx — retry below
      }

      if (attempt < _maxRetries - 1) {
        final delayMs = _retryBaseDelayMs * (1 << attempt);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    debugPrint('[upload] all retries exhausted; lastError=$lastError');
    return false;
  }
}
