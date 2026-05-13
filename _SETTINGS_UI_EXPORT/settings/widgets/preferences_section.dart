import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/providers/settings_provider.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

import 'package:labirynt_premium/src/features/game/data/game_repository.dart';

/// Visual and game preferences section
///
/// Contains toggles for:
/// - Dark mode
/// - Sound effects
/// - Haptic feedback
/// - Question repeating
class PreferencesSection extends ConsumerWidget {
  const PreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return EuSection(
      header: context.l10n.settingsPreferencesHeader,
      children: [
        // Sound effects toggle
        EuToggle(
          value: settings.soundEnabled,
          onChanged: (value) {
            AppHaptics.lightImpact(ref);
            notifier.toggleSound(value);
          },
          label: context.l10n.settingsSoundsLabel,
          subtitle: settings.soundEnabled
              ? context.l10n.settingsSoundsEnabled
              : context.l10n.settingsSoundsDisabled,
          icon: Icons.volume_up_outlined,
        ),

        // Haptic feedback toggle
        EuToggle(
          value: settings.hapticsEnabled,
          onChanged: (value) {
            AppHaptics.lightImpact(ref);
            notifier.toggleHaptics(value);
          },
          label: context.l10n.settingsHapticsLabel,
          subtitle: settings.hapticsEnabled
              ? context.l10n.settingsHapticsEnabled
              : context.l10n.settingsHapticsDisabled,
          icon: Icons.vibration_outlined,
        ),

        // Repeat questions toggle
        EuToggle(
          value: settings.repeatQuestions,
          onChanged: (value) {
            AppHaptics.lightImpact(ref);
            notifier.toggleRepeat(value);
          },
          label: context.l10n.settingsRepeatQuestionsLabel,
          subtitle: settings.repeatQuestions
              ? context.l10n.settingsRepeatEnabled
              : context.l10n.settingsRepeatDisabled,
          icon: Icons.replay_outlined,
        ),

        // Language selection
        const _LanguageSelectorOption(),
      ],
    );
  }
}

class _LanguageSelectorOption extends ConsumerWidget {
  const _LanguageSelectorOption();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final isPl = settings.languageCode == 'pl';
    final flag = isPl ? '🇵🇱' : '🇬🇧';
    final langName = isPl ? 'Polski (PL)' : 'English (UK)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.settingsLanguageLabel,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              AppHaptics.lightImpact(ref);
              _showLanguageModal(context, ref, settings.languageCode);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // filter drop-shadow-md text-2xl
                  Text(
                    flag,
                    style: const TextStyle(
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      langName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              context.l10n.settingsLanguageSubtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[400],
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showLanguageModal(
    BuildContext context,
    WidgetRef ref,
    String currentLang,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider);
            final currentLang = settings.languageCode;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.l10n.settingsLanguageSelectBtn,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'serif',
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _LanguageOptionTile(
                      flag: '🇵🇱',
                      name: 'Polski',
                      subtitle: 'Polish',
                      isSelected: currentLang == 'pl',
                      onTap: () async {
                        AppHaptics.lightImpact(ref);
                        await ref
                            .read(gameRepositoryProvider)
                            .initializeData(languageCode: 'pl', force: true);
                        ref.read(settingsProvider.notifier).setLanguage('pl');
                        // Small delay to let the user see the visual feedback (check icon)
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    _LanguageOptionTile(
                      flag: '🇬🇧',
                      name: 'English',
                      subtitle: 'English (UK)',
                      isSelected: currentLang == 'en',
                      onTap: () async {
                        AppHaptics.lightImpact(ref);
                        await ref
                            .read(gameRepositoryProvider)
                            .initializeData(languageCode: 'en', force: true);
                        ref.read(settingsProvider.notifier).setLanguage('en');
                        // Small delay to let the user see the visual feedback (check icon)
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String flag;
  final String name;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(
                fontSize: 28,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check, color: theme.primaryColor),
          ],
        ),
      ),
    );
  }
}
