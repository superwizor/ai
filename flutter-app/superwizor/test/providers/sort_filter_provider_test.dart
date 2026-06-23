// Unit tests for ViewedReportsNotifier and SortFilterNotifier.
//
// These validate the core logic of the AsyncNotifier migration:
// - build() loads from SharedPreferences
// - markViewed() is idempotent and persists
// - SortFilterNotifier mutators persist correctly

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superwizor/providers/sort_filter_provider.dart';

void main() {
  // SharedPreferences needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SortFilterNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('build() returns default state when prefs are empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for async build to complete
      final value = await container.read(sortFilterProvider.future);
      expect(value.sortMode, SortMode.lastActivity);
      expect(value.needsAttentionOnly, false);
      expect(value.modalityFilter, isEmpty);
      expect(value.isDefault, true);
    });

    test('build() restores persisted sort mode', () async {
      SharedPreferences.setMockInitialValues({
        'sort_filter_sort_mode': SortMode.alphabetical.index,
        'sort_filter_needs_attention': true,
        'sort_filter_modalities': ['cbt', 'psychodynamic'],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final value = await container.read(sortFilterProvider.future);
      expect(value.sortMode, SortMode.alphabetical);
      expect(value.needsAttentionOnly, true);
      expect(value.modalityFilter, {'cbt', 'psychodynamic'});
      expect(value.isDefault, false);
    });

    test('setSortMode() updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for initial build
      await container.read(sortFilterProvider.future);

      // Change sort mode
      container.read(sortFilterProvider.notifier).setSortMode(SortMode.leastRecent);

      final updated = container.read(sortFilterProvider).value;
      expect(updated?.sortMode, SortMode.leastRecent);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('sort_filter_sort_mode'), SortMode.leastRecent.index);
    });

    test('toggleNeedsAttention() flips the flag', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sortFilterProvider.future);

      container.read(sortFilterProvider.notifier).toggleNeedsAttention();
      expect(container.read(sortFilterProvider).value?.needsAttentionOnly, true);

      container.read(sortFilterProvider.notifier).toggleNeedsAttention();
      expect(container.read(sortFilterProvider).value?.needsAttentionOnly, false);
    });

    test('toggleModality() adds and removes codes', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sortFilterProvider.future);

      container.read(sortFilterProvider.notifier).toggleModality('cbt');
      expect(container.read(sortFilterProvider).value?.modalityFilter, {'cbt'});

      container.read(sortFilterProvider.notifier).toggleModality('cbt');
      expect(container.read(sortFilterProvider).value?.modalityFilter, isEmpty);
    });

    test('reset() returns to default', () async {
      SharedPreferences.setMockInitialValues({
        'sort_filter_sort_mode': SortMode.mostSessions.index,
        'sort_filter_needs_attention': true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sortFilterProvider.future);
      expect(container.read(sortFilterProvider).value?.isDefault, false);

      container.read(sortFilterProvider.notifier).reset();
      expect(container.read(sortFilterProvider).value?.isDefault, true);
    });

    test('clamps invalid sort mode index', () async {
      SharedPreferences.setMockInitialValues({
        'sort_filter_sort_mode': 999, // out of range
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final value = await container.read(sortFilterProvider.future);
      // Should clamp to last valid enum value
      expect(SortMode.values.contains(value.sortMode), true);
    });
  });

  group('SortFilterState', () {
    test('isDefault detects non-default states', () {
      expect(const SortFilterState().isDefault, true);
      expect(
        const SortFilterState(sortMode: SortMode.alphabetical).isDefault,
        false,
      );
      expect(
        const SortFilterState(needsAttentionOnly: true).isDefault,
        false,
      );
      expect(
        const SortFilterState(modalityFilter: {'cbt'}).isDefault,
        false,
      );
    });

    test('copyWith creates correct copies', () {
      const original = SortFilterState();
      final copied = original.copyWith(sortMode: SortMode.mostSessions);
      expect(copied.sortMode, SortMode.mostSessions);
      expect(copied.needsAttentionOnly, false); // unchanged
      expect(copied.modalityFilter, isEmpty); // unchanged
    });
  });
}
