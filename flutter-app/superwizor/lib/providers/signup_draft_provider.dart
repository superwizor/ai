// Szkic rejestracji — to, co wiemy o użytkowniku między logowaniem u dostawcy
// tożsamości a założeniem konta w identity-svc (docs/70 S1 kroki 1→2).
//
// Dlaczego to w ogóle istnieje, zamiast zwykłego `Navigator.push`:
//
//  • **Apple oddaje imię i nazwisko TYLKO przy pierwszym logowaniu** (E4b).
//    Jeśli użytkownik zamknie aplikację na ekranie profilu, dane przepadają
//    NA ZAWSZE — Apple ich drugi raz nie poda. Dlatego lądują w
//    SharedPreferences w tej samej milisekundzie, w której wracają
//    z credentiala, jeszcze przed pierwszym `setState`.
//
//  • Sesja Firebase bez wiersza w `users` to normalnie ślepy zaułek
//    (`AccountNotFoundScreen` — świadoma decyzja z docs/39, żeby aplikacja
//    NIE tworzyła kont-widm dla dowolnego cudzego Google). Szkic rejestracji
//    jest jedynym dowodem, że ten konkretny użytkownik przyszedł tu naszą
//    własną ścieżką „Załóż konto", a nie z cudzego zaproszenia.
//
// Szkic przeżywa ubicie aplikacji: kto zamknął apkę na ekranie profilu, wraca
// na ekran profilu, a nie na „nie znaleziono konta".

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'current_user_provider.dart';

@immutable
class SignupDraft {
  const SignupDraft({this.firstName = '', this.lastName = ''});

  /// Prefill z dostawcy. Puste, gdy dostawca nic nie dał (Apple przy drugim
  /// logowaniu, odmowa udostępnienia danych, „Hide My Email").
  final String firstName;
  final String lastName;
}

String _key(String uid) => 'signup_draft_$uid';

class SignupDraftNotifier extends Notifier<SignupDraft?> {
  @override
  SignupDraft? build() {
    // Sesja bez użytkownika = brak szkicu (wylogowanie czyści stan).
    final uid = ref.watch(firebaseUserProvider).value?.uid;
    if (uid == null) return null;
    unawaited(_hydrate(uid));
    return null;
  }

  Future<void> _hydrate(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key(uid));
      if (stored == null) return;
      // Notifier mógł zostać w międzyczasie przebudowany na innego użytkownika.
      if (ref.read(firebaseUserProvider).value?.uid != uid) return;
      if (state != null) return;
      state = SignupDraft(
        firstName: stored.isNotEmpty ? stored[0] : '',
        lastName: stored.length > 1 ? stored[1] : '',
      );
    } catch (e) {
      debugPrint('[signup] odczyt szkicu nieudany: $e');
    }
  }

  /// Otwiera rejestrację dla bieżącej sesji Firebase i utrwala prefill.
  ///
  /// Wołane NATYCHMIAST po powrocie z dostawcy — zanim cokolwiek zdąży
  /// zgubić `fullName` z credentiala Apple.
  Future<void> begin(String uid, {String firstName = '', String lastName = ''}) async {
    state = SignupDraft(firstName: firstName, lastName: lastName);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(uid), <String>[firstName, lastName]);
    } catch (e) {
      debugPrint('[signup] zapis szkicu nieudany: $e');
    }
  }

  /// Konto założone (albo rejestracja porzucona) — sprzątamy.
  Future<void> clear(String? uid) async {
    state = null;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid));
    } catch (e) {
      debugPrint('[signup] czyszczenie szkicu nieudane: $e');
    }
  }
}

final signupDraftProvider =
    NotifierProvider<SignupDraftNotifier, SignupDraft?>(SignupDraftNotifier.new);
