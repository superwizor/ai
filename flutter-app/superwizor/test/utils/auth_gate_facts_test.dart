// Fakty o koncie na PRAWDZIWYCH stanach AsyncValue z Riverpod 3 — w tym na
// stanie „ladowanie z zachowanym bledem", w ktorym provider siedzi przez
// cale ponowienie. To jest test, ktorego brakowalo 04.09.2026: bramka
// zostala trzykrotnie „naprawiona" na podstawie zalozenia, ze blad jest
// stanem koncowym, i trzykrotnie zawiodla w terenie.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/generated/identity/v1/identity.pb.dart'
    as identity_pb;
import 'package:superwizor/generated/identity/v1/identity.pbenum.dart'
    as identity_enum;
import 'package:superwizor/providers/current_user_provider.dart';
import 'package:superwizor/providers/retry_policy.dart';
import 'package:superwizor/utils/auth_gate_facts.dart';

const notRegistered = AccountNotRegisteredException();

/// Stan „ladowanie z zachowanym bledem" wziety z PRAWDZIWEGO kontenera z
/// domyslna polityka ponowien Riverpod 3 — dokladnie to, co bramka widzi
/// przez `ref.watch` miedzy wyjatkiem a kolejna proba. Bez recznego
/// skladania stanow: gdyby biblioteka zmienila zachowanie, test to pokaze.
Future<AsyncValue<identity_pb.User?>> retryingState(Object error) async {
  final probe = FutureProvider<identity_pb.User?>((ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw error;
  });
  final container = ProviderContainer(); // DOMYSLNA polityka: ponawia
  addTearDown(container.dispose);
  final seen = <AsyncValue<identity_pb.User?>>[];
  container.listen(probe, (_, next) => seen.add(next), fireImmediately: true);
  // Po pierwszym wyjatku Riverpod czeka 200 ms i ponawia; w tym oknie stan
  // to AsyncLoading z zachowanym bledem (isReloading == true).
  await Future<void>.delayed(const Duration(milliseconds: 60));
  final retrying = seen.lastWhere((s) => s.isLoading && s.hasError);
  expect(retrying.isReloading, isTrue, reason: 'to ma byc okno ponowienia');
  return retrying;
}

/// Stan „odswiezanie z zachowanym uzytkownikiem" (po `invalidate`).
Future<AsyncValue<identity_pb.User?>> refreshingWithUser(
    identity_pb.User user) async {
  final probe = FutureProvider<identity_pb.User?>((ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return user;
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final seen = <AsyncValue<identity_pb.User?>>[];
  container.listen(probe, (_, next) => seen.add(next), fireImmediately: true);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  container.invalidate(probe);
  await Future<void>.delayed(Duration.zero);
  return seen.lastWhere((s) => s.isLoading && s.hasValue);
}

void main() {
  group('brak konta jest widoczny w KAZDYM stanie, nie tylko w AsyncError', () {
    test('goly AsyncError', () {
      final f = accountFactsFrom(
        AsyncError<identity_pb.User?>(notRegistered, StackTrace.empty),
      );
      expect(f.notRegistered, isTrue);
      expect(f.unresolved, isFalse);
    });

    test('ponowienie Riverpod 3 (isReloading) — sedno bledu z 04.09.2026',
        () async {
      // Tak wyglada provider miedzy wyjatkiem a kolejna proba. `maybeWhen`
      // kierowal tu do `loading`, wiec stare `notRegistered` bylo falszem,
      // a `hasError` prawda — bramka wpuszczala na ekran glowny.
      final state = await retryingState(notRegistered);
      final f = accountFactsFrom(state);
      expect(f.notRegistered, isTrue,
          reason: 'blad jest ZACHOWANY podczas ponowienia');
      expect(f.unresolved, isFalse);
    });
  });

  group('awaria sieci to „nie wiem", a nie „w porzadku"', () {
    test('timeout w stanie AsyncError', () {
      final f = accountFactsFrom(AsyncError<identity_pb.User?>(
          TimeoutException('identity-svc'), StackTrace.empty));
      expect(f.unresolved, isTrue);
      expect(f.notRegistered, isFalse);
      expect(f.deactivated, isFalse);
    });

    test('timeout w trakcie ponowienia', () async {
      final f = accountFactsFrom(
          await retryingState(TimeoutException('identity-svc')));
      expect(f.unresolved, isTrue);
    });

    test('czyste ladowanie i AsyncData(null) z zimnego startu', () {
      expect(accountFactsFrom(const AsyncLoading()).unresolved, isTrue);
      expect(accountFactsFrom(const AsyncData(null)).unresolved, isTrue);
    });
  });

  group('rozstrzygniete konto', () {
    test('uzytkownik aktywny', () {
      final u = identity_pb.User()..isActive = true;
      final f = accountFactsFrom(AsyncData(u));
      expect(f.unresolved, isFalse);
      expect(f.deactivated, isFalse);
      expect(f.isClient, isFalse);
    });

    test('odswiezanie z zachowanym uzytkownikiem nadal jest rozstrzygniete',
        () async {
      final u = identity_pb.User()..isActive = true;
      final f = accountFactsFrom(await refreshingWithUser(u));
      expect(f.unresolved, isFalse,
          reason: 'offline i refresh nie moga cofac do splash');
    });

    test('dezaktywowany, usuniety, pacjent', () {
      expect(
        accountFactsFrom(AsyncData(identity_pb.User()..isActive = false))
            .deactivated,
        isTrue,
      );
      final del = accountFactsFrom(AsyncError<identity_pb.User?>(
          Exception('ACCOUNT_DELETED: …'), StackTrace.empty));
      expect(del.deactivated, isTrue);
      expect(del.deleted, isTrue);
      expect(del.unresolved, isFalse);
      final p = identity_pb.User()
        ..isActive = true
        ..role = identity_enum.UserRole.USER_ROLE_PATIENT;
      expect(accountFactsFrom(AsyncData(p)).isClient, isTrue);
    });
  });

  group('polityka ponowien', () {
    test('odpowiedzi o koncie nie sa ponawiane, awarie sieci tak', () {
      expect(superwizorRetry(0, notRegistered), isNull);
      expect(superwizorRetry(0, Exception('ACCOUNT_DEACTIVATED')), isNull);
      expect(superwizorRetry(0, Exception('ACCOUNT_DELETED')), isNull);
      expect(superwizorRetry(0, TimeoutException('x')), isNotNull);
      expect(superwizorRetry(0, Exception('UNAVAILABLE')), isNotNull);
    });

    test('na zywym kontenerze: brak konta = JEDNO wywolanie, nie siedem', () async {
      var calls = 0;
      final probe = FutureProvider<int?>((ref) async {
        calls++;
        throw notRegistered;
      });
      final container = ProviderContainer(retry: superwizorRetry);
      addTearDown(container.dispose);
      container.listen(probe, (_, _) {}, fireImmediately: true);
      // Domyslna polityka zrobilaby w tym czasie ~5 ponowien.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(calls, 1);
      expect(container.read(probe).error, isA<AccountNotRegisteredException>());
    });
  });
}
