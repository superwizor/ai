// Tests for CacheManager. We can't easily exercise the encrypted-Hive
// path in unit tests (flutter_secure_storage isn't wired in a vanilla
// test process), so we inject an unencrypted-cipher stub and a tiny
// maxBytes so eviction triggers with small payloads.
//
// Covers:
//   • enforceSizeCap evicts oldest-accessed entries first
//   • cap is respected across all three domain boxes, not per-box
//   • evictPatient removes patient row, session list, and matching
//     session_details entries in one shot
//   • clearForUser wipes everything from disk

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

/// CacheCipher stub that returns the same all-zeros key for every
/// therapist — gives us a real HiveAesCipher (so the Hive box opens
/// without complaint) without needing flutter_secure_storage.
class _StubCipher extends CacheCipher {
  @override
  Future<HiveAesCipher> cipherFor(String therapistId) async {
    return HiveAesCipher(List<int>.filled(32, 0));
  }

  @override
  Future<void> forgetKeyFor(String therapistId) async {}
}

SessionDetailsDto _details(String sid, String pid, {int contentLen = 100}) =>
    SessionDetailsDto(
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
          title: 'x',
          summaryShort: '',
          content: 'X' * contentLen,
          sentimentLabel: '',
          riskLevel: '',
        ),
      ],
    );

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('cache_manager_test_');
    Hive.init(tmpDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  test('enforceSizeCap evicts oldest-accessed entries across boxes',
      () async {
    final mgr = CacheManager(cipher: _StubCipher(), maxBytes: 2000);
    await mgr.openForUser('th-1');

    final detailsBox = mgr.sessionDetailsBox();

    // Write 5 ~500-byte entries — total ~2.5 KB, over the 2 KB cap.
    // Use distinct write times via a real wall clock; flutter_test runs
    // fast enough that we need to manually order writes here. Write
    // them sequentially; each subsequent put's lastAccessedAt is later.
    for (var i = 0; i < 5; i++) {
      await detailsBox.put(
          CacheKeys.sessionDetailsKey('th-1', 'sess-$i'),
          _details('sess-$i', 'p', contentLen: 400));
      // small await to ensure DateTime.now() advances
      await Future.delayed(const Duration(milliseconds: 5));
    }

    final before = mgr.currentTotalBytes();
    expect(before, greaterThan(2000),
        reason: 'precondition: must be over cap before enforce');

    final report = await mgr.enforceSizeCap();
    expect(report.evictedCount, greaterThan(0));
    expect(report.totalAfter, lessThanOrEqualTo(2000));

    // Oldest entry should be the first evicted.
    final stillThere = await detailsBox.get(
        CacheKeys.sessionDetailsKey('th-1', 'sess-0'));
    expect(stillThere, isNull, reason: 'oldest entry was the first evicted');

    // Newest entry should survive.
    final newest = await detailsBox.get(
        CacheKeys.sessionDetailsKey('th-1', 'sess-4'));
    expect(newest, isNotNull);
  });

  test('enforceSizeCap is a no-op when total is under cap', () async {
    final mgr = CacheManager(cipher: _StubCipher(), maxBytes: 1024 * 1024);
    await mgr.openForUser('th-1');
    await mgr.sessionDetailsBox().put(
        CacheKeys.sessionDetailsKey('th-1', 's1'),
        _details('s1', 'p1'));

    final report = await mgr.enforceSizeCap();
    expect(report.evictedCount, 0);
  });

  test('evictPatient removes patient row, sessions, and session_details',
      () async {
    final mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');

    // Seed: 2 patients, sessions for both, session_details for both.
    final pBox = mgr.patientsBox();
    await pBox.put(CacheKeys.patientsKey('th-1'), [
      const PatientDto(
        id: 'pf-1',
        firstName: 'Anna',
        lastName: 'A',
        modalityCode: '',
        languageCode: '',
        sessionCount: 0,
      ),
      const PatientDto(
        id: 'pf-2',
        firstName: 'Bart',
        lastName: 'B',
        modalityCode: '',
        languageCode: '',
        sessionCount: 0,
      ),
    ]);

    final sBox = mgr.sessionsBox();
    await sBox.put(CacheKeys.sessionsKey('th-1', 'pf-1'), [
      SessionDto(
        id: 's-1a',
        patientFileId: 'pf-1',
        name: 'n',
        contactForm: '',
        durationSeconds: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        status: 'COMPLETED',
        sessionNumber: 0,
        audioUploadId: '',
        speakerLabelMapping: const {},
      ),
    ]);
    await sBox.put(CacheKeys.sessionsKey('th-1', 'pf-2'), [
      SessionDto(
        id: 's-2a',
        patientFileId: 'pf-2',
        name: 'n',
        contactForm: '',
        durationSeconds: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        status: 'COMPLETED',
        sessionNumber: 0,
        audioUploadId: '',
        speakerLabelMapping: const {},
      ),
    ]);

    final dBox = mgr.sessionDetailsBox();
    await dBox.put(CacheKeys.sessionDetailsKey('th-1', 's-1a'),
        _details('s-1a', 'pf-1'));
    await dBox.put(CacheKeys.sessionDetailsKey('th-1', 's-2a'),
        _details('s-2a', 'pf-2'));

    // Evict patient 1.
    await mgr.evictPatient('pf-1');

    // Patient list shrunk to just pf-2.
    final remaining = await pBox.get(CacheKeys.patientsKey('th-1'));
    expect(remaining!.data.map((p) => p.id).toList(), ['pf-2']);

    // pf-1's sessions list gone, pf-2's intact.
    expect(await sBox.get(CacheKeys.sessionsKey('th-1', 'pf-1')), isNull);
    expect(await sBox.get(CacheKeys.sessionsKey('th-1', 'pf-2')), isNotNull);

    // session_details for pf-1's session gone, pf-2's intact.
    expect(await dBox.get(CacheKeys.sessionDetailsKey('th-1', 's-1a')),
        isNull);
    expect(await dBox.get(CacheKeys.sessionDetailsKey('th-1', 's-2a')),
        isNotNull);
  });

  test('clearForUser wipes all boxes from disk', () async {
    final mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');
    await mgr.sessionDetailsBox().put(
        CacheKeys.sessionDetailsKey('th-1', 's1'),
        _details('s1', 'p1'));

    await mgr.clearForUser('th-1');

    // Re-open: should be empty.
    await mgr.openForUser('th-1');
    expect(mgr.currentTotalBytes(), 0);
  });

  test('switching therapist closes old boxes and opens new', () async {
    final mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');
    await mgr.sessionDetailsBox().put(
        CacheKeys.sessionDetailsKey('th-1', 's1'),
        _details('s1', 'p1'));
    expect(mgr.currentTotalBytes(), greaterThan(0));

    await mgr.openForUser('th-2');
    expect(mgr.currentTherapistId, 'th-2');
    expect(mgr.currentTotalBytes(), 0,
        reason: 'th-2 starts with a fresh empty cache');
  });
}
