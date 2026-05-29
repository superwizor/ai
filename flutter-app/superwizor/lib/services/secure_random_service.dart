// F-06: Hardware-backed CSPRNG service.
//
// Provides cryptographically secure random bytes from the platform's
// hardware random number generator:
//   - iOS: SecRandomCopyBytes (Secure Enclave)
//   - Android: java.security.SecureRandom (Linux kernel CSPRNG + HWRNG)
//   - Web: crypto.getRandomValues (Web Crypto API, hardware-backed)
//
// Falls back gracefully to Dart's Random.secure() if the MethodChannel
// call fails (e.g. on desktop or old plugin registrations).
// Dart's Random.secure() uses /dev/urandom (mobile) or Web Crypto API
// (web), both of which are CSPRNGs — the native path is a
// defense-in-depth measure, not a hard requirement.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecureRandomService {
  SecureRandomService._();
  static final instance = SecureRandomService._();

  static const _channel = MethodChannel('ai.superwizor/secure_random');

  /// Returns [length] cryptographically secure random bytes.
  ///
  /// On Web: uses Dart's Random.secure() directly, which delegates
  /// to Web Crypto API's `crypto.getRandomValues()` — already
  /// hardware-backed in modern browsers. No MethodChannel attempt.
  ///
  /// On mobile: tries the native hardware RNG first (SecRandomCopyBytes
  /// on iOS, SecureRandom on Android). On failure, falls back to
  /// Dart's `Random.secure()`.
  Future<Uint8List> getRandomBytes(int length) async {
    assert(length > 0 && length <= 256);

    // On Web, MethodChannel is unavailable and would always throw
    // MissingPluginException. Skip directly to Random.secure() which
    // uses Web Crypto API's crypto.getRandomValues() under the hood.
    if (kIsWeb) return _dartSecureRandom(length);

    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'getRandomBytes',
        {'length': length},
      ).timeout(const Duration(seconds: 2));
      if (result != null && result.length == length) {
        return result;
      }
    } catch (e) {
      // MethodChannel not available (desktop, tests) or plugin
      // not registered. Fall through to Dart CSPRNG.
      if (kDebugMode) {
        debugPrint('[secure-random] native RNG unavailable, using Dart '
            'fallback: $e');
      }
    }

    return _dartSecureRandom(length);
  }

  /// Dart's Random.secure() — CSPRNG backed by /dev/urandom (mobile)
  /// or Web Crypto API (web).
  Uint8List _dartSecureRandom(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }
}

