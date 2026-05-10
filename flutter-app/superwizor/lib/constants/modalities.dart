// Therapy modalities (8 — per Etap 2 plan).
//
// `code` is the stable backend identifier; `displayKey` references
// the corresponding ARB key (D7 — i18n). Display names live in
// AppLocalizations, never hardcoded here.

class Modality {
  final String code;
  final String displayKey;

  const Modality({required this.code, required this.displayKey});
}

/// Source of truth for the 8 supported modalities.
const List<Modality> kModalities = [
  Modality(code: 'integrative', displayKey: 'modality_integrative'),
  Modality(code: 'cbt', displayKey: 'modality_cbt'),
  Modality(code: 'psychodynamic', displayKey: 'modality_psychodynamic'),
  Modality(code: 'positive', displayKey: 'modality_positive'),
  Modality(code: 'schema', displayKey: 'modality_schema'),
  Modality(code: 'systemic', displayKey: 'modality_systemic'),
  Modality(code: 'eft', displayKey: 'modality_eft'),
  Modality(code: 'coaching', displayKey: 'modality_coaching'),
];

/// Lookup helper for resolving a code → ARB key (UI uses
/// `AppLocalizations.of(context).modality_<key>` after this).
String? modalityDisplayKeyFor(String code) {
  for (final m in kModalities) {
    if (m.code == code) return m.displayKey;
  }
  return null;
}
