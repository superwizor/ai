// Bottom sheet for sort & filter options on the home screen.
//
// Opened via the tune icon next to the search bar.
// Follows Euphire design language: dark glassmorphism, rounded corners,
// drag handle, ember accents.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/modalities.dart';
import '../providers/sort_filter_provider.dart';
import '../theme/euphire_theme.dart';
import '../utils/haptics.dart';

class SortFilterSheet extends ConsumerWidget {
  /// Set of modality codes present in the therapist's active caseload.
  /// Used to decide whether the modality filter section appears.
  final Set<String> availableModalities;

  /// Number of patients currently flagged as "needs attention"
  /// (hasNewReport | analyzing | error). Shown as badge on the toggle.
  final int needsAttentionCount;

  const SortFilterSheet({
    super.key,
    required this.availableModalities,
    required this.needsAttentionCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sortFilterProvider).value ?? const SortFilterState();
    final notifier = ref.read(sortFilterProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── SORTOWANIE header ──
              Text(
                'SORTOWANIE',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: EuphireColors.mist.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),

              // ── Sort options ──
              _SortOption(
                icon: Icons.history_rounded,
                label: 'Ostatnia aktywność',
                subtitle: 'Klienci, z którymi ostatnio pracowałeś',
                selected: state.sortMode == SortMode.lastActivity,
                onTap: () {
                  AppHapticFeedback.selectionClick();
                  notifier.setSortMode(SortMode.lastActivity);
                },
              ),
              const SizedBox(height: 4),
              _SortOption(
                icon: Icons.hourglass_empty_rounded,
                label: 'Dawno niewidziani',
                subtitle: 'Klienci bez sesji od najdłuższego czasu',
                selected: state.sortMode == SortMode.leastRecent,
                onTap: () {
                  AppHapticFeedback.selectionClick();
                  notifier.setSortMode(SortMode.leastRecent);
                },
              ),
              const SizedBox(height: 4),
              _SortOption(
                icon: Icons.sort_by_alpha_rounded,
                label: 'Alfabetycznie',
                subtitle: 'Nazwy kartotek od A do Z',
                selected: state.sortMode == SortMode.alphabetical,
                onTap: () {
                  AppHapticFeedback.selectionClick();
                  notifier.setSortMode(SortMode.alphabetical);
                },
              ),
              const SizedBox(height: 4),
              _SortOption(
                icon: Icons.trending_up_rounded,
                label: 'Najdłuższe procesy',
                subtitle: 'Klienci z największą liczbą sesji',
                selected: state.sortMode == SortMode.mostSessions,
                onTap: () {
                  AppHapticFeedback.selectionClick();
                  notifier.setSortMode(SortMode.mostSessions);
                },
              ),

              // ── POKAŻ TYLKO (filter) ──
              if (needsAttentionCount > 0) ...[
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 16),
                Text(
                  'POKAŻ TYLKO',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                _FilterToggle(
                  label: 'Nowe raporty i analizy',
                  subtitle: 'Gotowe raporty AI lub trwające analizy',
                  badge: needsAttentionCount,
                  active: state.needsAttentionOnly,
                  onTap: () {
                    AppHapticFeedback.selectionClick();
                    notifier.toggleNeedsAttention();
                  },
                ),
              ],

              // ── MODALNOŚĆ (only if therapist uses >1 modality) ──
              if (availableModalities.length > 1) ...[
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 16),
                Text(
                  'MODALNOŚĆ',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableModalities.map((code) {
                    final selected = state.modalityFilter.contains(code);
                    final label = modalityShortLabelFor(code);
                    return GestureDetector(
                      onTap: () {
                        AppHapticFeedback.selectionClick();
                        notifier.toggleModality(code);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? EuphireColors.ember.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? EuphireColors.ember.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? EuphireColors.ember
                                : EuphireColors.mist.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // ── Wyczyść filtry ──
              if (!state.isDefault) ...[
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      AppHapticFeedback.mediumImpact();
                      notifier.reset();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Text(
                      'Wyczyść filtry',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: EuphireColors.mist.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sort option row (radio-style) ───────────────────────────────────

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? EuphireColors.ember
                      : EuphireColors.mist.withValues(alpha: 0.3),
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: EuphireColors.ember,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            // Icon
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: 18,
                color: selected
                    ? EuphireColors.ember
                    : EuphireColors.mist.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? EuphireColors.frostWhite
                          : EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter toggle row (checkbox-style) ──────────────────────────────

class _FilterToggle extends StatelessWidget {
  final String label;
  final String? subtitle;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  const _FilterToggle({
    required this.label,
    this.subtitle,
    required this.badge,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            // Checkbox indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: active
                    ? EuphireColors.ember.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: active
                      ? EuphireColors.ember
                      : EuphireColors.mist.withValues(alpha: 0.3),
                  width: active ? 2 : 1.5,
                ),
              ),
              child: active
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: EuphireColors.ember,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? EuphireColors.frostWhite
                          : EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: EuphireColors.mist.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Badge count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: EuphireColors.ember.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: EuphireColors.ember,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
