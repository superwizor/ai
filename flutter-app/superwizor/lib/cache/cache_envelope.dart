// CacheEnvelope — common metadata around every cached value.
//
// We don't store DTOs directly in Hive boxes. Instead each entry is
// an envelope that wraps the DTO's JSON payload with:
//   • cachedAt — when the network response was written (TTL gate)
//   • lastAccessedAt — touched on every read (LRU eviction signal)
//   • sizeBytes — JSON byte length, summed in cache_manager to enforce
//                 the 300 MB cap without a full scan-and-measure pass
//   • schemaVersion — bumped when DTO shape breaks back-compat; the
//                 cache_box rejects mismatched envelopes so a stale
//                 entry from an older app build doesn't blow up
//                 fromJson with a missing field
//
// Stored on disk as a `Map<String, dynamic>` — Hive serialises that
// natively without needing a TypeAdapter, which keeps the storage
// format inspectable and tooling-friendly.

class CacheEnvelope {
  final int schemaVersion;
  final Map<String, dynamic> data;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;
  final int sizeBytes;

  const CacheEnvelope({
    required this.schemaVersion,
    required this.data,
    required this.cachedAt,
    required this.lastAccessedAt,
    required this.sizeBytes,
  });

  // Compact JSON-key names ('v', 'd', 'ca', 'la', 'sz') to keep the
  // envelope overhead under ~30 bytes per entry; meaningful for
  // patients/sessions boxes that hold many small rows.
  Map<String, dynamic> toMap() => {
        'v': schemaVersion,
        'd': data,
        'ca': cachedAt.toUtc().toIso8601String(),
        'la': lastAccessedAt.toUtc().toIso8601String(),
        'sz': sizeBytes,
      };

  factory CacheEnvelope.fromMap(Map raw) {
    // Hive deserialises maps as Map<dynamic, dynamic> — normalise here
    // so callers always see Map<String, dynamic>.
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return CacheEnvelope(
      schemaVersion: (m['v'] as num?)?.toInt() ?? 0,
      data: _asStringMap(m['d']),
      cachedAt: DateTime.parse(m['ca'] as String).toUtc(),
      lastAccessedAt: DateTime.parse(m['la'] as String).toUtc(),
      sizeBytes: (m['sz'] as num?)?.toInt() ?? 0,
    );
  }

  CacheEnvelope touched(DateTime now) => CacheEnvelope(
        schemaVersion: schemaVersion,
        data: data,
        cachedAt: cachedAt,
        lastAccessedAt: now,
        sizeBytes: sizeBytes,
      );

  /// Stale if [now] - [cachedAt] exceeds [softTtl]. Soft-stale entries
  /// are still returned to the UI (so screens never block on network)
  /// but trigger a background refresh in the repository.
  bool isStale(Duration softTtl, DateTime now) =>
      now.toUtc().difference(cachedAt) > softTtl;

  /// Hard-expired entries are deleted by cache_box on read; they're
  /// effectively gone. Use [hardTtl] for the upper bound on how long
  /// stale data is acceptable to serve even momentarily (e.g. 30 days
  /// for session details).
  bool isExpired(Duration hardTtl, DateTime now) =>
      now.toUtc().difference(cachedAt) > hardTtl;

  /// Deep-normalises Hive's disk shape. CRITICAL (live-fix 2026-07-23,
  /// offline kartoteka): Hive re-reads maps as Map<dynamic, dynamic> at
  /// EVERY nesting level. The old one-level normalisation left nested
  /// DTO maps dynamic-keyed, the DTO fromJson threw on the first cold
  /// start after a write, and cache_box's self-healing DELETED the
  /// entry — so the cache looked permanently empty across restarts
  /// while working within a session (Hive serves the original
  /// in-memory object until the app dies).
  static Object? _deepNormalize(Object? v) {
    if (v is Map) {
      return v.map<String, dynamic>(
          (k, val) => MapEntry(k.toString(), _deepNormalize(val)));
    }
    if (v is List) return v.map(_deepNormalize).toList();
    return v;
  }

  static Map<String, dynamic> _asStringMap(Object? raw) {
    final normalized = _deepNormalize(raw);
    if (normalized is Map<String, dynamic>) return normalized;
    return const {};
  }
}
