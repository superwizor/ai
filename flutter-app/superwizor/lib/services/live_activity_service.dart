// LiveActivityService — bridges Flutter to native iOS Live Activities
// and Android AppWidgets via a shared MethodChannel.
//
// The native side (AppDelegate.swift / MainActivity.kt) handles
// platform-specific ActivityKit / AppWidgetManager calls. This service
// just dispatches state transitions over the channel.
//
// All methods are fire-and-forget — if the channel throws (e.g. on
// web or simulator without the extension), we log and move on.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents the current session state pushed to the native widget.
enum LiveActivityStatus {
  recording,
  paused,
  interrupted,
  uploading,
  analyzing,
  reportReady,
}

class LiveActivityService {
  LiveActivityService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('ai.superwizor/live_activity');

  final MethodChannel _channel;

  // ── Phase tracking for resume observer ─────────────────────────
  //
  // When the user resumes the app, the _LiveActivityResumeObserver
  // checks this flag. It only stops the Live Activity if the report
  // has arrived (so we don't kill it during recording or processing).
  static bool _reportReadyReceived = false;

  /// Whether the resume observer should dismiss the Live Activity.
  /// Checks BOTH the Dart-side flag (set by foreground push or cascade)
  /// AND the native ActivityKit state (set by background push in
  /// AppDelegate). This covers all cases including warm resume after
  /// a background push.
  static Future<bool> shouldDismissOnResume() async {
    // Fast path: Dart-side flag was already set
    if (_reportReadyReceived) return true;

    // Slow path: check native ActivityKit state. The background push
    // handler in AppDelegate may have updated the Live Activity to
    // report_ready without Dart knowing about it.
    const channel = MethodChannel('ai.superwizor/live_activity');
    try {
      final result = await channel.invokeMethod<bool>('isReportReady');
      return result ?? false;
    } catch (e) {
      debugPrint('[live-activity] isReportReady check failed: $e');
      return false;
    }
  }

  /// Start a new Live Activity / AppWidget for the given session.
  Future<void> start({
    required String patientAlias,
    required int elapsedSeconds,
  }) async {
    _reportReadyReceived = false; // New session — reset dismiss flag
    try {
      await _channel.invokeMethod('start', {
        'patientAlias': patientAlias,
        'elapsedSeconds': elapsedSeconds,
      });
    } catch (e) {
      debugPrint('[live-activity] start failed (ignored): $e');
    }
  }

  /// Update the Live Activity with new state.
  Future<void> update({
    required LiveActivityStatus status,
    required int elapsedSeconds,
  }) async {
    try {
      await _channel.invokeMethod('update', {
        'status': status.name,
        'elapsedSeconds': elapsedSeconds,
      });
    } catch (e) {
      debugPrint('[live-activity] update failed (ignored): $e');
    }
  }

  /// Transition the widget to "Report Ready" state with a deep link
  /// to the specific session's report.
  /// [reportCount] > 1 shows a badge with the count and
  /// "Nowe raporty czekają w kartotece" instead of single-report copy.
  Future<void> showReportReady({
    required String sessionId,
    int reportCount = 1,
  }) async {
    _reportReadyReceived = true; // Enable dismiss on resume
    try {
      await _channel.invokeMethod('reportReady', {
        'sessionId': sessionId,
        'reportCount': reportCount,
      });
    } catch (e) {
      debugPrint('[live-activity] reportReady failed (ignored): $e');
    }
  }

  /// End the Live Activity / dismiss the AppWidget.
  Future<void> stop() async {
    _reportReadyReceived = false; // Reset on explicit stop
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[live-activity] stop failed (ignored): $e');
    }
  }

  /// Check whether the OS-level Live Activities permission is enabled.
  /// On iOS this reflects Settings → [App] → Live Activities toggle.
  /// On Android returns true (no system-level toggle for widgets).
  Future<bool> isSystemEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermission');
      return result ?? true;
    } catch (e) {
      debugPrint('[live-activity] checkPermission failed (ignored): $e');
      return true; // Assume enabled if channel doesn't exist.
    }
  }

  /// Open the OS settings page for this app (iOS only).
  /// On Android this is a no-op.
  Future<void> openSystemSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (e) {
      debugPrint('[live-activity] openSettings failed (ignored): $e');
    }
  }

  // ── Static helpers for lifecycle contexts ────────────────────────

  /// Dismiss any lingering Live Activity. Called from:
  ///   - onMessageOpenedApp (user tapped push → about to see the report)
  ///   - _LiveActivityResumeObserver (user opened app after report arrived)
  ///
  /// NOTE: Background isolate Live Activity updates are handled NATIVELY
  /// in AppDelegate.swift — MethodChannel is not available from bg isolates.
  static Future<void> stopFromBackground() async {
    _reportReadyReceived = false;
    const channel = MethodChannel('ai.superwizor/live_activity');
    try {
      await channel.invokeMethod('stop');
      debugPrint('[live-activity] stopped from background/resume');
    } catch (e) {
      debugPrint('[live-activity] bg stop failed (ignored): $e');
    }
  }

  /// Mark that a report is ready (called by native side via AppDelegate).
  /// This enables the resume observer to dismiss the widget.
  static void markReportReady() {
    _reportReadyReceived = true;
  }
}
