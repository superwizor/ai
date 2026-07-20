// Runtime debug flag for simulation methods.
//
// Unlike kDebugMode (compile-time constant, always false in release),
// this flag can be toggled at runtime via the 7-tap gesture on the
// "Superwizor AI" logo. This lets TestFlight testers exercise the
// debug simulations without requiring a debug build.
//
// Defaults to false — only set to true by the 7-tap gesture handler
// in home_screen.dart. Resets on app restart (not persisted).

class DebugFlags {
  DebugFlags._();

  /// Whether debug simulation methods (debugInjectRow, debugInjectSession,
  /// etc.) should execute. Toggled by the 7-tap logo gesture.
  static bool simulationsEnabled = false;

  /// Custom reminder interval in seconds for debugging/testing.
  /// If > 0, overrides the normal minutes-based reminder interval.
  static int debugReminderIntervalSeconds = 0;
}
