// Sklejanie segmentów nagrania — czy wynik jest JEDNYM strumieniem FLAC.
//
// Kontekst (2026-07-30): terapeuta zgłosił, że po nagraniu w tle w
// transkrypcji brakuje mniej więcej minuty KOŃCÓWKI. Segment-per-resume
// (2026-07-23) zamyka plik przy każdym wznowieniu i otwiera nowy, a
// `stop()` skleja je z powrotem w `raw.flac`. Sklejanie jest bajt po
// bajcie (`sink.writeFrom(await f.readAsBytes())`), więc drugi segment
// trafia do pliku RAZEM z własnym nagłówkiem `fLaC` i blokiem
// STREAMINFO.
//
// Plik z dwoma nagłówkami to nie jedno nagranie, tylko dwa niezależne
// strumienie sklejone w jeden bajtostrumień. Dekodery (ffmpeg, a za nim
// STT) czytają pierwszy strumień i kończą na jego końcu — wszystko po
// nim jest ignorowane jako śmieci. Stąd „brakuje końcówki": brakuje
// dokładnie tego, co nagrało się po ostatnim wznowieniu.
//
// Test jest o wyniku, nie o implementacji: po `stop()` plik ma zawierać
// DOKŁADNIE JEDEN nagłówek `fLaC`, na offsecie 0.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:superwizor/services/recording_service.dart';

/// Magic FLAC — pierwsze cztery bajty każdego strumienia.
const _flacMagic = [0x66, 0x4C, 0x61, 0x43]; // "fLaC"

/// Ile razy sekwencja `fLaC` występuje w pliku.
int _countFlacStreams(List<int> bytes) {
  var count = 0;
  for (var i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] == _flacMagic[0] &&
        bytes[i + 1] == _flacMagic[1] &&
        bytes[i + 2] == _flacMagic[2] &&
        bytes[i + 3] == _flacMagic[3]) {
      count++;
    }
  }
  return count;
}

/// Rekorder-atrapa piszący pliki, które WYGLĄDAJĄ jak FLAC: nagłówek
/// `fLaC` + ładunek. Dzięki temu w wyniku da się policzyć strumienie.
class _FlacFakeRecorder extends Fake implements AudioRecorder {
  final _stateCtrl = StreamController<RecordState>.broadcast();

  bool permission = true;
  bool nativePaused = false;
  String? lastPath;

  /// Ile bajtów „audio" dopisać po nagłówku przy każdym starcie segmentu.
  int payloadBytes = 4096;

  void emitNative(RecordState s) => _stateCtrl.add(s);
  Future<void> closeForTest() => _stateCtrl.close();

  @override
  Stream<RecordState> onStateChanged() => _stateCtrl.stream;

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    lastPath = path;
    nativePaused = false;
    await File(path).writeAsBytes([
      ..._flacMagic,
      ...List.filled(payloadBytes, 0x42),
    ]);
    emitNative(RecordState.record);
    // Wznowienie musi „urosnąć", bo serwis weryfikuje, że nagrywanie
    // realnie ruszyło, zanim uzna resume za udane.
    // Opóźniony dopis MUSI być nierzucający: odpala się także po
    // teardownie, gdy katalog testu już nie istnieje, a nieobsłużony
    // wyjątek psuje kolejny test zamiast ten.
    unawaited(
        Future<void>.delayed(const Duration(milliseconds: 30)).then((_) async {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.writeAsBytes(List.filled(512, 0x43), mode: FileMode.append);
        }
      } catch (_) {/* katalog testu zniknął — nic nie szkodzi */}
    }));
  }

  @override
  Future<void> pause() async {
    nativePaused = true;
    emitNative(RecordState.pause);
  }

  @override
  Future<void> resume() async {
    nativePaused = false;
    // To robi record_ios: wznowienie NIE kontynuuje istniejącego
    // strumienia, tylko dopisuje do tego samego pliku nowy, kompletny
    // strumień FLAC — z własnym nagłówkiem `fLaC` i STREAMINFO
    // (recording_service.dart:184-200 opisuje to wprost).
    final path = lastPath;
    emitNative(RecordState.record);
    // Dopis MUSI trafić w okno sondy `_verifyCapture`, która mierzy
    // przyrost pliku PO powrocie z resume() — stąd opóźnienie, tak samo
    // jak w istniejącym recording_service_test.dart.
    if (path != null) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 30))
          .then((_) async {
        try {
          await File(path).writeAsBytes(
            [..._flacMagic, ...List.filled(payloadBytes, 0x44)],
            mode: FileMode.append,
          );
        } catch (_) {/* katalog testu zniknął */}
      }));
    }
  }

  @override
  Future<String?> stop() async {
    emitNative(RecordState.stop);
    return lastPath;
  }

  @override
  Future<bool> isPaused() async => nativePaused;

  @override
  Future<bool> isRecording() async => !nativePaused && lastPath != null;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('ai.superwizor/reminder_service'),
    (call) async => null,
  );

  late Directory tmp;
  late _FlacFakeRecorder recorder;
  late RecordingService service;

  Future<void> pump([int ms = 20]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('flac_concat_');
    recorder = _FlacFakeRecorder();
    service = RecordingService(
      recorder: recorder,
      recorderFactory: () => recorder,
      documentsDirProvider: () async => tmp,
      wakelockSetter: (_) async {},
      captureProbeWindow: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    await service.dispose();
    await recorder.closeForTest();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('nagranie bez wznowień to jeden strumień FLAC', () async {
    await service.start('s-clean');
    await pump();
    final out = await service.stop();

    expect(out, isNotNull);
    final bytes = await File(out!).readAsBytes();
    expect(_countFlacStreams(bytes), 1,
        reason: 'nagranie ciągłe ma dokładnie jeden nagłówek');
  });

  test('po przerwaniu i wznowieniu wynik NADAL musi być jednym strumieniem',
      () async {
    await service.start('s-rotated');
    await pump();

    // Przerwanie systemowe (telefon, alarm, Siri) — plugin sam pauzuje.
    recorder.emitNative(RecordState.pause);
    await pump();
    expect(service.state, RecordingState.interrupted);

    // Wznowienie: rotacja segmentów została wycofana 2026-07-23
    // (recording_service.dart:525-534), więc serwis robi zwykły
    // resume() do TEGO SAMEGO pliku.
    final resumed = await service.resume();
    expect(resumed, isTrue, reason: 'atrapa dopisuje bajty, sonda przechodzi');
    await pump(60);

    final out = await service.stop();
    expect(out, isNotNull);
    final bytes = await File(out!).readAsBytes();

    // Klient WIE, że plik wymaga naprawy — flaga steruje content-typem
    // `audio/x-flac`, którym ingestion-svc routuje plik do re-encode.
    expect(service.needsReencode, isTrue,
        reason: 'cykl wznowienia musi zapalić routing do re-encode');

    // Sedno sprawy. Dziś plik ma DWA nagłówki `fLaC`, bo segmenty są
    // sklejane bajt po bajcie. Dekoder czyta pierwszy strumień i kończy —
    // drugi segment (u terapeuty: ostatnia minuta) nie trafia do
    // transkrypcji, mimo że bajty są w obiekcie w GCS.
    expect(_countFlacStreams(bytes), 1,
        reason: 'sklejone segmenty muszą być JEDNYM strumieniem FLAC; '
            'każdy kolejny nagłówek to audio, którego dekoder nie przeczyta');
  });
}
