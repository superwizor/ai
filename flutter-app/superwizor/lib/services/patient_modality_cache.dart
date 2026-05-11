// Local cache of the therapist's UI-modality choice per patient.
//
// Why this exists:
//   - The backend only seeds 3 modalities (UNIV / CBT / PSYCHO —
//     migration 000006). The Flutter dropdown offers 8 (integrative,
//     cbt, psychodynamic, positive, schema, systemic, eft, coaching).
//   - `uiToBackendModalityCode` collapses 6 of those to UNIV; the
//     therapist's specific choice is lost server-side.
//   - When we re-display the patient later, we want to show the
//     ORIGINAL UI choice ("Schema") instead of the backend's
//     collapsed value ("Integratywne").
//
// This Hive box stores `patient_file_id → ui_code`. Written when a
// patient is created; read when a patient is rendered.
//
// Companion note: backend's `ListPatientFiles` / `GetPatientFile`
// also has a separate bug (returns empty modality_code — TODO marker
// in clinical-svc/server.go). Fixing that backend bug is necessary
// for the cross-device case (this Hive cache lives on a single
// install). For MVP single-install testing, this cache covers the
// gap.

import 'package:hive_flutter/hive_flutter.dart';

class PatientModalityCache {
  static const String _boxName = 'patient_modality_local';

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return Hive.openBox<String>(_boxName);
  }

  Future<void> remember({
    required String patientFileId,
    required String uiCode,
  }) async {
    final box = await _box();
    await box.put(patientFileId, uiCode);
  }

  Future<String?> lookup(String patientFileId) async {
    final box = await _box();
    return box.get(patientFileId);
  }

  /// Bulk lookup — useful from `_fetchPatients` to avoid awaiting
  /// once per patient. Returns a map keyed by patient_file_id; only
  /// entries with cached values appear.
  Future<Map<String, String>> lookupMany(Iterable<String> patientFileIds) async {
    final box = await _box();
    final out = <String, String>{};
    for (final id in patientFileIds) {
      final v = box.get(id);
      if (v != null) out[id] = v;
    }
    return out;
  }

  Future<void> forget(String patientFileId) async {
    final box = await _box();
    await box.delete(patientFileId);
  }
}
