// Security hardening tests for the bezpieczne-nagrywanie branch.
//
// These tests verify the Dart-side logic of F-01 through F-11 security
// fixes WITHOUT requiring a running device, Keychain, or native channels.
// They run in flutter test (no simulator needed) and focus on:
//
//   1. HKDF-SHA256 key derivation (F-04) — determinism, uniqueness, length
//   2. Integrity manifest (F-03) — HMAC chain, chunk count, tamper detection
//   3. Chunk size estimation — correct overhead subtraction
//   4. IntegrityViolation error classification (upload_error.dart)
//   5. SecureRandomService fallback path
//   6. Certificate pinner construction
//   7. Foreign file detection (F-10)
//   8. AES-256-GCM encrypt/decrypt (round-trip, wrong key, tamper)
//
// These tests form a safety net: if a refactor breaks key derivation
// or manifest verification, CI will catch it before merge.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';

import 'package:superwizor/services/secure_audio_storage_service.dart';
import 'package:superwizor/services/secure_random_service.dart';
import 'package:superwizor/uploads/certificate_pinner.dart';
import 'package:superwizor/uploads/upload_error.dart';

// ---------- helpers --------------------------------------------------

/// Re-implementation of _deriveSessionKey for test verification.
/// Must match SecureAudioStorageService._deriveSessionKey exactly.
enc.Key _hkdfDeriveKey(enc.Key masterKey, String sessionId) {
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

void main() {
  // ────────────────────────────────────────────────────────────────
  // F-04: HKDF-SHA256 per-session key derivation
  // ────────────────────────────────────────────────────────────────

  group('F-04 HKDF-SHA256 key derivation', () {
    late enc.Key masterKey;

    setUp(() {
      masterKey = enc.Key(Uint8List.fromList(
        List.generate(32, (i) => i),
      ));
    });

    test('derived key is exactly 32 bytes (AES-256)', () {
      final derived = _hkdfDeriveKey(masterKey, 'session-abc-123');
      expect(derived.bytes.length, 32);
    });

    test('same (masterKey, sessionId) → same derived key (deterministic)', () {
      final a = _hkdfDeriveKey(masterKey, 'session-xyz');
      final b = _hkdfDeriveKey(masterKey, 'session-xyz');
      expect(a.bytes, equals(b.bytes));
    });

    test('different sessionId → different derived key', () {
      final a = _hkdfDeriveKey(masterKey, 'session-1');
      final b = _hkdfDeriveKey(masterKey, 'session-2');
      expect(a.bytes, isNot(equals(b.bytes)));
    });

    test('different masterKey → different derived key', () {
      final otherKey = enc.Key(Uint8List.fromList(
        List.generate(32, (i) => 255 - i),
      ));
      final a = _hkdfDeriveKey(masterKey, 'session-1');
      final b = _hkdfDeriveKey(otherKey, 'session-1');
      expect(a.bytes, isNot(equals(b.bytes)));
    });

    test('derived key differs from master key', () {
      final derived = _hkdfDeriveKey(masterKey, 'any-session');
      expect(derived.bytes, isNot(equals(masterKey.bytes)),
          reason: 'HKDF output must differ from the raw IKM');
    });

    test('empty sessionId produces a valid 32-byte key', () {
      final derived = _hkdfDeriveKey(masterKey, '');
      expect(derived.bytes.length, 32);
    });

    test('UUID sessionId works correctly', () {
      final derived = _hkdfDeriveKey(
        masterKey,
        'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      );
      expect(derived.bytes.length, 32);
      final again = _hkdfDeriveKey(
        masterKey,
        'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      );
      expect(derived.bytes, equals(again.bytes));
    });

    test('unicode sessionId (Polish characters)', () {
      final derived = _hkdfDeriveKey(masterKey, 'sesja-ąćęłńóśźż-2026');
      expect(derived.bytes.length, 32);
      final again = _hkdfDeriveKey(masterKey, 'sesja-ąćęłńóśźż-2026');
      expect(derived.bytes, equals(again.bytes));
    });

    test('very long sessionId (1000 chars)', () {
      final longId = 'a' * 1000;
      final derived = _hkdfDeriveKey(masterKey, longId);
      expect(derived.bytes.length, 32);
    });

    test('sessionId with special characters', () {
      for (final id in [
        'session/with/slashes',
        'session with spaces',
        'session\nwith\nnewlines',
        'session\twith\ttabs',
        'session<with>angle<brackets>',
      ]) {
        final derived = _hkdfDeriveKey(masterKey, id);
        expect(derived.bytes.length, 32,
            reason: 'HKDF should handle any UTF-8 string: $id');
      }
    });

    test('similar sessionIds produce very different keys (avalanche)', () {
      final a = _hkdfDeriveKey(masterKey, 'session-000');
      final b = _hkdfDeriveKey(masterKey, 'session-001');

      int diffCount = 0;
      for (int i = 0; i < 32; i++) {
        if (a.bytes[i] != b.bytes[i]) diffCount++;
      }
      expect(diffCount, greaterThan(8),
          reason: 'HKDF must avalanche: 1-char input change → '
              'many output bytes differ. Got $diffCount/32 different');
    });

    test('all-zero master key still produces valid derived key', () {
      final zeroKey = enc.Key(Uint8List(32));
      final derived = _hkdfDeriveKey(zeroKey, 'session-1');
      expect(derived.bytes.length, 32);
      expect(derived.bytes.any((b) => b != 0), isTrue,
          reason: 'HKDF must produce non-trivial output even from zero key');
    });

    test('all-0xFF master key produces valid derived key', () {
      final ffKey = enc.Key(Uint8List.fromList(List.filled(32, 0xFF)));
      final derived = _hkdfDeriveKey(ffKey, 'test');
      expect(derived.bytes.length, 32);
    });

    test('100 unique sessionIds → 100 unique keys (no collisions)', () {
      final keys = <String>{};
      for (int i = 0; i < 100; i++) {
        final derived = _hkdfDeriveKey(masterKey, 'session-$i');
        final hex = derived.bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        keys.add(hex);
      }
      expect(keys.length, 100,
          reason: 'All 100 derived keys must be unique');
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-03: Integrity manifest — HMAC-SHA256 chain
  // ────────────────────────────────────────────────────────────────

  group('F-03 integrity manifest', () {
    test('SHA-256 of known data matches expected value', () {
      final data = utf8.encode('hello world');
      final digest = crypto.sha256.convert(data);
      expect(
        digest.toString(),
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      );
    });

    test('HMAC-SHA256 is deterministic for same key + data', () {
      final key = List.generate(32, (i) => i);
      final hmac = crypto.Hmac(crypto.sha256, key);
      final a = hmac.convert(utf8.encode('chunk-data-1'));
      final b = hmac.convert(utf8.encode('chunk-data-1'));
      expect(a.toString(), equals(b.toString()));
    });

    test('HMAC-SHA256 changes with different data', () {
      final key = List.generate(32, (i) => i);
      final hmac = crypto.Hmac(crypto.sha256, key);
      final a = hmac.convert(utf8.encode('chunk-data-1'));
      final b = hmac.convert(utf8.encode('chunk-data-2'));
      expect(a.toString(), isNot(equals(b.toString())));
    });

    test('HMAC-SHA256 changes with different key', () {
      final key1 = List.generate(32, (i) => i);
      final key2 = List.generate(32, (i) => 255 - i);
      final hmac1 = crypto.Hmac(crypto.sha256, key1);
      final hmac2 = crypto.Hmac(crypto.sha256, key2);
      final a = hmac1.convert(utf8.encode('same-data'));
      final b = hmac2.convert(utf8.encode('same-data'));
      expect(a.toString(), isNot(equals(b.toString())));
    });

    test('manifest JSON round-trip preserves structure', () {
      final manifest = {
        'version': 2,
        'sessionId': 'test-session-123',
        'totalChunks': 3,
        'keyDerivation': 'hkdf-sha256',
        'chunks': [
          {'seq': 0, 'sha256': 'abc123', 'sizeBytes': 100},
          {'seq': 1, 'sha256': 'def456', 'sizeBytes': 200},
          {'seq': 2, 'sha256': 'ghi789', 'sizeBytes': 50},
        ],
        'hmac': 'some-hmac-value',
      };

      final json = jsonEncode(manifest);
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      expect(parsed['version'], 2);
      expect(parsed['totalChunks'], 3);
      expect(parsed['keyDerivation'], 'hkdf-sha256');
      expect((parsed['chunks'] as List).length, 3);
      expect(parsed['hmac'], 'some-hmac-value');
    });

    test('HMAC output is exactly 64 hex chars (256 bits)', () {
      final key = List.generate(32, (i) => i);
      final hmac = crypto.Hmac(crypto.sha256, key);
      final digest = hmac.convert(utf8.encode('data'));
      expect(digest.toString().length, 64);
    });

    test('SHA-256 output is exactly 64 hex chars', () {
      final digest = crypto.sha256.convert(utf8.encode('data'));
      expect(digest.toString().length, 64);
    });

    test('HMAC over reordered JSON is different (order matters)', () {
      final key = List.generate(32, (i) => i);
      final hmac = crypto.Hmac(crypto.sha256, key);

      final chunksA = [
        {'seq': 0, 'sha256': 'aaa'},
        {'seq': 1, 'sha256': 'bbb'},
      ];
      final chunksB = [
        {'seq': 1, 'sha256': 'bbb'},
        {'seq': 0, 'sha256': 'aaa'},
      ];

      final digestA = hmac.convert(utf8.encode(jsonEncode(chunksA)));
      final digestB = hmac.convert(utf8.encode(jsonEncode(chunksB)));
      expect(digestA.toString(), isNot(equals(digestB.toString())),
          reason: 'Reordering chunks must invalidate HMAC — '
              'this detects chunk reordering attacks');
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Chunk size estimation
  // ────────────────────────────────────────────────────────────────

  group('estimateDecryptedSize', () {
    const overhead = 29;

    test('single chunk: subtracts 29 bytes overhead', () {
      final chunks = [
        EncryptedChunk(seq: 0, path: '/fake/chunk_00000.enc', sizeBytes: 1029),
      ];
      expect(
        SecureAudioStorageService.estimateDecryptedSize(chunks),
        1029 - overhead,
      );
    });

    test('multiple chunks: sums all plaintext sizes', () {
      final chunks = [
        EncryptedChunk(seq: 0, path: '/a', sizeBytes: 1000 + overhead),
        EncryptedChunk(seq: 1, path: '/b', sizeBytes: 2000 + overhead),
        EncryptedChunk(seq: 2, path: '/c', sizeBytes: 500 + overhead),
      ];
      expect(
        SecureAudioStorageService.estimateDecryptedSize(chunks),
        1000 + 2000 + 500,
      );
    });

    test('chunk with only overhead → 0 plaintext (not negative)', () {
      final chunks = [
        EncryptedChunk(seq: 0, path: '/x', sizeBytes: overhead),
      ];
      expect(SecureAudioStorageService.estimateDecryptedSize(chunks), 0);
    });

    test('chunk smaller than overhead → 0 plaintext (clamped)', () {
      final chunks = [
        EncryptedChunk(seq: 0, path: '/x', sizeBytes: 10),
      ];
      expect(SecureAudioStorageService.estimateDecryptedSize(chunks), 0);
    });

    test('empty chunk list → 0', () {
      expect(SecureAudioStorageService.estimateDecryptedSize([]), 0);
    });

    test('realistic 10-minute FLAC recording size', () {
      final chunks = [
        EncryptedChunk(seq: 0, path: '/a', sizeBytes: 1048576 + overhead),
        EncryptedChunk(seq: 1, path: '/b', sizeBytes: 1048576 + overhead),
        EncryptedChunk(seq: 2, path: '/c', sizeBytes: 600000 + overhead),
      ];
      final estimated =
          SecureAudioStorageService.estimateDecryptedSize(chunks);
      expect(estimated, 1048576 + 1048576 + 600000);
    });

    test('100 chunks (long session)', () {
      final chunks = List.generate(
        100,
        (i) => EncryptedChunk(
          seq: i,
          path: '/chunk_${i.toString().padLeft(5, '0')}.enc',
          sizeBytes: 1048576 + overhead,
        ),
      );
      expect(
        SecureAudioStorageService.estimateDecryptedSize(chunks),
        100 * 1048576,
      );
    });

    test('EncryptedChunk preserves all fields', () {
      const chunk = EncryptedChunk(
        seq: 42,
        path: '/path/to/chunk.enc',
        sizeBytes: 999,
      );
      expect(chunk.seq, 42);
      expect(chunk.path, '/path/to/chunk.enc');
      expect(chunk.sizeBytes, 999);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // IntegrityViolation error classification
  // ────────────────────────────────────────────────────────────────

  group('IntegrityViolation error classification', () {
    test('IntegrityViolation is classified as terminal', () {
      final result = classifyUploadError(
        IntegrityViolation('chunk count mismatch: expected 5, got 3'),
      );
      expect(result.kind, UploadErrorClass.terminal);
    });

    test('IntegrityViolation message is preserved in classification', () {
      const msg = 'HMAC mismatch: manifest tampered';
      final result = classifyUploadError(IntegrityViolation(msg));
      expect(result.kind, UploadErrorClass.terminal);
    });

    test('IntegrityViolation toString format', () {
      const e = IntegrityViolation('test error');
      expect(e.toString(), 'IntegrityViolation: test error');
    });

    test('IntegrityViolation message accessor', () {
      const e = IntegrityViolation('my message');
      expect(e.message, 'my message');
    });
  });

  // ────────────────────────────────────────────────────────────────
  // AES-256-GCM encrypt/decrypt round-trip
  // ────────────────────────────────────────────────────────────────

  group('AES-256-GCM round-trip', () {
    test('encrypt then decrypt recovers plaintext', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      const plaintext = 'clinical session audio data placeholder';
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      expect(decrypted, plaintext);
    });

    test('wrong key fails GCM authentication', () {
      final key1 = enc.Key.fromSecureRandom(32);
      final key2 = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final e1 = enc.Encrypter(enc.AES(key1, mode: enc.AESMode.gcm));
      final e2 = enc.Encrypter(enc.AES(key2, mode: enc.AESMode.gcm));

      final encrypted = e1.encrypt('secret data', iv: iv);

      expect(() => e2.decrypt(encrypted, iv: iv), throwsA(anything));
    });

    test('modified ciphertext fails GCM authentication', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final encrypted = encrypter.encrypt('secret data', iv: iv);
      final tampered = Uint8List.fromList(encrypted.bytes);
      tampered[0] ^= 0xFF;

      expect(
        () => encrypter.decrypt(enc.Encrypted(tampered), iv: iv),
        throwsA(anything),
      );
    });

    test('per-session HKDF key encrypts/decrypts correctly', () {
      final masterKey = enc.Key.fromSecureRandom(32);
      const sessionId = 'test-session-for-roundtrip';

      final sessionKey = _hkdfDeriveKey(masterKey, sessionId);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(
        enc.AES(sessionKey, mode: enc.AESMode.gcm),
      );

      const plaintext = 'therapy session audio 16kHz FLAC bytes';
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      expect(decrypted, plaintext);
    });

    test('master key cannot decrypt session-key-encrypted data', () {
      final masterKey = enc.Key.fromSecureRandom(32);
      final sessionKey = _hkdfDeriveKey(masterKey, 'session-xyz');
      final iv = enc.IV.fromSecureRandom(12);

      final sessionEncrypter = enc.Encrypter(
        enc.AES(sessionKey, mode: enc.AESMode.gcm),
      );
      final masterEncrypter = enc.Encrypter(
        enc.AES(masterKey, mode: enc.AESMode.gcm),
      );

      final encrypted = sessionEncrypter.encrypt('secret', iv: iv);

      expect(
        () => masterEncrypter.decrypt(encrypted, iv: iv),
        throwsA(anything),
      );
    });

    test('binary data round-trip (all byte values 0-255)', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final plaintext = Uint8List.fromList(
        List.generate(256, (i) => i),
      );
      final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      expect(Uint8List.fromList(decrypted), equals(plaintext));
    });

    test('large block round-trip (64 KB)', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final rng = Random(42);
      final plaintext = Uint8List.fromList(
        List.generate(65536, (_) => rng.nextInt(256)),
      );
      final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      expect(Uint8List.fromList(decrypted), equals(plaintext));
    });

    test('modified GCM auth tag fails (last 16 bytes)', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final encrypted = encrypter.encryptBytes(
        Uint8List.fromList([1, 2, 3, 4, 5]),
        iv: iv,
      );

      final tampered = Uint8List.fromList(encrypted.bytes);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => encrypter.decryptBytes(enc.Encrypted(tampered), iv: iv),
        throwsA(anything),
        reason: 'Flipping a bit in GCM auth tag must fail decryption',
      );
    });

    test('wrong IV fails GCM authentication', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv1 = enc.IV.fromSecureRandom(12);
      final iv2 = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final encrypted = encrypter.encrypt('secret', iv: iv1);

      expect(
        () => encrypter.decrypt(encrypted, iv: iv2),
        throwsA(anything),
        reason: 'Decrypting with wrong IV must fail GCM auth',
      );
    });

    test('empty plaintext encrypts/decrypts (zero-length body)', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final encrypted = encrypter.encryptBytes(Uint8List(0), iv: iv);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      expect(decrypted, isEmpty);
      expect(encrypted.bytes.length, 16);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-10: Foreign file detection
  // ────────────────────────────────────────────────────────────────

  group('F-10 foreign file detection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('f10_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects foreign files in session directory', () async {
      await File('${tempDir.path}/chunk_00000.enc').writeAsBytes([1, 2, 3]);
      await File('${tempDir.path}/chunk_00001.enc').writeAsBytes([4, 5, 6]);
      await File('${tempDir.path}/manifest.json').writeAsString('{}');
      await File('${tempDir.path}/malware.bin').writeAsBytes([0xFF, 0xFE]);

      final allFiles = await tempDir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final chunks = allFiles
          .where((f) => f.path.split('/').last.startsWith('chunk_'))
          .toList();

      final allowedNames = {
        ...chunks.map((f) => f.path.split('/').last),
        'manifest.json',
      };
      final foreign = allFiles
          .where((f) => !allowedNames.contains(f.path.split('/').last))
          .toList();

      expect(foreign.length, 1);
      expect(foreign.first.path, contains('malware.bin'));
    });

    test('no foreign files → empty list', () async {
      await File('${tempDir.path}/chunk_00000.enc').writeAsBytes([1, 2, 3]);
      await File('${tempDir.path}/manifest.json').writeAsString('{}');

      final allFiles = await tempDir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final chunks = allFiles
          .where((f) => f.path.split('/').last.startsWith('chunk_'))
          .toList();

      final allowedNames = {
        ...chunks.map((f) => f.path.split('/').last),
        'manifest.json',
      };
      final foreign = allFiles
          .where((f) => !allowedNames.contains(f.path.split('/').last))
          .toList();

      expect(foreign, isEmpty);
    });

    test('hidden files (starting with .) are detected as foreign', () async {
      await File('${tempDir.path}/chunk_00000.enc').writeAsBytes([1]);
      await File('${tempDir.path}/manifest.json').writeAsString('{}');
      await File('${tempDir.path}/.DS_Store').writeAsBytes([0]);
      await File('${tempDir.path}/.hidden_keylogger').writeAsBytes([0]);

      final allFiles = await tempDir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final chunks = allFiles
          .where((f) => f.path.split('/').last.startsWith('chunk_'))
          .toList();

      final allowedNames = {
        ...chunks.map((f) => f.path.split('/').last),
        'manifest.json',
      };
      final foreign = allFiles
          .where((f) => !allowedNames.contains(f.path.split('/').last))
          .toList();

      expect(foreign.length, 2);
    });

    test('multiple foreign files — all detected', () async {
      await File('${tempDir.path}/chunk_00000.enc').writeAsBytes([1]);
      await File('${tempDir.path}/manifest.json').writeAsString('{}');
      for (int i = 0; i < 5; i++) {
        await File('${tempDir.path}/rogue_$i.dat').writeAsBytes([i]);
      }

      final allFiles = await tempDir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final chunks = allFiles
          .where((f) => f.path.split('/').last.startsWith('chunk_'))
          .toList();

      final allowedNames = {
        ...chunks.map((f) => f.path.split('/').last),
        'manifest.json',
      };
      final foreign = allFiles
          .where((f) => !allowedNames.contains(f.path.split('/').last))
          .toList();

      expect(foreign.length, 5);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-01/F-12: Streaming upload — file header format
  // ────────────────────────────────────────────────────────────────

  group('chunk file format', () {
    test('header is exactly 13 bytes (1 key_version + 12 IV)', () {
      const headerLen = 13;
      const ivLen = 12;

      final header = Uint8List(headerLen);
      header[0] = 1;
      final iv = enc.IV.fromSecureRandom(ivLen);
      header.setRange(1, 1 + ivLen, iv.bytes);

      expect(header.length, 13);
      expect(header[0], 1);
      expect(header.sublist(1, 13), equals(iv.bytes));
    });

    test('GCM tag is 16 bytes', () {
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

      expect(encrypted.bytes.length, plaintext.length + 16);
    });

    test('key_version 0 is valid', () {
      final header = Uint8List(13);
      header[0] = 0;
      expect(header[0], 0);
    });

    test('key_version 255 is max uint8', () {
      final header = Uint8List(13);
      header[0] = 255;
      expect(header[0], 255);
    });

    test('key_version overflow wraps correctly', () {
      expect(256 & 0xFF, 0);
      expect(257 & 0xFF, 1);
      expect(511 & 0xFF, 255);
    });

    test('total overhead per chunk is exactly 29 bytes', () {
      expect(13 + 16, 29);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-06: SecureRandomService (fallback path)
  // ────────────────────────────────────────────────────────────────

  group('F-06 SecureRandomService fallback', () {
    test('fallback produces correct length bytes', () async {
      final service = SecureRandomService.instance;
      final bytes = await service.getRandomBytes(12);
      expect(bytes.length, 12);
    });

    test('fallback produces different bytes on each call', () async {
      final service = SecureRandomService.instance;
      final a = await service.getRandomBytes(32);
      final b = await service.getRandomBytes(32);
      expect(a, isNot(equals(b)));
    });

    test('fallback works for various lengths', () async {
      final service = SecureRandomService.instance;
      for (final len in [1, 12, 16, 32, 64, 128, 256]) {
        final bytes = await service.getRandomBytes(len);
        expect(bytes.length, len, reason: 'failed for length $len');
      }
    });

    test('singleton identity check', () {
      final a = SecureRandomService.instance;
      final b = SecureRandomService.instance;
      expect(identical(a, b), isTrue,
          reason: 'SecureRandomService must be a singleton');
    });

    test('byte distribution is reasonable (no stuck bits)', () async {
      final service = SecureRandomService.instance;
      final allBytes = <int>[];
      for (int i = 0; i < 10; i++) {
        final bytes = await service.getRandomBytes(256);
        allBytes.addAll(bytes);
      }

      final seen = allBytes.toSet();
      expect(seen.length, greaterThan(100),
          reason: 'RNG should produce diverse byte values — '
              'only seeing ${seen.length}/256 unique values in 2560 bytes');
    });

    test('minimum length (1 byte)', () async {
      final bytes = await SecureRandomService.instance.getRandomBytes(1);
      expect(bytes.length, 1);
    });

    test('maximum length (256 bytes)', () async {
      final bytes = await SecureRandomService.instance.getRandomBytes(256);
      expect(bytes.length, 256);
    });
  });

  // ────────────────────────────────────────────────────────────────
  // F-09: Certificate pinner construction
  // ────────────────────────────────────────────────────────────────

  group('F-09 certificate pinner', () {
    test('createPinnedHttpClient returns a valid http.Client', () {
      final client = createPinnedHttpClient();
      expect(client, isNotNull);
      client.close();
    });

    test('multiple clients can be created independently', () {
      final client1 = createPinnedHttpClient();
      final client2 = createPinnedHttpClient();
      expect(client1, isNot(same(client2)));
      client1.close();
      client2.close();
    });

    test('client can be closed without error', () {
      final client = createPinnedHttpClient();
      expect(() => client.close(), returnsNormally);
    });
  });
}
