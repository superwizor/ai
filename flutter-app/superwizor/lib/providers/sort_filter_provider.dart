// Sort & filter state for the home screen patient list.
//
// Persisted in SharedPreferences so the therapist's preference
// survives app restarts.
//
// ──────────────────────────────────────────────────────────────────────
// BUG FIX (2026-06): Migrated from synchronous Notifier to AsyncNotifier.
// Same race condition as ViewedReportsNotifier — build() returned a
// default SortFilterState synchronously while _load() ran async.
// On cold start the UI briefly ignored persisted sort preferences.
// ──────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the active patient list is sorted.
enum SortMode {
  /// Most recently active client at top (default).
  lastActivity,

  /// Clients without a session for the longest time at top.
  leastRecent,

  /// Alphabetical by displayed name (firstName + lastName) A → Z.
  alphabetical,

  /// Clients with the most sessions at top.
  mostSessions,
}

/// Immutable snapshot of the current sort & filter config.
class SortFilterState {
  final SortMode sortMode;
  final bool needsAttentionOnly;
  final Set<String> modalityFilter; // empty = show all

  const SortFilterState({
    this.sortMode = SortMode.lastActivity,
    this.needsAttentionOnly = false,
    this.modalityFilter = const {},
  });

  bool get isDefault =>
      sortMode == SortMode.lastActivity &&
      !needsAttentionOnly &&
      modalityFilter.isEmpty;

  SortFilterState copyWith({
    SortMode? sortMode,
    bool? needsAttentionOnly,
    Set<String>? modalityFilter,
  }) {
    return SortFilterState(
      sortMode: sortMode ?? this.sortMode,
      needsAttentionOnly: needsAttentionOnly ?? this.needsAttentionOnly,
      modalityFilter: modalityFilter ?? this.modalityFilter,
    );
  }
}

// ── SharedPreferences keys ───────────────────────────────────────────

const _kSortMode = 'sort_filter_sort_mode';
const _kNeedsAttention = 'sort_filter_needs_attention';
const _kModalities = 'sort_filter_modalities';

// ── Notifier (AsyncNotifier — awaits SharedPreferences in build) ─────

class SortFilterNotifier extends AsyncNotifier<SortFilterState> {
  @override
  Future<SortFilterState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_kSortMode) ?? 0;
    final attention = prefs.getBool(_kNeedsAttention) ?? false;
    final modalities = prefs.getStringList(_kModalities) ?? [];
    return SortFilterState(
      sortMode: SortMode.values[modeIndex.clamp(0, SortMode.values.length - 1)],
      needsAttentionOnly: attention,
      modalityFilter: modalities.toSet(),
    );
  }

  Future<void> _persist() async {
    final current = state.value ?? const SortFilterState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSortMode, current.sortMode.index);
    await prefs.setBool(_kNeedsAttention, current.needsAttentionOnly);
    await prefs.setStringList(_kModalities, current.modalityFilter.toList());
  }

  void setSortMode(SortMode mode) {
    final current = state.value ?? const SortFilterState();
    state = AsyncData(current.copyWith(sortMode: mode));
    _persist();
  }

  void toggleNeedsAttention() {
    final current = state.value ?? const SortFilterState();
    state = AsyncData(current.copyWith(needsAttentionOnly: !current.needsAttentionOnly));
    _persist();
  }

  void toggleModality(String code) {
    final current = state.value ?? const SortFilterState();
    final updated = Set<String>.from(current.modalityFilter);
    if (updated.contains(code)) {
      updated.remove(code);
    } else {
      updated.add(code);
    }
    state = AsyncData(current.copyWith(modalityFilter: updated));
    _persist();
  }

  void reset() {
    state = const AsyncData(SortFilterState());
    _persist();
  }
}

// ── Provider ─────────────────────────────────────────────────────────

final sortFilterProvider =
    AsyncNotifierProvider<SortFilterNotifier, SortFilterState>(
  SortFilterNotifier.new,
);
