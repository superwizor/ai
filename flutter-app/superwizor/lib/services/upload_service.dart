import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class UploadService {
  static const _maxRetries = 3;
  static const _retryBaseDelayMs = 1000;

  /// Combines chunk files into one m4a (placeholder — w prod używać ffmpeg lub native).
  /// W Fazie 2 zakładamy że chunki są wysyłane jako jeden ostatni plik
  /// (concatenation server-side w Cloud Functions albo client-side przez ffmpeg).
  Future<Uint8List> combineChunks(List<String> chunkPaths) async {
    final buffer = BytesBuilder();
    for (final path in chunkPaths) {
      final bytes = await File(path).readAsBytes();
      buffer.add(bytes);
    }
    return buffer.takeBytes();
  }

  /// Upload audio bytes to signed URL with retry policy.
  Future<bool> uploadToSignedUrl({
    required String signedUrl,
    required Uint8List audioBytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final md5Hash = md5.convert(audioBytes).toString();

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.put(
          Uri.parse(signedUrl),
          headers: {
            'Content-Type': contentType,
            'Content-MD5': md5Hash,
            'x-goog-meta-source': 'superwizor-mobile',
          },
          body: audioBytes,
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }

        // Retry on 5xx, fail on 4xx
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception('Upload rejected: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        if (attempt == _maxRetries - 1) rethrow;

        // Exponential backoff
        final delayMs = _retryBaseDelayMs * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return false;
  }
}
