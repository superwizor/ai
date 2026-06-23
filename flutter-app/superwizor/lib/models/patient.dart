class Patient {
  final String id;
  final String firstName;
  final String lastName;
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
  // Patient contact e-mail (PatientFile.patientEmail, docs/22). Empty
  // when none is on file. Drives the "send action plan / note" e-mail
  // gate. Persisted server-side via UpdatePatientUser(patient_email).
  final String email;
  // 3-state lifecycle (ACTIVE/COMPLETED/PAUSED). Persisted server-side
  // in patient_files.lifecycle_status (migration 000058). The Flutter
  // PatientLifecycleNotifier reads this on load and syncs changes back
  // via UpdatePatientFile.
  final String lifecycleStatus;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.modalityCode = '',
    this.languageCode = '',
    this.sessionCount = 0,
    this.email = '',
    this.lifecycleStatus = 'ACTIVE',
  });

  Patient copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? modalityCode,
    String? languageCode,
    int? sessionCount,
    String? email,
    String? lifecycleStatus,
  }) {
    return Patient(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      modalityCode: modalityCode ?? this.modalityCode,
      languageCode: languageCode ?? this.languageCode,
      sessionCount: sessionCount ?? this.sessionCount,
      email: email ?? this.email,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
    );
  }
}
