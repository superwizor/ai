import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/grpc_provider.dart';
import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../widgets/euphire_button.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_text_field.dart';
import 'home_screen.dart';

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

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        // Login flow
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );

        // After login, ensure user exists in identity-svc (auto-register if missing)
        await _ensureUserRegistered();
      } else {
        // Registration flow
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );

        // Register user in identity-svc (PostgreSQL)
        await _registerInIdentityService(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: $e');
      setState(() => _error = e.message != null ? '${e.message}.' : 'Wystąpił błąd Firebase.');
    } catch (e) {
      print('General Exception: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
      print('User registered in identity-svc successfully');
    } catch (e) {
      print('Error registering user in identity-svc: $e');
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
      print('User not found in identity-svc, auto-registering...');
      await _registerInIdentityService(firebaseUser);
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(
                  _isLogin ? 'Nie masz konta? Zarejestruj się.' : 'Masz już konto? Zaloguj się.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
