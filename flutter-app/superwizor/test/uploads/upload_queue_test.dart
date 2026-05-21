// UploadQueue tests. Uses an in-memory Hive box (no encryption) to
// isolate the queue's contract from CacheCipher / flutter_secure_storage.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_queue.dart';

PendingUpload _u(
  String id, {
  UploadPhase phase = UploadPhase.pending,
  DateTime? queuedAt,
  DateTime? nextAttemptAt,
}) {
  final q = queuedAt ?? DateTime.utc(2026, 5, 20, 12);
  return PendingUpload(
    localId: id,
    therapistId: 'th-1',
    patientFileId: 'pf-1',
    patientLanguageCode: 'pl-PL',
    sourceKind: UploadSourceKind.plainFile,
    sourcePath: '/$id',
    contentType: 'audio/flac',
    sizeBytes: 100,
    chunkCount: 1,
    actualDurationSeconds: 0,
    needsServerSideConversion: false,
    phase: phase,
    idempotencyKey: id,
    queuedAt: q,
    nextAttemptAt: nextAttemptAt ?? q,
  );
}

void main() {
  late Directory tmpDir;
  late Box<Map> rawBox;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('upload_queue_test_');
    Hive.init(tmpDir.path);
    rawBox = await Hive.openBox<Map>(
        'pending_uploads_test_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  UploadQueue queue({DateTime Function()? clock, Duration? maxAge}) =>
      UploadQueue(hiveBox: rawBox, clock: clock, maxAge: maxAge);

  test('enqueue + getById round-trips a row', () async {
    final q = queue();
    await q.enqueue(_u('a'));

    final hit = q.getById('a');
    expect(hit, isNotNull);
    expect(hit!.localId, 'a');
    expect(hit.phase, UploadPhase.pending);
  });

  test('enqueue with existing localId overwrites', () async {
    final q = queue();
    await q.enqueue(_u('a'));
    await q.enqueue(_u('a', phase: UploadPhase.uploaded));

    expect(q.all(), hasLength(1));
    expect(q.getById('a')!.phase, UploadPhase.uploaded);
  });

  test('update throws when row is missing', () async {
    final q = queue();
    expect(() => q.update(_u('missing')), throwsStateError);
  });

  test('removeById drops the row', () async {
    final q = queue();
    await q.enqueue(_u('a'));
    await q.removeById('a');
    expect(q.getById('a'), isNull);
  });

  test('dueNow returns only non-terminal rows that are due', () async {
    final now = DateTime.utc(2026, 5, 20, 13);
    final q = queue(clock: () => now);

    await q.enqueue(_u('due-pending', queuedAt: now.subtract(const Duration(hours: 1))));
    await q.enqueue(_u('due-uploaded',
        phase: UploadPhase.uploaded,
        queuedAt: now.subtract(const Duration(hours: 1))));
    await q.enqueue(_u('not-yet-due',
        nextAttemptAt: now.add(const Duration(minutes: 30))));
    await q.enqueue(_u('completed', phase: UploadPhase.completed));
    await q.enqueue(_u('failed', phase: UploadPhase.failed));

    final due = q.dueNow();
    expect(due.map((u) => u.localId).toSet(),
        equals({'due-pending', 'due-uploaded'}));
  });

  test('dueNow orders by queuedAt ascending (fair queue)', () async {
    final now = DateTime.utc(2026, 5, 20, 13);
    final q = queue(clock: () => now);

    await q.enqueue(_u('newer', queuedAt: now.subtract(const Duration(minutes: 5))));
    await q.enqueue(_u('older', queuedAt: now.subtract(const Duration(hours: 2))));
    await q.enqueue(_u('middle', queuedAt: now.subtract(const Duration(hours: 1))));

    final due = q.dueNow();
    expect(due.map((u) => u.localId).toList(), ['older', 'middle', 'newer']);
  });

  test('pruneStale force-terminates rows older than maxAge', () async {
    final now = DateTime.utc(2026, 5, 20, 12);
    final q = queue(
      clock: () => now,
      maxAge: const Duration(days: 7),
    );

    // Old non-terminal row should be reaped.
    await q.enqueue(_u('old', queuedAt: now.subtract(const Duration(days: 8))));
    // Young row should be untouched.
    await q.enqueue(_u('young', queuedAt: now.subtract(const Duration(hours: 1))));
    // Old but already terminal — leave alone.
    await q.enqueue(_u('old-completed',
        phase: UploadPhase.completed,
        queuedAt: now.subtract(const Duration(days: 8))));

    final swept = await q.pruneStale();
    expect(swept, 1);

    final reaped = q.getById('old')!;
    expect(reaped.phase, UploadPhase.failed);
    expect(reaped.lastError, 'queue.max_age_exceeded');
    expect(reaped.terminatedAt, isNotNull);

    expect(q.getById('young')!.phase, UploadPhase.pending);
    expect(q.getById('old-completed')!.phase, UploadPhase.completed);
  });

  test('clearAll wipes the box', () async {
    final q = queue();
    await q.enqueue(_u('a'));
    await q.enqueue(_u('b'));

    await q.clearAll();
    expect(q.all(), isEmpty);
  });

  test('all() skips corrupt rows without throwing', () async {
    final q = queue();
    await q.enqueue(_u('good'));
    // Hand-inject a corrupt row that fromJson would reject.
    await rawBox.put('bad', {'totally': 'wrong shape'});

    final rows = q.all();
    expect(rows.map((u) => u.localId).toList(), ['good']);
  });
}
