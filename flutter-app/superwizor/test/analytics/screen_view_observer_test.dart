// Obserwator ekranów zasila `screen.viewed` w naszym kolektorze, z
// którego panel administracyjny liczy lejki i retencję. Trzy rzeczy
// muszą być pewne: nie gubi powrotów, nie dubluje wejść i nie zaśmieca
// statystyk trasami bez nazwy.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/analytics/screen_view_observer.dart';

Route<dynamic> _trasa(String? nazwa) => PageRouteBuilder<dynamic>(
      settings: RouteSettings(name: nazwa),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );

void main() {
  late List<String> zgloszone;
  late ScreenViewObserver obserwator;

  setUp(() {
    zgloszone = [];
    obserwator = ScreenViewObserver(zgloszone.add);
  });

  test('wejście na ekran jest zgłaszane', () {
    obserwator.didPush(_trasa('HomeScreen'), null);

    expect(zgloszone, ['HomeScreen']);
  });

  test('powrót zgłasza ekran spod spodu', () {
    // Bez tego cofnięcie z podekranu byłoby niewidoczne i w lejku
    // wyglądałoby, jakby użytkownik został tam, gdzie wszedł.
    obserwator.didPop(_trasa('RecordingScreen'), _trasa('HomeScreen'));

    expect(zgloszone, ['HomeScreen']);
  });

  test('podmiana trasy zgłasza nowy ekran', () {
    obserwator.didReplace(
      newRoute: _trasa('LoginScreen'),
      oldRoute: _trasa('HomeScreen'),
    );

    expect(zgloszone, ['LoginScreen']);
  });

  test('trasa bez nazwy jest pomijana, nie zgłaszana jako null', () {
    obserwator.didPush(_trasa(null), null);
    obserwator.didPush(_trasa(''), null);

    // Zdarzenie "null" albo "" zaśmieciłoby statystyki i niczego nie
    // powiedziało — brak zdarzenia jest uczciwszy.
    expect(zgloszone, isEmpty);
  });

  test('to samo wejście z rzędu nie jest liczone dwa razy', () {
    // Przebudowa nawigatora (zmiana motywu, języka) odtwarza trasy.
    obserwator.didPush(_trasa('HomeScreen'), null);
    obserwator.didPush(_trasa('HomeScreen'), null);

    expect(zgloszone, ['HomeScreen']);
  });

  test('powrót na ten sam ekran po wyjściu jest liczony ponownie', () {
    obserwator.didPush(_trasa('HomeScreen'), null);
    obserwator.didPush(_trasa('RecordingScreen'), null);
    obserwator.didPop(_trasa('RecordingScreen'), _trasa('HomeScreen'));

    // Ochrona przed duplikatami nie może zjadać prawdziwych powrotów.
    expect(zgloszone, ['HomeScreen', 'RecordingScreen', 'HomeScreen']);
  });
}
