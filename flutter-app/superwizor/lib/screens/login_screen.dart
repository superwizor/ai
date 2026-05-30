import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../generated/identity/v1/identity.pb.dart' as identity_pb;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — from the Superwizor AI design system (dark M3 variant).
// Replicated here as const Color values so the login screen looks identical
// to the web design even before the global ThemeData propagates these.
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const primaryContainer = Color(0xFF004D54);
  static const surface = Color(0xFF131313);
  static const surfaceContainer = Color(0xFF202020);
  static const outlineVariant = Color(0xFF40484A);
  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFBFC8C9);
  static const primary = Color(0xFF95D0D8);
  static const onPrimary = Color(0xFF00363C);

  // Typography
  static const fontMontserrat = 'Montserrat';
  static const fontMerriweather = 'Merriweather';
  static const fontRobotoMono = 'RobotoMono';
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isLogin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if navigated from marketing site with ?email=...
    final emailParam = Uri.base.queryParameters['email'];
    if (emailParam != null && emailParam.isNotEmpty) {
      _emailCtrl.text = emailParam;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Social sign-in ────────────────────────────────────────────────────────
  // Uses firebase_auth's signInWithProvider (native iOS) /
  // signInWithPopup (web). No extra packages required.
  //   iOS Google  → ASWebAuthenticationSession (system Safari sheet)
  //   iOS Apple   → ASAuthorizationController (native Face ID / Touch ID)

  Future<void> _signInWithGoogle() async {
    final t = AppLocalizations.of(context);
    setState(() { _loading = true; _error = null; });
    try {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      await _ensureUserRegistered();
    } on FirebaseAuthException catch (e) {
      if (mounted &&
          e.code != 'popup-closed-by-user' &&
          e.code != 'canceled' &&
          e.code != 'user-cancelled') {
        setState(() => _error = t.auth_social_error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).auth_social_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    final t = AppLocalizations.of(context);
    setState(() { _loading = true; _error = null; });
    try {
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      await _ensureUserRegistered();
    } on FirebaseAuthException catch (e) {
      if (mounted &&
          e.code != 'popup-closed-by-user' &&
          e.code != 'canceled' &&
          e.code != 'user-cancelled') {
        setState(() => _error = t.auth_social_error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).auth_social_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Email/password ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final emailTrimmed = _emailCtrl.text.trim().toLowerCase();
    final passRaw = _passwordCtrl.text;
    try {
      if (_isLogin) {
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
      if (mounted) setState(() => _error = _friendlyError(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).auth_error_generic);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).auth_error_invalid_email);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) { /* intentional silent — show same message regardless */ }
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _DS.surfaceContainer,
        title: Text(t.auth_password_reset_sent_title,
            style: const TextStyle(fontFamily: _DS.fontMontserrat, color: _DS.onSurface)),
        content: Text(t.auth_password_reset_sent_body,
            style: const TextStyle(fontFamily: _DS.fontMerriweather, color: _DS.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common_understand,
                style: const TextStyle(color: _DS.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _registerInIdentityService(User user, {String? firstName, String? lastName}) async {
    String fName = firstName ?? '';
    String lName = lastName ?? '';
    if (fName.isEmpty && user.displayName != null) {
      final parts = (user.displayName ?? '').split(' ');
      fName = parts.isNotEmpty ? parts.first : '';
      lName = parts.length > 1 ? parts.skip(1).join(' ') : '';
    }
    final identityClient = ref.read(grpcClientsProvider).identity;
    try {
      await identityClient.createUser(identity_pb.CreateUserRequest(
        firebaseUid: user.uid,
        email: user.email ?? _emailCtrl.text.trim(),
        role: identity_pb.UserRole.USER_ROLE_THERAPIST,
        firstName: fName,
        lastName: lName,
        uiLanguage: 'pl',
        timezone: 'Europe/Warsaw',
        hasAcceptedTos: true,
      ));
    } catch (e) {
      debugPrint('[auth] identity-svc registration error: $e');
    }
  }

  Future<void> _ensureUserRegistered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final identityClient = ref.read(grpcClientsProvider).identity;
    try {
      await identityClient.getUserByFirebaseUID(
        identity_pb.GetUserByFirebaseUIDRequest(firebaseUid: user.uid),
      );
    } catch (_) {
      await _registerInIdentityService(user);
    }
  }

  String _friendlyError(String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return t.auth_error_invalid_credential;
      case 'email-already-in-use': return t.auth_error_email_already_in_use;
      case 'weak-password': return t.auth_error_weak_password;
      case 'invalid-email': return t.auth_error_invalid_email;
      case 'network-request-failed': return t.auth_error_network;
      case 'too-many-requests': return t.auth_error_too_many_requests;
      case 'user-disabled': return t.auth_error_user_disabled;
      default: return t.auth_error_generic;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.primaryContainer,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: _LoginCard(
                loading: _loading,
                isLogin: _isLogin,
                error: _error,
                emailCtrl: _emailCtrl,
                passwordCtrl: _passwordCtrl,
                onGoogle: _signInWithGoogle,
                onApple: _signInWithApple,
                onSubmit: _submit,
                onForgotPassword: _sendPasswordReset,
                onToggleMode: () => setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The card itself — extracted so build() stays readable.
// ─────────────────────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.loading,
    required this.isLogin,
    required this.error,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.onGoogle,
    required this.onApple,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onToggleMode,
  });

  final bool loading;
  final bool isLogin;
  final String? error;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _DS.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DS.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Logo ────────────────────────────────────────────────────────
          _LogoCircle(),
          const SizedBox(height: 32),

          // ── Headline ─────────────────────────────────────────────────────
          Text(
            'Witaj w Superwizor AI.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _DS.fontMontserrat,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _DS.onSurface,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zaloguj się, aby kontynuować.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _DS.fontMerriweather,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _DS.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ── Social buttons ────────────────────────────────────────────────
          _GoogleButton(loading: loading, onPressed: loading ? null : onGoogle),
          const SizedBox(height: 12),
          if (!_isAndroid(context))
            _AppleButton(loading: loading, onPressed: loading ? null : onApple),
          if (!_isAndroid(context)) const SizedBox(height: 12),

          // ── Divider ──────────────────────────────────────────────────────
          _OrDivider(),
          const SizedBox(height: 24),

          // ── Email input ───────────────────────────────────────────────────
          _InputField(
            controller: emailCtrl,
            label: 'Adres e-mail.',
            hint: 'Twój adres e-mail.',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            enabled: !loading,
          ),
          const SizedBox(height: 20),

          // ── Password input ────────────────────────────────────────────────
          _InputField(
            controller: passwordCtrl,
            label: 'Hasło.',
            hint: 'Twoje hasło.',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            enabled: !loading,
          ),
          const SizedBox(height: 24),

          // ── Error message ─────────────────────────────────────────────────
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF93000A).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB4AB).withValues(alpha: 0.4)),
              ),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _DS.fontMerriweather,
                  fontSize: 14,
                  color: Color(0xFFFFB4AB),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Submit button ─────────────────────────────────────────────────
          _SubmitButton(
            loading: loading,
            isLogin: isLogin,
            onPressed: loading ? null : onSubmit,
          ),
          const SizedBox(height: 32),

          // ── Links ─────────────────────────────────────────────────────────
          if (isLogin)
            TextButton(
              onPressed: loading ? null : onForgotPassword,
              child: const Text(
                'Zapomniałeś hasła?',
                style: TextStyle(
                  fontFamily: _DS.fontMerriweather,
                  fontSize: 16,
                  color: _DS.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0x5095D0D8),
                ),
              ),
            ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: _DS.fontMerriweather,
                fontSize: 16,
                color: _DS.onSurfaceVariant,
              ),
              children: [
                TextSpan(text: isLogin ? 'Nie masz konta? ' : 'Masz już konto? '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: loading ? null : onToggleMode,
                    child: Text(
                      isLogin ? 'Zarejestruj się.' : 'Zaloguj się.',
                      style: const TextStyle(
                        fontFamily: _DS.fontMerriweather,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _DS.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0x5095D0D8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isAndroid(BuildContext ctx) =>
      !kIsWeb && Theme.of(ctx).platform == TargetPlatform.android;
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo circle — app logo in a bordered circle, matching the web design.
// ─────────────────────────────────────────────────────────────────────────────
class _LogoCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: _DS.surface,
        shape: BoxShape.circle,
        border: Border.all(color: _DS.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/Ico/Logo_Superwizor_MVP.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google sign-in button — surface bg, border, colored G mark.
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, this.onPressed});
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _SocialButtonBase(
      onPressed: onPressed,
      backgroundColor: _DS.surface,
      borderColor: _DS.outlineVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(painter: _GoogleLogoPainter()),
          ),
          const SizedBox(width: 12),
          const Text(
            'Zaloguj się przez Google.',
            style: TextStyle(
              fontFamily: _DS.fontRobotoMono,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.03 * 14,
              color: _DS.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apple sign-in button — on-surface (near-white) bg, white text.
// ─────────────────────────────────────────────────────────────────────────────
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.loading, this.onPressed});
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _SocialButtonBase(
      onPressed: onPressed,
      backgroundColor: _DS.onSurface,
      borderColor: _DS.onSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 22,
            child: CustomPaint(painter: _AppleLogoPainter()),
          ),
          const SizedBox(width: 12),
          const Text(
            'Zaloguj się przez Apple.',
            style: TextStyle(
              fontFamily: _DS.fontRobotoMono,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.03 * 14,
              color: _DS.surface,
            ),
          ),
        ],
      ),
    );
  }
}

// Shared base for social buttons — handles press animation + disabled state.
class _SocialButtonBase extends StatefulWidget {
  const _SocialButtonBase({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.onPressed,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  State<_SocialButtonBase> createState() => _SocialButtonBaseState();
}

class _SocialButtonBaseState extends State<_SocialButtonBase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.02,
    );
    _scale = Tween(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => _ctrl.forward(),
      onTapUp: disabled ? null : (_) {
        _ctrl.reverse();
        widget.onPressed!();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: disabled ? 0.55 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Lub." divider — matches the web design exactly.
// ─────────────────────────────────────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: _DS.outlineVariant, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Lub.',
            style: const TextStyle(
              fontFamily: _DS.fontRobotoMono,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _DS.onSurfaceVariant,
              letterSpacing: 0.05 * 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: _DS.outlineVariant, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input field — with Material Symbols-style icon and focus ring.
// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: _DS.fontRobotoMono,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _DS.onSurfaceVariant,
            letterSpacing: 0.08 * 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          enabled: enabled,
          style: const TextStyle(
            fontFamily: _DS.fontMerriweather,
            fontSize: 16,
            color: _DS.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: _DS.fontMerriweather,
              fontSize: 16,
              color: _DS.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, color: _DS.onSurfaceVariant, size: 20),
            filled: true,
            fillColor: _DS.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _DS.outlineVariant.withValues(alpha: 0.4)),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit button — primary teal fill, matching the web's bg-primary button.
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.loading,
    required this.isLogin,
    this.onPressed,
  });
  final bool loading;
  final bool isLogin;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: loading ? 0.7 : 1.0,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _DS.primary,
            foregroundColor: _DS.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            shadowColor: _DS.primary.withValues(alpha: 0.3),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_DS.onPrimary),
                  ),
                )
              : Text(
                  isLogin ? 'Zaloguj się.' : 'Zarejestruj się.',
                  style: const TextStyle(
                    fontFamily: _DS.fontMontserrat,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.01 * 18,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google "G" full-color logo — 4 colored path segments.
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final p = Paint()..style = PaintingStyle.fill;

    // Blue — right arc
    final blue = Path()
      ..moveTo(22.56 * s, 12.25 * s)
      ..cubicTo(22.56 * s, 10.5 * s, 22.42 * s, 9.23 * s, 22.2 * s, 8.0 * s)
      ..lineTo(12 * s, 8.0 * s)
      ..lineTo(12 * s, 14.26 * s)
      ..lineTo(17.92 * s, 14.26 * s)
      ..cubicTo(17.44 * s, 16.18 * s, 16.16 * s, 17.78 * s, 14.48 * s, 18.78 * s)
      ..lineTo(14.48 * s, 22.08 * s)
      ..lineTo(18.92 * s, 22.08 * s)
      ..cubicTo(21.64 * s, 19.52 * s, 22.56 * s, 16.22 * s, 22.56 * s, 12.25 * s)
      ..close();
    p.color = const Color(0xFF4285F4);
    canvas.drawPath(blue, p);

    // Green — bottom
    final green = Path()
      ..moveTo(12 * s, 23 * s)
      ..cubicTo(15.24 * s, 23 * s, 17.94 * s, 21.96 * s, 19.84 * s, 20.08 * s)
      ..lineTo(15.4 * s, 16.78 * s)
      ..cubicTo(14.3 * s, 17.48 * s, 13.26 * s, 17.88 * s, 12 * s, 17.88 * s)
      ..cubicTo(8.86 * s, 17.88 * s, 6.22 * s, 15.72 * s, 5.26 * s, 12.78 * s)
      ..lineTo(0.7 * s, 12.78 * s)
      ..lineTo(0.7 * s, 15.92 * s)
      ..cubicTo(2.6 * s, 19.76 * s, 6.96 * s, 23 * s, 12 * s, 23 * s)
      ..close();
    p.color = const Color(0xFF34A853);
    canvas.drawPath(green, p);

    // Yellow — left
    final yellow = Path()
      ..moveTo(5.26 * s, 12.78 * s)
      ..cubicTo(5.0 * s, 11.96 * s, 4.86 * s, 11.0 * s, 4.86 * s, 12.0 * s)
      ..cubicTo(4.86 * s, 13.0 * s, 5.0 * s, 12.04 * s, 5.26 * s, 11.22 * s)
      ..lineTo(5.26 * s, 8.08 * s)
      ..lineTo(0.7 * s, 8.08 * s)
      ..cubicTo(-0.2 * s, 9.56 * s, -0.6 * s, 10.74 * s, 0.0 * s, 12.0 * s)
      ..cubicTo(0.0 * s, 13.26 * s, 0.36 * s, 14.54 * s, 0.7 * s, 15.92 * s)
      ..lineTo(5.26 * s, 12.78 * s)
      ..close();
    p.color = const Color(0xFFFBBC05);
    canvas.drawPath(yellow, p);

    // Red — top
    final red = Path()
      ..moveTo(12 * s, 5.38 * s)
      ..cubicTo(13.78 * s, 5.38 * s, 15.36 * s, 5.98 * s, 16.62 * s, 7.2 * s)
      ..lineTo(20.06 * s, 3.76 * s)
      ..cubicTo(17.94 * s, 1.78 * s, 15.22 * s, 0.5 * s, 12 * s, 0.5 * s)
      ..cubicTo(6.96 * s, 0.5 * s, 2.6 * s, 3.74 * s, 0.7 * s, 8.08 * s)
      ..lineTo(5.26 * s, 11.22 * s)
      ..cubicTo(6.22 * s, 8.28 * s, 8.86 * s, 5.38 * s, 12 * s, 5.38 * s)
      ..close();
    p.color = const Color(0xFFEA4335);
    canvas.drawPath(red, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Apple logo — uses the same SVG paths as the HTML design (viewBox 0 0 24 24).
// Rendered in _DS.surface (dark) to contrast with the light button bg.
// ─────────────────────────────────────────────────────────────────────────────
class _AppleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    final p = Paint()
      ..style = PaintingStyle.fill
      ..color = _DS.surface;

    // Body of the apple
    final body = Path()
      ..moveTo(12.152 * sx, 6.896 * sy)
      ..cubicTo(11.204 * sx, 6.896 * sy, 9.737 * sx, 5.818 * sy, 8.192 * sx, 5.856 * sy)
      ..cubicTo(6.152 * sx, 5.883 * sy, 4.282 * sx, 7.039 * sy, 3.231 * sx, 8.870 * sy)
      ..cubicTo(1.114 * sx, 12.545 * sy, 2.685 * sx, 17.973 * sy, 4.750 * sx, 20.960 * sy)
      ..cubicTo(5.763 * sx, 22.414 * sy, 6.958 * sx, 24.050 * sy, 8.542 * sx, 23.999 * sy)
      ..cubicTo(10.062 * sx, 23.934 * sy, 10.632 * sx, 23.012 * sy, 12.477 * sx, 23.012 * sy)
      ..cubicTo(14.308 * sx, 23.012 * sy, 14.827 * sx, 23.999 * sy, 16.437 * sx, 23.960 * sy)
      ..cubicTo(18.074 * sx, 23.934 * sy, 19.113 * sx, 22.480 * sy, 20.113 * sx, 21.012 * sy)
      ..cubicTo(21.269 * sx, 19.324 * sy, 21.749 * sx, 17.687 * sy, 21.775 * sx, 17.597 * sy)
      ..cubicTo(21.736 * sx, 17.584 * sy, 18.593 * sx, 16.376 * sy, 18.555 * sx, 12.740 * sy)
      ..cubicTo(18.529 * sx, 9.700 * sy, 21.035 * sx, 8.246 * sy, 21.152 * sx, 8.181 * sy)
      ..cubicTo(19.723 * sx, 6.091 * sy, 17.529 * sx, 5.857 * sy, 16.762 * sx, 5.805 * sy)
      ..cubicTo(14.762 * sx, 5.649 * sy, 13.087 * sx, 6.896 * sy, 12.152 * sx, 6.896 * sy)
      ..close();

    // Leaf / stem
    final leaf = Path()
      ..moveTo(15.530 * sx, 3.830 * sy)
      ..cubicTo(16.373 * sx, 2.818 * sy, 16.930 * sx, 1.403 * sy, 16.775 * sx, 0.000 * sy)
      ..cubicTo(15.568 * sx, 0.052 * sy, 14.113 * sx, 0.805 * sy, 13.243 * sx, 1.818 * sy)
      ..cubicTo(12.463 * sx, 2.714 * sy, 11.789 * sx, 4.156 * sy, 11.970 * sx, 5.532 * sy)
      ..cubicTo(13.308 * sx, 5.636 * sy, 14.685 * sx, 4.844 * sy, 15.530 * sx, 3.830 * sy)
      ..close();

    canvas.drawPath(body, p);
    canvas.drawPath(leaf, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
