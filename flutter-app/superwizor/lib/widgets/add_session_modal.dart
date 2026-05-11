// AddSessionModal — choose a modality and start recording.
//
// Updated for Etap 1-5b:
//   - Uses kModalities (codes + i18n display keys)
//   - Passes `patientAlias` to NewSessionScreen (which offers
//     both live recording and file upload paths)
//   - Routes to SessionStatusScreen on RecordingScreen pop (Etap 4)
//     instead of the legacy SessionDetailsScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/modalities.dart';
import '../l10n/app_localizations.dart';
import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../screens/new_session_screen.dart';
import '../theme/euphire_theme.dart';
import 'euphire_card.dart';
import 'euphire_list_tile.dart';

class AddSessionModal extends ConsumerWidget {
  final String patientId;
  final String therapistId;

  const AddSessionModal({
    super.key,
    required this.patientId,
    required this.therapistId,
  });

  String _modalityLabel(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'UNIV':
        return t.modality_integrative;
      case 'CBT':
        return t.modality_cbt;
      case 'PSYCHO':
        return t.modality_psychodynamic;
      case 'PPT':
        return t.modality_positive;
      case 'ST':
        return t.modality_schema;
      case 'SYS':
        return t.modality_systemic;
      case 'EFT':
        return t.modality_eft;
      case 'COACH':
        return t.modality_coaching;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).addSession_title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: EuphireColors.frostWhite,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).addSession_subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: EuphireColors.mist,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: kModalities.length,
              itemBuilder: (context, index) {
                final modality = kModalities[index];
                final label = _modalityLabel(context, modality.code);
                return ListTile(
                  title: Text(label, style: const TextStyle(color: EuphireColors.frostWhite)),
                  trailing: const Icon(Icons.chevron_right, color: EuphireColors.mist),
                  onTap: () async {
                    final patientsState =
                        ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? [];
                    final patient = patientsState.firstWhere(
                      (p) => p.id == patientId,
                      orElse: () => Patient(
                          id: patientId,
                          firstName: 'Nie znaleziono',
                          lastName: ''),
                    );

                    Navigator.pop(context);

                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewSessionScreen(
                          patientFileId: patientId,
                          therapistId: therapistId,
                          patientAlias:
                              '${patient.firstName} ${patient.lastName}'
                                  .trim(),
                        ),
                      ),
                    );
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
