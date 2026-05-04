
enum SessionStatus {
  inProgress,
  completed,
  error,
}

class Session {
  final String id;
  final String patientId;
  final String modality;
  final DateTime date;
  final Duration duration;
  final SessionStatus status;

  Session({
    required this.id,
    required this.patientId,
    required this.modality,
    required this.date,
    required this.duration,
    this.status = SessionStatus.inProgress,
  });

  Session copyWith({
    String? id,
    String? patientId,
    String? modality,
    DateTime? date,
    Duration? duration,
    SessionStatus? status,
  }) {
    return Session(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      modality: modality ?? this.modality,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      status: status ?? this.status,
    );
  }
}
