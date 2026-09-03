// VerifyEmailScreen — potwierdzenie adresu e-mail (docs/70 S1, D12).
//
// Ekran jest **blokujący** (decyzja Darka z 2026-09-03, po teście builda 58):
// dopóki adres nie jest potwierdzony, użytkownik nie wchodzi ani do
// profilu, ani do kartotek. Bramka w `main.dart` pokazuje ten ekran jako
// KORZEŃ aplikacji, więc nie ma z niego „dalej" — jest tylko „potwierdź"
// albo „wyloguj się" (dla kogoś, kto pomylił adres i nigdy tego maila nie
// dostanie).
//
// W praktyce dotyczy tylko rejestracji e-mailem i hasłem: Apple i Google
// oddają adres już zweryfikowany (relay „Hide My Email" również), więc ich
// użytkownicy tego ekranu nigdy nie zobaczą.
//
// Sprawdzanie stanu idzie trzema drogami, żeby nikt nie musiał wracać
// palcem do przycisku po kliknięciu linku w Mailu:
//   1. co kilka sekund w tle (`Timer.periodic`),
//   2. natychmiast po powrocie aplikacji na pierwszy plan
//      (`AppLifecycleState.resumed` — użytkownik właśnie wraca z klienta
//      poczty),
//   3. ręcznie przyciskiem.
// `emailVerified` w tokenie Firebase jest migawką z chwili logowania i sam
// się nie odświeża — każda z tych dróg woła `reload()`.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/email_verification_provider.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';

/// Odstęp między automatycznymi sprawdzeniami. Firebase nie ma limitu na
/// `reload()`, ale nie ma też powodu pytać częściej — kliknięcie linku w
/// poczcie i powrót do aplikacji trwają dłużej.
const _kPollInterval = Duration(seconds: 5);

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pierwsze sprawdzenie od razu: kto wraca do aplikacji po potwierdzeniu
    // adresu przy zamkniętej apce, ma przeterminowaną migawkę `emailVerified`
    // i bez tego widziałby ten ekran mimo potwierdzenia.
    unawaited(_refreshQuietly());
    _poll = Timer.periodic(_kPollInterval, (_) => unawaited(_refreshQuietly()));
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshQuietly());
  }

  /// Odświeża stan bez komunikatów. Gdy adres okaże się potwierdzony,
  /// `emailVerifiedProvider` zmienia stan i bramka sama podmienia korzeń —
  /// ten ekran znika, nie musi nic nawigować.
  Future<void> _refreshQuietly() async {
    if (!mounted || _busy) return;
    await ref.read(emailVerifiedProvider.notifier).refresh();
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    try {
      await ref.read(emailVerifiedProvider.notifier).sendVerificationEmail();
      if (mounted) EuphireToast.success(context, message: t.verify_email_resent);
    } catch (_) {
      if (mounted) {
        EuphireToast.error(context, message: t.verify_email_resend_failed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkNow() async {
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    final verified = await ref.read(emailVerifiedProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    if (verified) {
      EuphireToast.success(context, message: t.verify_email_confirmed);
    } else {
      EuphireToast.error(context, message: t.verify_email_still_unverified);
    }
  }

  /// Wyjście awaryjne: pomylony adres oznacza, że mail nigdy nie przyjdzie.
  /// Po wylogowaniu bramka pokazuje ekran logowania, gdzie można zacząć od
  /// nowa z właściwym adresem.
  Future<void> _signOut() async {
    await fb_auth.FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = fb_auth.FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration:
            const BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EuphireColors.ember.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        color: EuphireColors.ember, size: 38),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  t.verify_email_title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.verify_email_body(email),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 14,
                    height: 1.6,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.verify_email_why,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 13,
                    height: 1.6,
                    color: EuphireColors.mist,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _checkNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.ember,
                      foregroundColor: EuphireColors.obsidianBlack,
                      disabledBackgroundColor:
                          EuphireColors.ember.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  EuphireColors.obsidianBlack),
                            ),
                          )
                        : Text(
                            t.verify_email_check_now,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : _resend,
                  child: Text(
                    t.verify_email_resend,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EuphireColors.mist,
                    ),
                  ),
                ),
                // Jedyne wyjście poza potwierdzeniem: zły adres = brak maila.
                TextButton.icon(
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout, size: 16,
                      color: EuphireColors.mist),
                  label: Text(
                    t.deactivated_logout,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
