// CacheBox<T> — typed wrapper over a Hive Box<Map> that encodes
// CacheEnvelope on write and decodes on read.
//
// Generic over the DTO type T so callers see a typed value and never
// touch the JSON map shape. The DTO contract is captured by two
// caller-supplied functions (fromJson + toJson) — we deliberately
// don't depend on a shared base class so each DTO stays free of any
// caching-aware base class.
//
// Read semantics:
//   • returns null if the key is absent
//   • returns null AND deletes the entry if it's hard-expired
//   • on success, touches lastAccessedAt for LRU
//
// Write semantics:
//   • stamps cachedAt = lastAccessedAt = now
//   • computes sizeBytes from the encoded JSON length

import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import 'cache_envelope.dart';
import 'cache_keys.dart';

typedef DtoFromJson<T> = T Function(Map<String, dynamic> json);
typedef DtoToJson<T> = Map<String, dynamic> Function(T value);

class CacheReadResult<T> {
  final T data;
  final DateTime cachedAt;
  final bool isStale;
  final int sizeBytes;

  const CacheReadResult({
    required this.data,
    required this.cachedAt,
    required this.isStale,
    required this.sizeBytes,
  });
}

class CacheBox<T> {
  CacheBox({
    required Box<Map> hiveBox,
    required DtoFromJson<T> fromJson,
    required DtoToJson<T> toJson,
    required this.softTtl,
    required this.hardTtl,
    DateTime Function()? clock,
  })  : _box = hiveBox,
        _fromJson = fromJson,
        _toJson = toJson,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final Box<Map> _box;
  final DtoFromJson<T> _fromJson;
  final DtoToJson<T> _toJson;
  final Duration softTtl;
  final Duration hardTtl;
  final DateTime Function() _clock;

  String get name => _box.name;
  int get length => _box.length;

  /// Reads [key]. Returns null if absent, deletes & returns null if
  /// hard-expired or schema-mismatched. Touches lastAccessedAt as a
  /// side effect on a successful read so the entry moves to the back
  /// of the LRU queue.
  Future<CacheReadResult<T>?> get(String key) async {
    final raw = _box.get(key);
    if (raw == null) return null;

    final CacheEnvelope env;
    try {
      env = CacheEnvelope.fromMap(raw);
    } catch (_) {
      // Corrupt entry — drop it. Self-healing under field drift.
      await _box.delete(key);
      return null;
    }

    if (env.schemaVersion != CacheKeys.schemaVersion) {
      await _box.delete(key);
      return null;
    }

    final now = _clock();
    if (env.isExpired(hardTtl, now)) {
      await _box.delete(key);
      return null;
    }

    // Decode the DTO before touching access time — if the DTO
    // throws we surface that as a corrupt-entry drop too.
    final T value;
    try {
      value = _fromJson(env.data);
    } catch (_) {
      await _box.delete(key);
      return null;
    }

    // Touch LRU. Write is fire-and-forget for read latency.
    unawaited(_box.put(key, env.touched(now).toMap()));

    return CacheReadResult(
      data: value,
      cachedAt: env.cachedAt,
      isStale: env.isStale(softTtl, now),
      sizeBytes: env.sizeBytes,
    );
  }

  /// Writes [value] under [key]. Returns the bytes written so the
  /// cache_manager can update its size accounting without re-scanning.
  Future<int> put(String key, T value) async {
    final dataMap = _toJson(value);
    final encodedLen = utf8.encode(jsonEncode(dataMap)).length;
    final now = _clock();
    final env = CacheEnvelope(
      schemaVersion: CacheKeys.schemaVersion,
      data: dataMap,
      cachedAt: now,
      lastAccessedAt: now,
      sizeBytes: encodedLen,
    );
    await _box.put(key, env.toMap());
    return encodedLen;
  }

  Future<void> delete(String key) => _box.delete(key);

  Future<void> clear() => _box.clear();

  /// Total estimated bytes across all entries. Iterates keys
  /// (in-memory in Hive) and sums envelope.sizeBytes — does not
  /// decrypt full values.
  int totalSizeBytes() {
    var sum = 0;
    for (final k in _box.keys) {
      final raw = _box.get(k);
      if (raw == null) continue;
      final sz = raw['sz'];
      if (sz is num) sum += sz.toInt();
    }
    return sum;
  }

  /// All `(key, lastAccessedAt, sizeBytes)` tuples — feed for the LRU
  /// eviction sort in cache_manager.
  Iterable<({String key, DateTime lastAccessedAt, int sizeBytes})> lruIndex() sync* {
    for (final k in _box.keys) {
      final raw = _box.get(k);
      if (raw == null) continue;
      final la = raw['la'];
      final sz = raw['sz'];
      if (la is! String) continue;
      yield (
        key: k.toString(),
        lastAccessedAt: DateTime.tryParse(la)?.toUtc() ?? DateTime.utc(1970),
        sizeBytes: sz is num ? sz.toInt() : 0,
      );
    }
  }
}

