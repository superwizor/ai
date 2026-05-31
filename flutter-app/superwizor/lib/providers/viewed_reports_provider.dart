// ViewedReportsProvider — tracks which completed session reports the
// therapist has already opened. Used to auto-dismiss the "Raport gotowy"
// badge after the first view.
//
// Stored locally in SharedPreferences as a JSON list of session IDs.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'current_user_provider.dart';

class ViewedReportsNotifier extends Notifier<Set<String>> {
  static const _keyPrefix = 'viewed_reports_';

  @override
  Set<String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_keyPrefix${user.id}');
    if (raw != null) {
      state = raw.toSet();
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_keyPrefix${user.id}', state.toList());
  }

  bool isViewed(String sessionId) => state.contains(sessionId);

  Future<void> markViewed(String sessionId) async {
    if (state.contains(sessionId)) return;
    state = {...state, sessionId};
    await _save();
  }
}

final viewedReportsProvider =
    NotifierProvider<ViewedReportsNotifier, Set<String>>(
  ViewedReportsNotifier.new,
);
