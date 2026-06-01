// PatientContactProvider — the patient contact e-mail now comes from the
// SERVER (PatientFile.patientEmail, docs/22), surfaced on the loaded
// patient list via patientsProvider. The old Hive-local e-mail store has
// been removed: the e-mail is persisted server-side through
// UpdatePatientUser(patient_email) and read back here from the cached /
// fetched patient file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'patient_provider.dart';

// ── Provider ───────────────────────────────────────────────────────

/// Per-patient e-mail view — returns the patient's e-mail from the
/// loaded patient list (server-backed), or null when none is on file.
/// Reads from patientsProvider so it tracks the canonical server value
/// without a separate fetch.
final patientEmailProvider =
    Provider.family<String?, String>((ref, patientFileId) {
  final patients = ref.watch(patientsProvider).whenOrNull(data: (d) => d);
  if (patients == null) return null;
  for (final p in patients) {
    if (p.id == patientFileId) {
      final email = p.email.trim();
      return email.isNotEmpty ? email : null;
    }
  }
  return null;
});
