// PatientAvatarProvider — local SharedPreferences-backed provider
// for managing custom patient avatar labels and colors.
//
// This is a frontend-only feature. The avatar customization is stored
// locally per therapist and does not sync to the backend.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'current_user_provider.dart';

/// Euphire-harmonious avatar colors — tested for WCAG contrast
/// on dark background (#0A2326) with white text.
class AvatarColors {
  AvatarColors._();

  static const List<Color> palette = [
    Color(0xFF2D6068), // Deep Teal (default)
    Color(0xFF004D54), // Evergreen
    Color(0xFF4A8B6E), // Sage
    Color(0xFF8B5E3C), // Ember Warm
    Color(0xFF885553), // Dusk Rose
    Color(0xFF6E4E6A), // Plum
    Color(0xFF3B5998), // Aurora Blue
    Color(0xFF5C6B7A), // Slate
  ];

  static Color fromIndex(int index) =>
      palette[index.clamp(0, palette.length - 1)];
}

/// Data class for a patient's custom avatar config.
class PatientAvatarConfig {
  final String? customLabel; // null = use auto-initials
  final int colorIndex;      // index into AvatarColors.palette

  const PatientAvatarConfig({this.customLabel, this.colorIndex = 0});

  Map<String, dynamic> toJson() => {
        if (customLabel != null) 'label': customLabel,
        'color': colorIndex,
      };

  factory PatientAvatarConfig.fromJson(Map<String, dynamic> json) =>
      PatientAvatarConfig(
        customLabel: json['label'] as String?,
        colorIndex: (json['color'] as int?) ?? 0,
      );

  Color get color => AvatarColors.fromIndex(colorIndex);
}

class PatientAvatarNotifier extends Notifier<Map<String, PatientAvatarConfig>> {
  static const _keyPrefix = 'patient_avatar_';

  @override
  Map<String, PatientAvatarConfig> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix${user.id}');
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(
            k, PatientAvatarConfig.fromJson(v as Map<String, dynamic>)),
      );
      state = map;
    } catch (_) {}
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final map = state.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString('$_keyPrefix${user.id}', jsonEncode(map));
  }

  PatientAvatarConfig getConfig(String patientId) {
    return state[patientId] ?? const PatientAvatarConfig();
  }

  Future<void> setConfig(String patientId, PatientAvatarConfig config) async {
    state = {...state, patientId: config};
    await _save();
  }
}

final patientAvatarProvider =
    NotifierProvider<PatientAvatarNotifier, Map<String, PatientAvatarConfig>>(
  PatientAvatarNotifier.new,
);
