// delete_account_screen.dart
//
// Flow:
//   1. Ekran (slide from right) — tytuł "Usuń konto" + lista konsekwencji
//   2. Na dole sticky: wiersz "Rozumiem konsekwencje..." + toggle
//      → gdy toggle ON → przycisk "Usuń moje konto" aktywny
//   3. Kliknięcie aktywnego przycisku → bottom sheet z polem "USUWAM"
//      → po wpisaniu "USUWAM" przycisk aktywny → firebase delete

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/euphire_theme.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _understands = false;

  Future<void> _onDeletePressed() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ConfirmDeleteSheet(),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back + Title ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: EuphireColors.frostWhite, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Text(
                  'Usuń konto',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ),

              // ── Lista konsekwencji ────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _ConsequenceItem(
                        'Całą dokumentację kliniczną — wszystkich pacjentów, kartoteki, sesje i raporty AI — zostanie trwale usunięta.',
                      ),
                      SizedBox(height: 20),
                      _ConsequenceItem(
                        'Twoja subskrypcja (jeśli ją posiadasz) nie zostanie automatycznie anulowana. Musisz ją anulować osobno w App Store lub Google Play.',
                      ),
                      SizedBox(height: 20),
                      _ConsequenceItem(
                        'Nie będziesz mógł odzyskać danych po zakończeniu tego procesu. Operacja jest nieodwracalna.',
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stopka sticky: toggle + przycisk ─────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wiersz toggle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Rozumiem konsekwencje\ni chcę usunąć konto',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: EuphireColors.magma,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _understands,
                          onChanged: (v) => setState(() => _understands = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: EuphireColors.magma,
                          inactiveThumbColor: EuphireColors.mist,
                          inactiveTrackColor: EuphireColors.mist.withValues(alpha: 0.2),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Przycisk — aktywny gdy toggle ON
                    AnimatedOpacity(
                      opacity: _understands ? 1.0 : 0.35,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _understands ? _onDeletePressed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EuphireColors.magma,
                            disabledBackgroundColor: EuphireColors.magma,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Usuń moje konto',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wiersz z czerwoną ikonką check ──────────────────────────

class _ConsequenceItem extends StatelessWidget {
  final String text;
  const _ConsequenceItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EuphireColors.magma,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 15,
              color: EuphireColors.frostWhite,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Sheet — wpisz USUWAM ─────────────────────────────

class _ConfirmDeleteSheet extends StatefulWidget {
  const _ConfirmDeleteSheet();

  @override
  State<_ConfirmDeleteSheet> createState() => _ConfirmDeleteSheetState();
}

class _ConfirmDeleteSheetState extends State<_ConfirmDeleteSheet> {
  final _ctrl = TextEditingController();
  bool _confirmed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim() == 'USUWAM';
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_confirmed) return;
    setState(() => _deleting = true);
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      if (e.code == 'requires-recent-login') {
        Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zaloguj się ponownie, by usunąć konto.'),
            backgroundColor: Colors.red,
          ),
        );
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Przesuwa sheet nad klawiaturę
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),

                // Ikona
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.magma.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: EuphireColors.magma.withValues(alpha: 0.3),
                        blurRadius: 28, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: EuphireColors.magma, size: 32),
                ),
                const SizedBox(height: 16),

                Text(
                  'Ostatni krok.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aby potwierdzić, wpisz:',
                  style: theme.textTheme.bodyMedium?.copyWith(color: EuphireColors.mist),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'USUWAM',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'RobotoMono',
                    color: EuphireColors.magma,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),

                // Pole tekstowe
                TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  autofocus: true,
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
                      fontFamily: 'RobotoMono', fontSize: 14,
                      color: EuphireColors.mist.withValues(alpha: 0.4),
                      letterSpacing: 1,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
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
                        horizontal: 20, vertical: 16),
                    suffixIcon: _confirmed
                        ? const Icon(Icons.check_circle,
                            color: EuphireColors.magma, size: 22)
                        : null,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 20),

                // Przycisk
                AnimatedOpacity(
                  opacity: _confirmed ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _confirmed && !_deleting ? _delete : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EuphireColors.magma,
                        disabledBackgroundColor: EuphireColors.magma,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _deleting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'USUWAM KONTO',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Anuluj.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
