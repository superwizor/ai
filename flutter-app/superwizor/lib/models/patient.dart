class Patient {
  final String id;
  final String firstName;
  final String lastName;
  final int sessionCount;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.sessionCount = 0,
  });

  Patient copyWith({
    String? id,
    String? firstName,
    String? lastName,
    int? sessionCount,
  }) {
    return Patient(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }
}
