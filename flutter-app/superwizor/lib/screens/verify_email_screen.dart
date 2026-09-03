// VerifyEmailScreen — krok 3 rejestracji (docs/70 S1), pokazywany WYŁĄCZNIE
// gdy `FirebaseAuth.currentUser.emailVerified == false`.
//
// W praktyce oznacza to tylko rejestrację e-mailem i hasłem: Apple i Google
// oddają adres już zweryfikowany (relay „Hide My Email" również), więc ich
// użytkownicy tego ekranu nigdy nie zobaczą.
//
// Ekran jest **nieblokujący** — „Zrobię to później" prowadzi dalej, a
// przypomnieniem zostaje sticky baner. Weryfikacja jest egzekwowana dopiero
// przy pierwszym uploadzie (UploadQueueRunner), nigdy przy nagrywaniu:
// mikrofon musi działać zawsze (UX-1, docs/17).

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/email_verification_provider.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.onDone});

  /// Wywoływane po „Zrobię to później" i po potwierdzeniu adresu. Gdy null,
  /// ekran po prostu się zdejmuje ze stosu.
  final VoidCallback? onDone;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;

  void _finish() {
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
      _finish();
    } else {
      EuphireToast.error(context, message: t.verify_email_still_unverified);
    }
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
                // Nieblokująca furtka — wymóg z S1 kroku 3.
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: Text(
                    t.verify_email_later,
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
