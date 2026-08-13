// Automatyczne zdarzenia `screen.viewed` dla całej nawigacji.
//
// Po co: do 13.08.2026 ekrany raportowaliśmy ręcznie i było ich
// dokładnie TRZY (HomeScreen, LoginScreen, NewSessionScreen) na kilkadziesiąt
// w aplikacji. Panel administracyjny liczy lejki i retencję z tych
// zdarzeń, więc obraz użycia był fragmentaryczny.
//
// Dlaczego do WŁASNEGO kolektora, a nie do Firebase Analytics: aplikacja
// obsługuje dane o zdrowiu i podlega reżimowi pseudonimizacji opisanemu
// w docs/. Nazwy ekranów to dane behawioralne — trzymamy je w tym samym
// potoku co resztę metryk, zamiast otwierać drugi kanał na zewnątrz.
//
// UWAGA co do nazw: obserwator raportuje wyłącznie trasy z ustawionym
// `RouteSettings.name`. Trasa bez nazwy jest pomijana po cichu — lepszy
// brak zdarzenia niż zdarzenie "null" albo "MaterialPageRoute", które
// zaśmieciłoby statystyki i niczego nie powiedziało. Dodając nowy ekran,
// przekaż `settings: const RouteSettings(name: 'NazwaEkranu')`.

import 'package:flutter/widgets.dart';

/// Zgłasza wejścia na ekrany do przekazanej funkcji.
///
/// Celowo nie zna kolektora — dzięki temu daje się przetestować bez
/// gRPC i bez Firebase'a.
class ScreenViewObserver extends NavigatorObserver {
  ScreenViewObserver(this.onScreen);

  /// Wołane z nazwą ekranu, na który użytkownik właśnie wszedł.
  final void Function(String screenName) onScreen;

  /// Ostatnio zgłoszony ekran — chroni przed duplikatami przy
  /// przebudowach nawigatora (np. zmiana motywu albo języka odtwarza
  /// trasy i bez tego każde wejście liczyłoby się dwa razy).
  String? _ostatni;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _zglos(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Po zamknięciu ekranu użytkownik ogląda ten pod spodem — to też
    // jest wejście na ekran i bez tego powroty byłyby niewidoczne.
    _zglos(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _zglos(newRoute);
  }

  void _zglos(Route<dynamic>? route) {
    final nazwa = route?.settings.name;
    if (nazwa == null || nazwa.isEmpty) return;
    if (nazwa == _ostatni) return;
    _ostatni = nazwa;
    onScreen(nazwa);
  }
}
