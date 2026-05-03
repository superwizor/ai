import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_card.dart';
import '../widgets/euphire_list_tile.dart';
import '../screens/recording_screen.dart';
import '../providers/patient_provider.dart';
import '../models/session.dart';
import '../models/patient.dart';
import '../constants/modalities.dart';
import '../screens/session_details_screen.dart';

class AddSessionModal extends ConsumerWidget {
  final String patientId;

  const AddSessionModal({
    super.key,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nowa Sesja.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: EuphireColors.frostWhite,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Wybierz modalność dla tej sesji:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: EuphireColors.mist,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 400, // Fixed height for scrollable list
            child: ListView.builder(
              itemCount: clinicalModalities.length,
              itemBuilder: (context, index) {
                final modality = clinicalModalities[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: EuphireCard(
                    child: EuphireListTile(
                      title: modality,
                      onTap: () async {
                        // Pobierz dane pacjenta przed zamknięciem modala
                        final patientsState = ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? [];
                        final patient = patientsState.firstWhere(
                          (p) => p.id == patientId,
                          orElse: () => Patient(id: patientId, firstName: 'Nie znaleziono', lastName: ''),
                        );
                        
                        // Zamknij bottom sheet
                        Navigator.pop(context);
                        
                        // Utworz nową sesje
                        final session = Session(
                          id: const Uuid().v4(),
                          patientId: patientId,
                          modality: modality,
                          date: DateTime.now(),
                          duration: Duration.zero,
                        );
                        
                        // Zapisz sesje i zaktualizuj licznik pacjenta
                        ref.read(sessionsProvider.notifier).addSession(session);
                        ref.read(patientsProvider.notifier).incrementSessionCount(patientId);

                        // Przejdz do nagrywania i czekaj na powrót
                        final returnedSessionId = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecordingScreen(
                              patientFileId: patientId,
                              therapistId: 'eecf479b-08f8-4751-82e0-482b54043793', // mock valid ID dla backendu
                            ),
                          ),
                        );

                        // Jeśli wrócono z poprawnym id sesji, przejdź do szczegółów
                        if (returnedSessionId != null && context.mounted) {
                          final dateStr = '${session.date.day.toString().padLeft(2, '0')}.${session.date.month.toString().padLeft(2, '0')}.${session.date.year}';
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SessionDetailsScreen(
                                sessionId: returnedSessionId as String,
                                patientName: patient.firstName, // Używamy prawdziwego imienia
                                date: dateStr,
                                modality: modality,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
