// CacheCipher — per-therapist AES-256 key management for Hive's
// HiveAesCipher. The key lives in flutter_secure_storage (Keychain on
// iOS, encrypted SharedPreferences on Android) under
// `cache_master_key_v1_<therapistId>`. First call generates 32 random
// bytes from a CSPRNG; subsequent calls reuse it.
//
// On logout (or therapist switch), call `forgetKeyFor(therapistId)` to
// delete the secure-storage entry. The Hive box files on disk remain
// AES-encrypted with the now-deleted key — effectively unrecoverable.
// cache_manager.clearForUser also deletes the box files; the key-delete
// is the second wall of the belt-and-suspenders.
//
// The audio service in secure_audio_storage_service.dart uses its own
// device-wide key (different keychain entry) — we don't share so that
// rotating one doesn't blow up the other.

import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class CacheCipher {
  CacheCipher({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'cache_master_key_v1_';
  final FlutterSecureStorage _storage;

  /// Returns a HiveAesCipher for the given therapist, generating and
  /// persisting a fresh 256-bit key on first call. Subsequent calls
  /// for the same therapist return a cipher backed by the same key.
  Future<HiveAesCipher> cipherFor(String therapistId) async {
    final keyBytes = await _readOrCreateKey(therapistId);
    return HiveAesCipher(keyBytes);
  }

  /// Deletes the secure-storage key for [therapistId]. After this call,
  /// any Hive box files on disk encrypted with that key are
  /// unreadable — recovery requires re-fetching from the backend.
  Future<void> forgetKeyFor(String therapistId) async {
    await _storage.delete(key: _storageKey(therapistId));
  }

  Future<Uint8List> _readOrCreateKey(String therapistId) async {
    final key = _storageKey(therapistId);
    final stored = await _storage.read(key: key);
    if (stored != null) {
      return Uint8List.fromList(base64Decode(stored));
    }
    final fresh = enc.Key.fromSecureRandom(32).bytes; // 256-bit
    await _storage.write(key: key, value: base64Encode(fresh));
    return fresh;
  }

  String _storageKey(String therapistId) {
    // Same sanitiser as cache_keys to keep storage keys in lockstep
    // with box names.
    final safe = therapistId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$_keyPrefix$safe';
  }
}
