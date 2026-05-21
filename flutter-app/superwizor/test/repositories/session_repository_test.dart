// SessionRepository — exercises the same miss/hit/stale/invalidate
// contract as PatientRepository, plus the per-patient sharding and
// the local-mutation paths (rename, remove) used after gRPC succeeds.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/cache/cache_cipher.dart';
import 'package:superwizor/cache/cache_manager.dart';
import 'package:superwizor/cache/dto/session_dto.dart';
import 'package:superwizor/repositories/session_repository.dart';

class _StubCipher extends CacheCipher {
  @override
  Future<HiveAesCipher> cipherFor(String therapistId) async =>
      HiveAesCipher(List<int>.filled(32, 0));

  @override
  Future<void> forgetKeyFor(String therapistId) async {}
}

SessionDto _s(String id, String pid, {String status = 'COMPLETED'}) =>
    SessionDto(
      id: id,
      patientFileId: pid,
      name: 'Sesja $id',
      contactForm: '',
      durationSeconds: 1800,
      createdAt: DateTime.utc(2026, 5, 1),
      status: status,
      sessionNumber: 1,
      audioUploadId: '',
      speakerLabelMapping: const {},
    );

void main() {
  late Directory tmpDir;
  late CacheManager mgr;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('session_repo_test_');
    Hive.init(tmpDir.path);
    mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  SessionRepository repo(SessionFetcher fetcher) =>
      SessionRepository(cache: mgr, therapistId: 'th-1', fetcher: fetcher);

  test('getCached returns miss for a patient with no cached sessions',
      () async {
    final r = repo((pid) async => []);
    expect((await r.getCached('pf-1')).hasData, isFalse);
  });

  test('refresh fetches and writes per-patient', () async {
    final fetched = <String>[];
    final r = repo((pid) async {
      fetched.add(pid);
      return [_s('s-1', pid), _s('s-2', pid)];
    });

    final fresh = await r.refresh('pf-1');
    expect(fetched, ['pf-1']);
    expect(fresh, hasLength(2));

    final cached = await r.getCached('pf-1');
    expect(cached.isFresh, isTrue);
    expect(cached.data!.map((s) => s.id).toList(), ['s-1', 's-2']);
  });

  test('cache is sharded per patient — refreshing one does not affect another',
      () async {
    final r = repo((pid) async => [_s('s-${pid}a', pid)]);

    await r.refresh('pf-1');
    await r.refresh('pf-2');

    final c1 = await r.getCached('pf-1');
    final c2 = await r.getCached('pf-2');
    expect(c1.data!.single.id, 's-pf-1a');
    expect(c2.data!.single.id, 's-pf-2a');
  });

  test('invalidate(patientId) drops only that patient\'s entry', () async {
    final r = repo((pid) async => [_s('s', pid)]);
    await r.refresh('pf-1');
    await r.refresh('pf-2');

    await r.invalidate('pf-1');
    expect((await r.getCached('pf-1')).hasData, isFalse);
    expect((await r.getCached('pf-2')).hasData, isTrue);
  });

  test('removeSessionLocally drops a single session from the cached list',
      () async {
    final r = repo((pid) async => [_s('s-1', pid), _s('s-2', pid), _s('s-3', pid)]);
    await r.refresh('pf-1');

    await r.removeSessionLocally('pf-1', 's-2');

    final cached = await r.getCached('pf-1');
    expect(cached.data!.map((s) => s.id).toList(), ['s-1', 's-3']);
  });

  test('removeSessionLocally is a no-op when the patient has no cached list',
      () async {
    final r = repo((pid) async => []);
    // Should not throw.
    await r.removeSessionLocally('pf-1', 's-x');
    expect((await r.getCached('pf-1')).hasData, isFalse);
  });

  test('renameSessionLocally rewrites name and preserves other fields',
      () async {
    final r = repo((pid) async => [_s('s-1', pid)]);
    await r.refresh('pf-1');

    await r.renameSessionLocally('pf-1', 's-1', 'Nowa nazwa');

    final cached = await r.getCached('pf-1');
    final hit = cached.data!.single;
    expect(hit.name, 'Nowa nazwa');
    expect(hit.id, 's-1');
    expect(hit.status, 'COMPLETED', reason: 'other fields untouched');
  });

  test('getCachedAsModels maps DTO status to enum correctly', () async {
    final r = repo((pid) async => [
          _s('s-done', pid, status: 'COMPLETED'),
          _s('s-busy', pid, status: 'PROCESSING'),
          _s('s-fail', pid, status: 'ERROR'),
        ]);
    await r.refresh('pf-1');

    final models = (await r.getCachedAsModels('pf-1')).data!;
    expect(models.map((s) => s.status.name).toList(),
        ['completed', 'inProgress', 'error']);
  });
}
