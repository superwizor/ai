// Therapy modalities (8 — per Etap 2 plan).
//
// `code` is the stable backend identifier (system_code in DB);
// `displayKey` references the corresponding ARB key (D7 — i18n).
// Display names live in AppLocalizations, never hardcoded here.

import 'package:flutter/material.dart';

class Modality {
  final String code;
  final String displayKey;
  final IconData icon;

  const Modality({
    required this.code,
    required this.displayKey,
    required this.icon,
  });
}

/// Source of truth for the 8 supported modalities.
/// `code` matches `modalities.system_code` in PostgreSQL — used in
/// CreatePatientFileRequest.modalityCode and returned in
/// PatientFile.modalityCode.
const List<Modality> kModalities = [
  Modality(code: 'UNIV', displayKey: 'modality_integrative', icon: Icons.hub_outlined),
  Modality(code: 'CBT', displayKey: 'modality_cbt', icon: Icons.psychology_outlined),
  Modality(code: 'PSYCHO', displayKey: 'modality_psychodynamic', icon: Icons.self_improvement_outlined),
  Modality(code: 'PPT', displayKey: 'modality_positive', icon: Icons.wb_sunny_outlined),
  Modality(code: 'ST', displayKey: 'modality_schema', icon: Icons.view_module_outlined),
  Modality(code: 'SYS', displayKey: 'modality_systemic', icon: Icons.family_restroom_outlined),
  Modality(code: 'EFT', displayKey: 'modality_eft', icon: Icons.favorite_outline),
  Modality(code: 'COACH', displayKey: 'modality_coaching', icon: Icons.trending_up_outlined),
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
