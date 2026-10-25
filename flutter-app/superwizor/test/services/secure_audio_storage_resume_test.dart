// Wznawianie przyrostowe szyfrowania (fix z 18.09.2026).
//
// Regresja, której te testy pilnują: `encryptRecording` kasowała na
// wejściu wszystkie chunki z poprzedniej próby. W połączeniu z limitem
// czasu w fazie `encrypting` dawało to żywe zakleszczenie — nagranie,
// które raz nie zmieściło się w oknie, nie zmieściło się nigdy, bo
// każda próba zaczynała od zera. Sesja z 15.09.2026 (46 min, 76,8 MB)
// nie dotarła przez to nawet do CreateAudioUpload.
//
// Dowód na to, że chunk został PONOWNIE UŻYTY, a nie policzony od
// nowa: jego bajty są identyczne. IV jest losowy dla każdego chunka,
// więc ponowne szyfrowanie tych samych danych zawsze daje inny plik.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:superwizor/services/secure_audio_storage_service.dart';
import 'package:superwizor/uploads/stall_guard.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sas_resume_test_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// 2,5 MB deterministycznych bajtów → 2 pełne chunki + ogon.
  Uint8List zrobDane() {
    final rng = Random(7);
    final bytes = Uint8List(2500000);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  String sciezkaChunka(String sessionId, int seq) => p.join(
      root.path, 'sessions', sessionId, 'chunk_${seq.toString().padLeft(5, '0')}.enc');

  Future<String> zapiszRaw(String sessionId, Uint8List dane) async {
    final dir = Directory(p.join(root.path, 'sessions', sessionId))
      ..createSync(recursive: true);
    final rawPath = p.join(dir.path, 'raw.flac');
    await File(rawPath).writeAsBytes(dane, flush: true);
    return rawPath;
  }

  test('przerwana próba jest wznawiana, a gotowe chunki nie są liczone od nowa',
      () async {
    final svc = SecureAudioStorageService();
    const sessionId = 'sess-resume-1';
    final dane = zrobDane();

    // Pierwsze przejście — pełne, żeby mieć prawdziwe chunki na dysku.
    var rawPath = await zapiszRaw(sessionId, dane);
    final pierwsze = await svc.encryptRecording(
        rawPath: rawPath, sessionId: sessionId);
    expect(pierwsze.length, 3);

    final chunk0Przed = await File(sciezkaChunka(sessionId, 0)).readAsBytes();

    // Symulacja próby przerwanej po pierwszym chunku: raw.flac wraca
    // (bo kasowany jest dopiero po sukcesie), chunki 1 i 2 znikają.
    rawPath = await zapiszRaw(sessionId, dane);
    await File(sciezkaChunka(sessionId, 1)).delete();
    await File(sciezkaChunka(sessionId, 2)).delete();

    final postep = <double>[];
    final drugie = await svc.encryptRecording(
      rawPath: rawPath,
      sessionId: sessionId,
      onProgress: postep.add,
    );

    expect(drugie.length, 3, reason: 'komplet chunków po wznowieniu');
    expect(drugie.map((c) => c.seq), [0, 1, 2],
        reason: 'numeracja ciągła — wznowienie dokleja się do prefiksu');

    final chunk0Po = await File(sciezkaChunka(sessionId, 0)).readAsBytes();
    expect(chunk0Po, equals(chunk0Przed),
        reason: 'chunk 0 MUSI być ten sam plik — gdyby był szyfrowany od '
            'nowa, losowy IV dałby inne bajty');

    // I najważniejsze: wynik nadal odszyfrowuje się do oryginału.
    final temp = await svc.decryptToTempFile(sessionId: sessionId);
    expect(await temp.readAsBytes(), equals(dane),
        reason: 'wznowiony zestaw chunków musi odtworzyć dokładnie wejście');

    expect(postep, isNotEmpty,
        reason: 'onProgress karmi StallGuard — bez niego długie nagranie '
            'wygląda jak zawieszone');
    expect(postep.last, closeTo(1.0, 0.001));
  });

  test('urwany chunk nie jest wznawiany, tylko liczony od nowa', () async {
    final svc = SecureAudioStorageService();
    const sessionId = 'sess-resume-2';
    final dane = zrobDane();

    var rawPath = await zapiszRaw(sessionId, dane);
    await svc.encryptRecording(rawPath: rawPath, sessionId: sessionId);
    final chunk0Przed = await File(sciezkaChunka(sessionId, 0)).readAsBytes();

    // Zapis urwany w połowie — plik krótszy niż pełny chunk.
    rawPath = await zapiszRaw(sessionId, dane);
    await File(sciezkaChunka(sessionId, 0))
        .writeAsBytes(chunk0Przed.sublist(0, 5000), flush: true);
    await File(sciezkaChunka(sessionId, 1)).delete();
    await File(sciezkaChunka(sessionId, 2)).delete();

    final wynik = await svc.encryptRecording(
        rawPath: rawPath, sessionId: sessionId);

    expect(wynik.length, 3);
    final chunk0Po = await File(sciezkaChunka(sessionId, 0)).readAsBytes();
    expect(chunk0Po, isNot(equals(chunk0Przed)),
        reason: 'urwanego chunka nie wolno uznać za gotowy');

    final temp = await svc.decryptToTempFile(sessionId: sessionId);
    expect(await temp.readAsBytes(), equals(dane));
  });

  test('dziura w numeracji ucina prefiks — reszta liczona od nowa', () async {
    final svc = SecureAudioStorageService();
    const sessionId = 'sess-resume-3';
    final dane = zrobDane();

    var rawPath = await zapiszRaw(sessionId, dane);
    await svc.encryptRecording(rawPath: rawPath, sessionId: sessionId);

    // Chunk 0 zniknął, 1 i 2 zostały — prefiks jest pusty, więc cała
    // reszta musi zostać przeliczona, a stare pliki skasowane.
    rawPath = await zapiszRaw(sessionId, dane);
    final chunk1Przed = await File(sciezkaChunka(sessionId, 1)).readAsBytes();
    await File(sciezkaChunka(sessionId, 0)).delete();

    final wynik = await svc.encryptRecording(
        rawPath: rawPath, sessionId: sessionId);

    expect(wynik.length, 3);
    expect(wynik.map((c) => c.seq), [0, 1, 2]);
    final chunk1Po = await File(sciezkaChunka(sessionId, 1)).readAsBytes();
    expect(chunk1Po, isNot(equals(chunk1Przed)),
        reason: 'bez chunka 0 nie ma czego wznawiać — 1 też leci od nowa');

    final temp = await svc.decryptToTempFile(sessionId: sessionId);
    expect(await temp.readAsBytes(), equals(dane));
  });

  test('dwa równoległe wywołania scalają się w jedno szyfrowanie', () async {
    final svc = SecureAudioStorageService();
    const sessionId = 'sess-resume-4';
    final dane = zrobDane();
    final rawPath = await zapiszRaw(sessionId, dane);

    // Tak wygląda porzucona próba (limit czasu) + kolejny tick runnera:
    // dwa wywołania dla tej samej sesji żyją naraz. Bez scalania
    // drugie kasowałoby chunki pisane właśnie przez pierwsze.
    final a = svc.encryptRecording(rawPath: rawPath, sessionId: sessionId);
    final b = svc.encryptRecording(rawPath: rawPath, sessionId: sessionId);

    final wyniki = await Future.wait([a, b]);

    expect(wyniki[0].length, 3);
    expect(wyniki[1].length, 3);
    expect(wyniki[0].map((c) => c.path), equals(wyniki[1].map((c) => c.path)),
        reason: 'oba wywołania muszą zobaczyć ten sam zestaw plików');

    final temp = await svc.decryptToTempFile(sessionId: sessionId);
    expect(await temp.readAsBytes(), equals(dane));
  });

  // Regresja z 23.10.2026 (Altea Leszczynska, build 1.0.9+64): KAŻDE
  // nagranie na żywo stawało w `encrypting` z błędem
  //   "Illegal argument in isolate message: object is unsendable -
  //    Library:'dart:async'".
  // Domknięcie dla Isolate.run przechwytywało wspólny kontekst funkcji,
  // a w nim `onProgress`. W produkcji onProgress to `(_) => guard.beat()`
  // z UploadWorkera — ciągnie StallGuard, zegary i Timer, których nie da
  // się przesłać do izolatu. Testy z 18.09 tego nie złapały, bo podawały
  // `postep.add` — tear-off zwykłej listy, który akurat JEST przesyłalny.
  // Ten test używa dokładnie produkcyjnego kształtu: StallGuard.run
  // owija encryptRecording, a onProgress bije w guard.
  test('callback postępu z nieprzesyłalnym stanem nie wywraca izolatu',
      () async {
    final svc = SecureAudioStorageService();
    const sessionId = 'sess-unsendable-1';
    final dane = zrobDane();
    final rawPath = await zapiszRaw(sessionId, dane);

    // Produkcyjny zegar, nie MonotonicForegroundClock: UploadWorker
    // domyślnie bierze AppLifecycleForegroundClock, który trzyma
    // WidgetsBinding — i to on jest nieprzesyłalny. Pierwsza wersja
    // tego testu użyła zegara monotonicznego i PRZECHODZIŁA na wadliwym
    // kodzie, czyli powtarzała dokładnie ślepą plamkę testów z 18.09.
    final zegarBezczynnosci = AppLifecycleForegroundClock.create();
    final zegarBudzetu = AppLifecycleForegroundClock.create();
    addTearDown(zegarBezczynnosci.dispose);
    addTearDown(zegarBudzetu.dispose);
    expect(zegarBezczynnosci, isA<AppLifecycleForegroundClock>(),
        reason: 'test ma sens tylko z zegarem trzymającym WidgetsBinding');

    final guard = StallGuard(
      window: const Duration(minutes: 2),
      clock: zegarBezczynnosci,
      budget: const Duration(minutes: 100),
      budgetClock: zegarBudzetu,
    );
    var bicia = 0;

    final chunks = await guard.run(
      svc.encryptRecording(
        rawPath: rawPath,
        sessionId: sessionId,
        onProgress: (_) {
          bicia++;
          guard.beat();
        },
      ),
      label: 'Szyfrowanie nagrania',
    );

    expect(chunks.length, 3);
    expect(bicia, 3, reason: 'jedno bicie na każdy zapisany chunk');

    final temp = await svc.decryptToTempFile(sessionId: sessionId);
    expect(await temp.readAsBytes(), equals(dane));
  });
}
