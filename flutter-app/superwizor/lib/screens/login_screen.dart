import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_text_field.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
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
