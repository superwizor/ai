// Avatar Customize Sheet — beautiful bottom sheet for personalizing
// patient card avatars with custom labels (2 chars or emoji) and colors.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../utils/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/patient_avatar_provider.dart';
import '../theme/euphire_theme.dart';

class AvatarCustomizeSheet extends ConsumerStatefulWidget {
  final String patientId;
  final String defaultInitials; // auto-generated from name

  const AvatarCustomizeSheet({
    super.key,
    required this.patientId,
    required this.defaultInitials,
  });

  @override
  ConsumerState<AvatarCustomizeSheet> createState() =>
      _AvatarCustomizeSheetState();
}

class _AvatarCustomizeSheetState extends ConsumerState<AvatarCustomizeSheet>
    with SingleTickerProviderStateMixin {
  late TextEditingController _labelController;
  late int _selectedColorIndex;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  bool _showOnboarding = false;

  static const _onboardingKey = 'avatar_onboarding_count';

  @override
  void initState() {
    super.initState();
    final config = ref.read(patientAvatarProvider.notifier).getConfig(widget.patientId);
    _labelController = TextEditingController(
      text: config.customLabel ?? widget.defaultInitials,
    );
    _selectedColorIndex = config.colorIndex;

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutBack),
    );

    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_onboardingKey) ?? 0;
    if (count < 3) {
      if (mounted) setState(() => _showOnboarding = true);
      await prefs.setInt(_onboardingKey, count + 1);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _selectColor(int index) {
    setState(() => _selectedColorIndex = index);
    _bounceController.forward().then((_) => _bounceController.reverse());
    _autoSave();
  }

  void _autoSave() {
    final label = _labelController.text.trim();
    final isDefault = label.isEmpty || label == widget.defaultInitials;
    final config = PatientAvatarConfig(
      customLabel: isDefault ? null : label,
      colorIndex: _selectedColorIndex,
    );
    ref.read(patientAvatarProvider.notifier).setConfig(
          widget.patientId,
          config,
        );
  }

  String get _previewLabel {
    final text = _labelController.text.trim();
    return text.isEmpty ? widget.defaultInitials : text;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final t = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // Onboarding hint (first time only)
              if (_showOnboarding) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: EuphireColors.ember.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: EuphireColors.ember.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.avatar_customize_desc,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            color: EuphireColors.ember.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Live preview avatar
              ScaleTransition(
                scale: _bounceAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AvatarColors.fromIndex(_selectedColorIndex),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AvatarColors.fromIndex(_selectedColorIndex)
                            .withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _previewLabel,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                t.addPatient_customize_label_title,
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  color: EuphireColors.frostWhite,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Label input
              TextField(
                controller: _labelController,
                textAlign: TextAlign.center,
                maxLength: null,
                inputFormatters: [
                  _GraphemeClusterLengthFormatter(2),
                ],
                onChanged: (_) {
                  setState(() {});
                  _autoSave();
                },
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: EuphireColors.frostWhite,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: widget.defaultInitials,
                  hintStyle: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: EuphireColors.mist.withValues(alpha: 0.25),
                  ),
                  counterText: '', // hide the "0/2" counter
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: EuphireColors.ember, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.addPatient_avatar_format_hint,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  color: EuphireColors.mist.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),

              // Color grid
              Text(
                t.avatar_customize_background_color,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: EuphireColors.mist.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: List.generate(AvatarColors.palette.length, (i) {
                  final isSelected = i == _selectedColorIndex;
                  return GestureDetector(
                    onTap: () {
                      AppHapticFeedback.selectionClick();
                      _selectColor(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 40 : 36,
                      height: isSelected ? 40 : 36,
                      decoration: BoxDecoration(
                        color: AvatarColors.palette[i],
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: EuphireColors.ember, width: 2.5)
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: EuphireColors.ember
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: EuphireColors.frostWhite)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [TextInputFormatter] that limits input by grapheme cluster count rather
/// than UTF-16 code-unit count.  This allows emoji characters (which are
/// multi-code-unit) to be treated as a single "character" toward [maxLength].
class _GraphemeClusterLengthFormatter extends TextInputFormatter {
  final int maxLength;
  const _GraphemeClusterLengthFormatter(this.maxLength);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clusters = newValue.text.characters;
    if (clusters.length <= maxLength) return newValue;

    // Truncate to maxLength grapheme clusters
    final truncated = clusters.take(maxLength).toString();
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}
