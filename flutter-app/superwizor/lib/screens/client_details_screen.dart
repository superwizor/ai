import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_card.dart';
import '../widgets/euphire_list_tile.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';
import '../widgets/add_session_modal.dart';
import 'session_details_screen.dart';

class ClientDetailsScreen extends ConsumerWidget {
  final String patientId;
  final String clientName;

  const ClientDetailsScreen({
    super.key,
    required this.patientId,
    required this.clientName,
  });

  void _showAddSessionModal(BuildContext context, WidgetRef ref) {
    showEuphireBottomSheet(
      context: context,
      builder: (context) => AddSessionModal(patientId: patientId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientsProvider);
    final sessionsAsync = ref.watch(sessionsProvider);

    // Fetch sessions when screen builds (if needed, alternatively we can fetch on initState, but we can do it post frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionsState = ref.read(sessionsProvider).whenOrNull(data: (d) => d);
      if (sessionsState != null && !sessionsState.containsKey(patientId)) {
        ref.read(sessionsProvider.notifier).fetchSessions(patientId);
      }
    });

    return Scaffold(
      backgroundColor: EuphireColors.obsidianBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.mist),
      ),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: EuphireColors.ember)),
        error: (e, st) => Center(child: Text('Błąd: $e', style: const TextStyle(color: EuphireColors.ember))),
        data: (patients) {
          final patient = patients.firstWhere(
            (p) => p.id == patientId,
            orElse: () => Patient(id: patientId, firstName: 'Nie znaleziono', lastName: ''),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EuphireHeader(
                  title: '${patient.firstName} ${patient.lastName}'.trim(),
                  subtitle: '${patient.sessionCount} sesji',
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: sessionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: EuphireColors.ember)),
                    error: (e, st) => Center(child: Text('Błąd sesji: $e', style: const TextStyle(color: EuphireColors.ember))),
                    data: (sessionsMap) {
                      final sessions = sessionsMap[patientId] ?? [];
                      final reversedSessions = sessions.reversed.toList();
                      if (reversedSessions.isEmpty) {
                        return const Center(
                          child: Text(
                            'Brak sesji. Rozpocznij nową.',
                            style: TextStyle(color: EuphireColors.mist),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: reversedSessions.length,
                        itemBuilder: (context, index) {
                          final session = reversedSessions[index];
                          final dateStr = '${session.date.day.toString().padLeft(2, '0')}.${session.date.month.toString().padLeft(2, '0')}.${session.date.year}';
                          
                          return EuphireCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SessionDetailsScreen(
                                    sessionId: session.id,
                                    patientName: patient.firstName,
                                    date: dateStr,
                                    modality: session.modality,
                                  ),
                                ),
                              );
                            },
                            child: EuphireListTile(
                              title: session.modality,
                              subtitle: dateStr,
                              trailingIcon: Icons.more_vert,
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
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSessionModal(context, ref),
        backgroundColor: EuphireColors.ember,
        foregroundColor: EuphireColors.obsidianBlack,
        child: const Icon(Icons.add),
      ),
    );
  }
}
