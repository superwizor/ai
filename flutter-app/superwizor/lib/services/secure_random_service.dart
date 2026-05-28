// F-06: Hardware-backed CSPRNG service.
//
// Provides cryptographically secure random bytes from the platform's
// hardware random number generator:
//   - iOS: SecRandomCopyBytes (Secure Enclave)
//   - Android: java.security.SecureRandom (Linux kernel CSPRNG + HWRNG)
//
// Falls back gracefully to Dart's Random.secure() if the MethodChannel
// call fails (e.g. on web, desktop, or old plugin registrations).
// Dart's Random.secure() uses /dev/urandom which is also a CSPRNG —
// the native path is a defense-in-depth measure, not a hard requirement.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecureRandomService {
  SecureRandomService._();
  static final instance = SecureRandomService._();

  static const _channel = MethodChannel('ai.superwizor/secure_random');

  /// Returns [length] cryptographically secure random bytes.
  ///
  /// Tries the native hardware RNG first (SecRandomCopyBytes on iOS,
  /// SecureRandom on Android). On failure, falls back to Dart's
  /// `Random.secure()` which is also a CSPRNG but may not use the
  /// hardware entropy source directly.
  Future<Uint8List> getRandomBytes(int length) async {
    assert(length > 0 && length <= 256);
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'getRandomBytes',
        {'length': length},
      );
      if (result != null && result.length == length) {
        return result;
      }
    } catch (e) {
      // MethodChannel not available (web, desktop, tests) or plugin
      // not registered. Fall through to Dart CSPRNG.
      if (kDebugMode) {
        debugPrint('[secure-random] native RNG unavailable, using Dart '
            'fallback: $e');
      }
    }

    // Fallback: Dart's Random.secure() — still a CSPRNG, just not
    // guaranteed to be hardware-backed on all Android devices.
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
