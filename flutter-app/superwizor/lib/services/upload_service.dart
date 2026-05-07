import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UploadService {
  static const _maxRetries = 3;
  static const _retryBaseDelayMs = 1000;

  /// Odszyfrowuje chunki i łączy je do tymczasowego pliku
  /// (Dzięki temu nie ładujemy całego 1h nagrania do RAMu!)
  Future<File> combineAndDecryptToTemp(List<String> chunkPaths, enc.Key key, enc.IV iv) async {
    final tempDir = await getTemporaryDirectory();
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    final tempFile = File(p.join(tempDir.path, 'upload_buffer_${DateTime.now().millisecondsSinceEpoch}.flac'));
    
    final sink = tempFile.openWrite();
    final encrypter = enc.Encrypter(enc.AES(key));

    for (final path in chunkPaths) {
      final bytes = await File(path).readAsBytes();
      final decrypted = encrypter.decryptBytes(enc.Encrypted(bytes), iv: iv);
      sink.add(decrypted);
    }
    await sink.flush();
    await sink.close();
    
    return tempFile;
  }

  Future<bool> uploadFileToSignedUrl({
    required String signedUrl,
    required File file,
    required String contentType,
  }) async {


    final length = await file.length();

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final request = http.StreamedRequest('PUT', Uri.parse(signedUrl));
        request.headers['Content-Type'] = contentType;
        request.headers['Content-Length'] = length.toString();
        request.headers['x-goog-meta-source'] = 'superwizor-mobile';

        final stream = file.openRead();
        stream.listen(
          (data) => request.sink.add(data),
          onDone: () => request.sink.close(),
          onError: (e) => request.sink.addError(e!),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception('Upload rejected: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        if (attempt == _maxRetries - 1) rethrow;

        final delayMs = _retryBaseDelayMs * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return false;
  }
}
