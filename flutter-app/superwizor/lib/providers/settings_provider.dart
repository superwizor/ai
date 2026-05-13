import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  final bool soundEnabled;
  final bool hapticsEnabled;

  const AppSettings({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
  }

  void toggleHaptics(bool value) {
    state = state.copyWith(hapticsEnabled: value);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
