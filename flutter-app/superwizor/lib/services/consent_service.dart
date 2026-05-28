// ConsentService — RODO/DPA consent capture (D8 + D9).
//
// MVP impl is local-only (Hive box `consent_audit`). When backend
// adds `consent_given_at` to patient_files (post-MVP migration 000010
// + proto extension), swap the binding for a BackendConsentService
// in lib/providers/consent_provider.dart. Interface stays the same.
//
// Multi-device caveat (documented in plan v1.3): logging in on a new
// device shows zero consent records. UI must treat
// `hasConsent() == false` as "ask user to confirm again", not as a
// data-protection breach.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:hive_flutter/hive_flutter.dart';

import '../cache/cache_cipher.dart';

abstract class ConsentService {
  /// Records that the patient gave consent at a specific moment.
  /// Throws [ConsentRecordingFailed] if persistence fails — caller
  /// must abort patient creation in that case.
  Future<void> recordConsent({
    required String patientFileId,
    required String documentVersion,
  });

  /// Whether we have any audit record for this patient. Used as a
  /// second-line gate before starting recording (in case the patient
  /// was imported / created on another device).
  Future<bool> hasConsent({required String patientFileId});

  /// All consent records (debugging / admin). Order is undefined.
  Future<List<ConsentRecord>> listAll();
}

class ConsentRecord {
  final String patientFileId;
  final String documentVersion;
  final DateTime givenAt;
  final String givenByFirebaseUid;

  const ConsentRecord({
    required this.patientFileId,
    required this.documentVersion,
    required this.givenAt,
    required this.givenByFirebaseUid,
  });
}

class ConsentRecordingFailed implements Exception {
  final String reason;
  ConsentRecordingFailed(this.reason);
  @override
  String toString() => 'ConsentRecordingFailed: $reason';
}

/// MVP stub (D9): writes audit log to Hive `consent_audit` box, never
/// touches the backend. Interface-compatible with the future
/// BackendConsentService so the swap is one provider line.
class LocalConsentService implements ConsentService {
  LocalConsentService(this._auth);

  static const boxName = 'consent_audit';
  final fb_auth.FirebaseAuth _auth;

  // F-07 fix: encrypt the consent box with a device-wide key from
  // flutter_secure_storage (Keychain / Keystore). Without this the
  // box was plaintext on disk, leaking patient_file_id + firebase_uid
  // metadata (who recorded which patient).
  static HiveAesCipher? _cipher;

  Future<Box<Map>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<Map>(boxName);
    _cipher ??= await CacheCipher().cipherFor('__consent_audit__');
    return Hive.openBox<Map>(boxName, encryptionCipher: _cipher!);
  }

  @override
  Future<void> recordConsent({
    required String patientFileId,
    required String documentVersion,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw ConsentRecordingFailed('user not authenticated');
    }
    final box = await _box();
    await box.put(patientFileId, <String, Object>{
      'patient_file_id': patientFileId,
      'document_version': documentVersion,
      'given_at': DateTime.now().toUtc().toIso8601String(),
      'given_by_firebase_uid': user.uid,
    });
  }

  @override
  Future<bool> hasConsent({required String patientFileId}) async {
    final box = await _box();
    return box.containsKey(patientFileId);
  }

  @override
  Future<List<ConsentRecord>> listAll() async {
    final box = await _box();
    return box.values
        .map((m) => ConsentRecord(
              patientFileId: (m['patient_file_id'] ?? '').toString(),
              documentVersion: (m['document_version'] ?? '').toString(),
              givenAt: DateTime.parse((m['given_at'] ?? '').toString()),
              givenByFirebaseUid:
                  (m['given_by_firebase_uid'] ?? '').toString(),
            ))
        .toList();
  }
}
