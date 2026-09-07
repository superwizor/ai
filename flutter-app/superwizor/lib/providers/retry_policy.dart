// Polityka ponowień Riverpod 3 dla całej aplikacji.
//
// Riverpod 3 ponawia KAŻDY provider, który rzucił wyjątek — domyślnie do
// dziesięciu razy, z odstępami 200 ms → 6,4 s (`ProviderContainer.defaultRetry`).
// Dla awarii sieci to dobrze. Ale część naszych wyjątków to nie awarie,
// tylko ODPOWIEDZI serwera: „nie ma takiego konta", „konto zdezaktywowane",
// „konto usunięte". Ponawianie ich to kilkanaście sekund zbędnych wywołań
// identity-svc, a w tym czasie provider jest w stanie „ładowanie z
// zachowanym błędem", którego bramka startowa nie umiała odczytać —
// i wpuszczała świeżo zarejestrowanego terapeutę na ekran główny
// (zgłoszone trzy razy 04.09.2026, na buildach 59, 60 i 61; sonda na
// riverpod 3.2.1 pokazała 7 ponowień w 13 s przy atrapie 50 ms).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/account_status.dart';
import 'current_user_provider.dart';

/// Czy wyjątek jest rozstrzygającą odpowiedzią o stanie konta, a nie
/// przejściową awarią. Takiej odpowiedzi nie ma sensu ponawiać.
bool isDefinitiveAccountAnswer(Object? error) =>
    error is AccountNotRegisteredException || isAccountBlockedError(error);

/// Polityka dla `ProviderContainer(retry: …)`: rozstrzygające odpowiedzi o
/// koncie bez ponowień, reszta jak domyślnie w Riverpod 3.
Duration? superwizorRetry(int retryCount, Object error) {
  if (isDefinitiveAccountAnswer(error)) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}
