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
  Future<void> _registerInIdentityService(User firebaseUser) async {
    final identityClient = ref.read(grpcClientsProvider).identity;
    try {
      await identityClient.createUser(identity_pb.CreateUserRequest(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? _email.text.trim(),
        role: identity_pb.UserRole.USER_ROLE_THERAPIST,
        firstName: '',
        lastName: '',
        uiLanguage: 'pl',
        timezone: 'Europe/Warsaw',
        hasAcceptedTos: true,
      ));
      debugPrint('User registered in identity-svc successfully');
    } catch (e) {
      debugPrint('Error registering user in identity-svc: $e');
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
      debugPrint('User not found in identity-svc, auto-registering...');
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
                subtitle: _isLogin ? 'Zaloguj się, aby kontynuować.' : 'Zarejestruj się, aby rozpocząć.',
              ),
              const SizedBox(height: 48),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  child: Text(AppLocalizations.of(context).auth_forgot_password),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(
                  _isLogin ? 'Nie masz konta? Zarejestruj się.' : 'Masz już konto? Zaloguj się.',
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
}

// Shared-machine notice — Flutter Web only. Public kiosks, clinic
// reception desks, library computers etc. are realistic environments
// for the web build (iOS/Android wouldn't be). The notice is
// non-blocking (no checkbox, no dialog) — just a localized reminder
// styled as an outlined info card so it reads as advice rather than
// an error.
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
