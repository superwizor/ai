// Testy leasingu transferu natywnego (docs/58 §5-6).
//
// Sprawdzają cztery zachowania, których złamanie jest gorsze od
// dzisiejszego zwisu:
//   1. oddanie transferu systemowi NIE wysyła bajtów w procesie,
//   2. wiersz pod leasingiem nie jest wybierany przez dueNow() — inaczej
//      drugi tick podałby ten sam URI resumable i dwóch pisarzy na
//      różnych offsetach uszkodziłoby obiekt w GCS,
//   3. raport sukcesu z journala domyka wiersz tak samo jak udany PUT,
//   4. raport porażki i zgubiony raport zwracają wiersz na ścieżkę Dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/uploads/background_upload_channel.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_io.dart';
import 'package:superwizor/uploads/upload_queue.dart';
import 'package:superwizor/uploads/upload_queue_runner.dart';
import 'package:superwizor/uploads/upload_worker.dart';

/// Kanał-atrapa. Nadpisuje bramki platformowe, bo testy chodzą na dart VM,
/// gdzie `Platform.isIOS` jest false.
class _FakeChannel extends BackgroundUploadChannel {
  _FakeChannel({this.handOffResult = true});

  bool handOffResult;
  int handOffCalls = 0;
  List<String> cancelled = [];
  List<BackgroundUploadReport> journal = [];
  Set<String> alive = {};

  @override
  bool get supportsOsHandOff => true;

  @override
  bool get supportsForegroundWindow => false;

  @override
  Future<bool> handOff({
    required String localId,
    required String uploadUri,
    required String filePath,
    required String contentType,
    required int totalBytes,
  }) async {
    handOffCalls++;
    if (handOffResult) alive.add(localId);
    return handOffResult;
  }

  @override
  Future<void> cancel(String localId) async => cancelled.add(localId);

  @override
  Future<Set<String>> pendingIds() async => alive;

  @override
  Future<List<BackgroundUploadReport>> drainJournal() async {
    final out = journal;
    journal = [];
    return out;
  }
}

class _FakeIo implements UploadIo {
  int putCalls = 0;
  int cleanupCalls = 0;

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async =>
      CreateAudioUploadResult(
        uploadId: 'au-${u.localId}',
        signedUrl: 'https://signed/${u.localId}',
        sessionId: 'sess-${u.localId}',
        resumableSessionUri: 'https://storage.googleapis.com/upload/${u.localId}',
      );

  @override
  Future<void> putBytes(PendingUpload u,
      {void Function(double)? onProgress}) async {
    putCalls++;
  }

  @override
  Future<ConvertResult> convertSource(PendingUpload u,
          {void Function(double)? onProgress}) async =>
      ConvertResult(
        sourcePath: u.sourcePath,
        contentType: u.contentType,
        sizeBytes: u.sizeBytes,
        needsServerSideConversion: u.needsServerSideConversion,
      );

  @override
  Future<EncryptResult> encryptSource(PendingUpload u,
          {void Function(double)? onProgress}) async =>
      EncryptResult(sizeBytes: u.sizeBytes, chunkCount: u.chunkCount);

  @override
  Future<void> cleanupSource(PendingUpload u) async => cleanupCalls++;

  @override
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async =>
      0;
}

PendingUpload _seed(String id) => PendingUpload.initial(
      localId: id,
      therapistId: 'th-1',
      patientFileId: 'pf-1',
      patientLanguageCode: 'pl-PL',
      // plainFile: tylko ta ścieżka trafia do systemu — encryptedChunks
      // wymaga odszyfrowania do tempa i zostaje w Darcie.
      sourceKind: UploadSourceKind.plainFile,
      sourcePath: '/tmp/$id.flac',
      contentType: 'audio/flac',
      sizeBytes: 1024,
      chunkCount: 1,
      actualDurationSeconds: 60,
      needsServerSideConversion: false,
      idempotencyKey: id,
      now: DateTime.now().toUtc(),
    );

