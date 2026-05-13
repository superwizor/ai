// settings_provider.dart — Stan preferencji użytkownika (Superwizor AI)
//
// Riverpod 3 — używa Notifier + NotifierProvider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── State ────────────────────────────────────────────────────

class AppSettingsState {
  final bool soundEnabled;
  final bool hapticsEnabled;

  const AppSettingsState({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  AppSettingsState copyWith({bool? soundEnabled, bool? hapticsEnabled}) {
    return AppSettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() {
    _load();
    return const AppSettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettingsState(
      soundEnabled: prefs.getBool('sw_soundEnabled') ?? true,
      hapticsEnabled: prefs.getBool('sw_hapticsEnabled') ?? true,
    );
  }

  Future<void> toggleSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sw_soundEnabled', value);
    state = state.copyWith(soundEnabled: value);
  }

  Future<void> toggleHaptics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sw_hapticsEnabled', value);
    state = state.copyWith(hapticsEnabled: value);
  }
}

// ─── Provider ─────────────────────────────────────────────────

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
  AppSettingsNotifier.new,
);
