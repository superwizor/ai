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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Domyślny nurt', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kModalities.length,
              itemBuilder: (context, index) {
                final m = kModalities[index];
                final isSelected = m.code == selectedCode;
                return ListTile(
                  title: Text(_modalityDisplayName(context, m.code)),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: EuphireColors.ember)
                      : null,
                  onTap: () {
                    // Save to in-memory Notifier — persists for this
                    // app session. Used by addPatient when creating
                    // a new patient_file.
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
