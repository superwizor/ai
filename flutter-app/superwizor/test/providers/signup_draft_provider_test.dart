// Testy szkicu rejestracji — wyścig, przez który build 58 lądował na
// „Nie znaleziono konta" (docs/70 S1, incydent 2026-09-03).
//
// `firebaseUidProvider` podstawiamy zwykłym stringiem: `fb_auth.User` nie ma
// publicznego konstruktora, a notifier i tak potrzebuje wyłącznie uid.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superwizor/providers/current_user_provider.dart';
import 'package:superwizor/providers/signup_draft_provider.dart';

/// Kontener z podstawionym uid. `null` = brak sesji Firebase.
ProviderContainer _container(String? uid) {
  final c = ProviderContainer(overrides: [
    firebaseUidProvider.overrideWithValue(uid),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SignupDraftNotifier.resetForTest();
  });

  test('bez sesji nie ma szkicu', () {
    final c = _container(null);
    expect(c.read(signupDraftProvider), isNull);
  });

  test('sesja bez uzbrojenia i bez zapisu = brak szkicu (cudza tożsamość)',
      () async {
    // To jest ścieżka docs/39: nieznane konto Google, które NIE kliknęło
    // „Załóż konto", ma dostać „Nie znaleziono konta", nie ekran profilu.
    final c = _container('uid-obcy');
    expect(c.read(signupDraftProvider), isNull);
    await Future<void>.delayed(Duration.zero); // hydrate z pustych prefs
    expect(c.read(signupDraftProvider), isNull);
  });

  test('uzbrojenie PRZED sesją jest adoptowane synchronicznie przez sesję',
      () async {
    // Odtwarza kolejność z rejestracji e-mailem: arm() → Firebase tworzy
    // konto → sesja emituje. Bramka czyta szkic w tym samym buildzie, w
    // którym pojawia się uid — bez okna na AccountNotFoundScreen.
    final before = _container(null);
    before.read(signupDraftProvider.notifier).arm();

    final after = _container('uid-nowy');
    expect(after.read(signupDraftProvider), isNotNull,
        reason: 'uzbrojony szkic musi być widoczny od pierwszego odczytu');

    // …i przeżywa restart aplikacji (zapis w SharedPreferences).
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('signup_draft_uid-nowy'), isNotNull);
  });

  test('disarm() cofa intencję, gdy dostawca odrzucił rejestrację', () {
    final before = _container(null);
    final n = before.read(signupDraftProvider.notifier);
    n.arm();
    n.disarm();

    final after = _container('uid-po-bledzie');
    expect(after.read(signupDraftProvider), isNull);
  });

  test('begin() dokłada imię z dostawcy do już zaadoptowanego szkicu',
      () async {
    _container(null).read(signupDraftProvider.notifier).arm();
    final c = _container('uid-apple');
    expect(c.read(signupDraftProvider)!.hasName, isFalse);

    await c
        .read(signupDraftProvider.notifier)
        .begin('uid-apple', firstName: 'Anna', lastName: 'Kowalska');

    final draft = c.read(signupDraftProvider)!;
    expect(draft.firstName, 'Anna');
    expect(draft.lastName, 'Kowalska');
  });

  test('begin() nie kasuje imienia pustymi wartościami', () async {
    // Apple oddaje imię tylko raz. Drugie wywołanie bez danych (np. z innej
    // ścieżki) nie może zamazać tego, co już mamy.
    final c = _container('uid-apple');
    final n = c.read(signupDraftProvider.notifier);
    await n.begin('uid-apple', firstName: 'Anna', lastName: 'Kowalska');
    await n.begin('uid-apple');
    expect(c.read(signupDraftProvider)!.firstName, 'Anna');
  });

  test('przebudowa notifiera dla tego samego uid nie traci szkicu', () async {
    // Pierwsza wersja zaczynała każdy build() od null i czekała na dysk —
    // stan ustawiony chwilę wcześniej przepadał.
    final c = _container('uid-trwaly');
    await c.read(signupDraftProvider.notifier).begin('uid-trwaly',
        firstName: 'Jan');
    c.invalidate(signupDraftProvider);
    expect(c.read(signupDraftProvider)?.firstName, 'Jan');
  });

  test('szkic przeżywa zimny start z SharedPreferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'signup_draft_uid-wraca': <String>['Maria', 'Nowak'],
    });
    final c = _container('uid-wraca');
    expect(c.read(signupDraftProvider), isNull, reason: 'dysk jest asynchroniczny');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(signupDraftProvider)?.lastName, 'Nowak');
  });

  test('clear() sprząta pamięć, intencję i dysk', () async {
    final c = _container('uid-koniec');
    final n = c.read(signupDraftProvider.notifier);
    await n.begin('uid-koniec', firstName: 'Ewa');
    await n.clear('uid-koniec');

    expect(c.read(signupDraftProvider), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('signup_draft_uid-koniec'), isNull);

    // Nowa sesja z tym uid nie odzyskuje szkicu z pamięci procesu.
    final again = _container('uid-koniec');
    await Future<void>.delayed(Duration.zero);
    expect(again.read(signupDraftProvider), isNull);
  });
}
