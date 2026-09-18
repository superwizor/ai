// Per-user AES-256-GCM audio encryption service (D1).
//
// Responsibilities:
//   - Generate one master key per user on first login on this device,
//     stored in flutter_secure_storage (iOS Keychain, Android Keystore).
//   - Encrypt-after-recording: take the FLAC file from `record` package,
//     stream-read it in 1 MB chunks, AES-GCM each chunk with a fresh IV,
//     write encrypted .enc files to app documents directory.
//   - Securely delete the raw recording (zero-overwrite + unlink).
//   - Decrypt for upload: stream-read .enc files, GCM-verify, write to
//     a single temp file ready for HTTP PUT.
//
// File format per chunk:
//
//   [1 byte  key_version (uint8)]
//   [12 bytes GCM IV (random per chunk)]
//   [N bytes ciphertext]
//   [16 bytes GCM auth tag (appended by encrypter package)]
//
// Key rotation: bumping `key_version + 1` keeps old chunks decryptable
// with the old key (still in keystore) until they're successfully
// uploaded; only after all sessions are clear we purge older versions.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

class SecureAudioStorageService {
  SecureAudioStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _chunkSize = 1024 * 1024; // 1 MB
  static const _ivLen = 12; // GCM standard 96-bit IV
  static const _gcmTagLen = 16;
  static const _headerLen = 1 + _ivLen; // 1 byte version + IV

  static const _keyStoragePrefix = 'audio_master_key_v';
  static const _keyVersionStorage = 'audio_master_key_current_version';

  final FlutterSecureStorage _storage;

  // ---------- key management ----------

  /// Returns the current master key for the logged-in user, generating
  /// one on first call. The keychain item is bound to this device only
  /// (no iCloud sync), so logging in on a second device produces a
  /// fresh key — that's fine since the second device only needs to
  /// upload its own recordings.
  Future<({enc.Key key, int version})> _currentKeyAndVersion() async {
    final versionStr = await _storage.read(key: _keyVersionStorage);
    final version = int.tryParse(versionStr ?? '') ?? 1;
    final keyStorageKey = '$_keyStoragePrefix$version';
    final stored = await _storage.read(key: keyStorageKey);

    if (stored != null) {
      return (key: enc.Key(base64Decode(stored)), version: version);
    }

    // First-time bootstrap on this device.
    final fresh = enc.Key.fromSecureRandom(32); // 256 bits
    await _storage.write(key: keyStorageKey, value: base64Encode(fresh.bytes));
    await _storage.write(key: _keyVersionStorage, value: version.toString());
    return (key: fresh, version: version);
  }

  /// Used by upload-time decryption. Reads the key matching the
  /// version embedded in chunk headers.
  Future<enc.Key?> _keyForVersion(int version) async {
    final stored = await _storage.read(key: '$_keyStoragePrefix$version');
    if (stored == null) return null;
    return enc.Key(base64Decode(stored));
  }

  // ---------- size computation (no decryption) ----------

  /// Computes the exact decrypted plaintext size from encrypted chunk
  /// metadata.  Each chunk file contains:
  ///   [1 byte key_version] [12 bytes IV] [ciphertext] [16 bytes GCM tag]
  /// So: `plaintext_per_chunk = chunk.sizeBytes - _headerLen - _gcmTagLen`
  ///
  /// This lets callers (e.g. `_finishAndUpload`) obtain the size needed
  /// for `CreateAudioUploadRequest.estimatedSizeBytes` **without** an
  /// expensive decrypt→write→measure→delete round-trip.
  static int estimateDecryptedSize(List<EncryptedChunk> chunks) {
    const overhead = _headerLen + _gcmTagLen; // 13 + 16 = 29
    int total = 0;
    for (final c in chunks) {
      final plain = c.sizeBytes - overhead;
      if (plain > 0) total += plain;
    }
    return total;
  }

  // ---------- write path: encrypt the recorded FLAC ----------

