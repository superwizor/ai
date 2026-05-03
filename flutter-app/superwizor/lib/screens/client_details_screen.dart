import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_card.dart';
import '../widgets/euphire_list_tile.dart';
import 'recording_screen.dart';
import '../providers/patient_provider.dart';
import '../models/session.dart';
import '../constants/modalities.dart';
import '../widgets/add_session_modal.dart';
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
    final patient = ref.watch(patientsProvider).firstWhere((p) => p.id == patientId);
    final sessions = ref.watch(sessionsProvider.notifier).getSessionsForPatient(patientId);
    
    // Odwroc kolejnosc zeby najnowsze byly na gorze
    final reversedSessions = sessions.reversed.toList();

    return Scaffold(
      backgroundColor: EuphireColors.obsidianBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.mist),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EuphireHeader(
              title: '${patient.firstName} ${patient.lastName}',
              subtitle: '${patient.sessionCount} sesji',
            ),
            const SizedBox(height: 32),
            Expanded(
              child: reversedSessions.isEmpty
                ? const Center(
                    child: Text(
                      'Brak sesji. Rozpocznij nową.',
                      style: TextStyle(color: EuphireColors.mist),
                    ),
                  )
                : ListView.builder(
                itemCount: reversedSessions.length,
                itemBuilder: (context, index) {
                  final session = reversedSessions[index];
                  // Formatowanie daty proste
                  final dateStr = '${session.date.day.toString().padLeft(2, '0')}.${session.date.month.toString().padLeft(2, '0')}.${session.date.year}';
                  
                  return EuphireCard(
                    child: EuphireListTile(
                      title: session.modality,
                      subtitle: dateStr,
                      trailingIcon: Icons.more_vert,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
