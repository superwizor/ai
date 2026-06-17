import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool liveActivitiesEnabled;
  final bool hasSeenLiveActivitiesPrompt;

  const AppSettings({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.liveActivitiesEnabled = false,
    this.hasSeenLiveActivitiesPrompt = false,
  });

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? liveActivitiesEnabled,
    bool? hasSeenLiveActivitiesPrompt,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      liveActivitiesEnabled: liveActivitiesEnabled ?? this.liveActivitiesEnabled,
      hasSeenLiveActivitiesPrompt: hasSeenLiveActivitiesPrompt ?? this.hasSeenLiveActivitiesPrompt,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _keyLiveActivities = 'live_activities_enabled';
  static const _keyLiveActivitiesPrompt = 'live_activities_prompt_seen';

  @override
  AppSettings build() {
    _loadFromPrefs();
    return const AppSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      liveActivitiesEnabled: prefs.getBool(_keyLiveActivities) ?? false,
      hasSeenLiveActivitiesPrompt: prefs.getBool(_keyLiveActivitiesPrompt) ?? false,
    );
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
  }

  void toggleHaptics(bool value) {
    state = state.copyWith(hapticsEnabled: value);
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
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
