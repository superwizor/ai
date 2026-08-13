// Wersja aplikacji jako pojedyncze źródło prawdy dla diagnostyki.
//
// Po co: kolumna audio_uploads.client_app_version istniała od początku,
// ale klient jej nie wypełniał — wysyłał wyłącznie client_platform.
// Przy dochodzeniu w sprawie sesji wiszących w PENDING_UPLOAD (13.08.2026)
// oznaczało to, że nie dało się odpowiedzieć na najprostsze pytanie:
// czy użytkownik pracuje na buildzie sprzed poprawki uploadu w tle
// (1.0.6+39), czy po niej. Bez tej wartości każda taka diagnoza jest
// zgadywaniem.
//
// Format: "<wersja>+<build>", np. "1.0.6+39". Numer builda jest tu
// istotny — to on odróżnia faktycznie wydane paczki (1.0.5+38 vs
// 1.0.6+39), podczas gdy sama wersja bywa podbijana bez wydania.
//
// Rozstrzygane RAZ przy starcie i trzymane w pamięci, bo czytelnicy
// (kolejka wgrywania) bywają wołani w oknie wykonania w tle, gdzie
// round-trip po kanale platformowym jest niepożądany. Getter jest
// synchroniczny właśnie po to.

import 'package:package_info_plus/package_info_plus.dart';

String _cached = '';

/// Wersja aplikacji w formacie "1.0.6+39".
///
/// Pusty łańcuch, dopóki [initAppVersion] się nie wykona — pole w
/// kontrakcie jest opcjonalne, więc pusta wartość niczego nie psuje,
/// jedynie nie niesie informacji.
String get appVersion => _cached;

/// Źródło danych o pakiecie. Wstrzykiwalne wyłącznie po to, by dało się
/// przetestować SKŁADANIE formatu bez kanału platformowego — bez tego
/// szwu test mógłby sprawdzać tylko własną atrapę.
typedef PackageInfoResolver = Future<PackageInfo> Function();

/// Odczytuje wersję z pakietu i zapamiętuje ją. Idempotentne.
///
/// Wołane z main() przed runApp, żeby pierwsze wgranie po zimnym
/// starcie miało już czym się przedstawić.
Future<void> initAppVersion({PackageInfoResolver? resolver}) async {
  if (_cached.isNotEmpty) return;
  try {
    final info = await (resolver ?? PackageInfo.fromPlatform)();
    _cached = '${info.version}+${info.buildNumber}';
  } catch (_) {
    // Kanał platformowy potrafi zawieść na starcie (np. web/testy).
    // "unknown" jest uczciwsze od pustego pola: odróżnia "nie udało się
    // odczytać" od "stary build, który w ogóle tego nie wysyłał".
    _cached = 'unknown';
  }
}

/// Wyłącznie dla testów — pozwala ustawić wartość bez kanału platformowego.
void debugSetAppVersion(String value) {
  _cached = value;
}
