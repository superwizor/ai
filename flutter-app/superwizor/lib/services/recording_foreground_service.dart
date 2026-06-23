// RecordingForegroundService — Dart side of the `superwizor/recording_fgs`
// MethodChannel (android/.../RecordingForegroundService.kt, docs/28 WS5).
//
// Starts/stops a microphone foreground service so Android won't kill the
// app while it's backgrounded during a phone call mid-recording. The
// `record` plugin manages audio focus but NOT a foreground service, so
// without this an extended backgrounding can terminate the process and
// lose the in-progress recording.
//
// iOS / web: the channel doesn't exist (iOS uses UIBackgroundModes:audio
// instead) — every call no-ops. All calls are best-effort and never
// throw, so a foreground-service hiccup can never abort a recording.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RecordingForegroundService {
  static const MethodChannel _channel =
      MethodChannel('superwizor/recording_fgs');

  @visibleForTesting
  static bool debugOverrideSupported = false;

  static bool get _supported => debugOverrideSupported || (!kIsWeb && Platform.isAndroid);

  /// Brings up the foreground service with a localized persistent
  /// notification. [title]/[body] come from the l10n pipeline so the
  /// notification respects the user's locale; the native side has
  /// Polish-primary fallbacks if they're null.
  static Future<void> start({String? title, String? body}) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('start', {'title': title, 'body': body});
    } catch (e) {
      debugPrint('[recording-fgs] start failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[recording-fgs] stop failed: $e');
    }
  }

  /// Update the notification text without restarting the service.
  /// Used when the session transitions from recording → uploading →
  /// analyzing → done.
  static Future<void> updateStatus({String? title, String? body}) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('update', {'title': title, 'body': body});
    } catch (e) {
      debugPrint('[recording-fgs] update failed: $e');
    }
  }
}
