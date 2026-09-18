// StallGuard + ForegroundClock — limity czasu dla pracy lokalnej.
//
// Regresja, której te testy pilnują: faza `encrypting` miała sztywny
// limit 10 minut zegara ściennego. iOS zawiesza proces w tle, więc
// limit wypalał na robocie, która nigdy nie dostała tych 10 minut CPU
// (sesja z 15.09.2026, 46 min / 76,8 MB — nagranie nie dotarło nawet
// do CreateAudioUpload).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/uploads/stall_guard.dart';

/// Zegar sterowany ręcznie — [elapsed] ustawia test.
class _FakeClock implements ForegroundClock {
  Duration value = Duration.zero;
  int resets = 0;

  @override
  Duration get elapsed => value;

  @override
  void reset() {
    value = Duration.zero;
    resets++;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tick = Duration(milliseconds: 5);

  group('StallGuard', () {
    test('praca, która się kończy, przechodzi bez zmian', () async {
      final guard = StallGuard(
        window: const Duration(minutes: 2),
        clock: _FakeClock(),
        tick: tick,
      );

      final wynik = await guard.run(Future.value(42));

      expect(wynik, 42);
    });

    test('błąd pracy przechodzi na wierzch nietknięty', () async {
      final guard = StallGuard(
        window: const Duration(minutes: 2),
        clock: _FakeClock(),
        tick: tick,
      );

      expect(
        () => guard.run(Future<int>.error(StateError('bum'))),
        throwsA(isA<StateError>()),
      );
    });

    test('brak postępu przez okno → TimeoutException', () async {
      final clock = _FakeClock();
      final guard = StallGuard(
        window: const Duration(minutes: 2),
        clock: clock,
        tick: tick,
      );

      // Praca, która nigdy się nie kończy — dokładnie to, co robił
      // zawieszony izolat szyfrujący.
      final nigdy = Completer<int>();

      // Wartość ustawiamy PO starcie: run() zeruje zegar na wejściu.
      final f = guard.run(nigdy.future, label: 'Szyfrowanie nagrania');
      clock.value = const Duration(minutes: 3);

      await expectLater(
        f,
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Szyfrowanie nagrania'), contains('postępu')),
          ),
        ),
      );
    });

    test('regularny postęp trzyma pracę przy życiu mimo upływu czasu',
        () async {
      final clock = _FakeClock();
      final guard = StallGuard(
        window: const Duration(minutes: 2),
        clock: clock,
        tick: tick,
      );

      final praca = Completer<String>();

      // Zegar ciągle przekracza okno, ale każdy "chunk" go zeruje —
      // tak jak robi to onProgress z izolatu.
      final bicie = Timer.periodic(tick, (_) {
        clock.value = const Duration(minutes: 5);
        guard.beat();
      });

      final f = guard.run(praca.future);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      bicie.cancel();
      praca.complete('gotowe');

      expect(await f, 'gotowe');
      expect(clock.resets, greaterThan(3),
          reason: 'beat() musi zerować okno bezczynności');
    });

    test('budżet wypala nawet przy regularnym postępie', () async {
      final clockBezczynnosci = _FakeClock();
      final clockBudzetu = _FakeClock();
      final guard = StallGuard(
        window: const Duration(minutes: 2),
        clock: clockBezczynnosci,
        budget: const Duration(minutes: 100),
        budgetClock: clockBudzetu,
        tick: tick,
      );

      final nigdy = Completer<int>();

      // Okno bezczynności zostaje wyzerowane (postęp jest), ale łączny
      // czas na pierwszym planie przekracza budżet.
      final f = guard.run(nigdy.future, label: 'Szyfrowanie nagrania');
      clockBudzetu.value = const Duration(minutes: 101);

      await expectLater(
        f,
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            allOf(contains('budżet'), contains('100')),
          ),
        ),
      );
    });
  });

  group('AppLifecycleForegroundClock', () {
    test('zegar stoi, gdy aplikacja jest w tle', () async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final clock = AppLifecycleForegroundClock.create();
      addTearDown(clock.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final naPierwszymPlanie = clock.elapsed;
      expect(naPierwszymPlanie, greaterThan(Duration.zero),
          reason: 'na pierwszym planie zegar ma tykać');

      // Zejście w tło — od tej chwili czas nie może być doliczany,
      // bo iOS i tak zawiesza proces.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final wMomencieZejscia = clock.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(clock.elapsed, wMomencieZejscia,
          reason: 'w tle zegar musi STAĆ — to jest cały sens tej klasy');

      // Powrót na pierwszy plan wznawia liczenie.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(clock.elapsed, greaterThan(wMomencieZejscia));
    });

    test('reset zeruje licznik', () async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final clock = AppLifecycleForegroundClock.create();
      addTearDown(clock.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(clock.elapsed, greaterThan(Duration.zero));

      clock.reset();
      expect(clock.elapsed, lessThan(const Duration(milliseconds: 20)));
    });
  });
}
