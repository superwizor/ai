import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/haptics.dart';

/// Hard ceiling for auto-pause (= the D5 session cap). The configurable value
/// is clamped to [kAutoPauseMinMinutes, kAutoPauseMaxMinutes].
const int kAutoPauseMinMinutes = 30;
const int kAutoPauseMaxMinutes = 180;

class AppSettings {
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool liveActivitiesEnabled;
  final bool hasSeenLiveActivitiesPrompt;

  // ── Recording controls ──
  /// Auto-pause the session once it reaches this elapsed time (minutes).
  /// Clamped to [kAutoPauseMinMinutes, kAutoPauseMaxMinutes]; default 120.
  final int autoPauseMinutes;

  /// "Still recording" reminder cadence in minutes; 0 = off. Default 60.
  final int reminderIntervalMinutes;

  /// Play an audible bell at each reminder. Default false — an audible bell is
  /// captured by the open mic (it lands in the recording/transcript), so the
  /// default reminder is haptic + visual only.
  final bool reminderSound;

  const AppSettings({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.liveActivitiesEnabled = false,
    this.hasSeenLiveActivitiesPrompt = false,
    this.autoPauseMinutes = 120,
    this.reminderIntervalMinutes = 60,
    this.reminderSound = false,
  });

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? liveActivitiesEnabled,
    bool? hasSeenLiveActivitiesPrompt,
    int? autoPauseMinutes,
    int? reminderIntervalMinutes,
    bool? reminderSound,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      liveActivitiesEnabled:
          liveActivitiesEnabled ?? this.liveActivitiesEnabled,
      hasSeenLiveActivitiesPrompt:
          hasSeenLiveActivitiesPrompt ?? this.hasSeenLiveActivitiesPrompt,
      autoPauseMinutes: autoPauseMinutes ?? this.autoPauseMinutes,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      reminderSound: reminderSound ?? this.reminderSound,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _keyLiveActivities = 'live_activities_enabled';
  static const _keyLiveActivitiesPrompt = 'live_activities_prompt_seen';
  static const _keySound = 'sound_enabled';
  static const _keyHaptics = 'haptics_enabled';
  static const _keyAutoPause = 'rec_auto_pause_minutes';
  static const _keyReminder = 'rec_reminder_minutes';
  static const _keyReminderSound = 'rec_reminder_sound';

  @override
  AppSettings build() {
    _loadFromPrefs();
    return const AppSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final sound = prefs.getBool(_keySound) ?? true;
    final haptics = prefs.getBool(_keyHaptics) ?? true;
    AppHapticFeedback.enabled = haptics;
    state = state.copyWith(
      soundEnabled: sound,
      hapticsEnabled: haptics,
      liveActivitiesEnabled: prefs.getBool(_keyLiveActivities) ?? false,
      hasSeenLiveActivitiesPrompt:
          prefs.getBool(_keyLiveActivitiesPrompt) ?? false,
      autoPauseMinutes: (prefs.getInt(_keyAutoPause) ?? 120).clamp(
        kAutoPauseMinMinutes,
        kAutoPauseMaxMinutes,
      ),
      reminderIntervalMinutes: prefs.getInt(_keyReminder) ?? 60,
      reminderSound: prefs.getBool(_keyReminderSound) ?? false,
    );
  }

  Future<void> toggleSound(bool value) async {
    state = state.copyWith(soundEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, value);
  }

  Future<void> toggleHaptics(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, value);
    AppHapticFeedback.enabled = value;
  }

  Future<void> toggleLiveActivities(bool value) async {
    state = state.copyWith(liveActivitiesEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLiveActivities, value);
  }

  Future<void> markLiveActivitiesPromptSeen() async {
    state = state.copyWith(hasSeenLiveActivitiesPrompt: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLiveActivitiesPrompt, true);
  }

  Future<void> setAutoPauseMinutes(int value) async {
    final v = value.clamp(kAutoPauseMinMinutes, kAutoPauseMaxMinutes);
    state = state.copyWith(autoPauseMinutes: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoPause, v);
  }

  Future<void> setReminderIntervalMinutes(int value) async {
    state = state.copyWith(reminderIntervalMinutes: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminder, value);
  }

  Future<void> setReminderSound(bool value) async {
    state = state.copyWith(reminderSound: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderSound, value);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
