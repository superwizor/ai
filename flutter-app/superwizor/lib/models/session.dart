
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
  final String? name;
  final DateTime date;
  final Duration duration;
  final SessionStatus status;
  /// Server-authoritative sequential number (sessions.session_number).
  /// Used for display ("Sesja N") instead of fragile list-position math.
  final int sessionNumber;
  /// When the therapist first opened the report. null = unviewed
  /// ("nowy raport" badge). Populated from sessions.report_viewed_at
  /// via ClinicalService.MarkReportViewed (migration 000059).
  final DateTime? reportViewedAt;
  final int fileSizeBytes;

  Session({
    required this.id,
    required this.patientId,
    required this.modality,
    this.name,
    required this.date,
    required this.duration,
    this.status = SessionStatus.inProgress,
    this.sessionNumber = 0,
    this.reportViewedAt,
    this.fileSizeBytes = 0,
  });

  Session copyWith({
    String? id,
    String? patientId,
    String? modality,
    String? name,
    DateTime? date,
    Duration? duration,
    SessionStatus? status,
    int? sessionNumber,
    DateTime? reportViewedAt,
    int? fileSizeBytes,
  }) {
    return Session(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      modality: modality ?? this.modality,
      name: name ?? this.name,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      reportViewedAt: reportViewedAt ?? this.reportViewedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}
