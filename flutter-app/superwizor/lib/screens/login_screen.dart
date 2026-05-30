import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../generated/identity/v1/identity.pb.dart' as identity_pb;

// ─────────────────────────────────────────────────────────────────────────────
// Login screen — Apple / Google-style minimal UX.
//
// Design principles:
//   • Full-screen gradient background (teal → deep teal), no card frame.
//   • Single typeface: Montserrat throughout, varying weight only.
//   • Maximum whitespace, generous vertical rhythm.
//   • Social buttons first (conversion-optimized), divider, then email.
//   • Subtle micro-animations on buttons (scale on tap).
//   • Accessible contrast ratios on all text.
// ─────────────────────────────────────────────────────────────────────────────

// Design tokens
const _kFont = 'Montserrat';
const _kBgTop = Color(0xFF0A6B5E);       // rich teal
const _kBgBottom = Color(0xFF052E28);     // deep forest
const _kWhite = Color(0xFFF5F5F5);
const _kWhite70 = Color(0xB3F5F5F5);     // 70% white
const _kWhite40 = Color(0x66F5F5F5);     // 40% white
const _kWhite15 = Color(0x26F5F5F5);     // 15% white
const _kWhite08 = Color(0x14F5F5F5);     // 8% white
const _kAccent = Color(0xFF95D0D8);       // primary accent (light teal)
const _kErrorBg = Color(0x33FF6B6B);
const _kErrorBorder = Color(0x66FF6B6B);
const _kErrorText = Color(0xFFFFAAAA);

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
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
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

  // ── Social sign-in ──────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
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
      if (mounted && !_isCancelled(e.code)) {
        setState(() => _error = AppLocalizations.of(context).auth_social_error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).auth_social_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
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
      if (mounted && !_isCancelled(e.code)) {
        setState(() => _error = AppLocalizations.of(context).auth_social_error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).auth_social_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isCancelled(String code) =>
      code == 'popup-closed-by-user' ||
      code == 'canceled' ||
      code == 'user-cancelled';

  // ── Email / password ────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passwordCtrl.text;
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: pass,
        );
        await _ensureUserRegistered();
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: pass,
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
    } catch (_) {}
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.auth_password_reset_sent_title,
            style: const TextStyle(fontFamily: _kFont, fontWeight: FontWeight.w600, color: _kWhite)),
        content: Text(t.auth_password_reset_sent_body,
            style: const TextStyle(fontFamily: _kFont, fontWeight: FontWeight.w400, color: _kWhite70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common_understand,
                style: const TextStyle(fontFamily: _kFont, color: _kAccent, fontWeight: FontWeight.w600)),
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
        firstName: fName, lastName: lName,
        uiLanguage: 'pl', timezone: 'Europe/Warsaw',
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

  bool get _isAndroid =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.android;

  // ── Build ───────────────────────────────────────────────────────────────

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
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(32, 48, 32, 32 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo ──────────────────────────────────────────
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kWhite08,
                        border: Border.all(color: _kWhite15, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/Ico/Logo_Superwizor_MVP.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Title ─────────────────────────────────────────
                    const Text(
                      'Witaj ponownie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _kWhite,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zaloguj się do Superwizor AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: _kWhite70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Social buttons ────────────────────────────────
                    _SocialButton(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const _GoogleIcon(),
                      label: 'Kontynuuj z Google',
                      backgroundColor: _kWhite,
                      textColor: const Color(0xFF1F1F1F),
                    ),
                    const SizedBox(height: 12),
                    if (!_isAndroid) ...[
                      _SocialButton(
                        onPressed: _loading ? null : _signInWithApple,
                        icon: const _AppleIcon(),
                        label: 'Kontynuuj z Apple',
                        backgroundColor: const Color(0xFF1F1F1F),
                        textColor: _kWhite,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Divider ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: _kWhite15)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('lub', style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kWhite40,
                          )),
                        ),
                        Expanded(child: Container(height: 1, color: _kWhite15)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Email field ───────────────────────────────────
                    _TextField(
                      controller: _emailCtrl,
                      hint: 'Adres e-mail',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      enabled: !_loading,
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 14),

                    // ── Password field ────────────────────────────────
                    _TextField(
                      controller: _passwordCtrl,
                      hint: 'Hasło',
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      enabled: !_loading,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: _kWhite40,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Forgot password ───────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _sendPasswordReset,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Nie pamiętam hasła',
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Error ─────────────────────────────────────────
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kErrorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kErrorBorder),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: _kFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kErrorText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Submit button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: const Color(0xFF052E28),
                          disabledBackgroundColor: _kAccent.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF052E28)),
                                ),
                              )
                            : Text(
                                _isLogin ? 'Zaloguj się' : 'Zarejestruj się',
                                style: const TextStyle(
                                  fontFamily: _kFont,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Toggle login / register ──────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin ? 'Nie masz konta? ' : 'Masz już konto? ',
                          style: const TextStyle(
                            fontFamily: _kFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _kWhite70,
                          ),
                        ),
                        GestureDetector(
                          onTap: _loading ? null : () => setState(() {
                            _isLogin = !_isLogin;
                            _error = null;
                          }),
                          child: Text(
                            _isLogin ? 'Zarejestruj się' : 'Zaloguj się',
                            style: const TextStyle(
                              fontFamily: _kFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Reusable widgets
// ═════════════════════════════════════════════════════════════════════════════

/// Frosted-glass-style text field on the gradient background.
class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      enabled: enabled,
      style: const TextStyle(
        fontFamily: _kFont,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _kWhite,
      ),
      cursorColor: _kAccent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: _kFont,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _kWhite40,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: _kWhite40, size: 20)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _kWhite08,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _kWhite15),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _kWhite08),
        ),
      ),
    );
  }
}

