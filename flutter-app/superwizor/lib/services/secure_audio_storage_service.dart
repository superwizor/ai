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
  /// **Atomicity guard**: if a previous encryption attempt for the same
  /// [sessionId] left partial chunks on disk (crash, out-of-space),
  /// they are wiped before starting so the caller always gets a
  /// consistent set.
  Future<List<EncryptedChunk>> encryptRecording({
    required String rawPath,
    required String sessionId,
  }) async {
    final raw = File(rawPath);
    if (!await raw.exists()) {
      throw StateError('rawPath does not exist: $rawPath');
    }

    final keyInfo = await _currentKeyAndVersion();
    final key = keyInfo.key;
    final keyVersion = keyInfo.version;

    final dir = await _sessionDir(sessionId);
    // Atomic guard: wipe stale chunks from a previous failed attempt
    // so we don't end up with a mix of old + new chunks.
    if (await dir.exists()) {
      await for (final entry in dir.list()) {
        if (entry is File && entry.path.endsWith('.enc')) {
          try { await entry.delete(); } catch (_) {}
        }
      }
    } else {
      await dir.create(recursive: true);
    }

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
    final chunks = await Isolate.run(
      () => _encryptChunksIsolate(_EncryptRequest(
        rawPath: rawPath,
        dirPath: dir.path,
        keyBytes: key.bytes,
        keyVersion: keyVersion,
      )),
    );

    await _secureDelete(raw);
    return chunks;
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
  const _EncryptRequest({
    required this.rawPath,
    required this.dirPath,
    required this.keyBytes,
    required this.keyVersion,
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
  int seq = 0;

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
    seq++;
  }

  await for (final piece in File(req.rawPath).openRead()) {
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
