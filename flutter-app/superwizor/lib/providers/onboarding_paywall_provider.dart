// Paywall zaraz po rejestracji (docs/70 S1 krok 4) — jako STAN, nie jako
// nawigacja.
//
// Pierwsza wersja robiła to zwykłym `Navigator.push` na końcu
// `ProfileSetupScreen._submit()`. Wyglądało to niewinnie, ale ten push
// wykonywał się już PO tym, jak `container.invalidate(currentUserProvider)`
// przestawił bramkę na ekran główny i zniszczył `State` ekranu profilu.
// Nawigator był wprawdzie zapamiętany przed awaitami, ale reszta układanki
// nie: każdy wyjątek po drodze trafiał do `catch`, gdzie `if (mounted)`
// było już fałszem, więc błąd nie miał gdzie się pokazać, a `return`
// zjadał push bez śladu. Darek zgłosił to 04.09.2026 na buildzie 1.0.9+59:
// „po uzupełnieniu profilu nie uruchomił się ekran wyboru planów".
//
// Nawigacja z widgetu, który właśnie znika, jest z definicji wyścigiem.
// Dlatego zamiast pchać trasę, zapalamy flagę: korzeniem aplikacji i tak
// zarządza bramka w `main.dart`, więc niech ona pokaże paywall, gdy konto
// jest już rozstrzygnięte. Żadnego zapamiętanego nawigatora, żadnej
// zależności od kolejności awaitów.
//
// Flaga żyje tylko w pamięci procesu. Ubicie aplikacji na paywallu ma
// oznaczać „nie teraz", a nie ekran zakupu przy każdym kolejnym starcie —
// trial i tak jest już aktywny, a paywall zostaje w menu Subskrypcja.

import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPaywallNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Rejestracja domknięta — pokaż wybór planu, gdy tylko konto będzie
  /// rozstrzygnięte. Wołane WYŁĄCZNIE po udanym `CreateUser`: zapalenie
  /// tego wcześniej pokazałoby paywall komuś, kto konta nie ma.
  void show() => state = true;

  /// Użytkownik kupił plan albo wybrał „Na razie bez planu".
  void dismiss() => state = false;
}

final onboardingPaywallProvider =
    NotifierProvider<OnboardingPaywallNotifier, bool>(
        OnboardingPaywallNotifier.new);
