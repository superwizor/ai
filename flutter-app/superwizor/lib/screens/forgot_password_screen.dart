import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Forgot Password screen — Apple/Google-quality UX.
//
// Flow:
//   1. User sees a calming intro explaining what will happen.
//   2. Types their email (pre-filled if they started typing on login).
//   3. Taps "Wyślij link" → Firebase sends password reset email.
//   4. Screen transitions to a "check your inbox" confirmation with
//      clear next-step instructions and a "Back to login" CTA.
//
// Design: same gradient + Montserrat-only as login screen.
// ─────────────────────────────────────────────────────────────────────────────

const _kFont = 'Montserrat';
const _kBgTop = Color(0xFF004D54);
const _kBgBottom = Color(0xFF002E32);
const _kWhite = Color(0xFFF5F5F5);
const _kWhite70 = Color(0xB3F5F5F5);
const _kWhite40 = Color(0x66F5F5F5);
const _kWhite15 = Color(0x26F5F5F5);
const _kWhite08 = Color(0x14F5F5F5);
const _kAccent = Color(0xFF95D0D8);
const _kErrorBg = Color(0x33FF6B6B);
const _kErrorBorder = Color(0x66FF6B6B);
const _kErrorText = Color(0xFFFFAAAA);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Podaj poprawny adres e-mail.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'user-not-found' => 'Nie znaleźliśmy konta z tym adresem.',
            'invalid-email' => 'Ten adres e-mail wygląda nieprawidłowo.',
            'too-many-requests' => 'Za dużo prób. Odczekaj chwilę.',
            _ => 'Coś poszło nie tak. Spróbuj ponownie.',
          };
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Coś poszło nie tak. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar with back arrow ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _kWhite, size: 20),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // ── Content ──────────────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, 32 + bottomInset),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _sent
                            ? _SentConfirmation(
                                key: const ValueKey('sent'),
                                email: _emailCtrl.text.trim(),
                                onBack: () => Navigator.of(context).pop(),
                                onResend: () {
                                  setState(() => _sent = false);
                                },
                              )
                            : _RequestForm(
                                key: const ValueKey('form'),
                                emailCtrl: _emailCtrl,
                                loading: _loading,
                                error: _error,
                                onSend: _sendReset,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 1: Request form — explain what happens, collect email, send.
// ═════════════════════════════════════════════════════════════════════════════
class _RequestForm extends StatelessWidget {
  const _RequestForm({
    super.key,
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSend,
  });

  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kAccent.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.lock_reset_rounded, color: _kAccent, size: 36),
        ),
        const SizedBox(height: 28),

        // Title
        const Text(
          'Resetowanie hasła',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _kFont,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kWhite,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),

        // Explanation
        const Text(
          'Podaj adres e-mail powiązany z Twoim kontem. '
          'Wyślemy Ci link do ustawienia nowego hasła.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _kFont,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _kWhite70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Email field
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !loading,
          style: const TextStyle(
            fontFamily: _kFont,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _kWhite,
          ),
          cursorColor: _kAccent,
          decoration: InputDecoration(
            hintText: 'Twój adres e-mail',
            hintStyle: const TextStyle(
              fontFamily: _kFont, fontSize: 15,
              fontWeight: FontWeight.w400, color: _kWhite40,
            ),
            prefixIcon: const Icon(Icons.mail_outline_rounded,
                color: _kWhite40, size: 20),
            filled: true,
            fillColor: _kWhite08,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kWhite15),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kAccent, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kWhite08),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Error
        if (error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kErrorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kErrorBorder),
            ),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _kFont, fontSize: 13,
                fontWeight: FontWeight.w500, color: _kErrorText,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Send button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: const Color(0xFF002A25),
              disabledBackgroundColor: _kAccent.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF002A25)),
                    ),
                  )
                : const Text(
                    'Wyślij link',
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Security note
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: _kWhite40, size: 16),
            SizedBox(width: 6),
            Text(
              'Link wygasa po 1 godzinie',
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kWhite40,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 2: Confirmation — "Check your inbox" with clear next steps.
// ═════════════════════════════════════════════════════════════════════════════
class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({
    super.key,
    required this.email,
    required this.onBack,
    required this.onResend,
  });

  final String email;
  final VoidCallback onBack;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kAccent.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: _kAccent, size: 36),
        ),
        const SizedBox(height: 28),

        // Title
        const Text(
          'Sprawdź skrzynkę',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _kFont,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kWhite,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),

        // Explanation
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _kWhite70,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Wysłaliśmy wiadomość na adres\n'),
              TextSpan(
                text: email,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _kWhite,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Steps
        _StepItem(
          number: '1',
          text: 'Otwórz swoją skrzynkę e-mail',
        ),
        const SizedBox(height: 12),
        _StepItem(
          number: '2',
          text: 'Kliknij w link „Zresetuj hasło"',
        ),
        const SizedBox(height: 12),
        _StepItem(
          number: '3',
          text: 'Ustaw nowe hasło i zaloguj się',
        ),
        const SizedBox(height: 28),

        // Info tip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kWhite08,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kWhite15),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _kWhite40, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nie widzisz wiadomości? Sprawdź folder spam. '
                  'Wysyłka może potrwać do 2 minut.',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _kWhite70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Back to login button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: const Color(0xFF002A25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Wróć do logowania',
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend link
        TextButton(
          onPressed: onResend,
          child: const Text(
            'Wyślij ponownie',
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kAccent,
            ),
          ),
        ),
      ],
    );
  }
}

// Numbered step indicator
class _StepItem extends StatelessWidget {
  const _StepItem({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kAccent.withValues(alpha: 0.15),
            border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kAccent,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _kWhite,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
