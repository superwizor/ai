// Wersja aplikacji musi mieć numer builda.
//
// Regresja z 13.08.2026: kolumna audio_uploads.client_app_version była
// pusta we wszystkich wierszach, więc przy sesjach wiszących w
// PENDING_UPLOAD nie dało się odpowiedzieć, czy użytkownik pracuje na
// buildzie sprzed poprawki uploadu w tle (1.0.6+39), czy po niej.
//
// Sama wersja ("1.0.6") tego nie rozstrzyga — numer wersji bywa
// podbijany bez wydania. Rozstrzyga dopiero numer builda.

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:superwizor/client/app_version.dart';

void main() {
  group('appVersion', () {
    test('format niesie numer builda, nie samą wersję', () {
      debugSetAppVersion('1.0.6+39');

      expect(appVersion, '1.0.6+39');
      expect(appVersion, contains('+'),
          reason: 'bez numeru builda nie odróżnimy 1.0.6+39 od 1.0.6+38');
    });

    test('getter jest synchroniczny — czytelnicy działają w tle', () {
      debugSetAppVersion('1.0.6+39');

      // Gdyby to była Future, kolejka wgrywania musiałaby czekać na
      // kanał platformowy w oknie wykonania w tle.
      final String odczyt = appVersion;

      expect(odczyt, isA<String>());
      expect(odczyt, isNotEmpty);
    });

    test('initAppVersion nie nadpisuje już ustalonej wartości', () async {
      debugSetAppVersion('1.0.6+39');

      await initAppVersion();

      // Idempotencja ma znaczenie: init wołany jest z main(), a ekran
      // ustawień woła go ponownie przy wejściu.
      expect(appVersion, '1.0.6+39');
    });

    test('składa wersję Z numerem builda z danych pakietu', () async {
      debugSetAppVersion('');

      await initAppVersion(
        resolver: () async => PackageInfo(
          appName: 'Superwizor AI',
          packageName: 'ai.superwizor.superwizor',
          version: '1.0.6',
          buildNumber: '39',
        ),
      );

      // To jest właściwa asercja: sprawdza SKŁADANIE, nie atrapę.
      // Zejście do samego info.version wywali ten test.
      expect(appVersion, '1.0.6+39');
    });

    test('awaria odczytu daje "unknown", a nie pustkę', () async {
      debugSetAppVersion('');

      await initAppVersion(resolver: () async => throw StateError('brak kanału'));

      // "unknown" odróżnia "nie udało się odczytać" od "stary build,
      // który w ogóle tego nie wysyłał" — a to inne diagnozy.
      expect(appVersion, 'unknown');
    });

    test('pusta wartość jest dopuszczalna i nie wysadza odczytu', () {
      debugSetAppVersion('');

      expect(appVersion, isEmpty);
      expect(() => appVersion, returnsNormally);
    });
  });
}
