// Decyzja bramki startowej: KTÓRY ekran jest korzeniem aplikacji.
//
// Kolejność tych warunków jest regułą bezpieczeństwa i produktu naraz —
// stała w `build()` była nietestowalna, bo `fb_auth.User` nie ma
// publicznego konstruktora i nie da się go podstawić bez dodatkowego
// pakietu. Wyciągnięcie samej decyzji do czystej funkcji zdejmuje ten
// problem: bramka tylko zbiera fakty i pyta o werdykt.
//
// Historia, którą ta kolejność zapamiętuje:
//
//  • 03.09.2026 — potwierdzenie adresu e-mail stało się BLOKUJĄCE. Stąd
//    `verifyEmail` przed czymkolwiek innym poza logowaniem.
//  • 04.09.2026 — „nierozstrzygnięte" przestało znaczyć „w porządku".
//    Wcześniej, dopóki `currentUserProvider` nie odpowiedział, wszystkie
//    trzy pytania (brak konta / dezaktywacja / klient) dawały „nie", więc
//    bramka wpuszczała na ekran główny kogoś, o kim nie wiedziała jeszcze
//    nic. Świeżo zarejestrowany terapeuta patrzył kilkanaście sekund na
//    „Witaj, z kim dzisiaj pracujemy?", zanim dostał ekran profilu.

enum AuthGateDestination {
  /// Brak sesji Firebase.
  login,

  /// Sesja jest, adres e-mail niepotwierdzony.
  verifyEmail,

  /// Nie wiemy jeszcze, czy ta sesja ma konto po naszej stronie.
  resolving,

  /// Sesja bez konta, ale w środku naszej ścieżki „Załóż konto".
  profileSetup,

  /// Sesja bez konta i bez śladu rejestracji — cudza tożsamość.
  accountNotFound,

  /// Konto zdezaktywowane albo usunięte.
  deactivated,

  /// Konto pacjenta — osobna powierzchnia (docs/39).
  clientHome,

  /// Wybór planu tuż po rejestracji (docs/70 S1 krok 4).
  onboardingPaywall,

  /// Normalna aplikacja (blokada biometryczna + ekran główny).
  app,
}

/// Rozstrzyga korzeń aplikacji na podstawie samych faktów.
///
/// [accountUnresolved] — `currentUserProvider` nie oddał jeszcze ani
/// użytkownika, ani błędu. Uwaga: na zimnym starcie ten provider kończy
/// najpierw jako `AsyncData(null)` (bo `authStateChanges` emituje `null`,
/// zanim odtworzy sesję), więc „ma wartość" NIE znaczy tu „wie".
///
/// [hasKnownBackendUserId] — furtka offline z 2026-07-23: mapowanie
/// firebaseUid → users.id zapisane na urządzeniu przy poprzednim udanym
/// logowaniu. Kto je ma, wchodzi do aplikacji z pamięci podręcznej i nie
/// czeka na sieć; blokada na czas rozstrzygania dotyczy więc wyłącznie
/// pierwszego logowania na tym urządzeniu.
AuthGateDestination authGateDestination({
  required bool signedIn,
  required bool emailVerified,
  required bool accountUnresolved,
  required bool hasKnownBackendUserId,
  required bool notRegistered,
  required bool hasSignupDraft,
  required bool deactivated,
  required bool isClient,
  required bool showOnboardingPaywall,
}) {
  if (!signedIn) return AuthGateDestination.login;
  if (!emailVerified) return AuthGateDestination.verifyEmail;
  if (accountUnresolved) {
    // Szkic rejestracji to nasz WŁASNY dowód, że ta osoba przed chwilą
    // przeszła „Załóż konto" i konta jeszcze nie ma. Nie ma więc o co
    // pytać serwera — ekran profilu należy się jej natychmiast.
    //
    // Bez tego użytkownik płacił za zimny start identity-svc: usługa nie
    // ma `--min-instances`, więc pierwsze wejście po dłuższej przerwie
    // czekało kilkanaście sekund na `getUserByFirebaseUID`, którego
    // odpowiedź i tak była z góry znana („nie ma takiego konta").
    // Zgłoszone 04.09.2026, drugi raz — poprzednia poprawka usunęła zły
    // ekran w tym oknie, ale nie samo czekanie.
    if (hasSignupDraft) return AuthGateDestination.profileSetup;
    if (!hasKnownBackendUserId) return AuthGateDestination.resolving;
  }
  if (notRegistered) {
    return hasSignupDraft
        ? AuthGateDestination.profileSetup
        : AuthGateDestination.accountNotFound;
  }
  if (deactivated) return AuthGateDestination.deactivated;
  if (isClient) return AuthGateDestination.clientHome;
  if (showOnboardingPaywall) return AuthGateDestination.onboardingPaywall;
  return AuthGateDestination.app;
}
