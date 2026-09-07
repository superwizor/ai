// Fakty o koncie wyprowadzone z `AsyncValue<User?>` — w jednym miejscu,
// odpornie na stany przejściowe Riverpod 3.
//
// Dlaczego nie `maybeWhen(error: …)` jak dawniej: w Riverpod 3 provider po
// wyjątku przechodzi w „ładowanie z zachowanym błędem" (ponowienie), a
// `when`/`maybeWhen` z domyślnym `skipLoadingOnReload: false` kieruje wtedy
// do `loading`, NIE do `error`. Bramka widziała więc `hasError == true`
// (więc „rozstrzygnięte"), a jednocześnie „to nie jest błąd braku konta"
// (bo `maybeWhen` schował błąd) — i wpuszczała na ekran główny osobę bez
// konta. Getter `AsyncValue.error` zwraca zachowany błąd także podczas
// ładowania, i to z niego liczymy wszystko poniżej.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../generated/identity/v1/identity.pbenum.dart' as identity_enum;
import '../providers/current_user_provider.dart';
import 'account_status.dart';

class AccountFacts {
  const AccountFacts({
    required this.unresolved,
    required this.notRegistered,
    required this.deactivated,
    required this.deleted,
    required this.isClient,
  });

  /// Nie mamy jeszcze ROZSTRZYGAJĄCEJ odpowiedzi: ani użytkownika, ani
  /// jednego z wyjątków, które są odpowiedzią o stanie konta. Awaria sieci
  /// i ponowienie w toku liczą się jako „nie wiem", nie jako „w porządku".
  final bool unresolved;

  /// Sesja Firebase bez wiersza `users` (docs/39).
  final bool notRegistered;

  /// Konto zdezaktywowane albo usunięte przez administratora (docs/38).
  final bool deactivated;

  /// Odmiana [deactivated] różniąca się tylko treścią ekranu.
  final bool deleted;

  /// Konto pacjenta — osobna powierzchnia (docs/39).
  final bool isClient;
}

AccountFacts accountFactsFrom(AsyncValue<identity_pb.User?> user) {
  // `.error` i `.value` zwracają wartości zachowane z poprzedniego stanu
  // także podczas ładowania — o to tu chodzi.
  final err = user.error;
  final value = user.value;

  final notRegistered = err is AccountNotRegisteredException;
  final blocked = isAccountBlockedError(err);
  final deleted = isAccountDeletedError(err);
  final deactivated = (value != null && !value.isActive) || blocked;
  final isClient = value != null &&
      value.role == identity_enum.UserRole.USER_ROLE_PATIENT;

  return AccountFacts(
    unresolved: value == null && !notRegistered && !blocked,
    notRegistered: notRegistered,
    deactivated: deactivated,
    deleted: deleted,
    isClient: isClient,
  );
}
