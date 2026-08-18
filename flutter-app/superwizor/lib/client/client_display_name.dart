/// Co pokazać w nagłówku panelu klienta.
///
/// Wyciągnięte z `client_home_screen.dart` do osobnej funkcji, bo cała
/// wartość tej zmiany siedzi w KOLEJNOŚCI: pseudonim wygrywa, e-mail jest
/// wyłącznie ostatnią deską ratunku. Wpleciona w metodę `build` reguła
/// nie dałaby się przetestować, a cicha zamiana kolejności wystawiłaby
/// klientowi adres e-mail na wierzchu ekranu.
library;

/// Zwraca etykietę dla nagłówka: pseudonim konta, a gdy go nie ma —
/// adres e-mail.
///
/// [firstName] to `users.first_name` (pseudonim konta klienckiego),
/// [email] to `users.email`.
///
/// Pusty wynik jest poprawnym stanem — ekran podstawia wtedy tytuł
/// panelu — więc funkcja nie rzuca i nie zwraca null.
String clientDisplayName({required String firstName, required String email}) {
  // trim() nie jest kosmetyką: pole złożone z samych spacji przeszłoby
  // isNotEmpty i dałoby pusty nagłówek, nigdy nie sięgając po e-mail.
  final pseudonym = firstName.trim();
  if (pseudonym.isNotEmpty) return pseudonym;
  return email.trim();
}