void main() {
  late Directory tmpDir;
  late Box<Map> rawBox;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('bg_upload_');
    Hive.init(tmpDir.path);
    rawBox =
        await Hive.openBox<Map>('bg_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  UploadQueueRunner build({
    required UploadQueue queue,
    required _FakeIo io,
    required _FakeChannel channel,
  }) =>
      UploadQueueRunner(
        queue: queue,
        worker: UploadWorker(io: io, background: channel),
        background: channel,
        periodicInterval: const Duration(hours: 1),
        connectivityStream: const Stream.empty(),
        hasNetwork: () async => true,
      );

  test('oddanie systemowi: leasing zamiast PUT-a w procesie', () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final io = _FakeIo();
    final channel = _FakeChannel();
    final runner = build(queue: queue, io: io, channel: channel);
    await runner.start();
    await runner.enqueueAndKick(_seed('a'));

    final row = queue.getById('a')!;
    expect(channel.handOffCalls, 1);
    expect(io.putCalls, 0, reason: 'bajty wiozie system, nie proces');
    expect(row.phase, UploadPhase.created,
        reason: 'wiersz czeka na raport, nie jest jeszcze completed');
    expect(row.nativeLeaseAt, isNotNull);
    expect(row.isNativeLeaseFresh, isTrue);

    // 2. Wiersz pod leasingiem nie może wrócić do kolejki.
    expect(queue.dueNow().map((u) => u.localId), isNot(contains('a')));

    await runner.dispose();
  });

  test('native odmawia → spadamy na PUT w procesie', () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final io = _FakeIo();
    final channel = _FakeChannel(handOffResult: false);
    final runner = build(queue: queue, io: io, channel: channel);
    await runner.start();
    await runner.enqueueAndKick(_seed('b'));

    final row = queue.getById('b')!;
    expect(channel.handOffCalls, 1);
    expect(io.putCalls, 1, reason: 'fallback na ścieżkę Dart');
    expect(row.phase, UploadPhase.completed);
    expect(row.nativeLeaseAt, isNull);

    await runner.dispose();
  });

  test('journal: sukces domyka wiersz i sprząta źródło', () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final io = _FakeIo();
    final channel = _FakeChannel();
    final runner = build(queue: queue, io: io, channel: channel);
    await runner.start();
    await runner.enqueueAndKick(_seed('c'));
    expect(queue.getById('c')!.phase, UploadPhase.created);

    channel.journal = [
      const BackgroundUploadReport(
          localId: 'c', success: true, httpStatus: 200, bytesSent: 1024),
    ];
    await runner.kick();

    final row = queue.getById('c')!;
    expect(row.phase, UploadPhase.completed);
    expect(row.nativeLeaseAt, isNull);
    expect(row.terminatedAt, isNotNull);
    expect(io.cleanupCalls, greaterThanOrEqualTo(1),
        reason: 'ta sama ścieżka sprzątania co udany PUT w procesie');

    await runner.dispose();
  });

  test('journal: porażka zdejmuje leasing i wraca na ścieżkę Dart', () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final io = _FakeIo();
    final channel = _FakeChannel();
    final runner = build(queue: queue, io: io, channel: channel);
    await runner.start();
    await runner.enqueueAndKick(_seed('d'));

    channel.journal = [
      const BackgroundUploadReport(
          localId: 'd', success: false, httpStatus: 503),
    ];
    channel.alive.clear();
    await runner.kick();

    final row = queue.getById('d')!;
    expect(row.phase, UploadPhase.pending);
    expect(row.nativeLeaseAt, isNull);
    expect(row.lastError, contains('503'),
        reason: 'błąd musi być widoczny — cichy zwis był całym problemem');
    expect(row.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue,
        reason: 'zwykły backoff, nie natychmiastowa pętla');

    await runner.dispose();
  });

  test('przedawniony raport: failed bez leasingu ignorowany, success przyjmowany',
      () async {
    // Pułapka zgłoszona przez implementację iOS: `task.cancel()` ląduje w
    // tym samym callbacku co prawdziwa porażka, więc anulowany wiersz
    // zostawia w journalu wpis `failed`. Gdybyśmy go zastosowali, każdy
    // anulowany-i-ponowiony upload dostawałby fałszywy błąd i niezasłużony
    // backoff. Sukces jest odwrotnie: musi wejść nawet bez leasingu, bo
    // inaczej Dart wysłałby obiekt drugi raz, a ifGenerationMatch=0 zwróci
    // wtedy 412, które klasyfikator uznaje za terminalne.
    final queue = UploadQueue(hiveBox: rawBox);
    final io = _FakeIo();
    final channel = _FakeChannel(handOffResult: false);
    final runner = build(queue: queue, io: io, channel: channel);
    await runner.start();

    await queue.enqueue(_seed('f').copyWith(
      phase: UploadPhase.pending,
      nextAttemptAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      lastError: 'poprzedni błąd',
    ));

    channel.journal = [
      const BackgroundUploadReport(
          localId: 'f', success: false, httpStatus: 499),
    ];
    await runner.kick();

    var row = queue.getById('f')!;
    expect(row.lastError, 'poprzedni błąd',
        reason: 'przedawniony failed nie może nadpisać stanu wiersza');
    expect(row.phase, UploadPhase.pending);

    channel.journal = [
      const BackgroundUploadReport(
          localId: 'f', success: true, httpStatus: 200, bytesSent: 10),
    ];
    await runner.kick();

    row = queue.getById('f')!;
    expect(row.phase, UploadPhase.completed,
        reason: 'bajty są w GCS — powtórny upload skończyłby się 412');

    await runner.dispose();
  });

  test('zgubiony raport: leasing bez zadania w systemie wraca do kolejki',
      () async {
    final queue = UploadQueue(hiveBox: rawBox);
    final io = _FakeIo();
    final channel = _FakeChannel();
    final runner = build(queue: queue, io: io, channel: channel);
    await runner.start();
    await runner.enqueueAndKick(_seed('e'));
    expect(queue.getById('e')!.isNativeLeaseFresh, isTrue);

    // Force-quit / reinstall: system nie ma już zadania, journal pusty.
    channel.alive.clear();
    await runner.kick();

    // Wiersz MUSI znowu jechać. Ten sam tick zdjął martwy leasing i oddał
    // go systemowi ponownie — bez tego czekałby na wygaśnięcie TTL, czyli
    // 12 h. To jest cała pointa tej gałęzi rekoncyliacji.
    expect(channel.handOffCalls, 2,
        reason: 'martwy leasing zdjęty i wiersz podany dalej');
    expect(queue.getById('e')!.isNativeLeaseFresh, isTrue);

    // Wariant: system odmawia przy drugim podejściu → ścieżka Dart domyka.
    channel.handOffResult = false;
    channel.alive.clear();
    await runner.kick();

    final row = queue.getById('e')!;
    expect(row.nativeLeaseAt, isNull);
    expect(row.phase, UploadPhase.completed);
    expect(io.putCalls, 1, reason: 'PUT w procesie jako fallback');

    await runner.dispose();
  });
}
