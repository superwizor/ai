// settings_wheel_picker.dart — shared iOS-Timer-style wheel picker used by the
// Settings "Nagrywanie" section AND the in-recording quick controls, so both
// surfaces present the exact same auto-pause / reminder pickers.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

/// Tappable settings row that shows the current value in [subtitle] and opens
/// a picker via [onTap]. Used for the recording controls (auto-pause, reminder).
class PickerRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PickerRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: EuphireColors.ember, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: EuphireColors.frostWhite,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: EuphireColors.mist.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: EuphireColors.mist,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the wheel picker in a bottom sheet and calls [onPicked] with the
/// chosen value when it differs from [current].
Future<void> openWheelPicker({
  required BuildContext context,
  required String title,
  required List<int> values,
  required int current,
  required String Function(int) labelFor,
  required void Function(int) onPicked,
}) async {
  final picked = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => WheelPickerSheet(
      title: title,
      values: values,
      current: current,
      labelFor: labelFor,
    ),
  );
  if (picked != null && picked != current) onPicked(picked);
}

/// iOS-Timer-style wheel picker over a list of integer [values]. Returns the
/// selected value via Navigator.pop on "Zapisz". Visual styling matches the
/// report-preferences picker sheets (drag handle + evergreen panel).
class WheelPickerSheet extends StatefulWidget {
  final String title;
  final List<int> values;
  final int current;
  final String Function(int) labelFor;

  const WheelPickerSheet({
    super.key,
    required this.title,
    required this.values,
    required this.current,
    required this.labelFor,
  });

  @override
  State<WheelPickerSheet> createState() => _WheelPickerSheetState();
}

class _WheelPickerSheetState extends State<WheelPickerSheet> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final i = widget.values.indexOf(widget.current);
    _index = i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: EuphireColors.evergreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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
            Text(widget.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: _index,
                ),
                itemExtent: 38,
                magnification: 1.1,
                squeeze: 1.1,
                useMagnifier: true,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: EuphireColors.ember.withValues(alpha: 0.12),
                ),
                onSelectedItemChanged: (i) => _index = i,
                children: widget.values
                    .map(
                      (v) => Center(
                        child: Text(
                          widget.labelFor(v),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: EuphireColors.frostWhite,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuphireColors.ember,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(widget.values[_index]),
                child: Text(
                  t.report_prefs_save,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
