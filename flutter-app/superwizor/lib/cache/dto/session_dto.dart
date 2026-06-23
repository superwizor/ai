// SessionDto — JSON-serializable cache row mirroring clinical.Session
// from the proto. We preserve the raw status string from the server
// (proto field 10 is `string status`) rather than the compressed
// SessionStatus enum so we don't lose information across the cache
// boundary — the UI mapping (`COMPLETED` → completed, else inProgress)
// happens in toModel().
//
// Storage shape: Hive box `sessions_v1` keyed by
// `{therapistId}#{patientFileId}` holds `List<SessionDto>`.

import '../../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../../models/session.dart';

class SessionDto {
  final String id;
  final String patientFileId;
  final String name;
  final String contactForm;
  final int durationSeconds;
  final DateTime createdAt;
  final String status;
  final int sessionNumber;
  final String audioUploadId;
  final Map<String, String> speakerLabelMapping;
  /// When the therapist first opened the report. null = unviewed.
  final DateTime? reportViewedAt;

  const SessionDto({
    required this.id,
    required this.patientFileId,
    required this.name,
    required this.contactForm,
    required this.durationSeconds,
    required this.createdAt,
    required this.status,
    required this.sessionNumber,
    required this.audioUploadId,
    required this.speakerLabelMapping,
    this.reportViewedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientFileId': patientFileId,
        'name': name,
        'contactForm': contactForm,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status,
        'sessionNumber': sessionNumber,
        'audioUploadId': audioUploadId,
        'speakerLabelMapping': speakerLabelMapping,
        if (reportViewedAt != null)
          'reportViewedAt': reportViewedAt!.toUtc().toIso8601String(),
      };

  factory SessionDto.fromJson(Map<String, dynamic> j) => SessionDto(
        id: j['id'] as String,
        patientFileId: j['patientFileId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        contactForm: j['contactForm'] as String? ?? '',
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
        status: j['status'] as String? ?? '',
        sessionNumber: (j['sessionNumber'] as num?)?.toInt() ?? 0,
        audioUploadId: j['audioUploadId'] as String? ?? '',
        speakerLabelMapping: (j['speakerLabelMapping'] as Map?)
                ?.map((k, v) => MapEntry(k as String, v as String)) ??
            const {},
        reportViewedAt: j['reportViewedAt'] != null
            ? DateTime.parse(j['reportViewedAt'] as String).toUtc()
            : null,
      );

  factory SessionDto.fromProto(clinical_pb.Session s) => SessionDto(
        id: s.id,
        patientFileId: s.patientFileId,
        name: s.name,
        contactForm: s.contactForm,
        durationSeconds: s.durationSeconds,
        createdAt: s.createdAt.toDateTime().toUtc(),
        status: s.status,
        sessionNumber: s.sessionNumber,
        audioUploadId: s.audioUploadId,
        speakerLabelMapping: Map<String, String>.from(s.speakerLabelMapping),
        reportViewedAt: s.hasReportViewedAt()
            ? s.reportViewedAt.toDateTime().toUtc()
            : null,
      );

  // UI-facing Session model. Mirrors the mapping in
  // patient_provider.dart fetchSessions() — keep these in sync.
  Session toModel() => Session(
        id: id,
        patientId: patientFileId,
        modality: name.isNotEmpty ? name : 'Rozmowa',
        // Map the server `sessions.name` to Session.name so a custom title set
        // via UpdateSession (rename) is read back on EVERY refresh — not just
        // shown optimistically. The server defaults this to
        // "<modality_display> <N>" on create, so non-renamed sessions still get
        // a sensible title; the card's own 'Sesja $n' fallback only fires if
        // the server name is ever empty. (Without this, a rename persisted
        // server-side but reverted to the default on re-entry.)
        name: name.isNotEmpty ? name : null,
        date: createdAt.toLocal(),
        duration: Duration(seconds: durationSeconds),
        status: status == 'PENDING_UPLOAD'
            ? SessionStatus.pendingUpload
            : status == 'COMPLETED'
                ? SessionStatus.completed
                : status == 'ERROR' || status == 'FAILED'
                    ? SessionStatus.error
                    : SessionStatus.inProgress,
        reportViewedAt: reportViewedAt?.toLocal(),
      );
}
