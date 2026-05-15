import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/euphire_theme.dart';
import '../constants/modalities.dart';
import '../l10n/app_localizations.dart';

/// Notifier for the therapist's currently selected default modality.
/// Initialized from the user profile's `defaultModalityId`, but since
/// the backend doesn't yet persist modality preference on the user
/// (UpdateProfile doesn't support defaultModalityId), we cache it
/// in-memory for the session. The modality is passed per-patient-file
/// at creation time, so the therapist can pick one before creating
/// a patient file.
class SelectedModalityNotifier extends Notifier<String> {
  @override
  String build() => kDefaultModalityCode;

  void select(String code) => state = code;
}

final selectedModalityProvider =
    NotifierProvider<SelectedModalityNotifier, String>(
  () => SelectedModalityNotifier(),
);

class ModalitySheet extends ConsumerWidget {
  const ModalitySheet({super.key});

  String _modalityDisplayName(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'UNIV': return t.modality_integrative;
      case 'CBT': return t.modality_cbt;
      case 'PSYCHO': return t.modality_psychodynamic;
      case 'PPT': return t.modality_positive;
      case 'ST': return t.modality_schema;
      case 'SYS': return t.modality_systemic;
      case 'EFT': return t.modality_eft;
      case 'COACH': return t.modality_coaching;
      default: return code;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCode = ref.watch(selectedModalityProvider);
    final t = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ──
          Text(
            t.modality_sheet_title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),

          // ── Subtitle — reassuring UX copy ──
          Text(
            t.modality_sheet_subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EuphireColors.mist,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 20),

          // ── Modality list ──
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: kModalities.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                final m = kModalities[index];
                final isSelected = m.code == selectedCode;
                return _ModalityTile(
                  icon: m.icon,
                  label: _modalityDisplayName(context, m.code),
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(selectedModalityProvider.notifier).select(m.code);

                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (context.mounted) Navigator.of(context).pop();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual modality row with icon, label, and selection indicator.
class _ModalityTile extends StatelessWidget {
  const _ModalityTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: EuphireColors.ember.withValues(alpha: 0.08),
        highlightColor: EuphireColors.ember.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? EuphireColors.ember.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // ── Icon ──
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? EuphireColors.ember.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: isSelected
                        ? EuphireColors.ember.withValues(alpha: 0.30)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? EuphireColors.ember
                      : EuphireColors.mist,
                ),
              ),
              const SizedBox(width: 14),

              // ── Label ──
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? EuphireColors.frostWhite
                            : EuphireColors.frostWhite
                                .withValues(alpha: 0.80),
                      ),
                ),
              ),

              // ── Check mark ──
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.ember,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: EuphireColors.obsidianBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
