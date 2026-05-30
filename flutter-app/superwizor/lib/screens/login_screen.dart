import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../widgets/euphire_button.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isLogin = true;

  @override
  void initState() {
    super.initState();
    // Cross-origin login bridge (stop-gap):
    // marketing-site's /account page links here as
    //   https://superwizor-app.web.app/?email=<encoded>
    // because Firebase Auth IndexedDB is origin-scoped (docs/18 §5
    // R3) — the user is logged in on superwizor.web.app but starts
    // signed-out here. Pre-fill the email so they only need to
    // re-type the password. Uri.base reflects the current page URL
    // on web; on iOS/Android Uri.base is a custom scheme and
    // queryParameters is empty, so this is a no-op on native.
    final emailParam = Uri.base.queryParameters['email'];
    if (emailParam != null && emailParam.isNotEmpty) {
      _email.text = emailParam;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Social sign-in — uses firebase_auth's signInWithProvider (native) /
  // signInWithPopup (web). No extra packages required — firebase_auth
  // 6.4.0 handles both paths. On iOS, signInWithProvider uses:
  //   • Google  → ASWebAuthenticationSession (system Safari sheet)
  //   • Apple   → ASAuthorizationController (native Face ID / Touch ID sheet)
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      await _ensureUserRegistered();
    } on FirebaseAuthException catch (e) {
      debugPrint('[social] Google sign-in FirebaseAuthException: ${e.code}');
      if (mounted) {
        // popup-closed / cancelled → silent
        if (e.code != 'popup-closed-by-user' &&
            e.code != 'canceled' &&
            e.code != 'user-cancelled') {
          setState(() => _error = t.auth_social_error);
        }
      }
    } catch (e) {
      debugPrint('[social] Google sign-in error: $e');
      if (mounted) setState(() => _error = t.auth_social_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // On iOS: uses ASAuthorizationController → native Sign In with Apple
        // sheet (Face ID / Touch ID). Requires Runner.entitlements to have
        // com.apple.developer.applesignin = [Default].
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      await _ensureUserRegistered();
    } on FirebaseAuthException catch (e) {
      debugPrint('[social] Apple sign-in FirebaseAuthException: ${e.code}');
      if (mounted) {
        if (e.code != 'popup-closed-by-user' &&
            e.code != 'canceled' &&
            e.code != 'user-cancelled') {
          setState(() => _error = t.auth_social_error);
        }
      }
    } catch (e) {
      debugPrint('[social] Apple sign-in error: $e');
      if (mounted) setState(() => _error = t.auth_social_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Email / password sign-in
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Diagnose silent input issues that look like wrong-password but are
    // really iOS autofill artifacts (trailing whitespace, smart-quote
    // substitution, hidden zero-width chars, etc.). We never log the
    // password value itself — only its shape.
    final emailRaw = _email.text;
    final emailTrimmed = emailRaw.trim().toLowerCase();
    final passRaw = _password.text;
    final passTrimmed = passRaw.trim();
    final hasEmailWhitespace = emailRaw != emailTrimmed;
    final hasPassWhitespace = passRaw != passTrimmed;
    final passHasNonAscii = passRaw.codeUnits.any((c) => c > 127);
    debugPrint(
        '[auth] mode=${_isLogin ? "login" : "register"} '
        'email="$emailTrimmed" emailLen=${emailRaw.length} '
        'passLen=${passRaw.length} '
        'emailHadWhitespace=$hasEmailWhitespace '
        'passHadWhitespace=$hasPassWhitespace '
        'passHasNonAscii=$passHasNonAscii');

    try {
      if (_isLogin) {
        // Login flow.
        // - Email is lower-cased + trimmed (Firebase canonicalises emails
        //   to lowercase internally; doing it here makes the local logs
        //   accurate and avoids client/server mismatch noise).
        // - Password is sent untrimmed: trimming would silently mangle
        //   passwords that legitimately contain leading/trailing spaces
        //   (rare but valid). If the user has a trailing-space artifact
        //   from iOS autofill, the diagnostic above will surface it
        //   so they can fix the input rather than us masking it.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailTrimmed,
          password: passRaw,
        );
        await _ensureUserRegistered();
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailTrimmed,
          password: passRaw,
        );
        await _registerInIdentityService(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException code=${e.code} message=${e.message}');
      if (mounted) {
        setState(() => _error = _friendlyAuthError(context, e.code));
      }
    } catch (e) {
      debugPrint('General Exception: $e');
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).auth_error_generic);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Sends a password-reset email via Firebase Auth. Used by the
  /// "Forgot password" affordance. We always show the same success
  /// message regardless of whether the email exists — this matches
  /// Firebase's email-enumeration protection and avoids leaking which
  /// emails are registered.
  Future<void> _sendPasswordReset() async {
    final emailTrimmed = _email.text.trim().toLowerCase();
    if (emailTrimmed.isEmpty) {
      setState(() => _error =
          AppLocalizations.of(context).auth_error_invalid_email);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailTrimmed);
    } catch (e) {
      debugPrint('sendPasswordResetEmail: $e');
      // intentional — show the same success message even on failure
    }
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.auth_password_reset_sent_title),
        content: Text(t.auth_password_reset_sent_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common_understand),
          ),
        ],
      ),
    );
  }

  /// Register the Firebase user in the identity-svc PostgreSQL database.
  /// Accepts optional firstName/lastName from social providers (Google,
  /// Apple) — only available on first sign-in; subsequent logins may
  /// have null displayName.
  Future<void> _registerInIdentityService(
    User firebaseUser, {
    String? firstName,
    String? lastName,
  }) async {
    // Derive first/last name: prefer explicit args, then split displayName,
    // then fall back to empty strings (user fills in profile later).
    String resolvedFirst = firstName ?? '';
    String resolvedLast = lastName ?? '';
    if (resolvedFirst.isEmpty && firebaseUser.displayName != null) {
      final parts = (firebaseUser.displayName ?? '').split(' ');
      resolvedFirst = parts.isNotEmpty ? parts.first : '';
      resolvedLast = parts.length > 1 ? parts.skip(1).join(' ') : '';
    }

    final identityClient = ref.read(grpcClientsProvider).identity;
    try {
      await identityClient.createUser(identity_pb.CreateUserRequest(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? _email.text.trim(),
        role: identity_pb.UserRole.USER_ROLE_THERAPIST,
        firstName: resolvedFirst,
        lastName: resolvedLast,
        uiLanguage: 'pl',
        timezone: 'Europe/Warsaw',
        hasAcceptedTos: true,
      ));
      debugPrint('[auth] User registered in identity-svc successfully');
    } catch (e) {
      debugPrint('[auth] Error registering user in identity-svc: $e');
      // Don't block login even if registration fails — user can retry
    }
  }

  /// For existing Firebase users who might not be in identity-svc yet.
  Future<void> _ensureUserRegistered() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final identityClient = ref.read(grpcClientsProvider).identity;
    try {
      // Try to fetch user — if they exist, do nothing
      await identityClient.getUserByFirebaseUID(
        identity_pb.GetUserByFirebaseUIDRequest(firebaseUid: firebaseUser.uid),
      );
    } catch (e) {
      // User not found in identity-svc — auto-register them
      debugPrint('[auth] User not found in identity-svc, auto-registering...');
      await _registerInIdentityService(firebaseUser);
    }
  }

  /// Maps Firebase Auth error codes to Polish user-friendly messages.
  /// `invalid-credential` is the new generic code Firebase returns
  /// for both "wrong password" and "user not found" — Email
  /// Enumeration Protection is on by default (good for clinical PHI).
  /// We can't tell which one happened, so we say "wrong email or
  /// password" and trust the user to figure it out via Forgot Password.
  String _friendlyAuthError(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return t.auth_error_invalid_credential;
      case 'email-already-in-use':
        return t.auth_error_email_already_in_use;
      case 'weak-password':
        return t.auth_error_weak_password;
      case 'invalid-email':
        return t.auth_error_invalid_email;
      case 'network-request-failed':
        return t.auth_error_network;
      case 'too-many-requests':
        return t.auth_error_too_many_requests;
      case 'user-disabled':
        return t.auth_error_user_disabled;
      default:
        return t.auth_error_generic;
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EuphireHeader(
                title: 'Superwizor AI.',
                subtitle: _isLogin
                    ? 'Zaloguj się, aby kontynuować.'
                    : 'Zarejestruj się, aby rozpocząć.',
              ),
              const SizedBox(height: 48),

              // ── Social login buttons ──────────────────────────────
              _SocialButton(
                label: t.auth_sign_in_with_google,
                icon: _GoogleIcon(),
                onPressed: _loading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 12),
              // Apple Sign In: shown on all platforms (iOS + web).
              // On Android we omit it — Apple's HIG requires Apple
              // Sign In to be available wherever Google Sign In is,
              // but the reverse isn't required and Android users
              // rarely have Apple IDs.
              if (!_isAndroid) ...[
                _SocialButton(
                  label: t.auth_sign_in_with_apple,
                  icon: const _AppleIcon(),
                  onPressed: _loading ? null : _signInWithApple,
                ),
                const SizedBox(height: 12),
              ],

              // ── Divider ───────────────────────────────────────────
              _OrDivider(label: t.auth_or_use_email),
              const SizedBox(height: 20),

              // ── Email / Password form ─────────────────────────────
              EuphireTextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                labelText: 'Twój email.',
              ),
              const SizedBox(height: 16),
              EuphireTextField(
                controller: _password,
                obscureText: true,
                labelText: 'Twoje hasło.',
              ),
              const SizedBox(height: 24),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),

              EuphireButton(
                text: _isLogin ? 'Zaloguj się.' : 'Zarejestruj się.',
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              if (_isLogin)
                TextButton(
                  onPressed: _loading ? null : _sendPasswordReset,
                  child: Text(t.auth_forgot_password),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(
                  _isLogin
                      ? 'Nie masz konta? Zarejestruj się.'
                      : 'Masz już konto? Zaloguj się.',
                ),
              ),

              // Web-only: shared-machine reminder. iOS/Android run on
              // personal devices so the warning would be noise there;
              // app.superwizor.ai is the only context where someone
              // else might walk up and re-open the browser tab.
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                const _SharedMachineNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// True when running on Android (not web, not iOS/macOS).
  bool get _isAndroid =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.android;
}

