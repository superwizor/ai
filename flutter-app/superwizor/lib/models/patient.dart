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

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.modalityCode = '',
    this.languageCode = '',
    this.sessionCount = 0,
  });

  Patient copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? modalityCode,
    String? languageCode,
    int? sessionCount,
  }) {
    return Patient(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      modalityCode: modalityCode ?? this.modalityCode,
      languageCode: languageCode ?? this.languageCode,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }
}
