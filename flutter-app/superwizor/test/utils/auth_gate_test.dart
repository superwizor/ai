// Kolejność ekranów bramki startowej — dwa błędy z produkcji, zgłoszone
// 04.09.2026 na buildzie 1.0.9+59, i reguły, które mają je trzymać.

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/utils/auth_gate.dart';

/// Świeżo zarejestrowany terapeuta tuż po potwierdzeniu adresu: konto po
/// naszej stronie jeszcze nie istnieje, a serwer nie zdążył odpowiedzieć.
AuthGateDestination gate({
  bool signedIn = true,
  bool emailVerified = true,
  bool accountUnresolved = false,
  bool hasKnownBackendUserId = false,
  bool notRegistered = false,
  bool hasSignupDraft = false,
  bool deactivated = false,
  bool isClient = false,
  bool showOnboardingPaywall = false,
}) =>
    authGateDestination(
      signedIn: signedIn,
      emailVerified: emailVerified,
      accountUnresolved: accountUnresolved,
      hasKnownBackendUserId: hasKnownBackendUserId,
      notRegistered: notRegistered,
      hasSignupDraft: hasSignupDraft,
      deactivated: deactivated,
      isClient: isClient,
      showOnboardingPaywall: showOnboardingPaywall,
    );

void main() {
  group('nierozstrzygnięte konto nie wpuszcza do aplikacji', () {
    test('pierwsze logowanie: czekamy, zamiast pokazywać ekran główny', () {
      // TO jest zgłoszony błąd. Zanim `currentUserProvider` odpowiedział,
      // wszystkie trzy pytania (brak konta / dezaktywacja / klient) dawały
      // „nie", więc bramka zwracała ekran główny. Użytkownik oglądał
      // „Witaj, z kim dzisiaj pracujemy?" z kręcącym się kółkiem przez
      // kilkanaście sekund, zanim pojawił się ekran profilu.
      expect(
        gate(accountUnresolved: true),
        AuthGateDestination.resolving,
      );
    });

    test('nierozstrzygnięte nie przebija dezaktywacji ani roli klienta', () {
      // Te flagi też są fałszem, dopóki nie ma odpowiedzi — więc samo
      // „nie jest zdezaktywowany" nie może nikogo wpuścić.
      expect(
        gate(accountUnresolved: true, deactivated: false, isClient: false),
        AuthGateDestination.resolving,
      );
    });

    test('znane mapowanie users.id wpuszcza od razu — praca offline', () {
      // Furtka z 2026-07-23: kto logował się na tym urządzeniu, wchodzi do
      // kartotek z pamięci podręcznej bez czekania na sieć. Blokada wyżej
      // nie może tego cofnąć, bo w trybie samolotowym odpowiedź nigdy nie
      // przyjdzie.
      expect(
        gate(accountUnresolved: true, hasKnownBackendUserId: true),
        AuthGateDestination.app,
      );
    });

    test('rozstrzygnięte konto idzie dalej normalnie', () {
      expect(gate(), AuthGateDestination.app);
    });
  });

  group('weryfikacja adresu jest blokująca', () {
    test('niepotwierdzony adres wyprzedza wszystko poza logowaniem', () {
      // Decyzja z 03.09.2026: bez potwierdzenia ani profilu, ani kartotek.
      expect(
        gate(
          emailVerified: false,
          notRegistered: true,
          hasSignupDraft: true,
          accountUnresolved: true,
        ),
        AuthGateDestination.verifyEmail,
      );
    });

    test('brak sesji wyprzedza nawet weryfikację', () {
      expect(
        gate(signedIn: false, emailVerified: false),
        AuthGateDestination.login,
      );
    });
  });

  group('sesja bez konta', () {
    test('ze szkicem rejestracji — ekran profilu', () {
      expect(
        gate(notRegistered: true, hasSignupDraft: true),
        AuthGateDestination.profileSetup,
      );
    });

    test('bez szkicu — ślepy zaułek, NIE zakładamy konta po cichu', () {
      // docs/39: ciche auto-zakładanie robiło konta-widma dla dowolnej
      // cudzej tożsamości Google.
      expect(
        gate(notRegistered: true),
        AuthGateDestination.accountNotFound,
      );
    });
  });

  group('paywall powitalny', () {
    test('pokazuje się dopiero po rozstrzygnięciu konta', () {
      // Drugi zgłoszony błąd: paywall wchodził przez `Navigator.push` z
      // widgetu, który bramka właśnie niszczyła, i potrafił zniknąć bez
      // śladu. Teraz to stan, więc ma sens tylko wtedy, gdy konto istnieje.
      expect(
        gate(showOnboardingPaywall: true),
        AuthGateDestination.onboardingPaywall,
      );
      expect(
        gate(showOnboardingPaywall: true, accountUnresolved: true),
        AuthGateDestination.resolving,
      );
    });

    test('nie przebija konta zdezaktywowanego ani panelu klienta', () {
      expect(
        gate(showOnboardingPaywall: true, deactivated: true),
        AuthGateDestination.deactivated,
      );
      expect(
        gate(showOnboardingPaywall: true, isClient: true),
        AuthGateDestination.clientHome,
      );
    });

    test('zgaszona flaga oddaje aplikację', () {
      expect(gate(showOnboardingPaywall: false), AuthGateDestination.app);
    });
  });
}
