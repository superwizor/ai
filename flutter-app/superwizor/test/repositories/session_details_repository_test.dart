// SessionDetailsRepository tests. Covers the same miss/hit/refresh/
// invalidate contract as the other repos, plus the size-cap-on-write
// behavior — session details are the bulk of cache usage and the
// only repo that explicitly calls enforceSizeCap() after every put.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/cache/cache_cipher.dart';
import 'package:superwizor/cache/cache_keys.dart';
import 'package:superwizor/cache/cache_manager.dart';
import 'package:superwizor/cache/dto/report_dto.dart';
import 'package:superwizor/cache/dto/session_details_dto.dart';
import 'package:superwizor/cache/dto/session_dto.dart';
import 'package:superwizor/cache/dto/transcript_dto.dart';
import 'package:superwizor/repositories/session_details_repository.dart';

class _StubCipher extends CacheCipher {
  @override
  Future<HiveAesCipher> cipherFor(String therapistId) async =>
      HiveAesCipher(List<int>.filled(32, 0));

  @override
  Future<void> forgetKeyFor(String therapistId) async {}
}

SessionDetailsDto _details(String sid, {int contentLen = 100}) =>
    SessionDetailsDto(
      session: SessionDto(
        id: sid,
        patientFileId: 'pf-1',
        name: 'Sesja $sid',
        contactForm: '',
        durationSeconds: 1800,
        createdAt: DateTime.utc(2026, 5, 1),
        status: 'COMPLETED',
        sessionNumber: 1,
        audioUploadId: 'au-$sid',
        speakerLabelMapping: const {'1': 'Therapist', '2': 'Client'},
      ),
      transcript: TranscriptDto(
        id: 't-$sid',
        segments: [
          TranscriptSegmentDto(
            speakerTag: 1,
            speakerLabel: 'Therapist',
            startOffsetMs: 0,
            endOffsetMs: 2000,
            text: 'X' * contentLen,
            confidence: 0.95,
          ),
        ],
        turns: [
          SpeakerTurnDto(
            speakerTag: 1,
            speakerLabel: 'Therapist',
            startOffsetMs: 0,
            endOffsetMs: 5000,
            text: 'Y' * contentLen,
            segmentCount: 1,
            confidenceAvg: 0.95,
          ),
        ],
      ),
      reports: [
        ReportDto(
          id: 'r-$sid',
          title: 'Sesja $sid — podsumowanie',
          summaryShort: '',
          content: 'Z' * contentLen,
          sentimentLabel: 'positive',
          riskLevel: 'low',
        ),
      ],
    );

void main() {
  late Directory tmpDir;
  late CacheManager mgr;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('session_details_repo_');
    Hive.init(tmpDir.path);
    mgr = CacheManager(cipher: _StubCipher());
    await mgr.openForUser('th-1');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  SessionDetailsRepository repo(SessionDetailsFetcher fetcher) =>
      SessionDetailsRepository(
        cache: mgr,
        therapistId: 'th-1',
        fetcher: fetcher,
      );

  test('getCached returns miss on cold cache', () async {
    final r = repo((sid) async => _details(sid));
    expect((await r.getCached('s-1')).hasData, isFalse);
  });

  test('refresh fetches, writes, and returns the composite', () async {
    var calls = 0;
    final r = repo((sid) async {
      calls++;
      return _details(sid);
    });

    final fresh = await r.refresh('s-1');
    expect(calls, 1);
    expect(fresh.session.id, 's-1');
    expect(fresh.reports.single.id, 'r-s-1');
    expect(fresh.transcript.turns.single.text.startsWith('Y'), isTrue);

    final cached = await r.getCached('s-1');
    expect(cached.isFresh, isTrue);
    expect(cached.data!.session.id, 's-1');
  });

  test('cache is sharded per session_id', () async {
    final r = repo((sid) async => _details(sid));
    await r.refresh('s-1');
    await r.refresh('s-2');

    expect((await r.getCached('s-1')).data!.session.id, 's-1');
    expect((await r.getCached('s-2')).data!.session.id, 's-2');
  });

  test('invalidate drops the cache entry', () async {
    final r = repo((sid) async => _details(sid));
    await r.refresh('s-1');
    expect((await r.getCached('s-1')).hasData, isTrue);

    await r.invalidate('s-1');
    expect((await r.getCached('s-1')).hasData, isFalse);
  });

  test('refresh enforces the size cap after writes', () async {
    // Set a tiny cap so we can verify eviction kicks in. Each fake
    // details entry is ~500 bytes; we write 5 with a 1 KB cap.
    final tinyMgr = CacheManager(cipher: _StubCipher(), maxBytes: 1024);
    await tinyMgr.openForUser('th-2');

    final tinyRepo = SessionDetailsRepository(
      cache: tinyMgr,
      therapistId: 'th-2',
      fetcher: (sid) async => _details(sid, contentLen: 300),
    );

    for (var i = 0; i < 5; i++) {
      await tinyRepo.refresh('s-$i');
      // small await so lastAccessedAt strictly orders.
      await Future.delayed(const Duration(milliseconds: 5));
    }

    // Total should now be under the cap (refresh() called
    // enforceSizeCap each time).
    expect(tinyMgr.currentTotalBytes(), lessThanOrEqualTo(1024));
  });

  test('fetcher errors propagate from refresh', () async {
    final r = repo((sid) async => throw Exception('boom'));
    expect(r.refresh('s-1'), throwsException);
  });

  test('cache key shape matches CacheKeys helper', () async {
    final r = repo((sid) async => _details(sid));
    await r.refresh('sess-42');

    // Verify the entry actually landed at the expected key.
    final box = mgr.sessionDetailsBox();
    final hit = await box.get(CacheKeys.sessionDetailsKey('th-1', 'sess-42'));
    expect(hit, isNotNull);
    expect(hit!.data.session.id, 'sess-42');
  });
}
