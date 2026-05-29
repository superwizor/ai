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
//   - Write integrity manifest (HMAC-SHA256 over chunk SHA-256 hashes)
//     that detects tampering or corruption before upload (F-03 fix).
//   - Decrypt for upload: verify manifest, stream-read .enc files,
//     GCM-verify, write to a single temp file ready for HTTP PUT.
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

import 'package:crypto/crypto.dart' as crypto;

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'secure_random_service.dart';
import 'secure_audio_types.dart';

// Re-export types so existing `import 'secure_audio_storage_service.dart'`
// still exposes EncryptedChunk and IntegrityViolation.
export 'secure_audio_types.dart';



class SecureAudioStorageService {
  SecureAudioStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _manifestFileName = 'manifest.json';

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
    // F-06: Use hardware-backed CSPRNG for master key generation.
    final freshBytes = await SecureRandomService.instance.getRandomBytes(32);
    final fresh = enc.Key(freshBytes);
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

  /// F-04: Derive a per-session AES-256 key via HKDF-SHA256 (RFC 5869).
  ///
  /// IKM (input keying material) = master key from Keychain/Keystore
  /// info = sessionId (UTF-8 bytes)
  /// salt = empty (HKDF spec uses HashLen zero-bytes)
  /// output = 32 bytes = AES-256
  ///
  /// HKDF is deterministic: given the same (masterKey, sessionId)
  /// it always produces the same derived key, so:
  ///   - Re-encryption after a crash produces identical chunks
  ///   - Decrypt-for-upload can re-derive without storing the key
  ///
  /// Backward compat: sessions encrypted before F-04 used the master
  /// key directly. The manifest's `keyDerivation` field distinguishes
  /// old vs new sessions at decrypt time.
  static enc.Key _deriveSessionKey(enc.Key masterKey, String sessionId) {
    // HKDF-Extract: PRK = HMAC-SHA256(salt, IKM)
    // salt = 32 zero-bytes (SHA-256 hash length)
    final salt = Uint8List(32);
    final extractHmac = crypto.Hmac(crypto.sha256, salt);
    final prk = extractHmac.convert(masterKey.bytes).bytes;

    // HKDF-Expand: OKM = HMAC-SHA256(PRK, info || 0x01)
    // We only need 32 bytes = one iteration (SHA-256 output = 32B)
    // Domain separation label prevents key collision if HKDF is reused
    // for a different purpose (e.g. key wrapping) with the same sessionId.
    final info = utf8.encode('superwizor-audio-v1:$sessionId');
    final expandInput = Uint8List(info.length + 1);
    expandInput.setRange(0, info.length, info);
    expandInput[info.length] = 0x01; // counter byte
    final expandHmac = crypto.Hmac(crypto.sha256, prk);
    final okm = expandHmac.convert(expandInput).bytes;

    return enc.Key(Uint8List.fromList(okm));
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
    final masterKey = keyInfo.key;
    final keyVersion = keyInfo.version;

    // F-04: Derive a per-session key via HKDF-SHA256. The master key
    // is the IKM (input keying material), the sessionId is the info
    // parameter. This ensures each session is encrypted with a unique
    // key — compromise of one derived key doesn't expose other
    // sessions. HKDF is deterministic: same (masterKey, sessionId)
    // always yields the same derived key, so re-encryption after a
    // crash and upload-time decryption both work without storing the
    // derived key.
    final sessionKey = _deriveSessionKey(masterKey, sessionId);

    final dir = await _sessionDir(sessionId);
    // F-10: Atomic guard — wipe ALL files from a previous attempt
    // (or injected by an attacker on a jailbroken device). We delete
    // everything, not just .enc files, to prevent:
    //   - Stale chunks from a partial earlier encryption
    //   - Foreign files injected into the directory
    //   - Stale manifest.json from a previous run
    if (await dir.exists()) {
      await for (final entry in dir.list()) {
        if (entry is File) {
          try { await entry.delete(); } catch (_) {}
        }
      }
    } else {
      await dir.create(recursive: true);
    }

    final encrypter = enc.Encrypter(enc.AES(sessionKey, mode: enc.AESMode.gcm));
    final out = <EncryptedChunk>[];

    final input = raw.openRead();
    final buffer = BytesBuilder(copy: false);
    int seq = 0;

    Future<void> flushChunk(Uint8List data) async {
      // F-06: Use hardware-backed CSPRNG for IV generation.
      // SecureRandomService tries the native platform RNG first
      // (SecRandomCopyBytes on iOS, SecureRandom on Android) and
      // falls back to Dart's Random.secure() if unavailable.
      final ivBytes = await SecureRandomService.instance.getRandomBytes(_ivLen);
      final iv = enc.IV(ivBytes);
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

    // F-03: Write integrity manifest — HMAC-SHA256 chain over chunk
    // SHA-256 hashes, keyed by the per-session derived key. Verified
    // before decrypt-for-upload to detect tampering or corruption.
    await _writeManifest(
      dir: dir,
      sessionId: sessionId,
      chunks: out,
      key: sessionKey,
    );

    return out;
  }

  // ---------- integrity manifest ----------

  /// Writes `manifest.json` to [dir] containing SHA-256 of each chunk
  /// file and an HMAC-SHA256 over the serialised chunk list, keyed by
  /// the encryption master key. This detects:
  ///   - File deletion (chunk count mismatch)
  ///   - File replacement/corruption (SHA-256 mismatch)
  ///   - Manifest tampering (HMAC mismatch)
  Future<void> _writeManifest({
    required Directory dir,
    required String sessionId,
    required List<EncryptedChunk> chunks,
    required enc.Key key,
  }) async {
    final chunkEntries = <Map<String, dynamic>>[];
    for (final c in chunks) {
      final fileBytes = await File(c.path).readAsBytes();
      final hash = crypto.sha256.convert(fileBytes).toString();
      chunkEntries.add({
        'seq': c.seq,
        'sha256': hash,
        'sizeBytes': c.sizeBytes,
      });
    }

    // HMAC over the JSON-encoded chunk list — NOT over the raw file
    // content (that's already covered by per-chunk SHA-256). The HMAC
    // binds the manifest to the master key so an attacker can't forge
    // a valid manifest after replacing chunks.
    final chunksJson = jsonEncode(chunkEntries);
    final hmac = crypto.Hmac(crypto.sha256, key.bytes);
    final digest = hmac.convert(utf8.encode(chunksJson));

    final manifest = {
      'version': 2,
      'sessionId': sessionId,
      'keyDerivation': 'hkdf-sha256',
      'totalChunks': chunks.length,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'chunks': chunkEntries,
      'hmac': digest.toString(),
    };

    final manifestFile = File(p.join(dir.path, _manifestFileName));
    await manifestFile.writeAsString(jsonEncode(manifest));
  }

  /// Verifies the integrity manifest before decryption. Throws
  /// [IntegrityViolation] if any check fails. Returns the
  /// key derivation strategy from the manifest ('hkdf-sha256' for
  /// F-04+ sessions, null for pre-F-04 sessions without manifest).
  Future<String?> _verifyManifest({
    required Directory dir,
    required String sessionId,
    required List<File> chunkFiles,
  }) async {
    final manifestFile = File(p.join(dir.path, _manifestFileName));

    // Graceful degradation: sessions encrypted before F-03 won't have
    // a manifest. We skip verification for those — they're already
    // protected by AES-GCM auth tags per chunk.
    if (!await manifestFile.exists()) return null;

    final manifestJson =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final expectedChunks =
        (manifestJson['chunks'] as List).cast<Map<String, dynamic>>();
    final expectedHmac = manifestJson['hmac'] as String;
    final totalChunks = manifestJson['totalChunks'] as int;
    final keyDerivation = manifestJson['keyDerivation'] as String?;

    // 1. Chunk count check
    if (chunkFiles.length != totalChunks) {
      throw IntegrityViolation(
        'chunk count mismatch: expected $totalChunks, found ${chunkFiles.length}',
      );
    }

    // 2. Per-chunk SHA-256 check
    for (int i = 0; i < chunkFiles.length; i++) {
      final fileBytes = await chunkFiles[i].readAsBytes();
      final actualHash = crypto.sha256.convert(fileBytes).toString();
      final expectedHash = expectedChunks[i]['sha256'] as String;
      if (actualHash != expectedHash) {
        throw IntegrityViolation(
          'SHA-256 mismatch on chunk $i: '
          'expected ${expectedHash.substring(0, 12)}…, '
          'got ${actualHash.substring(0, 12)}…',
        );
      }
    }

    // 3. HMAC verification — re-derive from chunk list + correct key
    final chunksJson = jsonEncode(expectedChunks);
    final firstChunkBytes = await chunkFiles.first.readAsBytes();
    final keyVersion = firstChunkBytes[0];
    final masterKey = await _keyForVersion(keyVersion);
    if (masterKey == null) {
      throw IntegrityViolation(
        'cannot verify HMAC: no key for version $keyVersion',
      );
    }
    // F-04: use per-session derived key for HMAC if manifest says so
    final hmacKey = (keyDerivation == 'hkdf-sha256')
        ? _deriveSessionKey(masterKey, sessionId)
        : masterKey;
    final hmac = crypto.Hmac(crypto.sha256, hmacKey.bytes);
    final actualDigest = hmac.convert(utf8.encode(chunksJson)).toString();
    if (actualDigest != expectedHmac) {
      throw IntegrityViolation('manifest HMAC mismatch — tampering detected');
    }
    return keyDerivation;
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

    final allFiles = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();

    final chunks = allFiles
        .where((f) => p.basename(f.path).startsWith('chunk_'))
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    if (chunks.isEmpty) {
      throw StateError('no encrypted chunks found in $dir');
    }

    // F-10: Foreign file detection — ensure the directory contains
    // ONLY chunk files and manifest.json. Any other file (injected
    // by an attacker on a jailbroken device, or left by a rogue
    // process) is a red flag.
    final allowedNames = {
      ...chunks.map((f) => p.basename(f.path)),
      _manifestFileName,
    };
    final foreign = allFiles
        .where((f) => !allowedNames.contains(p.basename(f.path)))
        .toList();
    if (foreign.isNotEmpty) {
      final names = foreign.map((f) => p.basename(f.path)).join(', ');
      throw IntegrityViolation(
        'foreign files detected in session directory: $names',
      );
    }

    // F-03: Verify integrity manifest before decryption. If the
    // manifest exists and any check fails, IntegrityViolation is
    // thrown and the upload is aborted.
    // F-04: The returned keyDerivation tells us whether to use
    // a per-session derived key or the raw master key.
    final keyDerivation = await _verifyManifest(
      dir: dir,
      sessionId: sessionId,
      chunkFiles: chunks,
    );
    final useHkdf = (keyDerivation == 'hkdf-sha256');

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

        final masterKey = await _keyForVersion(keyVersion);
        if (masterKey == null) {
          throw StateError(
              'no key for chunk version $keyVersion (was the keychain wiped?)');
        }
        // F-04: derive per-session key if this session used HKDF
        final decryptKey = useHkdf
            ? _deriveSessionKey(masterKey, sessionId)
            : masterKey;
        final decrypter = enc.Encrypter(enc.AES(decryptKey, mode: enc.AESMode.gcm));
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
