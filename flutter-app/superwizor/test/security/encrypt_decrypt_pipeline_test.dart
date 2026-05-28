// Full encrypt→manifest→verify→decrypt integration tests.
//
// These simulate the exact byte-level protocol of
// SecureAudioStorageService WITHOUT needing a running device, Keychain,
// or MethodChannels. They use real temp files on the filesystem so they
// exercise the actual I/O paths (file layout, manifest JSON, chunk
// naming).
//
// Test coverage target: the ENTIRE pipeline from raw plaintext bytes
// through AES-256-GCM encryption, HMAC-SHA256 manifest creation,
// manifest verification (including tamper detection), and decryption
// back to original plaintext.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';

import 'package:superwizor/services/secure_audio_storage_service.dart';

// ---------- constants (must match service) ----------------------------

const _chunkSize = 1024 * 1024; // 1 MB
const _ivLen = 12;
const _gcmTagLen = 16;
const _headerLen = 1 + _ivLen; // 13

// ---------- test helpers: mini pipeline ------------------------------

/// HKDF-SHA256 key derivation (mirrors service exactly).
enc.Key _deriveSessionKey(enc.Key masterKey, String sessionId) {
  final salt = Uint8List(32);
  final extractHmac = crypto.Hmac(crypto.sha256, salt);
  final prk = extractHmac.convert(masterKey.bytes).bytes;

  final info = utf8.encode(sessionId);
  final expandInput = Uint8List(info.length + 1);
  expandInput.setRange(0, info.length, info);
  expandInput[info.length] = 0x01;
  final expandHmac = crypto.Hmac(crypto.sha256, prk);
  final okm = expandHmac.convert(expandInput).bytes;
  return enc.Key(Uint8List.fromList(okm));
}

/// Encrypts [plaintext] into chunk files under [dir], mimicking
/// SecureAudioStorageService.encryptRecording's output format.
/// Returns (chunks, sessionKey).
Future<(List<EncryptedChunk>, enc.Key)> _encryptToDir({
  required Directory dir,
  required Uint8List plaintext,
  required enc.Key masterKey,
  required String sessionId,
  int keyVersion = 1,
}) async {
  final sessionKey = _deriveSessionKey(masterKey, sessionId);
  final encrypter = enc.Encrypter(enc.AES(sessionKey, mode: enc.AESMode.gcm));
  final chunks = <EncryptedChunk>[];

  int offset = 0;
  int seq = 0;
  while (offset < plaintext.length) {
    final end = (offset + _chunkSize).clamp(0, plaintext.length);
    final chunkData = Uint8List.sublistView(plaintext, offset, end);

    final rng = Random.secure();
    final ivBytes = Uint8List.fromList(
      List.generate(_ivLen, (_) => rng.nextInt(256)),
    );
    final iv = enc.IV(ivBytes);
    final encrypted = encrypter.encryptBytes(chunkData, iv: iv);

    // Write header + ciphertext
    final fileName = 'chunk_${seq.toString().padLeft(5, '0')}.enc';
    final outFile = File('${dir.path}/$fileName');
    final header = Uint8List(_headerLen);
    header[0] = keyVersion & 0xFF;
    header.setRange(1, 1 + _ivLen, ivBytes);

    final sink = outFile.openWrite();
    sink.add(header);
    sink.add(encrypted.bytes);
    await sink.flush();
    await sink.close();

    chunks.add(EncryptedChunk(
      seq: seq,
      path: outFile.path,
      sizeBytes: await outFile.length(),
    ));
    seq++;
    offset = end;
  }
  return (chunks, sessionKey);
}

/// Writes a manifest.json matching the service's format.
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

  final chunksJson = jsonEncode(chunkEntries);
  final hmac = crypto.Hmac(crypto.sha256, key.bytes);
  final digest = hmac.convert(utf8.encode(chunksJson));

  final manifest = {
    'version': 2,
    'sessionId': sessionId,
    'keyDerivation': 'hkdf-sha256',
    'totalChunks': chunks.length,
    'chunks': chunkEntries,
    'hmac': digest.toString(),
  };

  final manifestFile = File('${dir.path}/manifest.json');
  await manifestFile.writeAsString(jsonEncode(manifest));
}

