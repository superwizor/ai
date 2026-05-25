
enum SessionStatus {
  /// Option E (2026-05-25): server-side session row exists but the
  /// audio upload hasn't been confirmed yet. ClientDetailsScreen
  /// renders these as the same placeholder card the local Hive
  /// queue uses so the visible affordance is identical regardless
  /// of which device the upload was initiated from.
  pendingUpload,
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
