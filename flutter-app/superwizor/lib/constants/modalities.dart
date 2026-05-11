// Therapy modalities (8 — per Etap 2 plan).
//
// `code` is the stable backend identifier (system_code in DB);
// `displayKey` references the corresponding ARB key (D7 — i18n).
// Display names live in AppLocalizations, never hardcoded here.

class Modality {
  final String code;
  final String displayKey;

  const Modality({required this.code, required this.displayKey});
}

/// Source of truth for the 8 supported modalities.
/// `code` matches `modalities.system_code` in PostgreSQL — used in
/// CreatePatientFileRequest.modalityCode and returned in
/// PatientFile.modalityCode.
const List<Modality> kModalities = [
  Modality(code: 'UNIV', displayKey: 'modality_integrative'),
  Modality(code: 'CBT', displayKey: 'modality_cbt'),
  Modality(code: 'PSYCHO', displayKey: 'modality_psychodynamic'),
  Modality(code: 'PPT', displayKey: 'modality_positive'),
  Modality(code: 'ST', displayKey: 'modality_schema'),
  Modality(code: 'SYS', displayKey: 'modality_systemic'),
  Modality(code: 'EFT', displayKey: 'modality_eft'),
  Modality(code: 'COACH', displayKey: 'modality_coaching'),
];

/// Default modality used when creating a new patient file and the
/// therapist hasn't explicitly chosen one yet.
const String kDefaultModalityCode = 'UNIV';

/// Lookup helper for resolving a code → ARB key (UI uses
/// `AppLocalizations.of(context).modality_<key>` after this).
String? modalityDisplayKeyFor(String code) {
  for (final m in kModalities) {
    if (m.code == code) return m.displayKey;
  }
  return null;
}