  /// Reads [rawPath] in 1 MB chunks, AES-GCM-encrypts each, writes
  /// `chunk_NNNNN.enc` files to `<docs>/sessions/<sessionId>/`.
  /// On success the source file is securely deleted (zero-overwrite
  /// followed by unlink). Returns metadata about all written chunks.
  ///
  /// **Wznawianie przyrostowe** (2026-09-18): chunki z poprzedniej,
  /// przerwanej próby NIE są kasowane. Zachowujemy najdłuższy prefiks
  /// chunków pełnej długości i dopisujemy dalszy ciąg od pierwszego
  /// brakującego numeru. Wcześniej każde wejście czyściło katalog, więc
  /// próba przerwana limitem czasu zaczynała od zera — przy nagraniu,
  /// które raz nie zmieściło się w oknie, dawało to żywy zakleszczenie
  /// (sesja z 15.09.2026: 46 min / 76,8 MB, zero śladu na serwerze).
  ///
  /// [onProgress] dostaje ułamek 0..1 po każdym zapisanym chunku —
  /// to jest sygnał „jest postęp" dla `StallGuard` w UploadWorker.
  ///
  /// Wielokrotne wywołania dla tego samego [sessionId] są scalane:
  /// druga próba dopina się do trwającej, zamiast ścigać się z nią o
  /// ten sam katalog. Bez tego porzucony (a wciąż pracujący) izolat
  /// pisałby chunki pod nogami kolejnej próbie.
  Future<List<EncryptedChunk>> encryptRecording({
    required String rawPath,
    required String sessionId,
    void Function(double)? onProgress,
  }) {
    final trwajace = _inFlight[sessionId];
    if (trwajace != null) {
      debugPrint('[secure-audio] encryptRecording sessionId=$sessionId '
          'już trwa — dopinam się do niej zamiast startować drugą');
      return trwajace;
    }
    final future = _encryptRecordingOnce(
      rawPath: rawPath,
      sessionId: sessionId,
      onProgress: onProgress,
    );
    _inFlight[sessionId] = future;
    return future.whenComplete(() => _inFlight.remove(sessionId));
  }

  /// Trwające szyfrowania, po `sessionId`. Statyczne, bo warstwa
  /// uploadu tworzy własne instancje serwisu.
  static final Map<String, Future<List<EncryptedChunk>>> _inFlight = {};

  /// Rozmiar pliku chunka niosącego PEŁNY megabajt jawnego tekstu.
  /// Cokolwiek krótszego to albo ogon nagrania, albo urwany zapis —
  /// w obu przypadkach nie nadaje się do wznowienia.
  static const _fullChunkFileSize = _headerLen + _chunkSize + _gcmTagLen;

  Future<List<EncryptedChunk>> _encryptRecordingOnce({
    required String rawPath,
    required String sessionId,
    void Function(double)? onProgress,
  }) async {
    final raw = File(rawPath);
    if (!await raw.exists()) {
      throw StateError('rawPath does not exist: $rawPath');
    }

    final keyInfo = await _currentKeyAndVersion();
    final key = keyInfo.key;
    final keyVersion = keyInfo.version;

    final dir = await _sessionDir(sessionId);
    if (!await dir.exists()) await dir.create(recursive: true);

    // Najdłuższy ciągły prefiks chunków pełnej długości = robota,
    // której nie trzeba powtarzać. Reszta (dziury, ogon, urwany zapis)
    // leci do kosza, żeby wynik był spójnym zestawem.
    final doWznowienia = await _reusableChunkPrefix(dir);
    await _dropChunksFrom(dir, doWznowienia.length);

    final totalBytes = await raw.length();
    final totalChunks = (totalBytes / _chunkSize).ceil();
    if (doWznowienia.isNotEmpty) {
      debugPrint('[secure-audio] wznawiam sessionId=$sessionId od chunka '
          '${doWznowienia.length}/$totalChunks — '
          '${doWznowienia.length} MB już zaszyfrowane');
    }

    // Postęp z izolatu wraca portem: każdy zapisany chunk to jeden
    // komunikat. Mieszanie tego z wynikiem nie wchodzi w grę —
    // Isolate.run oddaje wynik dopiero na końcu, a strażnik postępu
    // musi widzieć ruch W TRAKCIE.
    final progressPort = ReceivePort();
    final progressSub = progressPort.listen((msg) {
      if (msg is int && totalChunks > 0) {
        onProgress?.call(((msg + 1) / totalChunks).clamp(0.0, 1.0));
      }
    });

    // Run the CPU-heavy AES-GCM loop in a BACKGROUND ISOLATE so it never
    // starves the main isolate's UI event loop. Encrypting a 60-90 min
    // FLAC (~130 MB) is hundreds of synchronous block-cipher ops + file
    // writes; on the main isolate that froze navigation for tens of
    // seconds. The key plugin (flutter_secure_storage) is main-isolate
    // only, so we resolve the key bytes here and hand them — with the
    // paths and params — to a pure-Dart isolate entry (encrypt pkg +
    // dart:io, no plugins). See also Option D: this only runs when the
    // upload is deferred offline; an online recording uploads its raw
    // FLAC directly and never reaches here.
    final List<EncryptedChunk> nowe;
    try {
      final sendPort = progressPort.sendPort;
      final startSeq = doWznowienia.length;
      final startOffset = startSeq * _chunkSize;
      nowe = await Isolate.run(
        () => _encryptChunksIsolate(_EncryptRequest(
          rawPath: rawPath,
          dirPath: dir.path,
          keyBytes: key.bytes,
          keyVersion: keyVersion,
          startSeq: startSeq,
          startOffset: startOffset,
          progress: sendPort,
        )),
      );
    } finally {
      await progressSub.cancel();
      progressPort.close();
    }

    await _secureDelete(raw);
    return [...doWznowienia, ...nowe];
  }

