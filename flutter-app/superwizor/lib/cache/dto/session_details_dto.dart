// SessionDetailsDto — composite cache row for the
// clinical.GetSessionDetails RPC response. One per session_id;
// contains the session metadata, the full transcript (segments +
// turns), and any reports generated for the session.
//
// Storage shape: Hive box `session_details_v1` keyed by
// `{therapistId}#{sessionId}`. This is the heavy box — a 60-min
// session sits at roughly 50–300 KB of transcript + 1–5 reports
// × ~5 KB each. The 300 MB LRU cap in cache_manager bounds the box
// regardless of how many sessions accumulate.

import '../../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import 'report_dto.dart';
import 'session_dto.dart';
import 'transcript_dto.dart';

class SessionDetailsDto {
  final SessionDto session;
  final TranscriptDto transcript;
  final List<ReportDto> reports;

  const SessionDetailsDto({
    required this.session,
    required this.transcript,
    required this.reports,
  });

  Map<String, dynamic> toJson() => {
        'session': session.toJson(),
        'transcript': transcript.toJson(),
        'reports': reports.map((r) => r.toJson()).toList(),
      };

  factory SessionDetailsDto.fromJson(Map<String, dynamic> j) =>
      SessionDetailsDto(
        session: SessionDto.fromJson(j['session'] as Map<String, dynamic>),
        transcript:
            TranscriptDto.fromJson(j['transcript'] as Map<String, dynamic>),
        reports: ((j['reports'] as List?) ?? const [])
            .map((e) => ReportDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory SessionDetailsDto.fromProto(clinical_pb.GetSessionDetailsResponse r) =>
      SessionDetailsDto(
        session: SessionDto.fromProto(r.session),
        transcript: TranscriptDto.fromProto(r.transcript),
        reports: r.reports.map(ReportDto.fromProto).toList(),
      );
}
