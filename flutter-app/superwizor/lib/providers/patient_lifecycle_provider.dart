// PatientLifecycleProvider — local SharedPreferences-backed provider
// for managing the lifecycle state of patient files (active/completed/archived).
//
// This is a frontend-only feature for now. The lifecycle state is stored
// locally per therapist and does not sync to the backend.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'current_user_provider.dart';

enum PatientLifecycle { active, completed, paused }

class PatientLifecycleNotifier extends Notifier<Map<String, PatientLifecycle>> {
  static const _keyPrefix = 'patient_lifecycle_';

  @override
  Map<String, PatientLifecycle> build() {
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
        (k, v) => MapEntry(k, PatientLifecycle.values.byName(v as String)),
      );
      state = map;
    } catch (_) {}
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final map = state.map((k, v) => MapEntry(k, v.name));
    await prefs.setString('$_keyPrefix${user.id}', jsonEncode(map));
  }

  PatientLifecycle getLifecycle(String patientId) {
    return state[patientId] ?? PatientLifecycle.active;
  }

  Future<void> setLifecycle(String patientId, PatientLifecycle lifecycle) async {
    state = {...state, patientId: lifecycle};
    await _save();
  }
}

final patientLifecycleProvider =
    NotifierProvider<PatientLifecycleNotifier, Map<String, PatientLifecycle>>(
  PatientLifecycleNotifier.new,
);
