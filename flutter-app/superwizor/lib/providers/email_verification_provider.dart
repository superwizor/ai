// Stan weryfikacji adresu e-mail (docs/70 S1, D12).
//
// Weryfikacja jest **blokująca** (decyzja 2026-09-03, po teście builda 58):
// bramka w `main.dart` pokazuje `VerifyEmailScreen` jako korzeń aplikacji
// dla każdej sesji z niepotwierdzonym adresem — przed profilem, przed
// kartotekami, przed nagrywaniem. Pierwsza wersja była nieblokująca i
// egzekwowała adres dopiero przy uploadzie; zostało po niej twarde
// sprawdzenie w `UploadQueueRunner` jako druga linia obrony.
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
/// Sesja bez użytkownika albo bez adresu (konta telefoniczne) liczy się jako
/// zweryfikowana — nie ma czego potwierdzać. Dla zwykłych kont wartość
/// startowa to migawka z tokena; `refresh()` odświeża ją przez `reload()`.
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