/// Social sign-in button with scale-on-tap micro-animation.
class _SocialButton extends StatefulWidget {
  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => _anim.forward(),
      onTapUp: disabled ? null : (_) {
        _anim.reverse();
        widget.onPressed!();
      },
      onTapCancel: () => _anim.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final scale = 1.0 - (_anim.value * 0.03);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.icon,
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
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

// ── Google "G" icon ─────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final p = Paint()..style = PaintingStyle.fill;

    p.color = const Color(0xFF4285F4);
    canvas.drawPath(Path()
      ..moveTo(22.56*s, 12.25*s)..cubicTo(22.56*s,11.47*s,22.49*s,10.72*s,22.36*s,10*s)
      ..lineTo(12*s,10*s)..lineTo(12*s,14.26*s)..lineTo(17.92*s,14.26*s)
      ..cubicTo(17.66*s,15.63*s,16.88*s,16.79*s,15.71*s,17.57*s)
      ..lineTo(15.71*s,20.34*s)..lineTo(19.28*s,20.34*s)
      ..cubicTo(21.36*s,18.42*s,22.56*s,15.6*s,22.56*s,12.25*s)..close(), p);

    p.color = const Color(0xFF34A853);
    canvas.drawPath(Path()
      ..moveTo(12*s,23*s)..cubicTo(14.97*s,23*s,17.46*s,22.02*s,19.28*s,20.34*s)
      ..lineTo(15.71*s,17.57*s)..cubicTo(14.73*s,18.23*s,13.48*s,18.63*s,12*s,18.63*s)
      ..cubicTo(9.14*s,18.63*s,6.71*s,16.7*s,5.84*s,14.1*s)
      ..lineTo(2.18*s,14.1*s)..lineTo(2.18*s,16.94*s)
      ..cubicTo(3.99*s,20.53*s,7.7*s,23*s,12*s,23*s)..close(), p);

