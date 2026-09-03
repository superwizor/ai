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
// ─── Dlaczego szkic jest UZBRAJANY, zanim znamy uid (2026-09-03) ───────────
//
// Pierwsza wersja wołała `begin(uid)` PO `createUserWithEmailAndPassword`.
// Między utworzeniem konta a `begin()` stała jeszcze wysyłka maila
// weryfikacyjnego — kilkaset milisekund, w których Firebase zdążył
// wyemitować nową sesję. Bramka uwierzytelniania zobaczyła wtedy sesję bez
// wiersza w `users` i BEZ szkicu, więc podmieniła `LoginScreen` na
// `AccountNotFoundScreen`. Zniszczony widget zabił `ref.read(...).begin()`
// (ref po dispose rzuca), szkic nigdy nie powstał i użytkownik utknął na
// „Nie znaleziono konta" — dokładnie to zobaczył Darek na buildzie 58.
// Ścieżka Apple/Google miała ten sam wyścig, tylko na `_identityRowExists`.
//
// Do tego `build()` tej klasy przebudowuje się przy każdej zmianie sesji i
// zaczynał od `null`, kasując stan ustawiony chwilę wcześniej przez `begin()`
// — a odczyt z SharedPreferences ścigał się z zapisem.
//
// Stąd dwa mechanizmy:
//   1. `arm()` — intencja rejestracji zapisana PRZED wywołaniem Firebase,
//      gdy uid nie jest jeszcze znany. `build()` adoptuje ją synchronicznie
//      w chwili, gdy sesja się pojawi: bramka nigdy nie widzi „sesja bez
//      szkicu" dla kogoś, kto kliknął „Załóż konto".
//   2. Pamięć per-uid poza notifierem — przebudowa `build()` zwraca to, co
//      już wiemy, zamiast zaczynać od zera i czekać na dysk.
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

  SignupDraft copyWith({String? firstName, String? lastName}) => SignupDraft(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
      );

  bool get hasName => firstName.isNotEmpty || lastName.isNotEmpty;
}

String _key(String uid) => 'signup_draft_$uid';

/// Intencja rejestracji ustawiona przed wywołaniem dostawcy tożsamości —
/// jeszcze bez uid. Adoptowana przez pierwszą sesję, która się pojawi.
SignupDraft? _armed;

/// Szkice per-uid. Żyją poza instancją notifiera, bo ta przebudowuje się
/// przy każdej zmianie sesji Firebase i traci stan.
final Map<String, SignupDraft> _memory = <String, SignupDraft>{};

class SignupDraftNotifier extends Notifier<SignupDraft?> {
  @override
  SignupDraft? build() {
    final uid = ref.watch(firebaseUidProvider);
    if (uid == null) return null;

    final known = _memory[uid];
    if (known != null) return known;

    final armed = _armed;
    if (armed != null) {
      // Ktoś kliknął „Załóż konto" i właśnie wrócił od dostawcy: ta sesja
      // jest jego. Adoptujemy synchronicznie — bramka w tym samym buildzie
      // dostaje szkic i nie ma okna na „Nie znaleziono konta".
      _armed = null;
      _memory[uid] = armed;
      unawaited(_persist(uid, armed));
      return armed;
    }

    unawaited(_hydrate(uid));
    return null;
  }

  Future<void> _hydrate(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key(uid));
      if (stored == null) return;
      // Sesja mogła się w międzyczasie zmienić albo szkic już jest w pamięci.
      if (ref.read(firebaseUidProvider) != uid) return;
      if (_memory.containsKey(uid)) return;
      final draft = SignupDraft(
        firstName: stored.isNotEmpty ? stored[0] : '',
        lastName: stored.length > 1 ? stored[1] : '',
      );
      _memory[uid] = draft;
      state = draft;
    } catch (e) {
      debugPrint('[signup] odczyt szkicu nieudany: $e');
    }
  }

  Future<void> _persist(String uid, SignupDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key(uid), <String>[draft.firstName, draft.lastName]);
    } catch (e) {
      debugPrint('[signup] zapis szkicu nieudany: $e');
    }
  }

  /// Uzbraja rejestrację PRZED wywołaniem Firebase — gdy uid nie istnieje.
  ///
  /// Wołać tuż przed `createUserWithEmailAndPassword` /
  /// `signInWithCredential` w trybie „Załóż konto". Jeśli dostawca zwróci
  /// błąd albo okaże się, że konto już istnieje, wywołujący ma zawołać
  /// `disarm()` (albo `clear(uid)`, gdy sesja zdążyła powstać).
  void arm({String firstName = '', String lastName = ''}) {
    _armed = SignupDraft(firstName: firstName, lastName: lastName);
  }

  /// Cofa uzbrojenie, gdy do sesji nie doszło (błąd dostawcy, anulowanie).
  void disarm() {
    _armed = null;
  }

  /// Uzupełnia szkic dla znanej sesji (imię z credentiala Apple/Google, które
  /// dostajemy dopiero PO powrocie od dostawcy) i utrwala go.
  ///
  /// Idempotentne i bezpieczne w dowolnej kolejności względem `build()`:
  /// pamięć per-uid jest źródłem prawdy, a `state` tylko jej odbiciem.
  Future<void> begin(String uid,
      {String firstName = '', String lastName = ''}) async {
    final existing = _memory[uid] ?? _armed ?? const SignupDraft();
    _armed = null;
    final draft = SignupDraft(
      firstName: firstName.isNotEmpty ? firstName : existing.firstName,
      lastName: lastName.isNotEmpty ? lastName : existing.lastName,
    );
    _memory[uid] = draft;
    if (ref.read(firebaseUidProvider) == uid) state = draft;
    await _persist(uid, draft);
  }

  /// Konto założone (albo rejestracja porzucona) — sprzątamy.
  Future<void> clear(String? uid) async {
    _armed = null;
    if (uid != null) _memory.remove(uid);
    state = null;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid));
    } catch (e) {
      debugPrint('[signup] czyszczenie szkicu nieudane: $e');
    }
  }

  /// Wyłącznie dla testów: zeruje pamięć procesu między przypadkami.
  @visibleForTesting
  static void resetForTest() {
    _armed = null;
    _memory.clear();
  }
}

final signupDraftProvider =
    NotifierProvider<SignupDraftNotifier, SignupDraft?>(
        SignupDraftNotifier.new);
