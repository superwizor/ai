// delete_account_screen.dart — Pełnoekranowy flow usuwania konta
//
// Flow:
//   1. Strona ostrzeżenia (ikona + lista co użytkownik utraci)
//   2. Pole tekstowe "wpisz USUWAM" aby aktywować przycisk
//   3. Przycisk czerwony — wywołuje delete konta w Firebase
//
// Nawigacja: push jako fullscreenDialog (MaterialPageRoute z fullscreenDialog: true)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/euphire_theme.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _confirmed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim() == 'USUWAM';
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_confirmed) return;
    setState(() => _deleting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();
      // Konto usunięte — Firebase Auth wyloguje automatycznie
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      if (e.code == 'requires-recent-login') {
        _showReauthDialog();
      } else {
        _showError('Nie udało się usunąć konta: ${e.message}');
      }
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showReauthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EuphireColors.nocturne,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Wymagane ponowne logowanie',
            style: const TextStyle(fontFamily: 'Montserrat', color: EuphireColors.frostWhite)),
        content: Text(
          'Ze względów bezpieczeństwa musisz się wylogować i zalogować ponownie, aby usunąć konto.',
          style: TextStyle(fontFamily: 'Merriweather', color: EuphireColors.mist, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Wyloguj i zaloguj się ponownie',
                style: TextStyle(color: EuphireColors.ember)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: EuphireColors.magma),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration: const BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: EuphireColors.frostWhite),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // Ikona ostrzeżenia
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EuphireColors.magma.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: EuphireColors.magma.withValues(alpha: 0.25),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: EuphireColors.magma,
                          size: 44,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        'Usuwasz konto bezpowrotnie.',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFamily: 'Merriweather',
                          fontStyle: FontStyle.italic,
                          color: EuphireColors.frostWhite,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Ta operacja jest nieodwracalna. Nie można jej cofnąć.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: EuphireColors.magma,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Lista co się stanie
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: EuphireColors.magma.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: EuphireColors.magma.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Po usunięciu konta bezpowrotnie utracisz:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: EuphireColors.frostWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._lossItems.map((item) => _LossItem(
                              icon: item.$1,
                              text: item.$2,
                            )),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Separator
                      Divider(color: EuphireColors.mist.withValues(alpha: 0.2)),

                      const SizedBox(height: 24),

                      Text(
                        'Aby potwierdzić, wpisz poniżej słowo:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: EuphireColors.mist,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'USUWAM',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: 'RobotoMono',
                          color: EuphireColors.magma,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Pole tekstowe
                      TextField(
                        controller: _controller,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.frostWhite,
                          letterSpacing: 3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'wpisz tutaj…',
                          hintStyle: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 14,
                            color: EuphireColors.mist.withValues(alpha: 0.4),
                            letterSpacing: 1,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _confirmed
                                  ? EuphireColors.magma
                                  : EuphireColors.mist.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          suffixIcon: _confirmed
                              ? const Icon(Icons.check_circle,
                                  color: EuphireColors.magma, size: 22)
                              : null,
                        ),
                        autocorrect: false,
                        enableSuggestions: false,
                      ),

                      const SizedBox(height: 32),

                      // Przycisk Usuwam
                      AnimatedOpacity(
                        opacity: _confirmed ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 200),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _confirmed && !_deleting ? _deleteAccount : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EuphireColors.magma,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: EuphireColors.magma.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _deleting
                                ? const SizedBox(width: 24, height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text(
                                    'USUWAM KONTO BEZPOWROTNIE',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Anuluj — chcę zachować konto.',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: EuphireColors.mist.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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

// ─── Lista strat ──────────────────────────────────────────────

const _lossItems = [
  (Icons.folder_off_outlined, 'Całą dokumentację kliniczną — wszystkich Twoich pacjentów i ich kartoteki'),
  (Icons.mic_off_outlined, 'Wszystkie nagrania sesji i transkrypcje'),
  (Icons.psychology_outlined, 'Wszystkie raporty AI i pomiary HiTOP'),
  (Icons.cloud_off_outlined, 'Dostęp do konta i historii subskrypcji'),
  (Icons.lock_clock_outlined, 'Dane są usuwane trwale i nie mogą zostać odtworzone'),
];

class _LossItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LossItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EuphireColors.magma, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 13,
                  color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                  height: 1.5,
                )),
          ),
        ],
      ),
    );
  }
}
