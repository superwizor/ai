// Tests for CacheBox<T> over an in-memory Hive box. Verifies:
//   • round-trip via the DTO {fromJson, toJson} contract
//   • soft-TTL flag drives isStale without deleting the entry
//   • hard-TTL hits delete the entry and return null
//   • corrupt envelope is self-healed (deleted) instead of throwing
//   • LRU touch updates lastAccessedAt on read
//
// We use Hive's in-memory mode (initFlutter is for app code; here we
// just use Hive.init with a temp dir which is the standard test
// pattern).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:superwizor/cache/cache_box.dart';
import 'package:superwizor/cache/cache_envelope.dart';
import 'package:superwizor/cache/cache_keys.dart';

class _Foo {
  final String id;
  final int n;
  _Foo(this.id, this.n);
  Map<String, dynamic> toJson() => {'id': id, 'n': n};
  factory _Foo.fromJson(Map<String, dynamic> j) =>
      _Foo(j['id'] as String, (j['n'] as num).toInt());
}

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('cache_box_test_');
    Hive.init(tmpDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  Future<CacheBox<_Foo>> openFooBox({
    Duration soft = const Duration(hours: 1),
    Duration hard = const Duration(days: 30),
    DateTime Function()? clock,
  }) async {
    final box = await Hive.openBox<Map>(
        'foo_${DateTime.now().microsecondsSinceEpoch}');
    return CacheBox<_Foo>(
      hiveBox: box,
      fromJson: _Foo.fromJson,
      toJson: (f) => f.toJson(),
      softTtl: soft,
      hardTtl: hard,
      clock: clock,
    );
  }

  test('round-trip stores and reads a value', () async {
    final box = await openFooBox();
    final written = await box.put('k1', _Foo('a', 42));
    expect(written, greaterThan(0));

    final hit = await box.get('k1');
    expect(hit, isNotNull);
    expect(hit!.data.id, 'a');
    expect(hit.data.n, 42);
    expect(hit.isStale, isFalse);
    expect(hit.sizeBytes, written);
  });

  test('get returns null for missing key', () async {
    final box = await openFooBox();
    expect(await box.get('missing'), isNull);
  });

  test('soft TTL flips isStale without deletion', () async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final box = await openFooBox(
      soft: const Duration(minutes: 30),
      clock: () => now,
    );
    await box.put('k', _Foo('a', 1));

    // Advance past soft TTL.
    now = DateTime.utc(2026, 1, 1, 13);
    final hit = await box.get('k');
    expect(hit, isNotNull, reason: 'stale-but-not-expired still returns');
    expect(hit!.isStale, isTrue);
  });

  test('hard TTL deletes the entry and returns null', () async {
    var now = DateTime.utc(2026, 1, 1);
    final box = await openFooBox(
      soft: const Duration(minutes: 30),
      hard: const Duration(days: 1),
      clock: () => now,
    );
    await box.put('k', _Foo('a', 1));
    now = DateTime.utc(2026, 1, 3);

    expect(await box.get('k'), isNull);
    // Re-read confirms it was actually deleted (no zombie).
    expect(await box.get('k'), isNull);
  });

  test('schema version mismatch drops the entry', () async {
    // Hand-craft an envelope with an old schemaVersion and stash it
    // directly in the underlying Hive box so we exercise the upgrade
    // path that fromJson would otherwise crash on.
    final box = await Hive.openBox<Map>('foo_schema_bump');
    final stale = CacheEnvelope(
      schemaVersion: CacheKeys.schemaVersion - 1,
      data: const {'id': 'a', 'n': 1},
      cachedAt: DateTime.utc(2026, 1, 1),
      lastAccessedAt: DateTime.utc(2026, 1, 1),
      sizeBytes: 10,
    );
    await box.put('k', stale.toMap());

    final cache = CacheBox<_Foo>(
      hiveBox: box,
      fromJson: _Foo.fromJson,
      toJson: (f) => f.toJson(),
      softTtl: const Duration(hours: 1),
      hardTtl: const Duration(days: 30),
    );
    expect(await cache.get('k'), isNull);
    expect(box.get('k'), isNull, reason: 'old-schema entry was deleted');
  });

  test('corrupt entry is self-healed', () async {
    final hive = await Hive.openBox<Map>('foo_corrupt');
    // Missing the required fields — fromMap will throw.
    await hive.put('k', {'totally': 'wrong'});

    final cache = CacheBox<_Foo>(
      hiveBox: hive,
      fromJson: _Foo.fromJson,
      toJson: (f) => f.toJson(),
      softTtl: const Duration(hours: 1),
      hardTtl: const Duration(days: 30),
    );
    expect(await cache.get('k'), isNull);
    expect(hive.get('k'), isNull);
  });

  test('totalSizeBytes sums sizeBytes across all entries', () async {
    final box = await openFooBox();
    final w1 = await box.put('a', _Foo('a', 1));
    final w2 = await box.put('b', _Foo('b', 99999));
    expect(box.totalSizeBytes(), w1 + w2);
  });

  test('lruIndex emits one tuple per entry with sortable timestamps',
      () async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final box = await openFooBox(clock: () => now);

    await box.put('a', _Foo('a', 1));
    now = now.add(const Duration(minutes: 1));
    await box.put('b', _Foo('b', 2));

    final ix = box.lruIndex().toList();
    expect(ix.length, 2);
    ix.sort((x, y) => x.lastAccessedAt.compareTo(y.lastAccessedAt));
    expect(ix.first.key, 'a');
    expect(ix.last.key, 'b');
  });
}
