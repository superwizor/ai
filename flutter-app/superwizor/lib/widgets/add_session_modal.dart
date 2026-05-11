// AddSessionModal — confirms the start of a new session.
//
// The therapy modality is now picked once per kartoteka (see
// AddPatientModal), so this modal no longer needs a modality
// selector. It shows the kartoteka alias + the modality inherited
// from the patient_file, and presents a single "Rozpocznij sesję."
// button that pushes RecordingScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../screens/recording_screen.dart';
import '../theme/euphire_theme.dart';
import 'euphire_button.dart';

class AddSessionModal extends ConsumerWidget {
  final String patientId;
  final String therapistId;

  const AddSessionModal({
    super.key,
    required this.patientId,
    required this.therapistId,
  });

  String _modalityDisplay(BuildContext context, String uiCode) {
    final t = AppLocalizations.of(context);
    switch (uiCode) {
      case 'cbt':
        return t.modality_cbt;
      case 'psychodynamic':
        return t.modality_psychodynamic;
      case 'positive':
        return t.modality_positive;
      case 'schema':
        return t.modality_schema;
      case 'systemic':
        return t.modality_systemic;
      case 'eft':
        return t.modality_eft;
      case 'coaching':
        return t.modality_coaching;
      case 'integrative':
      default:
        return t.modality_integrative;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    final patientsState =
        ref.watch(patientsProvider).whenOrNull(data: (d) => d) ?? const [];
    final patient = patientsState.firstWhere(
      (p) => p.id == patientId,
      orElse: () => Patient(
        id: patientId,
        firstName: '—',
        lastName: '',
      ),
    );

    final patientAlias =
        '${patient.firstName} ${patient.lastName}'.trim().isEmpty
            ? '—'
            : '${patient.firstName} ${patient.lastName}'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.addSession_title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: EuphireColors.frostWhite,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t.addSession_summary_patient(patientAlias),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: EuphireColors.mist,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.addSession_summary_modality(
              _modalityDisplay(context, patient.uiModalityCode),
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: EuphireColors.mist,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: EuphireButton(
              text: t.addSession_start_primary,
              onPressed: () async {
                Navigator.pop(context);
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordingScreen(
                      patientFileId: patientId,
                      therapistId: therapistId,
                      patientAlias: patientAlias,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
