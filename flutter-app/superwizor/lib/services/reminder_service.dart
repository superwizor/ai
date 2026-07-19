import 'package:flutter/services.dart';

/// A native reminder service that delegates time-tracking and sound playback
/// to Swift/Kotlin to bypass Flutter MethodChannel suspension when the iOS
/// main thread is frozen during background recording.
class ReminderService {
  static const _channel = MethodChannel('ai.superwizor/reminder_service');

  static Future<void> start({
    required int intervalMinutes,
    required bool soundEnabled,
    required bool hapticsEnabled,
    required int elapsedMillis,
  }) async {
    await _channel.invokeMethod('start', {
      'intervalMinutes': intervalMinutes,
      'soundEnabled': soundEnabled,
      'hapticsEnabled': hapticsEnabled,
      'elapsedMillis': elapsedMillis,
    });
  }

  static Future<void> pause({required int elapsedMillis}) async {
    await _channel.invokeMethod('pause', {
      'elapsedMillis': elapsedMillis,
    });
  }

  static Future<void> resume({
    required int intervalMinutes,
    required bool soundEnabled,
    required bool hapticsEnabled,
    required int elapsedMillis,
  }) async {
    await _channel.invokeMethod('resume', {
      'intervalMinutes': intervalMinutes,
      'soundEnabled': soundEnabled,
      'hapticsEnabled': hapticsEnabled,
      'elapsedMillis': elapsedMillis,
    });
  }

  static Future<void> update({
    required int intervalMinutes,
    required bool soundEnabled,
    required bool hapticsEnabled,
  }) async {
    await _channel.invokeMethod('update', {
      'intervalMinutes': intervalMinutes,
      'soundEnabled': soundEnabled,
      'hapticsEnabled': hapticsEnabled,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
}
