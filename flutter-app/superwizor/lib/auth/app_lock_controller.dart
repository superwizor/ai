// App-lock — biometric / device-passcode gate in front of a signed-in
// session (docs: persistent-login mitigation, DPIA D-1).
//
// Firebase Auth persists the session across app restarts (good UX), but for a
// clinical PHI app an unlocked, unattended device would expose patient data.
// This controller keeps the silent session and instead requires a Face ID /
// Touch ID / Android biometric (with device-passcode fallback) to *view* it:
//
//   - locked on every cold launch (the gate shows LockScreen until unlocked),
//   - re-locked when the app has been in the background longer than
//     [inactivityTimeout].
//
// Scope (v1): mobile only. On web/desktop the provider stays unlocked — the
// biometric APIs aren't available there; a web re-auth/timeout is a follow-up.
// If the device has no biometric AND no passcode enrolled we don't trap the
// user (we unlock) — there's nothing to authenticate against.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Whether the app-lock applies on this platform (mobile only for now).
bool get appLockSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// Result of an unlock attempt — richer than a bare bool so the UI can
/// show appropriate feedback.
enum UnlockResult {
  /// Biometric / passcode succeeded — app is now unlocked.
  success,

  /// User explicitly cancelled the prompt (tapped "Cancel").
  cancelled,

  /// Device has no biometric or passcode enrolled — auto-unlocked.
  unsupported,

  /// Authentication failed (wrong face, wrong fingerprint, lockout, etc.).
  failed,

  /// Another unlock attempt is already in progress.
  alreadyInProgress,
}

/// `true` == locked (show the LockScreen), `false` == unlocked.
class AppLockController extends Notifier<bool> {
  /// Re-lock once the app has been backgrounded at least this long. Short
  /// enough to protect an unattended phone, long enough to survive a quick
  /// app-switch / incoming notification.
  static const Duration inactivityTimeout = Duration(seconds: 60);

  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _backgroundedAt;
  _LockLifecycleObserver? _observer;
  bool _unlocking = false;

  @override
  bool build() {
    if (!appLockSupported) return false; // web/desktop: never locked (v1)

    _observer = _LockLifecycleObserver(
      onBackground: _onBackground,
      onResume: _onResume,
    );
    WidgetsBinding.instance.addObserver(_observer!);
    ref.onDispose(() {
      final o = _observer;
      if (o != null) WidgetsBinding.instance.removeObserver(o);
    });

    return true; // start locked on cold launch
  }

  void _onBackground() {
    _backgroundedAt ??= DateTime.now();
  }

  void _onResume() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (state) return; // already locked
    if (since != null &&
        DateTime.now().difference(since) >= inactivityTimeout) {
      // Breadcrumb for "Face ID out of nowhere" reports: says exactly
      // when and why the mid-session relock engaged.
      debugPrint('[app-lock] relock on resume — backgrounded '
          '${DateTime.now().difference(since).inSeconds}s '
          '(threshold ${inactivityTimeout.inSeconds}s)');
      state = true;
    }
  }

  /// Runs the platform biometric / device-passcode prompt. Unlocks on success.
  /// Returns a detailed [UnlockResult] so the UI can react accordingly.
  Future<UnlockResult> unlock(String localizedReason) async {
    // Guard against concurrent unlock attempts (e.g. widget rebuild during
    // an active biometric dialog).
    if (_unlocking) return UnlockResult.alreadyInProgress;
    _unlocking = true;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        // No biometric/passcode enrolled — nothing to gate against; don't
        // lock the user out of their own data.
        state = false;
        return UnlockResult.unsupported;
      }
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        // Survive the OS auth UI momentarily backgrounding the app.
        persistAcrossBackgrounding: true,
        // biometricOnly:false (default) → allow the device passcode fallback.
      );
      if (ok) {
        _backgroundedAt = null; // K5: Prevent double-prompt if OS fires onResume late
        state = false;
        return UnlockResult.success;
      }
      return UnlockResult.cancelled;
    } catch (_) {
      // Cancelled / no hardware / lockout — stay locked, let the user retry.
      return UnlockResult.failed;
    } finally {
      _unlocking = false;
    }
  }

  /// Force the lock (e.g. an explicit "lock now" affordance).
  void lock() {
    if (appLockSupported) state = true;
  }
}

class _LockLifecycleObserver extends WidgetsBindingObserver {
  _LockLifecycleObserver({required this.onBackground, required this.onResume});

  final VoidCallback onBackground;
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    switch (s) {
      // Only true backgrounding — NOT `inactive`, which fires when the OS
      // biometric overlay appears and would otherwise re-lock mid-unlock.
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        onBackground();
      case AppLifecycleState.resumed:
        onResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);
