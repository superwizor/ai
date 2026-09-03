// Bramka „potwierdzony e-mail" przed CreateAudioUpload (docs/70 S1 krok 3, E4).
//
// Kontrakt, którego te testy pilnują:
//   1. bez potwierdzonego adresu CreateAudioUpload NIE leci — to jedyne
//      miejsce, w którym da się spalić tokeny STT/LLM, więc tu zamyka się
//      „farma triali" na zmyślone adresy,
//   2. wiersz jest WSTRZYMANY, nie utracony i nie oznaczony jako błąd:
//      audio zostaje na urządzeniu i rusza samo po potwierdzeniu,
//   3. nieudana sonda (brak sieci) PRZEPUSZCZA — usterka sieci nie może
//      zamienić się w utratę sesji; prawdziwą bramką jest i tak serwer,
//   4. UX-1 z docs/17 nietknięte: bramka nie dotyka nagrywania ani
//      szyfrowania, wyłącznie wysyłki.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_io.dart';
import 'package:superwizor/uploads/upload_queue.dart';
import 'package:superwizor/uploads/upload_queue_runner.dart';
import 'package:superwizor/uploads/upload_worker.dart';

class _FakeIo implements UploadIo {
  int createCalls = 0;
  int encryptCalls = 0;

  @override
  Future<CreateAudioUploadResult> createUpload(PendingUpload u) async {
    createCalls++;
    return const CreateAudioUploadResult(
        uploadId: 'au-1', signedUrl: 'https://signed/1', sessionId: 'sess-1');
  }

  @override
  Future<void> putBytes(PendingUpload u,
      {void Function(double)? onProgress}) async {}

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
      {void Function(double)? onProgress}) async {
    encryptCalls++;
    return EncryptResult(sizeBytes: u.sizeBytes, chunkCount: u.chunkCount);
  }

  @override
  Future<String?> materializeForOsHandOff(PendingUpload u) async =>
      u.sourcePath;

  @override
  Future<void> cleanupSource(PendingUpload u) async {}

  @override
  Future<int> pruneOrphanedSources({
    required Set<String> liveLocalIds,
    required Duration maxAge,
  }) async =>
      0;
}

PendingUpload _seed(String id, {UploadSourceKind? kind}) =>
    PendingUpload.initial(
      localId: id,
      therapistId: 'th',
      patientFileId: 'pf',
      patientLanguageCode: 'pl-PL',
      sourceKind: kind ?? UploadSourceKind.plainFile,
      sourcePath: '/$id',
      contentType: 'audio/flac',
      sizeBytes: 100,
      chunkCount: 1,
      actualDurationSeconds: 0,
      needsServerSideConversion: false,
      idempotencyKey: id,
      now: DateTime.now().toUtc(),
    );

void main() {
  late Directory tmpDir;
  late Box<Map> rawBox;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('email_gate_test_');
    Hive.init(tmpDir.path);
    rawBox = await Hive.openBox<Map>(
        'gate_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  UploadQueueRunner build(UploadQueue queue, _FakeIo io,
          {IsEmailVerified? gate}) =>
      UploadQueueRunner(
        queue: queue,
        worker: UploadWorker(io: io, backoff: (_) => Duration.zero),
        periodicInterval: const Duration(hours: 1),
        connectivityStream: const Stream.empty(),
        hasNetwork: () async => true,
        isEmailVerified: gate,
      );

  test('niepotwierdzony adres wstrzymuje CreateAudioUpload', () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = build(queue, io, gate: () async => false);
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));

    final row = queue.getById('a')!;
    expect(io.createCalls, 0, reason: 'żaden token nie może zostać spalony');
    expect(row.phase, UploadPhase.pending,
        reason: 'wiersz czeka, nie jest ani błędem, ani parkiem kwotowym');
    expect(row.lastError, kEmailUnverifiedError);
    expect(row.nextAttemptAt.isAfter(DateTime.now().toUtc()), isTrue,
        reason: 'próba jest odroczona, nie porzucona');

    await runner.dispose();
  });

  test('potwierdzony adres przepuszcza upload', () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = build(queue, io, gate: () async => true);
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));

    expect(io.createCalls, 1);
    expect(queue.getById('a')!.lastError, isNot(kEmailUnverifiedError));

    await runner.dispose();
  });

  test('nieudana sonda NIE blokuje — usterka sieci to nie utrata sesji',
      () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = build(queue, io,
        gate: () async => throw Exception('brak sieci'));
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));

    expect(io.createCalls, 1);

    await runner.dispose();
  });

  test('brak wstrzykniętej bramki zachowuje się jak przed docs/70', () async {
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = build(queue, io);
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));

    expect(io.createCalls, 1);

    await runner.dispose();
  });

  test('bramka NIE dotyka szyfrowania — audio jest zabezpieczane mimo blokady',
      () async {
    // UX-1: nagrywanie i zabezpieczanie nagrania działają zawsze. Bramka
    // stoi wyłącznie przed wysyłką, a nie przed pracą lokalną.
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = build(queue, io, gate: () async => false);
    await runner.start();

    // Wiersz z nagrania na żywo: najpierw szyfrowanie na urządzeniu,
    // dopiero potem wysyłka.
    await runner.enqueueAndKick(
      _seed('a', kind: UploadSourceKind.encryptedChunks)
          .copyWith(phase: UploadPhase.encrypting),
    );

    expect(io.encryptCalls, greaterThan(0),
        reason: 'faza encrypting musi się wykonać mimo zamkniętej bramki');
    expect(io.createCalls, 0,
        reason: 'wysyłka czeka na potwierdzony adres');
    final row = queue.getById('a')!;
    expect(row.phase, UploadPhase.pending,
        reason: 'audio jest już zaszyfrowane i czeka bezpiecznie na wysyłkę');
    expect(row.lastError, kEmailUnverifiedError);

    await runner.dispose();
  });

  test('po potwierdzeniu adresu bramka nie pyta ponownie', () async {
    // `emailVerified` nie wraca do false, a każde sprawdzenie to
    // `currentUser.reload()` — sieciowe wywołanie na każdy wiersz i tick.
    var probes = 0;
    final io = _FakeIo();
    final queue = UploadQueue(hiveBox: rawBox);
    final runner = build(queue, io, gate: () async {
      probes++;
      return true;
    });
    await runner.start();

    await runner.enqueueAndKick(_seed('a'));
    await runner.enqueueAndKick(_seed('b'));

    expect(probes, 1);
    expect(io.createCalls, 2);

    await runner.dispose();
  });
}
