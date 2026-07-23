// AudioSessionHelper — thin Dart wrapper over the `superwizor/audio_session`
// MethodChannel (ios/Runner/AudioSessionHelper.swift).
//
// Why this exists (docs/28 WS3): after a phone call ends, iOS leaves our
// AVAudioSession deactivated. The `record` plugin's native resume() is just
// `audioRecorder?.record()` — it neither reactivates the session nor checks
// the call's Bool result, so resuming after a call can silently capture
// nothing. We reactivate the session ourselves before resuming.
//
// Android / web: the channel doesn't exist — calls report "unavailable"
// (treated as best-effort success by callers; the real capture verification
// is RecordingService's file-growth probe, which is platform-neutral).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioSessionHelper {
  static const MethodChannel _channel =
      MethodChannel('superwizor/audio_session');

  /// Re-activates the shared AVAudioSession. Returns false ONLY when the
  /// native side explicitly failed (e.g. `setActive(true)` threw because a
  /// call still owns the session — AVAudioSessionErrorCodeInsufficientPriority).
  /// Missing channel (non-iOS, tests, hot-restart races) returns true so
  /// callers fall through to the capture probe instead of hard-failing.
  static Future<bool> reactivate() async {
    try {
      final ok = await _channel.invokeMethod<bool>('reactivate');
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[audio-session] reactivate failed: ${e.code} ${e.message}');
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Android: AudioManager.getMode() — 0 NORMAL, 1 RINGTONE, 2 IN_CALL,
  /// 3 IN_COMMUNICATION. Android delivers NO recorder pause event on an
  /// incoming call (the mic is silently muted for other apps), so
  /// RecordingService polls this to detect call interruptions itself
  /// (2026-07-23). Missing channel (iOS, tests) returns 0 (= normal).
  static Future<int> getAudioMode() async {
    try {
      final mode = await _channel.invokeMethod<int>('getAudioMode');
      return mode ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }
}
