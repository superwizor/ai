// Local cache for transcripts (Etap 5a.1).
//
// Hive box `transcripts` keyed by sessionId. Each entry holds the
// segments + speaker label mapping + cached_at timestamp. Reading
// is synchronous after openBox; refresh-in-background pattern is
// the responsibility of the view-model.
//
// Cache invalidation:
//   - DeletePatientFile / hard-delete → call `invalidate(sessionId)`
//     for every session of that patient
//   - Status change to FAILED → caller decides; usually fine to keep

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CachedTranscript {
  final String sessionId;
  final List<CachedSegment> segments;
  final Map<String, String> speakerLabels;
  final DateTime cachedAt;

  const CachedTranscript({
    required this.sessionId,
    required this.segments,
    required this.speakerLabels,
    required this.cachedAt,
  });

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'segments': segments.map((s) => s.toJson()).toList(),
        'speakerLabels': speakerLabels,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory CachedTranscript.fromJson(Map<dynamic, dynamic> json) {
    return CachedTranscript(
      sessionId: (json['sessionId'] ?? '').toString(),
      segments: ((json['segments'] as List?) ?? const [])
          .map((s) => CachedSegment.fromJson(Map<dynamic, dynamic>.from(s as Map)))
          .toList(),
      speakerLabels: Map<String, String>.from(
          (json['speakerLabels'] as Map?) ?? const {}),
      cachedAt: DateTime.parse((json['cachedAt'] ?? '').toString()),
    );
  }
}

class CachedSegment {
  final int speakerTag;
  final String speakerLabel;
  final int startOffsetMs;
  final int endOffsetMs;
  final String text;
  final double confidence;

  const CachedSegment({
    required this.speakerTag,
    required this.speakerLabel,
    required this.startOffsetMs,
    required this.endOffsetMs,
    required this.text,
    required this.confidence,
  });

  Map<String, Object?> toJson() => {
        'speakerTag': speakerTag,
        'speakerLabel': speakerLabel,
        'startOffsetMs': startOffsetMs,
        'endOffsetMs': endOffsetMs,
        'text': text,
        'confidence': confidence,
      };

  factory CachedSegment.fromJson(Map<dynamic, dynamic> json) {
    return CachedSegment(
      speakerTag: (json['speakerTag'] ?? 0) as int,
      speakerLabel: (json['speakerLabel'] ?? '').toString(),
      startOffsetMs: (json['startOffsetMs'] ?? 0) as int,
      endOffsetMs: (json['endOffsetMs'] ?? 0) as int,
      text: (json['text'] ?? '').toString(),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }
}

class TranscriptCacheStore {
  static const _boxName = 'transcripts';
  static const _staleThreshold = Duration(hours: 1);

  Future<Box<Map>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<Map>(_boxName);
    return Hive.openBox<Map>(_boxName);
  }

  Future<CachedTranscript?> load(String sessionId) async {
    final box = await _box();
    final raw = box.get(sessionId);
    if (raw == null) return null;
    try {
      return CachedTranscript.fromJson(raw);
    } catch (_) {
      // Schema drift — drop and re-fetch.
      await box.delete(sessionId);
      return null;
    }
  }

  Future<void> save(CachedTranscript t) async {
    final box = await _box();
    await box.put(t.sessionId, t.toJson());
  }

  Future<void> invalidate(String sessionId) async {
    final box = await _box();
    await box.delete(sessionId);
  }

  bool isStale(CachedTranscript t) =>
      DateTime.now().difference(t.cachedAt) > _staleThreshold;
}
