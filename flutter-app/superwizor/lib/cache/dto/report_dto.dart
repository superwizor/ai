// ReportDto — JSON-serializable cache row mirroring clinical.Report.

import '../../generated/clinical/v1/clinical.pb.dart' as clinical_pb;

class ReportDto {
  final String id;
  final String title;
  final String summaryShort;
  final String content;
  final String sentimentLabel;
  final String riskLevel;
  /// Raport zbudowany na ontologii BEZ autoryzacji ekspertów.
  ///
  /// Pole z serwera, nie dopasowanie prefiksu w tytule: o tym, czy coś
  /// jest materiałem klinicznym, nie rozstrzyga się porównywaniem
  /// napisów. Prefiks w tytule zostaje, bo przeżywa kopiowanie i eksport.
  final bool isExperimental;
  final String pipelineVersion;
  final String ontologyVersion;

  const ReportDto({
    required this.id,
    required this.title,
    required this.summaryShort,
    required this.content,
    required this.sentimentLabel,
    required this.riskLevel,
    this.isExperimental = false,
    this.pipelineVersion = '',
    this.ontologyVersion = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summaryShort': summaryShort,
        'content': content,
        'sentimentLabel': sentimentLabel,
        'riskLevel': riskLevel,
        'isExperimental': isExperimental,
        'pipelineVersion': pipelineVersion,
        'ontologyVersion': ontologyVersion,
      };

  factory ReportDto.fromJson(Map<String, dynamic> j) => ReportDto(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        summaryShort: j['summaryShort'] as String? ?? '',
        content: j['content'] as String? ?? '',
        sentimentLabel: j['sentimentLabel'] as String? ?? '',
        riskLevel: j['riskLevel'] as String? ?? '',
        isExperimental: j['isExperimental'] as bool? ?? false,
        pipelineVersion: j['pipelineVersion'] as String? ?? '',
        ontologyVersion: j['ontologyVersion'] as String? ?? '',
      );

  factory ReportDto.fromProto(clinical_pb.Report r) => ReportDto(
        id: r.id,
        title: r.title,
        summaryShort: r.summaryShort,
        content: r.content,
        sentimentLabel: r.sentimentLabel,
        riskLevel: r.riskLevel,
        isExperimental: r.isExperimental,
        pipelineVersion: r.pipelineVersion,
        ontologyVersion: r.ontologyVersion,
      );
}
