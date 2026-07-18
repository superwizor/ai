class Patient {
  final String id;
  // Pseudonymous client label (PatientFile.workingAlias, docs/43 §4).
  // The kartoteka never carries real names — the working alias is the
  // ONLY therapist-facing identifier. The backend ignores the deprecated
  // patient_first_name/patient_last_name fields, so all display, sorting
  // and filtering must go through this value.
  final String workingAlias;
  final String modalityCode;
  // BCP47-tagged audio/report language for this patient. Mirrors
  // PatientFile.patientLanguageCode from the gRPC proto (which itself
  // comes from users.ui_language on the paired patient_user row).
  // Used by NewSessionScreen to populate reportLanguage on
  // CreateAudioUploadRequest — without this, the server defaulted
  // every report to Polish regardless of the patient's actual
  // language (the 2026-05-15 EN-patient bug).
  // Default empty string when missing; consumers should fall back
  // to a safe value (e.g. 'pl-PL') in that case.
  final String languageCode;
  final int sessionCount;
  // Client account e-mail as RESOLVED by the backend (from the linked
  // account or a pending invitation — docs/43 §4). Read-only in the
  // kartoteka; it changes only by sending a new client-panel invitation
  // (client_invite_sheet). Empty when none is on file.
  final String email;
  // 3-state lifecycle (ACTIVE/COMPLETED/PAUSED). Persisted server-side
  // in patient_files.lifecycle_status (migration 000058). The Flutter
  // PatientLifecycleNotifier reads this on load and syncs changes back
  // via UpdatePatientFile.
  final String lifecycleStatus;

  Patient({
    required this.id,
    required this.workingAlias,
    this.modalityCode = '',
    this.languageCode = '',
    this.sessionCount = 0,
    this.email = '',
    this.lifecycleStatus = 'ACTIVE',
  });

  Patient copyWith({
    String? id,
    String? workingAlias,
    String? modalityCode,
    String? languageCode,
    int? sessionCount,
    String? email,
    String? lifecycleStatus,
  }) {
    return Patient(
      id: id ?? this.id,
      workingAlias: workingAlias ?? this.workingAlias,
      modalityCode: modalityCode ?? this.modalityCode,
      languageCode: languageCode ?? this.languageCode,
      sessionCount: sessionCount ?? this.sessionCount,
      email: email ?? this.email,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
    );
  }
}
