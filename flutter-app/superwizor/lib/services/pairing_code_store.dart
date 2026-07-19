// PairingCodeStore — per-device memory of the LAST pairing code issued
// for a kartoteka's client invitation (docs/42 O1).
//
// The server stores the code as a SHA-256 hash only (deliberate — the
// plaintext exists exactly once, in the InviteClient response), so once
// the therapist leaves the invite sheet the code is unrecoverable
// server-side. That stranded therapists who closed the sheet before
// passing the code on (reported 2026-07-19). We keep the plaintext in
// the device Keychain/Keystore instead: the therapist legitimately saw
// it, the device already gates PHI behind the app-lock, and the entry
// dies with the invitation (revoke / accept / re-invite overwrite).
//
// The stored e-mail lets the sheet cross-check that the remembered code
// still belongs to the CURRENT pending invitation (an invite sent from
// another device rotates the code — then we have nothing to show).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PairingCodeStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _key(String patientFileId) => 'pairing_code_$patientFileId';

  static Future<void> save(
    String patientFileId, {
    required String code,
    required String email,
  }) async {
    try {
      await _storage.write(
        key: _key(patientFileId),
        value: jsonEncode({'code': code, 'email': email}),
      );
    } catch (e) {
      debugPrint('[pairing-store] save failed: $e');
    }
  }

  static Future<({String code, String email})?> read(
      String patientFileId) async {
    try {
      final raw = await _storage.read(key: _key(patientFileId));
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final code = m['code'];
      if (code is! String || code.isEmpty) return null;
      return (code: code, email: (m['email'] ?? '') as String);
    } catch (e) {
      debugPrint('[pairing-store] read failed: $e');
      return null;
    }
  }

  static Future<void> delete(String patientFileId) async {
    try {
      await _storage.delete(key: _key(patientFileId));
    } catch (e) {
      debugPrint('[pairing-store] delete failed: $e');
    }
  }
}
