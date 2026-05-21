// TranscriptDto — JSON-serializable cache row mirroring
// clinical.Transcript. Includes both `segments` (raw STT chunks, used
// by the speaker-label edit UI) and `turns` (server-collapsed
// per-speaker spans, what the read-only transcript view binds to).
//
// We persist both because rebuilding `turns` from `segments` client-side
// would diverge from the server's GroupSegmentsIntoTurns policy — keep
// the server as the single source of truth and just store its output.

import '../../generated/clinical/v1/clinical.pb.dart' as clinical_pb;

class TranscriptSegmentDto {
  final int speakerTag;
  final String speakerLabel;
  final int startOffsetMs;
  final int endOffsetMs;
  final String text;
  final double confidence;

  const TranscriptSegmentDto({
    required this.speakerTag,
    required this.speakerLabel,
    required this.startOffsetMs,
    required this.endOffsetMs,
    required this.text,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'speakerTag': speakerTag,
        'speakerLabel': speakerLabel,
        'startOffsetMs': startOffsetMs,
        'endOffsetMs': endOffsetMs,
        'text': text,
        'confidence': confidence,
      };

  factory TranscriptSegmentDto.fromJson(Map<String, dynamic> j) =>
      TranscriptSegmentDto(
        speakerTag: (j['speakerTag'] as num?)?.toInt() ?? 0,
        speakerLabel: j['speakerLabel'] as String? ?? '',
        startOffsetMs: (j['startOffsetMs'] as num?)?.toInt() ?? 0,
        endOffsetMs: (j['endOffsetMs'] as num?)?.toInt() ?? 0,
        text: j['text'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );

  factory TranscriptSegmentDto.fromProto(clinical_pb.TranscriptSegment s) =>
      TranscriptSegmentDto(
        speakerTag: s.speakerTag,
        speakerLabel: s.speakerLabel,
        startOffsetMs: s.startOffsetMs,
        endOffsetMs: s.endOffsetMs,
        text: s.text,
        confidence: s.confidence,
      );
}

class SpeakerTurnDto {
  final int speakerTag;
  final String speakerLabel;
  final int startOffsetMs;
  final int endOffsetMs;
  final String text;
  final int segmentCount;
  final double confidenceAvg;

  const SpeakerTurnDto({
    required this.speakerTag,
    required this.speakerLabel,
    required this.startOffsetMs,
    required this.endOffsetMs,
    required this.text,
    required this.segmentCount,
    required this.confidenceAvg,
  });

  Map<String, dynamic> toJson() => {
        'speakerTag': speakerTag,
        'speakerLabel': speakerLabel,
        'startOffsetMs': startOffsetMs,
        'endOffsetMs': endOffsetMs,
        'text': text,
        'segmentCount': segmentCount,
        'confidenceAvg': confidenceAvg,
      };

  factory SpeakerTurnDto.fromJson(Map<String, dynamic> j) => SpeakerTurnDto(
        speakerTag: (j['speakerTag'] as num?)?.toInt() ?? 0,
        speakerLabel: j['speakerLabel'] as String? ?? '',
        startOffsetMs: (j['startOffsetMs'] as num?)?.toInt() ?? 0,
        endOffsetMs: (j['endOffsetMs'] as num?)?.toInt() ?? 0,
        text: j['text'] as String? ?? '',
        segmentCount: (j['segmentCount'] as num?)?.toInt() ?? 0,
        confidenceAvg: (j['confidenceAvg'] as num?)?.toDouble() ?? 0.0,
      );

  factory SpeakerTurnDto.fromProto(clinical_pb.SpeakerTurn t) => SpeakerTurnDto(
        speakerTag: t.speakerTag,
        speakerLabel: t.speakerLabel,
        startOffsetMs: t.startOffsetMs,
        endOffsetMs: t.endOffsetMs,
        text: t.text,
        segmentCount: t.segmentCount,
        confidenceAvg: t.confidenceAvg,
      );
}

class TranscriptDto {
  final String id;
  final List<TranscriptSegmentDto> segments;
  final List<SpeakerTurnDto> turns;

  const TranscriptDto({
    required this.id,
    required this.segments,
    required this.turns,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'segments': segments.map((s) => s.toJson()).toList(),
        'turns': turns.map((t) => t.toJson()).toList(),
      };

  factory TranscriptDto.fromJson(Map<String, dynamic> j) => TranscriptDto(
        id: j['id'] as String? ?? '',
        segments: ((j['segments'] as List?) ?? const [])
            .map((e) => TranscriptSegmentDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        turns: ((j['turns'] as List?) ?? const [])
            .map((e) => SpeakerTurnDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory TranscriptDto.fromProto(clinical_pb.Transcript t) => TranscriptDto(
        id: t.id,
        segments: t.segments.map(TranscriptSegmentDto.fromProto).toList(),
        turns: t.turns.map(SpeakerTurnDto.fromProto).toList(),
      );
}
