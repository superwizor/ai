// Nagłówek panelu klienta pokazywał adres e-mail. Zamiast tego ma
// pokazywać pseudonim konta, a e-mail zostaje WYŁĄCZNIE jako fallback.
//
// Cała wartość zmiany siedzi w kolejności, więc to ona jest tu testowana:
// odwrócenie jej z powrotem wystawiłoby klientowi adres e-mail na
// wierzchu ekranu, a widok jest za logowaniem i nikt by tego nie złapał
// wcześniej niż użytkownik.

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/client/client_display_name.dart';

void main() {
  group('clientDisplayName', () {
    test('pseudonim wygrywa z e-mailem', () {
      expect(
        clientDisplayName(firstName: 'Kasia', email: 'kasia@example.com'),
        'Kasia',
      );
    });

    // Sedno zgłoszenia: gdy pseudonim jest, e-mail nie ma prawa się pokazać.
    test('e-mail NIE pojawia sie, gdy jest pseudonim', () {
      final out = clientDisplayName(
        firstName: 'Kasia',
        email: 'kasia@example.com',
      );
      expect(out.contains('@'), isFalse,
          reason: 'adres e-mail wyciekł do nagłówka mimo pseudonimu');
    });

    test('bez pseudonimu zostaje e-mail', () {
      expect(
        clientDisplayName(firstName: '', email: 'kasia@example.com'),
        'kasia@example.com',
      );
    });

    // Pole z samych spacji przechodzi isNotEmpty — bez trim() dałoby
    // pusty nagłówek i nigdy nie sięgnęłoby po e-mail.
    test('pseudonim z samych spacji traktujemy jak brak', () {
      expect(
        clientDisplayName(firstName: '   ', email: 'kasia@example.com'),
        'kasia@example.com',
      );
    });

    test('pseudonim jest przycinany', () {
      expect(
        clientDisplayName(firstName: '  Kasia  ', email: 'k@example.com'),
        'Kasia',
      );
    });

    // Konto bez obu wartości to poprawny stan — ekran podstawia wtedy
    // tytuł panelu, więc funkcja ma zwrócić pusty łańcuch, nie wybuchnąć.
    test('brak obu wartosci daje pusty lancuch', () {
      expect(clientDisplayName(firstName: '', email: ''), '');
      expect(clientDisplayName(firstName: '  ', email: '  '), '');
    });
  });
}
