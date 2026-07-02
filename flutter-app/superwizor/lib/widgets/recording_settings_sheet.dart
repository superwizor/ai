// recording_settings_sheet.dart — in-recording quick controls for the two
// "Nagrywanie" options (auto-pause + reminder). Opened from the Timer icon on
// the live recording screen. Reads/writes the SAME appSettingsProvider and uses
// the SAME wheel pickers as Settings, so changes here persist and vice-versa.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../theme/euphire_theme.dart';
import 'settings_wheel_picker.dart';

class RecordingSettingsSheet extends ConsumerWidget {
  const RecordingSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: EuphireColors.evergreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                t.settings_recording_section,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  PickerRow(
                    icon: Icons.timer_outlined,
                    title: t.settings_recording_autopause,
                    subtitle: t.settings_recording_autopause_value(
                      settings.autoPauseMinutes,
                    ),
                    onTap: () => openWheelPicker(
                      context: context,
                      title: t.settings_recording_autopause,
                      values: [
                        for (
                          int m = kAutoPauseMinMinutes;
                          m <= kAutoPauseMaxMinutes;
                          m += 10
                        )
                          m,
                      ],
                      current: settings.autoPauseMinutes,
                      labelFor: (m) => t.settings_recording_autopause_value(m),
                      onPicked: notifier.setAutoPauseMinutes,
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                    indent: 52,
                  ),
                  PickerRow(
                    icon: Icons.notifications_active_outlined,
                    title: t.settings_recording_reminder,
                    subtitle: settings.reminderIntervalMinutes == 0
                        ? t.settings_recording_reminder_off
                        : t.settings_recording_autopause_value(
                            settings.reminderIntervalMinutes,
                          ),
                    onTap: () => openWheelPicker(
                      context: context,
                      title: t.settings_recording_reminder,
                      values: [for (int m = 0; m <= 120; m += 10) m],
                      current: settings.reminderIntervalMinutes,
                      labelFor: (m) => m == 0
                          ? t.settings_recording_reminder_off
                          : t.settings_recording_autopause_value(m),
                      onPicked: notifier.setReminderIntervalMinutes,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                t.settings_recording_reminder_sound_hint,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  color: EuphireColors.mist.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
