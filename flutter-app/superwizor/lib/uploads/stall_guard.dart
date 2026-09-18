// Limity czasu dla pracy LOKALNEJ, liczone zegarem, który stoi w tle.
//
// Po co to powstało (sesja z 15.09.2026, 46 min / 76,8 MB):
// faza `encrypting` miała sztywny limit 10 minut zegara ściennego.
// iOS zawiesza proces po zejściu w tło — zegar leciał dalej, praca
// stała, limit wypalał na robocie, która nigdy nie dostała 10 minut
// CPU. Nagranie nie dotarło nawet do CreateAudioUpload, więc po
// stronie serwera nie było ŻADNEGO śladu, że coś się psuje.
//
// Dwie zmiany względem `.timeout(Duration(minutes: 10))`:
//
//   1. Zegar stoi, gdy aplikacja jest w tle ([ForegroundClock]).
//   2. Mierzymy BRAK POSTĘPU, nie łączny czas pracy. Szyfrowanie
//      godzinnego nagrania ma prawo trwać długo; nie ma prawa stać
//      w miejscu. Każdy zapisany chunk to [StallGuard.beat].

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Zegar mierzący czas spędzony NA PIERWSZYM PLANIE.
abstract class ForegroundClock {
  /// Czas na pierwszym planie od ostatniego [reset].
  Duration get elapsed;

  /// Zeruje licznik (wywoływane przy każdym postępie).
  void reset();

  void dispose();
}

/// Zegar bez wiedzy o cyklu życia — tyka zawsze. Używany jako
/// bezpieczny fallback tam, gdzie nie ma `WidgetsBinding` (testy
/// jednostkowe bez bindingu, izolaty, `dart test`).
class MonotonicForegroundClock implements ForegroundClock {
  final Stopwatch _sw = Stopwatch()..start();

  @override
  Duration get elapsed => _sw.elapsed;

  @override
  void reset() => _sw.reset();

  @override
  void dispose() => _sw.stop();
}

/// Zegar zatrzymywany na czas, gdy aplikacja nie jest na pierwszym
/// planie.
///
/// `Stopwatch` liczy czas monotoniczny, więc SAM Z SIEBIE liczy też
/// czas zawieszenia procesu — dlatego zatrzymujemy go jawnie na
/// `inactive`/`paused`/`hidden` i wznawiamy na `resumed`. Flutter
/// dostarcza `inactive` zanim iOS zawiesi proces, więc okno, w którym
/// zegar tyka mimo braku CPU, jest pomijalne.
class AppLifecycleForegroundClock
    with WidgetsBindingObserver
    implements ForegroundClock {
  AppLifecycleForegroundClock._(this._binding) {
    _binding.addObserver(this);
    if (!_isForeground(_binding.lifecycleState)) _sw.stop();
  }

  /// Zwraca zegar świadomy cyklu życia, a gdy binding jest
  /// niedostępny — zwykły [MonotonicForegroundClock]. Nigdy nie rzuca:
  /// brak bindingu nie może wywrócić uploadu.
  static ForegroundClock create() {
    try {
      final binding = WidgetsBinding.instance;
      return AppLifecycleForegroundClock._(binding);
    } catch (e) {
      debugPrint('[stall-guard] brak WidgetsBinding ($e) — zegar monotoniczny');
      return MonotonicForegroundClock();
    }
  }

  final WidgetsBinding _binding;
  final Stopwatch _sw = Stopwatch()..start();
  bool _disposed = false;

  static bool _isForeground(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (_isForeground(state)) {
      if (!_sw.isRunning) _sw.start();
    } else {
      if (_sw.isRunning) _sw.stop();
    }
  }

  @override
  Duration get elapsed => _sw.elapsed;

  @override
  void reset() => _sw.reset();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _binding.removeObserver(this);
    _sw.stop();
  }
}

/// Przerywa pracę, która przestała robić postępy albo przekroczyła
/// całkowity budżet czasu.
///
/// Dwa niezależne limity, oba liczone zegarem stojącym w tle:
///
///   • [window] — ile wolno NIE robić postępu. Łapie prawdziwe
///     zawieszenie (zablokowany Keychain, zakleszczony izolat) od razu,
///     zamiast czekać do końca budżetu.
///   • [budget] — ile w sumie wolno pracować. Siatka bezpieczeństwa na
///     robotę, która postęp robi, ale beznadziejnie wolno.
///
/// Praca, która regularnie bije i mieści się w budżecie, nie jest
/// przerywana.
///
/// Uwaga: tak jak `Future.timeout`, porzucenie Future NIE zatrzymuje
/// roboty pod spodem. Tu jest to zamierzone — izolat szyfrujący pisze
/// dalej i jego chunki przejmie kolejna próba (wznawianie przyrostowe
/// w SecureAudioStorageService).
class StallGuard {
  StallGuard({
    required Duration window,
    required ForegroundClock clock,
    Duration? budget,
    ForegroundClock? budgetClock,
    Duration? tick,
  })  : _window = window,
        _clock = clock,
        _budget = budget,
        _budgetClock = budgetClock,
        _tick = tick ?? const Duration(seconds: 10);

  final Duration _window;
  final ForegroundClock _clock;
  final Duration? _budget;

  /// Osobny zegar na budżet — bo [beat] zeruje ten od bezczynności.
  final ForegroundClock? _budgetClock;

  final Duration _tick;

  /// Sygnał „jest postęp" — zeruje okno bezczynności (ale nie budżet).
  void beat() => _clock.reset();

  Future<T> run<T>(Future<T> work, {String label = 'praca'}) {
    final done = Completer<T>();
    _clock.reset();
    _budgetClock?.reset();

    final budget = _budget;
    final budgetClock = _budgetClock;

    final timer = Timer.periodic(_tick, (t) {
      if (done.isCompleted) {
        t.cancel();
        return;
      }
      if (_clock.elapsed >= _window) {
        t.cancel();
        done.completeError(
          TimeoutException(
            '$label nie zrobiła postępu przez '
            '${_window.inMinutes} min na pierwszym planie',
            _window,
          ),
        );
        return;
      }
      if (budget != null &&
          budgetClock != null &&
          budgetClock.elapsed >= budget) {
        t.cancel();
        done.completeError(
          TimeoutException(
            '$label przekroczyła budżet ${budget.inMinutes} min '
            'na pierwszym planie',
            budget,
          ),
        );
      }
    });

    work.then(
      (v) {
        if (!done.isCompleted) done.complete(v);
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
    ).whenComplete(timer.cancel);

    return done.future;
  }
}
