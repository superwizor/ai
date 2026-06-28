// LockScreen — shown by the auth gate when a signed-in session is locked
// (see auth/app_lock_controller.dart). Auto-prompts the platform biometric /
// device passcode on appear; on success the gate rebuilds to the app. A
// "sign out" escape hatch is always available (e.g. biometric lockout, or a
// user who wants to switch accounts).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/app_lock_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on show so the user lands straight on Face ID / passcode.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final reason = AppLocalizations.of(context).appLock_reason;
    await ref.read(appLockProvider.notifier).unlock(reason);
    // On success the gate watches appLockProvider and swaps in the app; this
    // widget is disposed. On failure we just re-enable the button.
    if (mounted) setState(() => _authenticating = false);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: EuphireColors.frostWhite.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: EuphireColors.ember,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l.appLock_title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.appLock_subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 14,
                        height: 1.5,
                        color: EuphireColors.frostWhite.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _authenticating ? null : _unlock,
                        style: FilledButton.styleFrom(
                          backgroundColor: EuphireColors.ember,
                          foregroundColor: EuphireColors.obsidianBlack,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _authenticating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: EuphireColors.obsidianBlack,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded, size: 22),
                        label: Text(
                          l.appLock_unlock,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _signOut,
                      child: Text(
                        l.settings_logout,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: EuphireColors.frostWhite.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
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