    p.color = const Color(0xFFFBBC05);
    canvas.drawPath(Path()
      ..moveTo(5.84*s,14.1*s)..cubicTo(5.62*s,13.44*s,5.49*s,12.74*s,5.49*s,12*s)
      ..cubicTo(5.49*s,11.26*s,5.62*s,10.56*s,5.84*s,9.9*s)
      ..lineTo(5.84*s,7.07*s)..lineTo(2.18*s,7.07*s)
      ..cubicTo(1.43*s,8.55*s,1*s,10.22*s,1*s,12*s)
      ..cubicTo(1*s,13.78*s,1.43*s,15.45*s,2.18*s,16.94*s)
      ..lineTo(5.84*s,14.1*s)..close(), p);

    p.color = const Color(0xFFEA4335);
    canvas.drawPath(Path()
      ..moveTo(12*s,5.38*s)..cubicTo(13.62*s,5.38*s,15.06*s,5.94*s,16.21*s,7.02*s)
      ..lineTo(19.36*s,3.87*s)..cubicTo(17.45*s,2.09*s,14.97*s,1*s,12*s,1*s)
      ..cubicTo(7.7*s,1*s,3.99*s,3.47*s,2.18*s,7.07*s)
      ..lineTo(5.84*s,9.9*s)..cubicTo(6.71*s,7.3*s,9.14*s,5.38*s,12*s,5.38*s)
      ..close(), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Apple icon ──────────────────────────────────────────────────────────────
class _AppleIcon extends StatelessWidget {
  const _AppleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 20,
      child: CustomPaint(painter: _ApplePainter()),
    );
  }
}

class _ApplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    final p = Paint()
      ..style = PaintingStyle.fill
      ..color = _kWhite;

    canvas.drawPath(Path()
      ..moveTo(12.152*sx, 6.896*sy)
      ..cubicTo(11.204*sx,6.896*sy, 9.737*sx,5.818*sy, 8.192*sx,5.856*sy)
      ..cubicTo(6.152*sx,5.883*sy, 4.282*sx,7.039*sy, 3.231*sx,8.87*sy)
      ..cubicTo(1.114*sx,12.545*sy, 2.685*sx,17.973*sy, 4.75*sx,20.96*sy)
      ..cubicTo(5.763*sx,22.414*sy, 6.958*sx,24.05*sy, 8.542*sx,23.999*sy)
      ..cubicTo(10.062*sx,23.934*sy, 10.632*sx,23.012*sy, 12.477*sx,23.012*sy)
      ..cubicTo(14.308*sx,23.012*sy, 14.827*sx,23.999*sy, 16.437*sx,23.96*sy)
      ..cubicTo(18.074*sx,23.934*sy, 19.113*sx,22.48*sy, 20.113*sx,21.012*sy)
      ..cubicTo(21.269*sx,19.324*sy, 21.749*sx,17.687*sy, 21.775*sx,17.597*sy)
      ..cubicTo(21.736*sx,17.584*sy, 18.593*sx,16.376*sy, 18.555*sx,12.74*sy)
      ..cubicTo(18.529*sx,9.7*sy, 21.035*sx,8.246*sy, 21.152*sx,8.181*sy)
      ..cubicTo(19.723*sx,6.091*sy, 17.529*sx,5.857*sy, 16.762*sx,5.805*sy)
      ..cubicTo(14.762*sx,5.649*sy, 13.087*sx,6.896*sy, 12.152*sx,6.896*sy)
      ..close(), p);

    canvas.drawPath(Path()
      ..moveTo(15.53*sx, 3.83*sy)
      ..cubicTo(16.373*sx,2.818*sy, 16.93*sx,1.403*sy, 16.775*sx,0*sy)
      ..cubicTo(15.568*sx,0.052*sy, 14.113*sx,0.805*sy, 13.243*sx,1.818*sy)
      ..cubicTo(12.463*sx,2.714*sy, 11.789*sx,4.156*sy, 11.97*sx,5.532*sy)
      ..cubicTo(13.308*sx,5.636*sy, 14.685*sx,4.844*sy, 15.53*sx,3.83*sy)
      ..close(), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}


