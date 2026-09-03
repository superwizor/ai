// Stan weryfikacji adresu e-mail (docs/70 S1 krok 3, E4).
//
// Weryfikacja jest **nieblokująca**: nie zatrzymuje logowania, nawigacji ani
// — co najważniejsze — nagrywania (UX-1 z docs/17: brak czegokolwiek nigdy nie
// blokuje mikrofonu). Jedyne miejsce, w którym jest egzekwowana, to wysyłka
// nagrania do analizy: bez potwierdzonego adresu nie da się spalić tokenów
// STT/LLM, co zamyka „farmę triali" na zmyślone adresy.
//
// Konta z Apple/Google wracają z `emailVerified == true` (dostawca już
// zweryfikował adres, „Hide My Email" też), więc w praktyce dotyczy to
// wyłącznie rejestracji e-mailem i hasłem.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_user_provider.dart';

/// `true`, gdy zalogowany użytkownik MA potwierdzony adres — albo gdy nie ma
/// sensu o to pytać (brak sesji, konto bez adresu e-mail).
///
/// Domyślnie zakładamy „zweryfikowany". Fałszywy alarm banerem u kogoś, kto
/// adres potwierdził, byłby gorszy niż jego chwilowy brak: baner wraca przy
/// pierwszym `refresh()`, a upload i tak ma własną, twardą bramkę.
class EmailVerifiedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final user = ref.watch(firebaseUserProvider).value;
    if (user == null) return true;
    if ((user.email ?? '').isEmpty) return true;
    return user.emailVerified;
  }

  /// Odpytuje Firebase o świeży stan (`reload()` — `emailVerified` w tokenie
  /// jest migawką z chwili logowania i sam się nie odświeża).
  Future<bool> refresh() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return true;
    try {
      await user.reload();
    } catch (e) {
      debugPrint('[verify-email] reload nieudany: $e');
      return state;
    }
    final fresh = fb_auth.FirebaseAuth.instance.currentUser;
    final verified = fresh == null ||
        (fresh.email ?? '').isEmpty ||
        fresh.emailVerified;
    state = verified;
    return verified;
  }

  /// Wysyła (ponownie) wiadomość z linkiem potwierdzającym.
  Future<void> sendVerificationEmail() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }
}

final emailVerifiedProvider =
    NotifierProvider<EmailVerifiedNotifier, bool>(EmailVerifiedNotifier.new);

/// Czy pokazać sticky baner „Potwierdź adres e-mail".
final needsEmailVerificationProvider = Provider<bool>((ref) {
  final signedIn = ref.watch(firebaseUserProvider).value != null;
  return signedIn && !ref.watch(emailVerifiedProvider);
});