  /// Najdłuższy ciągły prefiks `chunk_00000..` o pełnej długości.
  /// Przerywa na pierwszej dziurze albo pierwszym krótszym pliku.
  Future<List<EncryptedChunk>> _reusableChunkPrefix(Directory dir) async {
    final wgNazwy = <String, File>{};
    await for (final e in dir.list()) {
      if (e is File &&
          p.basename(e.path).startsWith('chunk_') &&
          e.path.endsWith('.enc')) {
        wgNazwy[p.basename(e.path)] = e;
      }
    }
    final out = <EncryptedChunk>[];
    for (var seq = 0;; seq++) {
      final f = wgNazwy['chunk_${seq.toString().padLeft(5, '0')}.enc'];
      if (f == null) break;
      final len = await f.length();
      if (len != _fullChunkFileSize) break;
      out.add(EncryptedChunk(seq: seq, path: f.path, sizeBytes: len));
    }
    return out;
  }

  /// Kasuje chunki o numerze >= [fromSeq] oraz wszystko, co nie pasuje
  /// do schematu nazw — żeby po wznowieniu katalog był spójny.
  Future<void> _dropChunksFrom(Directory dir, int fromSeq) async {
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.enc')) continue;
      final nazwa = p.basename(e.path);
      final seq = int.tryParse(
          nazwa.replaceFirst('chunk_', '').replaceFirst('.enc', ''));
      if (seq != null && seq < fromSeq) continue;
      try {
        await e.delete();
      } catch (_) {}
    }
  }

  /// Inwentarz chunków sesji, w kolejności sekwencji. Pusta lista, gdy
  /// katalog nie istnieje albo nic w nim nie ma. Do idempotentnego
  /// wznowienia szyfrowania i diagnozy „czy audio naprawdę przepadło".
  Future<List<EncryptedChunk>> listChunks(String sessionId) async {
    final dir = await _sessionDir(sessionId);
    if (!await dir.exists()) return const [];
    final files = (await dir
            .list()
            .where((e) =>
                e is File &&
                p.basename(e.path).startsWith('chunk_') &&
                e.path.endsWith('.enc'))
            .toList())
        .cast<File>()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final out = <EncryptedChunk>[];
    for (var i = 0; i < files.length; i++) {
      out.add(EncryptedChunk(
        seq: i,
        path: files[i].path,
        sizeBytes: await files[i].length(),
      ));
    }
    return out;
  }

  // ---------- read path: decrypt for upload ----------

  /// Nazwa odszyfrowanego pliku oddawanego systemowemu uploaderowi.
  /// Leży w KATALOGU SESJI, nie w tmp/ — patrz [decryptForOsHandOff].
  static const osHandOffFileName = 'upload.flac';

  /// Odszyfrowuje chunki do pliku w katalogu sesji, gotowego do oddania
  /// systemowemu uploaderowi (iOS background URLSession).
  ///
  /// Dlaczego NIE tmp/, jak [decryptToTempFile]: transfer w tle trwa po
  /// zawieszeniu procesu, a `tmp/` jest kasowane przez system, gdy
  /// aplikacja nie działa. Katalog sesji jest tym samym miejscem, z
  /// którego ścieżka online oddaje `raw.flac`, więc nie wprowadzamy
  /// nowej klasy plików ani nowego miejsca z materiałem jawnym.
  ///
  /// Sprzątanie jest już załatwione: `cleanupSource` dla encryptedChunks
  /// woła `purgeSession`, a ta czyści KAŻDY plik w katalogu sesji.
  ///
  /// Idempotentne. Jeżeli plik już istnieje i ma niezerowy rozmiar,
  /// zwracamy go bez ponownego odszyfrowywania — ponowienie transferu
  /// nie może kosztować kolejnych minut CPU na baterii, bo to dokładnie
  /// ten scenariusz, który ta ścieżka naprawia.
  Future<File> decryptForOsHandOff({required String sessionId}) async {
    final dir = await _sessionDir(sessionId);
    final out = File(p.join(dir.path, osHandOffFileName));
    if (await out.exists() && await out.length() > 0) return out;
    return _decryptChunksTo(sessionId: sessionId, out: out);
  }

  /// Decrypts every `chunk_NNNNN.enc` in the session directory in seq
  /// order and writes the joined plaintext to a single temp file
  /// returned to the caller. Caller is responsible for deleting the
  /// temp file once the upload completes.
  Future<File> decryptToTempFile({required String sessionId}) async {
    final tempDir = await getTemporaryDirectory();
    // On macOS, the sandboxed temp directory (Caches/<bundleId>/) may not
    // exist yet — getTemporaryDirectory() returns the *expected* path but
    // doesn't guarantee the directory is created.  Without this guard,
    // File.openWrite() throws PathNotFoundException.
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return _decryptChunksTo(
      sessionId: sessionId,
      out: File(p.join(tempDir.path, 'session_$sessionId.flac')),
    );
  }

  /// Wspólny rdzeń obu ścieżek odszyfrowania. Różnią się WYŁĄCZNIE
  /// miejscem zapisu, więc reguły kolejności chunków, obsługi wersji
  /// klucza i pracy poza wątkiem UI muszą pozostać jedną implementacją.
  Future<File> _decryptChunksTo({
    required String sessionId,
    required File out,
  }) async {
    final dir = await _sessionDir(sessionId);
    if (!await dir.exists()) {
      throw StateError('no encrypted chunks for session $sessionId');
    }

    final chunks = (await dir
            .list()
            .where((e) => e is File && p.basename(e.path).startsWith('chunk_'))
            .toList())
        .cast<File>()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    if (chunks.isEmpty) {
      throw StateError('no encrypted chunks found in $dir');
    }

    // Resolve every key version that might be referenced by these chunks
    // on the MAIN isolate (the keychain plugin is main-isolate only),
    // then hand the bytes + chunk paths to a pure-Dart isolate that does
    // the CPU-heavy AES-GCM decrypt + reassembly off the UI thread.
    final keysByVersion = await _keyBytesByVersion();
    await Isolate.run(
      () => _decryptChunksIsolate(_DecryptRequest(
        chunkPaths: [for (final c in chunks) c.path],
        outPath: out.path,
        keysByVersion: keysByVersion,
      )),
    );
    return out;
  }

  /// Reads all stored master-key versions (1..current) into a sendable
  /// map for the decrypt isolate. Almost always a single entry (v1);
  /// covers key rotation where old chunks still reference an older key.
  Future<Map<int, Uint8List>> _keyBytesByVersion() async {
    final versionStr = await _storage.read(key: _keyVersionStorage);
    final current = int.tryParse(versionStr ?? '') ?? 1;
    final out = <int, Uint8List>{};
    for (var v = 1; v <= current; v++) {
      final k = await _keyForVersion(v);
      if (k != null) out[v] = Uint8List.fromList(k.bytes);
    }
    return out;
  }

  /// Called by UploadService after a successful PUT — wipes the
  /// session directory.
  Future<void> purgeSession(String sessionId) async {
    final dir = await _sessionDir(sessionId);
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is File) {
        await _secureDelete(entry);
      }
    }
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ---------- helpers ----------

  Future<Directory> _sessionDir(String sessionId) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'sessions', sessionId));
  }

  /// Best-effort secure delete: overwrite with zeros once, fsync, unlink.
  /// On modern flash storage this isn't perfect (wear-levelling), but
  /// it's better than a plain delete if the device is later compromised.
  /// iOS Data Protection encrypts at-rest anyway when the device is
  /// locked — this is belt-and-braces.
  Future<void> _secureDelete(File f) async {
    try {
      final size = await f.length();
      if (size > 0) {
        final raf = await f.open(mode: FileMode.write);
        try {
          const blockSize = 64 * 1024;
          final zeros = Uint8List(blockSize);
          int written = 0;
          while (written < size) {
            final remain = size - written;
            await raf.writeFrom(
                zeros, 0, remain >= blockSize ? blockSize : remain);
            written += blockSize;
          }
          await raf.flush();
        } finally {
          await raf.close();
        }
      }
      await f.delete();
    } catch (e) {
      // We tried — log and move on. On iOS the file is still
      // protected by Data Protection until the user wipes the device.
      debugPrint('secure delete failed for ${f.path}: $e');
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}

// ─── Isolate entry points (Option A) ────────────────────────────────
//
// Top-level, pure-Dart functions run via Isolate.run so the AES-GCM
// CPU work never blocks the main (UI) isolate. They use only the
// `encrypt` package + dart:io — NO plugins (flutter_secure_storage is
// main-isolate only, so key bytes are resolved on the main isolate and
// passed in). Private constants of SecureAudioStorageService are
// library-visible here (same file).

/// Sendable request for [_encryptChunksIsolate].
class _EncryptRequest {
  final String rawPath;
  final String dirPath;
  final Uint8List keyBytes;
  final int keyVersion;

  /// Numer pierwszego chunka do zapisania i odpowiadające mu
  /// przesunięcie w pliku źródłowym. Niezerowe przy wznowieniu
  /// przerwanej próby — chunki 0..startSeq-1 już leżą na dysku.
  final int startSeq;
  final int startOffset;

  /// Port, na który idzie numer każdego zapisanego chunka. Karmi
  /// strażnika postępu na głównym izolacie.
  final SendPort? progress;

  const _EncryptRequest({
    required this.rawPath,
    required this.dirPath,
    required this.keyBytes,
    required this.keyVersion,
    this.startSeq = 0,
    this.startOffset = 0,
    this.progress,
  });
}

/// Streams [_EncryptRequest.rawPath] in 1 MB chunks, AES-GCM-encrypts
/// each, writes `chunk_NNNNN.enc` into the session dir, returns chunk
/// metadata. Runs in a background isolate.
Future<List<EncryptedChunk>> _encryptChunksIsolate(_EncryptRequest req) async {
  final encrypter = enc.Encrypter(
      enc.AES(enc.Key(req.keyBytes), mode: enc.AESMode.gcm));
  final out = <EncryptedChunk>[];
  final buffer = BytesBuilder(copy: false);
  int seq = req.startSeq;

  Future<void> flushChunk(Uint8List data) async {
    final iv = enc.IV.fromSecureRandom(SecureAudioStorageService._ivLen);
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    final fileName = 'chunk_${seq.toString().padLeft(5, '0')}.enc';
    final outFile = File(p.join(req.dirPath, fileName));

    final header = Uint8List(SecureAudioStorageService._headerLen);
    header[0] = req.keyVersion & 0xFF;
    header.setRange(1, 1 + SecureAudioStorageService._ivLen, iv.bytes);

    final sink = outFile.openWrite();
    sink.add(header);
    sink.add(encrypted.bytes);
    await sink.flush();
    await sink.close();

    out.add(EncryptedChunk(
      seq: seq,
      path: outFile.path,
      sizeBytes: await outFile.length(),
    ));
    req.progress?.send(seq);
    seq++;
  }

  await for (final piece in File(req.rawPath).openRead(req.startOffset)) {
    buffer.add(piece);
    while (buffer.length >= SecureAudioStorageService._chunkSize) {
      final all = buffer.toBytes();
      final taken =
          Uint8List.sublistView(all, 0, SecureAudioStorageService._chunkSize);
      final remainder =
          Uint8List.sublistView(all, SecureAudioStorageService._chunkSize);
      buffer.clear();
      if (remainder.isNotEmpty) buffer.add(remainder);
      await flushChunk(taken);
    }
  }
  final tail = buffer.toBytes();
  if (tail.isNotEmpty) await flushChunk(tail);
  return out;
}

/// Sendable request for [_decryptChunksIsolate].
class _DecryptRequest {
  final List<String> chunkPaths; // sorted, seq order
  final String outPath;
  final Map<int, Uint8List> keysByVersion;
  const _DecryptRequest({
    required this.chunkPaths,
    required this.outPath,
    required this.keysByVersion,
  });
}

/// Decrypts each chunk (resolving its key by the version byte in the
/// header) and writes the joined plaintext to [outPath]. Runs in a
/// background isolate.
Future<void> _decryptChunksIsolate(_DecryptRequest req) async {
  final sink = File(req.outPath).openWrite();
  try {
    for (final cp in req.chunkPaths) {
      final bytes = await File(cp).readAsBytes();
      if (bytes.length <
          SecureAudioStorageService._headerLen +
              SecureAudioStorageService._gcmTagLen) {
        throw StateError('chunk too short: $cp');
      }
      final keyVersion = bytes[0];
      final iv = enc.IV(Uint8List.sublistView(
          bytes, 1, 1 + SecureAudioStorageService._ivLen));
      final ciphertext =
          Uint8List.sublistView(bytes, SecureAudioStorageService._headerLen);

      final keyBytes = req.keysByVersion[keyVersion];
      if (keyBytes == null) {
        throw StateError(
            'no key for chunk version $keyVersion (was the keychain wiped?)');
      }
      final decrypter =
          enc.Encrypter(enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm));
      sink.add(decrypter.decryptBytes(enc.Encrypted(ciphertext), iv: iv));
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
}
