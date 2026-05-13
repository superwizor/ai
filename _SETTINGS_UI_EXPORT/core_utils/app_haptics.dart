import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/core/providers/settings_provider.dart';

/// Centralized Haptic Feedback utility using native Flutter platform channels.
/// Usage: AppHaptics.lightImpact(ref);
class AppHaptics {
  /// Ensure we checked hardware at least once.
  /// Deprecated logic - HapticFeedback from flutter/services does not require explicit init.
  static Future<void> init() async {}

  /// Light click for UI selection, switches, and navigation.
  static void lightImpact(WidgetRef ref) {
    if (_shouldHaptic(ref)) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium click for primary actions (Like/Dislike buttons).
  static void mediumImpact(WidgetRef ref) {
    if (_shouldHaptic(ref)) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact for significant events.
  static void heavyImpact(WidgetRef ref) {
    if (_shouldHaptic(ref)) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Rhythmic card-reveal haptic - two-impulse pattern like turning a page.
  /// Modified to a heavier "Card Snap" for a stronger, more satisfying tactile feel on iOS.
  static void cardReveal(WidgetRef? ref) async {
    if (_shouldHaptic(ref)) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      HapticFeedback.mediumImpact();
    }
  }

  /// Click feedback for primary buttons and main actions
  static void buttonPress(WidgetRef? ref) {
    if (_shouldHaptic(ref)) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Double-tap error haptic - signals failure (wrong code, network error, etc.).
  /// Changed to double heavy impact for clear interruption sense.
  static void error(WidgetRef? ref) async {
    if (_shouldHaptic(ref)) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 120));
      HapticFeedback.heavyImpact();
    }
  }

  /// Success haptic - signals positive completion (e.g., Daily Spark done, Quiz answered).
  /// Upgraded to a "Tada" effect: medium then heavy finish.
  static void success(WidgetRef? ref) async {
    if (_shouldHaptic(ref)) {
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();
    }
  }

  /// Warning haptic - signals destructive actions, error states, or blocking operations.
  static void warning(WidgetRef? ref) {
    if (_shouldHaptic(ref)) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Helper to verify user permissions and web conditions
  static bool _shouldHaptic(WidgetRef? ref) {
    if (ref != null) {
      final settings = ref.read(settingsProvider);
      if (!settings.hapticsEnabled) return false;
    }

    // We can technically use HapticFeedback on web if browsers support it,
    // but typically it's ignored. We return true and let flutter/services handle it.
    return true;
  }
}
