// Eviction cascade tests — verifies that PatientRepository.evictPatient
// (called from the delete-patient code path) drops the right rows
// from all three boxes in one shot.
//
// CacheManager.evictPatient is already covered by cache_manager_test.dart;
// here we exercise the PatientRepository pass-through so a regression in
// the wiring (e.g. someone replaces evictPatient with invalidate) breaks
// the test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/cache/cache_cipher.dart';
import 'package:superwizor/cache/cache_keys.dart';
import 'package:superwizor/cache/cache_manager.dart';
import 'package:superwizor/cache/dto/patient_dto.dart';
import 'package:superwizor/cache/dto/report_dto.dart';
import 'package:superwizor/cache/dto/session_details_dto.dart';
import 'package:superwizor/cache/dto/session_dto.dart';
import 'package:superwizor/cache/dto/transcript_dto.dart';
import 'package:superwizor/repositories/patient_repository.dart';
import 'package:superwizor/repositories/session_repository.dart';

class _StubCipher extends CacheCipher {
  @override
  Future<HiveAesCipher> cipherFor(String therapistId) async =>
      HiveAesCipher(List<int>.filled(32, 0));

  @override
  Future<void> forgetKeyFor(String therapistId) async {}
}

SessionDetailsDto _details(String sid, String pid) => SessionDetailsDto(
      session: SessionDto(
        id: sid,
        patientFileId: pid,
        name: 'n',
        contactForm: '',
        durationSeconds: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        status: 'COMPLETED',
        sessionNumber: 0,
        audioUploadId: '',
        speakerLabelMapping: const {},
      ),
      transcript: const TranscriptDto(id: 't', segments: [], turns: []),
      reports: [
        ReportDto(
          id: 'r-$sid',
          title: '',
          summaryShort: '',
          content: '',
          sentimentLabel: '',
          riskLevel: '',
        ),
      ],
    );

void main() {
  late Directory tmpDir;
  late CacheManager mgr;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('eviction_cascade_test_');
    Hive.init(tmpDir.path);
    mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  test('PatientRepository.evictPatient cascades to all three boxes',
      () async {
    final pRepo = PatientRepository(
      cache: mgr,
      therapistId: 'th-1',
      fetcher: () async => const [
        PatientDto(
          id: 'pf-1',
          workingAlias: 'A',
          modalityCode: '',
          languageCode: '',
          sessionCount: 0,
        ),
        PatientDto(
          id: 'pf-2',
          workingAlias: 'B',
          modalityCode: '',
          languageCode: '',
          sessionCount: 0,
        ),
      ],
    );
    final sRepo = SessionRepository(
      cache: mgr,
      therapistId: 'th-1',
      fetcher: (pid) async => [
        SessionDto(
          id: 's-$pid',
          patientFileId: pid,
          name: 'n',
          contactForm: '',
          durationSeconds: 0,
          createdAt: DateTime.utc(2026, 1, 1),
          status: 'COMPLETED',
          sessionNumber: 0,
          audioUploadId: '',
          speakerLabelMapping: const {},
        ),
      ],
    );

    // Seed all three boxes.
    await pRepo.refresh();
    await sRepo.refresh('pf-1');
    await sRepo.refresh('pf-2');
    await mgr.sessionDetailsBox().put(
        CacheKeys.sessionDetailsKey('th-1', 's-pf-1'),
        _details('s-pf-1', 'pf-1'));
    await mgr.sessionDetailsBox().put(
        CacheKeys.sessionDetailsKey('th-1', 's-pf-2'),
        _details('s-pf-2', 'pf-2'));

    // Sanity-check seed.
    expect((await pRepo.getCached()).data, hasLength(2));
    expect((await sRepo.getCached('pf-1')).hasData, isTrue);
    expect((await sRepo.getCached('pf-2')).hasData, isTrue);

    // Evict pf-1.
    await pRepo.evictPatient('pf-1');

    // Patient list shrinks to pf-2 only.
    final remaining = await pRepo.getCached();
    expect(remaining.data!.map((p) => p.id).toList(), ['pf-2']);

    // pf-1's session list is gone; pf-2 untouched.
    expect((await sRepo.getCached('pf-1')).hasData, isFalse);
    expect((await sRepo.getCached('pf-2')).hasData, isTrue);

    // session_details for pf-1's session is gone; pf-2's is intact.
    final dBox = mgr.sessionDetailsBox();
    expect(await dBox.get(CacheKeys.sessionDetailsKey('th-1', 's-pf-1')),
        isNull);
    expect(await dBox.get(CacheKeys.sessionDetailsKey('th-1', 's-pf-2')),
        isNotNull);
  });
}
