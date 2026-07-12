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

  /// Start a new Live Activity / AppWidget for the given session.
  Future<void> start({
    required String patientAlias,
    required int elapsedSeconds,
  }) async {
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
}
