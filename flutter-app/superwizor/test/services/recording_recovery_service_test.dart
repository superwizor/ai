// Orphan-recovery scan semantics (docs/28 WS1): skip rules, duration
// estimation, queue handoff, and the retention sweep.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:superwizor/services/recording_manifest_store.dart';
import 'package:superwizor/services/recording_recovery_service.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_queue_runner.dart';

class _FakeRunner extends Fake implements UploadQueueRunner {
  final List<PendingUpload> rows = [];
  final List<PendingUpload> enqueued = [];
  int kicks = 0;

  @override
  List<PendingUpload> snapshotNow() => List.unmodifiable(rows);

  @override
  Future<void> enqueue(PendingUpload upload) async {
    enqueued.add(upload);
    rows.add(upload);
  }

  @override
  Future<void> kick() async {
    kicks++;
  }
}

void main() {
  late Directory tmp;
  late RecordingManifestStore store;
  late _FakeRunner runner;
  late RecordingRecoveryService svc;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('recovery_test_');
    store = RecordingManifestStore(documentsDirProvider: () async => tmp);
    runner = _FakeRunner();
    svc = RecordingRecoveryService(store: store, runner: runner);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> plantOrphan(
    String id, {
    String therapist = 'th_1',
    int sizeBytes = 600 * 1024,
    DateTime? startedAtUtc,
    bool withFlac = true,
  }) async {
    await store.write(RecordingManifest(
      sessionId: id,
      therapistId: therapist,
      patientFileId: 'pf_1',
      patientAlias: 'Jan K.',
      patientLanguageCode: 'pl-PL',
      startedAtUtc:
          startedAtUtc ?? DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
    ));
    if (withFlac) {
      await File(p.join(tmp.path, 'sessions', id, 'raw.flac'))
          .writeAsBytes(List.filled(sizeBytes, 1));
    }
  }

  PendingUpload queueRow(String id) => PendingUpload.initial(
        localId: id,
        therapistId: 'th_1',
        patientFileId: 'pf_1',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: '/x/raw.flac',
        contentType: 'audio/flac',
        sizeBytes: 1,
        chunkCount: 1,
        actualDurationSeconds: 1,
        needsServerSideConversion: false,
        idempotencyKey: id,
        now: DateTime.now().toUtc(),
      );

  test('finds a valid orphan with a sane duration estimate', () async {
    // 600 KiB / 9000 B/s ≈ 68 s — well under the 30-min wall clock, so
    // the size bound wins (the recorder sat paused before dying).
    await plantOrphan('s1');
    final found = await svc.findOrphans('th_1');
    expect(found, hasLength(1));
    final r = found.single;
    expect(r.manifest.sessionId, 's1');
    expect(r.sizeBytes, 600 * 1024);
    expect(r.estimatedDuration.inSeconds, 600 * 1024 ~/ 9000);
  });

  test('wall clock bounds the estimate when the file is large', () async {
    // Huge file but only 60 s of wall clock → wall clock wins.
    await plantOrphan('s1',
        sizeBytes: 5 * 1024 * 1024,
        startedAtUtc:
            DateTime.now().toUtc().subtract(const Duration(seconds: 60)));
    final r = (await svc.findOrphans('th_1')).single;
    expect(r.estimatedDuration.inSeconds, lessThanOrEqualTo(62));
    expect(r.estimatedDuration.inSeconds, greaterThanOrEqualTo(58));
  });

  test('skips sessions already owned by the upload queue', () async {
    await plantOrphan('s1');
    runner.rows.add(queueRow('s1'));
    expect(await svc.findOrphans('th_1'), isEmpty);
    // Not deleted either — the queue row owns the audio.
    expect(
      File(p.join(tmp.path, 'sessions', 's1', 'raw.flac')).existsSync(),
      isTrue,
    );
  });

  test('deletes undersized stubs instead of offering them', () async {
    await plantOrphan('tiny', sizeBytes: 10 * 1024);
    expect(await svc.findOrphans('th_1'), isEmpty);
    expect(
      Directory(p.join(tmp.path, 'sessions', 'tiny')).existsSync(),
      isFalse,
    );
  });

  test('missing raw.flac is treated as an undersized stub', () async {
    await plantOrphan('ghost', withFlac: false);
    expect(await svc.findOrphans('th_1'), isEmpty);
    expect(
      Directory(p.join(tmp.path, 'sessions', 'ghost')).existsSync(),
      isFalse,
    );
  });

  test('never surfaces another therapist\'s recording', () async {
    await plantOrphan('foreign', therapist: 'th_OTHER');
    expect(await svc.findOrphans('th_1'), isEmpty);
    // Left on disk for the sweep, not deleted.
    expect(
      File(p.join(tmp.path, 'sessions', 'foreign', 'raw.flac')).existsSync(),
      isTrue,
    );
  });

  test('orphans are returned oldest first', () async {
    await plantOrphan('newer',
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(hours: 1)));
    await plantOrphan('older',
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(hours: 5)));
    final found = await svc.findOrphans('th_1');
    expect(found.map((r) => r.manifest.sessionId).toList(),
        ['older', 'newer']);
  });

  test('recover enqueues the exact plainFile shape and hands off ownership',
      () async {
    await plantOrphan('s1');
    final r = (await svc.findOrphans('th_1')).single;

    await svc.recover(r);

    expect(runner.enqueued, hasLength(1));
    final row = runner.enqueued.single;
    expect(row.localId, 's1');
    expect(row.idempotencyKey, 's1');
    expect(row.therapistId, 'th_1');
    expect(row.patientFileId, 'pf_1');
    expect(row.patientLanguageCode, 'pl-PL');
    expect(row.sourceKind, UploadSourceKind.plainFile);
    expect(row.sourcePath, r.flacPath);
    // audio/x-flac (not audio/flac) so the server re-encodes a possibly
    // unfinalized FLAC header via ffmpeg — see recover() docs / docs/28 R1.
    expect(row.contentType, 'audio/x-flac');
    expect(row.sizeBytes, r.sizeBytes);
    expect(row.chunkCount, 1);
    expect(row.actualDurationSeconds, r.estimatedDuration.inSeconds);
    expect(row.needsServerSideConversion, isTrue);
    expect(row.phase, UploadPhase.pending);
    expect(runner.kicks, 1);

    // Manifest gone (queue row owns the session now), audio intact.
    expect(await store.scanAll(), isEmpty);
    expect(File(r.flacPath).existsSync(), isTrue);

    // And the scan no longer reports it.
    expect(await svc.findOrphans('th_1'), isEmpty);
  });

  test('discard deletes the whole session directory', () async {
    await plantOrphan('s1');
    final r = (await svc.findOrphans('th_1')).single;
    await svc.discard(r);
    expect(
      Directory(p.join(tmp.path, 'sessions', 's1')).existsSync(),
      isFalse,
    );
  });

  test('sweep deletes expired orphans regardless of owner, keeps the rest',
      () async {
    await plantOrphan('fresh');
    await plantOrphan('expired',
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 15)));
    await plantOrphan('expired_foreign',
        therapist: 'th_OTHER',
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 20)));
    await plantOrphan('expired_but_queued',
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 15)));
    runner.rows.add(queueRow('expired_but_queued'));

    await svc.sweep();

    bool dirExists(String id) =>
        Directory(p.join(tmp.path, 'sessions', id)).existsSync();
    expect(dirExists('fresh'), isTrue);
    expect(dirExists('expired'), isFalse);
    expect(dirExists('expired_foreign'), isFalse);
    expect(dirExists('expired_but_queued'), isTrue);
  });

  // ── Manifest-less orphans (sesja a5ce601f, 2026-07-23) ──
  // An App Store downgrade mid-upload dropped the queue row after the
  // manifest was already deleted at enqueue — a full raw.flac nothing
  // owned. These lock the fallback scan + explicit-patient recover.

  Future<void> plantGhost(String id, {int sizeBytes = 600 * 1024}) async {
    final f = File(p.join(tmp.path, 'sessions', id, 'raw.flac'));
    await f.create(recursive: true);
    await f.writeAsBytes(List.filled(sizeBytes, 1));
  }

  test('manifest-less dir with raw.flac is offered with empty patientFileId',
      () async {
    await plantGhost('ghost1');
    final out = await svc.findOrphans('th_1');
    expect(out, hasLength(1));
    expect(out.single.manifest.sessionId, 'ghost1');
    expect(out.single.manifest.patientFileId, isEmpty);
    expect(out.single.manifest.therapistId, 'th_1');
    expect(out.single.sizeBytes, 600 * 1024);
  });

  test('manifest-less dir owned by the queue is not offered', () async {
    await plantGhost('ghost1');
    runner.rows.add(queueRow('ghost1'));
    expect(await svc.findOrphans('th_1'), isEmpty);
  });

  test('undersized manifest-less dir is not offered (left for sweep)',
      () async {
    await plantGhost('tiny', sizeBytes: 10 * 1024);
    expect(await svc.findOrphans('th_1'), isEmpty);
    // NOT deleted eagerly — sweep owns retention for manifest-less dirs.
    expect(
      Directory(p.join(tmp.path, 'sessions', 'tiny')).existsSync(),
      isTrue,
    );
  });

  test('manifest-less recover requires an explicit patientFileId', () async {
    await plantGhost('ghost1');
    final r = (await svc.findOrphans('th_1')).single;

    expect(() => svc.recover(r), throwsArgumentError);
    expect(runner.enqueued, isEmpty);

    await svc.recover(r, patientFileId: 'pf_9', patientLanguageCode: 'en-US');
    final row = runner.enqueued.single;
    expect(row.localId, 'ghost1');
    expect(row.patientFileId, 'pf_9');
    expect(row.patientLanguageCode, 'en-US');
    expect(row.contentType, 'audio/x-flac');
  });

  test('manifest-less CHUNK dir (no raw.flac) is offered as encryptedChunks',
      () async {
    // Offline enqueue encrypted + deleted raw.flac before the row was
    // lost — only chunk_NNNNN.enc files remain.
    final dir = Directory(p.join(tmp.path, 'sessions', 'ghostc'));
    await dir.create(recursive: true);
    for (var i = 0; i < 3; i++) {
      await File(p.join(dir.path, 'chunk_0000$i.enc'))
          .writeAsBytes(List.filled(300 * 1024, 2));
    }
    final r = (await svc.findOrphans('th_1')).single;
    expect(r.encryptedChunks, isTrue);
    expect(r.chunkCount, 3);
    expect(r.flacPath, dir.path);
    expect(r.sizeBytes, 3 * 300 * 1024 - 3 * 29);

    await svc.recover(r, patientFileId: 'pf_9');
    final row = runner.enqueued.single;
    expect(row.sourceKind, UploadSourceKind.encryptedChunks);
    expect(row.sourcePath, dir.path);
    expect(row.chunkCount, 3);
    expect(row.phase, UploadPhase.pending);
  });

  test('sweep ages out stale manifest-less dirs, keeps fresh and queued ones',
      () async {
    await plantGhost('ghost_fresh');
    await plantGhost('ghost_old');
    await plantGhost('ghost_old_queued');
    final old = DateTime.now().subtract(const Duration(days: 15));
    File(p.join(tmp.path, 'sessions', 'ghost_old', 'raw.flac'))
        .setLastModifiedSync(old);
    File(p.join(tmp.path, 'sessions', 'ghost_old_queued', 'raw.flac'))
        .setLastModifiedSync(old);
    runner.rows.add(queueRow('ghost_old_queued'));

    await svc.sweep();

    bool dirExists(String id) =>
        Directory(p.join(tmp.path, 'sessions', id)).existsSync();
    expect(dirExists('ghost_fresh'), isTrue);
    expect(dirExists('ghost_old'), isFalse);
    expect(dirExists('ghost_old_queued'), isTrue);
  });
}