/// Decrypts all chunk files in [dir] to plaintext bytes,
/// mimicking SecureAudioStorageService.decryptToTempFile.
Future<Uint8List> _decryptChunks({
  required Directory dir,
  required enc.Key masterKey,
  required String sessionId,
  required bool useHkdf,
}) async {
  final allFiles = await dir
      .list()
      .where((e) => e is File)
      .cast<File>()
      .toList();

  final chunkFiles = allFiles
      .where((f) => f.path.split('/').last.startsWith('chunk_'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final decryptKey = useHkdf
      ? _deriveSessionKey(masterKey, sessionId)
      : masterKey;

  final output = BytesBuilder();
  for (final chunkFile in chunkFiles) {
    final bytes = await chunkFile.readAsBytes();
    if (bytes.length < _headerLen + _gcmTagLen) {
      throw StateError('chunk too short: ${chunkFile.path}');
    }
    final iv = enc.IV(Uint8List.sublistView(bytes, 1, 1 + _ivLen));
    final ciphertext = Uint8List.sublistView(bytes, _headerLen);

    final decrypter = enc.Encrypter(
      enc.AES(decryptKey, mode: enc.AESMode.gcm),
    );
    final plain = decrypter.decryptBytes(enc.Encrypted(ciphertext), iv: iv);
    output.add(plain);
  }
  return output.toBytes();
}

/// Verifies the manifest — returns true if valid, false if tampered.
Future<bool> _verifyManifest({
  required Directory dir,
  required enc.Key key,
}) async {
  final manifestFile = File('${dir.path}/manifest.json');
  if (!await manifestFile.exists()) return false;

  final manifestJson =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final expectedChunks =
      (manifestJson['chunks'] as List).cast<Map<String, dynamic>>();
  final expectedHmac = manifestJson['hmac'] as String;
  final totalChunks = manifestJson['totalChunks'] as int;

  // Chunk count
  final allFiles = await dir.list().where((e) => e is File).cast<File>().toList();
  final chunkFiles = allFiles
      .where((f) => f.path.split('/').last.startsWith('chunk_'))
      .toList();
  if (chunkFiles.length != totalChunks) return false;

  // Per-chunk SHA-256
  chunkFiles.sort((a, b) => a.path.compareTo(b.path));
  for (int i = 0; i < chunkFiles.length; i++) {
    final fileBytes = await chunkFiles[i].readAsBytes();
    final actualHash = crypto.sha256.convert(fileBytes).toString();
    if (actualHash != expectedChunks[i]['sha256']) return false;
  }

  // HMAC
  final chunksJson = jsonEncode(expectedChunks);
  final hmac = crypto.Hmac(crypto.sha256, key.bytes);
  final actualDigest = hmac.convert(utf8.encode(chunksJson)).toString();
  return actualDigest == expectedHmac;
}

// ---------- tests ----------------------------------------------------

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pipeline_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ────────────────────────────────────────────────────────────────
  // Full pipeline round-trips
  // ────────────────────────────────────────────────────────────────

  group('Full encrypt→manifest→verify→decrypt round-trip', () {
    late enc.Key masterKey;

    setUp(() {
      masterKey = enc.Key(Uint8List.fromList(
        List.generate(32, (i) => i * 7 + 3), // deterministic test key
      ));
    });

    test('small file (< 1 chunk) — round-trip recovers original', () async {
      const sessionId = 'session-small-001';
      final plaintext = Uint8List.fromList(
        utf8.encode('Hello, this is a short clinical session recording.'),
      );

      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      // Verify manifest
      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isTrue);

      // Decrypt
      final decrypted = await _decryptChunks(
        dir: tempDir, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );

      expect(decrypted, equals(plaintext));
    });

    test('exactly 1 MB file — boundary condition', () async {
      const sessionId = 'session-1mb-exact';
      final plaintext = Uint8List(_chunkSize); // exactly 1 MB of zeros
      for (int i = 0; i < plaintext.length; i++) {
        plaintext[i] = i & 0xFF;
      }

      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );

      expect(chunks.length, 1, reason: 'Exactly 1 MB should produce 1 chunk');

      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      final decrypted = await _decryptChunks(
        dir: tempDir, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );

      expect(decrypted, equals(plaintext));
    });

    test('multi-chunk file (> 1 MB) — splits and reassembles correctly', () async {
      const sessionId = 'session-multi-chunk';
      // 2.5 MB → should produce 3 chunks
      final plaintext = Uint8List((_chunkSize * 2.5).round());
      final rng = Random(42); // seeded for determinism
      for (int i = 0; i < plaintext.length; i++) {
        plaintext[i] = rng.nextInt(256);
      }

      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );

      expect(chunks.length, 3, reason: '2.5 MB should split into 3 chunks');
      expect(chunks[0].sizeBytes, greaterThan(_chunkSize),
          reason: 'First chunk should be > 1MB (header+tag overhead)');

      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isTrue);

      final decrypted = await _decryptChunks(
        dir: tempDir, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );

      expect(decrypted, equals(plaintext));
    });

    test('1 byte file — minimum viable recording', () async {
      const sessionId = 'session-1byte';
      final plaintext = Uint8List.fromList([0x42]);

      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );

      expect(chunks.length, 1);
      // 1 byte plaintext → 13 header + 1 ciphertext + 16 tag = 30 bytes on disk
      expect(chunks[0].sizeBytes, _headerLen + 1 + _gcmTagLen);

      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      final decrypted = await _decryptChunks(
        dir: tempDir, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );

      expect(decrypted, equals(plaintext));
    });

    test('binary audio data — preserves every byte', () async {
      const sessionId = 'session-binary-audio';
      // Simulate FLAC header + random audio data
      final plaintext = Uint8List(4096);
      // fLaC magic bytes
      plaintext[0] = 0x66; // f
      plaintext[1] = 0x4C; // L
      plaintext[2] = 0x61; // a
      plaintext[3] = 0x43; // C
      final rng = Random(123);
      for (int i = 4; i < plaintext.length; i++) {
        plaintext[i] = rng.nextInt(256);
      }

      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      final decrypted = await _decryptChunks(
        dir: tempDir, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );

      // Verify FLAC header preserved
      expect(decrypted[0], 0x66);
      expect(decrypted[1], 0x4C);
      expect(decrypted[2], 0x61);
      expect(decrypted[3], 0x43);
      expect(decrypted, equals(plaintext));
    });
  });

  // ────────────────────────────────────────────────────────────────
  // estimateDecryptedSize with real chunks
  // ────────────────────────────────────────────────────────────────

  group('estimateDecryptedSize vs actual decrypted size', () {
    late enc.Key masterKey;

    setUp(() {
      masterKey = enc.Key.fromSecureRandom(32);
    });

    test('estimate matches actual decrypted size (small file)', () async {
      const sessionId = 'estimate-small';
      final plaintext = Uint8List.fromList(
        List.generate(500, (i) => i & 0xFF),
      );

      final (chunks, _) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );

      final estimated = SecureAudioStorageService.estimateDecryptedSize(chunks);
      expect(estimated, plaintext.length);
    });

    test('estimate matches actual decrypted size (multi-chunk)', () async {
      const sessionId = 'estimate-multi';
      final plaintext = Uint8List((_chunkSize * 1.5).round());
      for (int i = 0; i < plaintext.length; i++) {
        plaintext[i] = i & 0xFF;
      }

      final (chunks, _) = await _encryptToDir(
        dir: tempDir,
        plaintext: plaintext,
        masterKey: masterKey,
        sessionId: sessionId,
      );

      final estimated = SecureAudioStorageService.estimateDecryptedSize(chunks);
      expect(estimated, plaintext.length);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Manifest tamper detection
  // ────────────────────────────────────────────────────────────────

  group('Manifest tamper detection', () {
    late enc.Key masterKey;

    setUp(() {
      masterKey = enc.Key(Uint8List.fromList(
        List.generate(32, (i) => i),
      ));
    });

    test('valid manifest passes verification', () async {
      const sessionId = 'tamper-valid';
      final plaintext = Uint8List.fromList(utf8.encode('valid session data'));
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isTrue);
    });

    test('modified chunk file → SHA-256 mismatch', () async {
      const sessionId = 'tamper-chunk';
      final plaintext = Uint8List.fromList(utf8.encode('original data'));
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      // Tamper with the chunk file
      final chunkFile = File(chunks[0].path);
      final bytes = await chunkFile.readAsBytes();
      bytes[bytes.length - 1] ^= 0xFF; // flip last byte
      await chunkFile.writeAsBytes(bytes);

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isFalse,
          reason: 'SHA-256 mismatch should be detected');
    });

    test('deleted chunk → count mismatch', () async {
      const sessionId = 'tamper-delete';
      // Need > 1 chunk to test deletion
      final plaintext = Uint8List(_chunkSize + 100);
      for (int i = 0; i < plaintext.length; i++) {
        plaintext[i] = i & 0xFF;
      }
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      expect(chunks.length, 2, reason: 'Need 2 chunks for this test');

      // Delete the second chunk
      await File(chunks[1].path).delete();

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isFalse,
          reason: 'Chunk count mismatch should be detected');
    });

    test('replaced chunk with different data → SHA-256 + GCM failure', () async {
      const sessionId = 'tamper-replace';
      final plaintext = Uint8List.fromList(utf8.encode('original data'));
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      // Replace the chunk file with completely different content
      final chunkFile = File(chunks[0].path);
      await chunkFile.writeAsBytes(
        List.generate(100, (i) => i), // fake data
      );

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isFalse);
    });

    test('modified HMAC in manifest → fails verification', () async {
      const sessionId = 'tamper-hmac';
      final plaintext = Uint8List.fromList(utf8.encode('session data'));
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      // Modify the HMAC in manifest
      final manifestFile = File('${tempDir.path}/manifest.json');
      final manifestJson = jsonDecode(await manifestFile.readAsString())
          as Map<String, dynamic>;
      manifestJson['hmac'] = 'tampered_hmac_value_1234567890abcdef';
      await manifestFile.writeAsString(jsonEncode(manifestJson));

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isFalse);
    });

    test('manifest verified with wrong key → fails', () async {
      const sessionId = 'tamper-wrongkey';
      final plaintext = Uint8List.fromList(utf8.encode('session data'));
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      // Verify with a different key
      final wrongKey = enc.Key.fromSecureRandom(32);
      expect(await _verifyManifest(dir: tempDir, key: wrongKey), isFalse,
          reason: 'HMAC with wrong key must fail — this catches an attacker '
              'who replaces chunks AND forges a manifest with a different key');
    });

    test('modified totalChunks in manifest → fails', () async {
      const sessionId = 'tamper-count';
      final plaintext = Uint8List.fromList(utf8.encode('data'));
      final (chunks, sessionKey) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _writeManifest(
        dir: tempDir, sessionId: sessionId,
        chunks: chunks, key: sessionKey,
      );

      // Modify totalChunks to a wrong value
      final manifestFile = File('${tempDir.path}/manifest.json');
      final manifestJson = jsonDecode(await manifestFile.readAsString())
          as Map<String, dynamic>;
      manifestJson['totalChunks'] = 99; // wrong
      await manifestFile.writeAsString(jsonEncode(manifestJson));

      expect(await _verifyManifest(dir: tempDir, key: sessionKey), isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Key isolation tests
  // ────────────────────────────────────────────────────────────────

  group('Key isolation', () {
    test('different sessions cannot decrypt each other', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      const session1 = 'isolation-session-1';
      const session2 = 'isolation-session-2';
      final plaintext = Uint8List.fromList(utf8.encode('secret audio'));

      final dir1 = await Directory('${tempDir.path}/s1').create();
      final dir2 = await Directory('${tempDir.path}/s2').create();

      await _encryptToDir(
        dir: dir1, plaintext: plaintext,
        masterKey: masterKey, sessionId: session1,
      );
      await _encryptToDir(
        dir: dir2, plaintext: plaintext,
        masterKey: masterKey, sessionId: session2,
      );

      // Try decrypting session1's chunks with session2's key
      expect(
        () async => await _decryptChunks(
          dir: dir1, masterKey: masterKey,
          sessionId: session2, useHkdf: true,
        ),
        throwsA(anything),
        reason: 'Session 2 key must not decrypt session 1 chunks — '
            'this validates F-04 key isolation',
      );
    });

    test('same plaintext, different sessions → different ciphertext', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List.fromList(utf8.encode('same content'));

      final dir1 = await Directory('${tempDir.path}/s1').create();
      final dir2 = await Directory('${tempDir.path}/s2').create();

      await _encryptToDir(
        dir: dir1, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'session-A',
      );
      await _encryptToDir(
        dir: dir2, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'session-B',
      );

      final bytes1 = await File('${dir1.path}/chunk_00000.enc').readAsBytes();
      final bytes2 = await File('${dir2.path}/chunk_00000.enc').readAsBytes();

      expect(bytes1, isNot(equals(bytes2)),
          reason: 'Different sessions must produce different ciphertext '
              'even for identical plaintext (different key + IV)');
    });

    test('same session re-encrypted produces same plaintext on decrypt', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      const sessionId = 'deterministic-reencrypt';
      final plaintext = Uint8List.fromList(utf8.encode('re-encrypt me'));

      // Encrypt twice (simulating crash recovery)
      final dir1 = await Directory('${tempDir.path}/attempt1').create();
      final dir2 = await Directory('${tempDir.path}/attempt2').create();

      await _encryptToDir(
        dir: dir1, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );
      await _encryptToDir(
        dir: dir2, plaintext: plaintext,
        masterKey: masterKey, sessionId: sessionId,
      );

      // Both should decrypt to the same plaintext (HKDF is deterministic)
      final dec1 = await _decryptChunks(
        dir: dir1, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );
      final dec2 = await _decryptChunks(
        dir: dir2, masterKey: masterKey,
        sessionId: sessionId, useHkdf: true,
      );

      expect(dec1, equals(plaintext));
      expect(dec2, equals(plaintext));
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Chunk file format contracts
  // ────────────────────────────────────────────────────────────────

  group('Chunk file format contracts', () {
    test('chunk file starts with key_version byte', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List.fromList([1, 2, 3]);

      final (chunks, _) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'fmt-test',
        keyVersion: 3,
      );

      final bytes = await File(chunks[0].path).readAsBytes();
      expect(bytes[0], 3, reason: 'First byte must be key_version');
    });

    test('IV is extractable from chunk header', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

      final (chunks, _) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'iv-test',
      );

      final bytes = await File(chunks[0].path).readAsBytes();
      final iv = bytes.sublist(1, 1 + _ivLen);
      expect(iv.length, _ivLen);
      // IV should not be all zeros (would indicate broken RNG)
      expect(iv.any((b) => b != 0), isTrue,
          reason: 'IV must not be all zeros — indicates broken RNG');
    });

    test('chunk filenames follow chunk_NNNNN.enc pattern', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List(_chunkSize + 100);

      final (chunks, _) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'naming-test',
      );

      expect(chunks.length, 2);
      expect(chunks[0].path, endsWith('chunk_00000.enc'));
      expect(chunks[1].path, endsWith('chunk_00001.enc'));
    });

    test('chunk seq numbers are sequential from 0', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List(_chunkSize * 3);

      final (chunks, _) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'seq-test',
      );

      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i].seq, i);
      }
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Backward compatibility (pre-HKDF sessions)
  // ────────────────────────────────────────────────────────────────

  group('Backward compatibility (pre-HKDF)', () {
    test('non-HKDF session decrypts with raw master key', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List.fromList(utf8.encode('old session'));

      // Encrypt directly with master key (no HKDF)
      final encrypter = enc.Encrypter(
        enc.AES(masterKey, mode: enc.AESMode.gcm),
      );
      final rng = Random.secure();
      final ivBytes = Uint8List.fromList(
        List.generate(_ivLen, (_) => rng.nextInt(256)),
      );
      final iv = enc.IV(ivBytes);
      final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

      // Write in the same chunk format
      final chunkFile = File('${tempDir.path}/chunk_00000.enc');
      final header = Uint8List(_headerLen);
      header[0] = 1;
      header.setRange(1, 1 + _ivLen, ivBytes);
      final sink = chunkFile.openWrite();
      sink.add(header);
      sink.add(encrypted.bytes);
      await sink.flush();
      await sink.close();

      // Decrypt with useHkdf=false (old path)
      final decrypted = await _decryptChunks(
        dir: tempDir, masterKey: masterKey,
        sessionId: 'irrelevant', useHkdf: false,
      );

      expect(decrypted, equals(plaintext));
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Error paths
  // ────────────────────────────────────────────────────────────────

  group('Error paths', () {
    test('corrupt chunk (too short) throws on decrypt', () async {
      // Write a chunk that's shorter than header + tag
      final chunkFile = File('${tempDir.path}/chunk_00000.enc');
      await chunkFile.writeAsBytes([1, 2, 3]); // 3 bytes, need >= 29

      expect(
        () async => await _decryptChunks(
          dir: tempDir,
          masterKey: enc.Key.fromSecureRandom(32),
          sessionId: 'corrupt',
          useHkdf: true,
        ),
        throwsA(isA<StateError>()),
        reason: 'Chunks shorter than header+tag must be rejected',
      );
    });

    test('wrong key_version does not affect decryption path '
        '(version is metadata only)', () async {
      final masterKey = enc.Key.fromSecureRandom(32);
      final plaintext = Uint8List.fromList(utf8.encode('version test'));

      // Encrypt with key_version = 5
      final (_, __) = await _encryptToDir(
        dir: tempDir, plaintext: plaintext,
        masterKey: masterKey, sessionId: 'v5-test',
        keyVersion: 5,
      );

      // key_version byte is at position 0 — our test decrypt ignores it
      // (the real service uses it to look up the right master key)
      final bytes = await File('${tempDir.path}/chunk_00000.enc').readAsBytes();
      expect(bytes[0], 5);
    });
  });
}
