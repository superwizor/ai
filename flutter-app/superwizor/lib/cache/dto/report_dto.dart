// ReportDto — JSON-serializable cache row mirroring clinical.Report.

import '../../generated/clinical/v1/clinical.pb.dart' as clinical_pb;

class ReportDto {
  final String id;
  final String title;
  final String summaryShort;
  final String content;
  final String sentimentLabel;
  final String riskLevel;

  const ReportDto({
    required this.id,
    required this.title,
    required this.summaryShort,
    required this.content,
    required this.sentimentLabel,
    required this.riskLevel,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summaryShort': summaryShort,
        'content': content,
        'sentimentLabel': sentimentLabel,
        'riskLevel': riskLevel,
      };

  factory ReportDto.fromJson(Map<String, dynamic> j) => ReportDto(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        summaryShort: j['summaryShort'] as String? ?? '',
        content: j['content'] as String? ?? '',
        sentimentLabel: j['sentimentLabel'] as String? ?? '',
        riskLevel: j['riskLevel'] as String? ?? '',
      );

  factory ReportDto.fromProto(clinical_pb.Report r) => ReportDto(
        id: r.id,
        title: r.title,
        summaryShort: r.summaryShort,
        content: r.content,
        sentimentLabel: r.sentimentLabel,
        riskLevel: r.riskLevel,
      );
}