// ──────────────────────────────────────────────────────────────────────────
// Social button — generic outlined button for Google / Apple.
// ──────────────────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onPressed == null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        side: BorderSide(
          color: disabled
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.outline,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: theme.colorScheme.onSurface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: disabled
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// "— lub —" divider between social and email sections.
// ──────────────────────────────────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Google "G" monochrome icon (SVG paths as CustomPainter).
// ──────────────────────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue
    paint.color = const Color(0xFF4285F4);
    final pathBlue = Path()
      ..moveTo(17.64 * s, 9.2 * s)
      ..cubicTo(17.64 * s, 8.56 * s, 17.58 * s, 7.95 * s, 17.48 * s, 7.36 * s)
      ..lineTo(9 * s, 7.36 * s)
      ..lineTo(9 * s, 10.84 * s)
      ..lineTo(13.84 * s, 10.84 * s)
      ..cubicTo(13.63 * s, 11.97 * s, 13.0 * s, 12.92 * s, 12.05 * s, 13.56 * s)
      ..lineTo(12.05 * s, 15.82 * s)
      ..lineTo(14.95 * s, 15.82 * s)
      ..cubicTo(16.65 * s, 14.26 * s, 17.64 * s, 11.95 * s, 17.64 * s, 9.2 * s)
      ..close();
    canvas.drawPath(pathBlue, paint);

    // Green
    paint.color = const Color(0xFF34A853);
    final pathGreen = Path()
      ..moveTo(9 * s, 18 * s)
      ..cubicTo(11.43 * s, 18 * s, 13.47 * s, 17.19 * s, 14.96 * s, 15.82 * s)
      ..lineTo(12.06 * s, 13.56 * s)
      ..cubicTo(11.25 * s, 14.1 * s, 10.22 * s, 14.42 * s, 9 * s, 14.42 * s)
      ..cubicTo(6.64 * s, 14.42 * s, 4.64 * s, 12.83 * s, 3.93 * s, 10.68 * s)
      ..lineTo(0.96 * s, 10.68 * s)
      ..lineTo(0.96 * s, 13.02 * s)
      ..cubicTo(2.45 * s, 15.98 * s, 5.48 * s, 18 * s, 9 * s, 18 * s)
      ..close();
    canvas.drawPath(pathGreen, paint);

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    final pathYellow = Path()
      ..moveTo(3.93 * s, 10.71 * s)
      ..cubicTo(3.75 * s, 10.17 * s, 3.64 * s, 9.6 * s, 3.64 * s, 9 * s)
      ..cubicTo(3.64 * s, 8.4 * s, 3.75 * s, 7.82 * s, 3.93 * s, 7.29 * s)
      ..lineTo(3.93 * s, 4.96 * s)
      ..lineTo(0.96 * s, 4.96 * s)
      ..cubicTo(0.35 * s, 6.17 * s, 0 * s, 7.55 * s, 0 * s, 9 * s)
      ..cubicTo(0, 10.45 * s, 0.35 * s, 11.83 * s, 0.96 * s, 13.04 * s)
      ..lineTo(3.93 * s, 10.71 * s)
      ..close();
    canvas.drawPath(pathYellow, paint);

    // Red
    paint.color = const Color(0xFFEA4335);
    final pathRed = Path()
      ..moveTo(9 * s, 3.58 * s)
      ..cubicTo(10.32 * s, 3.58 * s, 11.51 * s, 4.03 * s, 12.44 * s, 4.93 * s)
      ..lineTo(15.02 * s, 2.35 * s)
      ..cubicTo(13.47 * s, 0.9 * s, 11.43 * s, 0, 9 * s, 0)
      ..cubicTo(5.48 * s, 0, 2.45 * s, 2.02 * s, 0.96 * s, 4.96 * s)
      ..lineTo(3.93 * s, 7.29 * s)
      ..cubicTo(4.64 * s, 5.17 * s, 6.64 * s, 3.58 * s, 9 * s, 3.58 * s)
      ..close();
    canvas.drawPath(pathRed, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ──────────────────────────────────────────────────────────────────────────
// Apple  icon (monochrome, adapts to light/dark).
// ──────────────────────────────────────────────────────────────────────────
class _AppleIcon extends StatelessWidget {
  const _AppleIcon();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Icon(Icons.apple, size: 22, color: color);
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Shared-machine notice — Flutter Web only. Public kiosks, clinic
// reception desks, library computers etc. are realistic environments
// for the web build (iOS/Android wouldn't be). The notice is
// non-blocking (no checkbox, no dialog) — just a localized reminder
// styled as an outlined info card so it reads as advice rather than
// an error.
// ──────────────────────────────────────────────────────────────────────────
class _SharedMachineNotice extends StatelessWidget {
  const _SharedMachineNotice();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.auth_shared_machine_warning_title,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l.auth_shared_machine_warning_body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
