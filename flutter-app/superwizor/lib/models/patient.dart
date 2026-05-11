class Patient {
  final String id;
  final String firstName;
  final String lastName;
  final int sessionCount;
  /// Backend modality code as stored on `patient_files.modality_code`
  /// (currently one of UNIV / CBT / PSYCHO — see migration 000006).
  /// Used to drive LLM prompt selection on the backend.
  final String modalityCode;
  /// User's original UI choice (one of 8 lowercase codes from
  /// kModalities). Lives in PatientModalityCache (Hive) — the
  /// backend collapses 6 of these into UNIV, so this is the only
  /// way to preserve the therapist's specific intent for display.
  /// Falls back to a best-effort inverse-map if no cache entry.
  final String uiModalityCode;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.sessionCount = 0,
    this.modalityCode = 'UNIV',
    this.uiModalityCode = 'integrative',
  });

  Patient copyWith({
    String? id,
    String? firstName,
    String? lastName,
    int? sessionCount,
    String? modalityCode,
    String? uiModalityCode,
  }) {
    return Patient(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      sessionCount: sessionCount ?? this.sessionCount,
      modalityCode: modalityCode ?? this.modalityCode,
      uiModalityCode: uiModalityCode ?? this.uiModalityCode,
    );
  }
}
