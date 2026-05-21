// PatientRepository behavior tests. We inject a fake PatientFetcher
// instead of mocking the gRPC channel — keeps tests fast and focused
// on the cache contract (miss → fetch → store, hit, stale, invalidate).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/cache/cache_cipher.dart';
import 'package:superwizor/cache/cache_manager.dart';
import 'package:superwizor/cache/dto/patient_dto.dart';
import 'package:superwizor/repositories/patient_repository.dart';

class _StubCipher extends CacheCipher {
  @override
  Future<HiveAesCipher> cipherFor(String therapistId) async =>
      HiveAesCipher(List<int>.filled(32, 0));

  @override
  Future<void> forgetKeyFor(String therapistId) async {}
}

const _samplePatients = [
  PatientDto(
    id: 'pf-1',
    firstName: 'Anna',
    lastName: 'K',
    modalityCode: 'CBT',
    languageCode: 'pl-PL',
    sessionCount: 3,
  ),
  PatientDto(
    id: 'pf-2',
    firstName: 'Bart',
    lastName: 'N',
    modalityCode: 'PSYCHO',
    languageCode: 'en-US',
    sessionCount: 1,
  ),
];

void main() {
  late Directory tmpDir;
  late CacheManager mgr;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('patient_repo_test_');
    Hive.init(tmpDir.path);
    mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  PatientRepository repo({
    required PatientFetcher fetcher,
    String therapistId = 'th-1',
  }) =>
      PatientRepository(cache: mgr, therapistId: therapistId, fetcher: fetcher);

  test('getCached returns miss on cold cache', () async {
    final r = repo(fetcher: () async => _samplePatients);
    final hit = await r.getCached();
    expect(hit.hasData, isFalse);
    expect(hit.data, isNull);
  });

  test('refresh fetches, writes to cache, and returns DTOs', () async {
    var calls = 0;
    final r = repo(fetcher: () async {
      calls++;
      return _samplePatients;
    });

    final fresh = await r.refresh();
    expect(calls, 1);
    expect(fresh, hasLength(2));

    final cached = await r.getCached();
    expect(cached.hasData, isTrue);
    expect(cached.isFresh, isTrue);
    expect(cached.data!.map((p) => p.id).toList(), ['pf-1', 'pf-2']);
  });

  test('getCachedAsModels maps DTO to UI Patient model', () async {
    final r = repo(fetcher: () async => _samplePatients);
    await r.refresh();

    final cached = await r.getCachedAsModels();
    expect(cached.data!.first.firstName, 'Anna');
    expect(cached.data!.first.sessionCount, 3);
    expect(cached.data!.last.languageCode, 'en-US');
  });

  test('invalidate drops the cache entry', () async {
    final r = repo(fetcher: () async => _samplePatients);
    await r.refresh();
    expect((await r.getCached()).hasData, isTrue);

    await r.invalidate();
    expect((await r.getCached()).hasData, isFalse);
  });

  test('refresh overwrites stale entries', () async {
    final r1 = repo(fetcher: () async => _samplePatients);
    await r1.refresh();

    final r2 = repo(fetcher: () async => const [
          PatientDto(
            id: 'pf-3',
            firstName: 'Cecylia',
            lastName: 'Z',
            modalityCode: 'UNIV',
            languageCode: 'pl-PL',
            sessionCount: 0,
          ),
        ]);
    final fresh = await r2.refresh();
    expect(fresh.single.id, 'pf-3');

    final cached = await r2.getCached();
    expect(cached.data!.single.id, 'pf-3');
  });

  test('cache is scoped per therapist', () async {
    final rA = repo(fetcher: () async => _samplePatients, therapistId: 'th-1');
    await rA.refresh();

    // Switch to th-2 — should be a clean cache for them.
    await mgr.openForUser('th-2');
    final rB = repo(fetcher: () async => const [], therapistId: 'th-2');
    final cachedForB = await rB.getCached();
    expect(cachedForB.hasData, isFalse,
        reason: 'th-2 must not see th-1 cached patients');
  });

  test('fetcher errors propagate from refresh', () async {
    final r = repo(fetcher: () async => throw Exception('boom'));
    expect(r.refresh(), throwsException);
  });
}
