class Patient {
  final String id;
  final String firstName;
  final String lastName;
  final String modalityCode;
  final int sessionCount;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.modalityCode = '',
    this.sessionCount = 0,
  });

  Patient copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? modalityCode,
    int? sessionCount,
  }) {
    return Patient(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      modalityCode: modalityCode ?? this.modalityCode,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }
}
