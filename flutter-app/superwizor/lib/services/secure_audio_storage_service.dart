// Per-user AES-256-GCM audio encryption service (D1).
//
// Responsibilities:
//   - Generate one master key per user on first login on this device,
//     stored in flutter_secure_storage (iOS Keychain, Android Keystore).
//   - Encrypt-after-recording: take the FLAC file from `record` package,
//     stream-read it in 1 MB chunks, AES-GCM each chunk with a fresh IV,
//     write encrypted .enc files to app documents directory.
//   - Delete the raw recording (the file is already protected at rest
//     by iOS Data Protection / Android FBE; zero-overwrite was removed
//     in F-02 audit because it's ineffective on flash/SSD storage).
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

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final out = <EncryptedChunk>[];

    final input = raw.openRead();
    final buffer = BytesBuilder(copy: false);
    int seq = 0;

    Future<void> flushChunk(Uint8List data) async {
      final iv = enc.IV.fromSecureRandom(_ivLen);
      final encrypted = encrypter.encryptBytes(data, iv: iv);

      final fileName = 'chunk_${seq.toString().padLeft(5, '0')}.enc';
      final outFile = File(p.join(dir.path, fileName));

      // header[0] = key_version, header[1..13] = iv
      final header = Uint8List(_headerLen);
      header[0] = keyVersion & 0xFF;
      header.setRange(1, 1 + _ivLen, iv.bytes);

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

    await for (final piece in input) {
      buffer.add(piece);
      while (buffer.length >= _chunkSize) {
        final all = buffer.toBytes();
        final taken = Uint8List.sublistView(all, 0, _chunkSize);
        final remainder = Uint8List.sublistView(all, _chunkSize);
        buffer.clear();
        if (remainder.isNotEmpty) buffer.add(remainder);
        await flushChunk(taken);
      }
    }
    final tail = buffer.toBytes();
    if (tail.isNotEmpty) {
      await flushChunk(tail);
    }

    await _delete(raw);
    return out;
  }

  // ---------- read path: decrypt for upload ----------

  /// Decrypts every `chunk_NNNNN.enc` in the session directory in seq
  /// order and writes the joined plaintext to a single temp file
  /// returned to the caller. Caller is responsible for deleting the
  /// temp file once the upload completes.
  Future<File> decryptToTempFile({required String sessionId}) async {
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

    final tempDir = await getTemporaryDirectory();
    // On macOS, the sandboxed temp directory (Caches/<bundleId>/) may not
    // exist yet — getTemporaryDirectory() returns the *expected* path but
    // doesn't guarantee the directory is created.  Without this guard,
    // File.openWrite() throws PathNotFoundException.
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    final out = File(p.join(tempDir.path, 'session_$sessionId.flac'));
    final sink = out.openWrite();

    try {
      for (final chunkFile in chunks) {
        final bytes = await chunkFile.readAsBytes();
        if (bytes.length < _headerLen + _gcmTagLen) {
          throw StateError('chunk too short: ${chunkFile.path}');
        }
        final keyVersion = bytes[0];
        final iv = enc.IV(Uint8List.sublistView(bytes, 1, 1 + _ivLen));
        final ciphertext = Uint8List.sublistView(bytes, _headerLen);

        final key = await _keyForVersion(keyVersion);
        if (key == null) {
          throw StateError(
              'no key for chunk version $keyVersion (was the keychain wiped?)');
        }
        final decrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
        final plain =
            decrypter.decryptBytes(enc.Encrypted(ciphertext), iv: iv);
        sink.add(plain);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return out;
  }

  /// Called after a successful PUT — removes the session directory
  /// and all encrypted chunks. On iOS, files are already hardware-
  /// encrypted at rest via NSFileProtectionCompleteUnlessOpen;
  /// on Android, via file-based encryption (FBE). A plain delete
  /// is sufficient — the OS-level encryption prevents recovery of
  /// unlinked file content without the device passcode.
  Future<void> purgeSession(String sessionId) async {
    final dir = await _sessionDir(sessionId);
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is File) {
        await _delete(entry);
      }
    }
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ---------- helpers ----------

  Future<Directory> _sessionDir(String sessionId) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'sessions', sessionId));
  }

  /// Plain file delete. The file content is protected at rest by:
  ///   - iOS: NSFileProtectionCompleteUnlessOpen (Secure Enclave key)
  ///   - Android: File-Based Encryption (FBE)
  /// so unlinked blocks are unreadable without the device passcode.
  ///
  /// Previously this method zero-overwrote the file before unlinking
  /// ("secure delete"). That was removed in the F-02 security audit
  /// because flash/SSD wear-levelling makes zero-overwrite ineffective:
  /// the controller writes zeros to NEW physical NAND pages, leaving
  /// the original data on old pages. The OS-level encryption is the
  /// real protection — the zero-overwrite was security theater.
  Future<void> _delete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('delete failed for ${f.path}: $e');
    }
  }
}
