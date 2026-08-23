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
  /// Dlaczego raport eksperymentalny nie powstał, jeśli nie powstał.
  ///
  /// Wypełnione WYŁĄCZNIE wtedy, gdy terapeuta miał włączony przełącznik
  /// — serwer nie zapisuje pominięcia dla nikogo, kto raportu się nie
  /// spodziewał. Sama obecność wartości znaczy więc „spodziewał się".
  final ExperimentalSkipDto? experimentalSkip;

  const SessionDetailsDto({
    required this.session,
    required this.transcript,
    required this.reports,
    this.experimentalSkip,
  });

  Map<String, dynamic> toJson() => {
        'session': session.toJson(),
        'transcript': transcript.toJson(),
        'reports': reports.map((r) => r.toJson()).toList(),
        if (experimentalSkip != null) 'experimentalSkip': experimentalSkip!.toJson(),
      };

  factory SessionDetailsDto.fromJson(Map<String, dynamic> j) =>
      SessionDetailsDto(
        session: SessionDto.fromJson(j['session'] as Map<String, dynamic>),
        transcript:
            TranscriptDto.fromJson(j['transcript'] as Map<String, dynamic>),
        // Ten sam porzadek co przy odczycie z sieci. Cache zapisany
        // starsza wersja aplikacji nie ma pola isExperimental, wiec
        // domyslne false ustawia wszystko jako produkcyjne — kolejnosc
        // z serwera zostaje i nic sie nie psuje.
        reports: uporzadkujRaporty(((j['reports'] as List?) ?? const [])
            .map((e) => ReportDto.fromJson(e as Map<String, dynamic>))
            .toList()),
        experimentalSkip: j['experimentalSkip'] == null
            ? null
            : ExperimentalSkipDto.fromJson(
                j['experimentalSkip'] as Map<String, dynamic>),
      );

  factory SessionDetailsDto.fromProto(clinical_pb.GetSessionDetailsResponse r) =>
      SessionDetailsDto(
        session: SessionDto.fromProto(r.session),
        transcript: TranscriptDto.fromProto(r.transcript),
        reports: uporzadkujRaporty(r.reports.map(ReportDto.fromProto).toList()),
        experimentalSkip: r.hasExperimentalSkip()
            ? ExperimentalSkipDto(
                reason: r.experimentalSkip.reason,
                detail: r.experimentalSkip.detail,
              )
            : null,
      );
}

/// Raport PRODUKCYJNY idzie pierwszy, niezależnie od czasu powstania.
///
/// Serwer zwraca raporty od najnowszego, a raport eksperymentalny
/// powstaje PO produkcyjnym (dual-run rusza dopiero po opublikowaniu
/// „gotowe"). Bez tego porządku otwarcie sesji pokazywałoby domyślnie
/// eksperyment — czyli materiał, który jawnie nie służy do pracy
/// klinicznej — a raport właściwy trzeba by odszukać.
///
/// W obrębie każdej z grup kolejność z serwera zostaje.
List<ReportDto> uporzadkujRaporty(List<ReportDto> raporty) {
  final produkcyjne = raporty.where((r) => !r.isExperimental).toList();
  final eksperymentalne = raporty.where((r) => r.isExperimental).toList();
  return [...produkcyjne, ...eksperymentalne];
}

/// Powód, dla którego raport eksperymentalny nie powstał.
class ExperimentalSkipDto {
  final String reason;
  final String detail;

  const ExperimentalSkipDto({required this.reason, this.detail = ''});

  Map<String, dynamic> toJson() => {'reason': reason, 'detail': detail};

  factory ExperimentalSkipDto.fromJson(Map<String, dynamic> j) =>
      ExperimentalSkipDto(
        reason: j['reason'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
      );
}
