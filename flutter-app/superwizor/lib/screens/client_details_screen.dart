import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_card.dart';
import '../widgets/euphire_list_tile.dart';
import '../models/patient.dart';
import '../models/session.dart';
import '../providers/current_user_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/add_session_modal.dart';
import '../widgets/edit_patient_modal.dart';
import 'new_session_screen.dart';
import 'session_status_screen.dart';
import 'transcript_screen.dart';

class ClientDetailsScreen extends ConsumerWidget {
  final String patientId;
  final String clientName;

  const ClientDetailsScreen({
    super.key,
    required this.patientId,
    required this.clientName,
  });

  Future<void> _showAddSessionModal(BuildContext context, WidgetRef ref) async {
    // First try the cached value.
    var therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) {
      // Provider not resolved yet — await the future once. Identity-svc
      // round-trip is ~100-500ms, so we just block briefly. If it's
      // still null after that, fall through to the snackbar.
      try {
        final user = await ref.read(currentUserProvider.future);
        therapistId = user?.id;
      } catch (e) {
        // network / auth error — fall through with null
      }
    }
    if (!context.mounted) return;
    if (therapistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil nie został jeszcze załadowany. Spróbuj za chwilę.',
          ),
        ),
      );
      return;
    }
    final patientsState = ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? [];
    final patient = patientsState.firstWhere(
      (p) => p.id == patientId,
      orElse: () => Patient(id: patientId, firstName: 'Brak', lastName: ''),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewSessionScreen(
          patientFileId: patientId,
          therapistId: therapistId!,
          patientAlias: '${patient.firstName} ${patient.lastName}'.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientsProvider);
    final sessionsAsync = ref.watch(sessionsProvider);

    // Always re-fetch sessions on entry. Backend is the source of
    // truth for session.status (CREATED → TRANSCRIBING → ANALYZING →
    // COMPLETED), and we may be returning here from RecordingScreen
    // /SessionStatusScreen where status just transitioned. The
    // previous "only fetch if not cached" check kept stale state
    // forever — caused the bug where finished sessions kept routing
    // to SessionStatusScreen instead of TranscriptScreen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsProvider.notifier).fetchSessions(patientId);
    });

    return Scaffold(
      backgroundColor: EuphireColors.obsidianBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.mist),
        actions: [
          patientAsync.when(
            data: (patients) {
              final patient = patients.firstWhere(
                (p) => p.id == patientId,
                orElse: () => Patient(id: patientId, firstName: '', lastName: ''),
              );
              if (patient.firstName.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit, color: EuphireColors.mist),
                onPressed: () {
                  showEuphireBottomSheet(
                    context: context,
                    builder: (_) => EditPatientModal(patient: patient),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: EuphireColors.ember)),
        error: (e, st) => Center(child: Text('Błąd: $e', style: const TextStyle(color: EuphireColors.ember))),
        data: (patients) {
          final patient = patients.firstWhere(
            (p) => p.id == patientId,
            orElse: () => Patient(id: patientId, firstName: 'Nie znaleziono', lastName: ''),
          );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EuphireHeader(
                    title: '${patient.firstName} ${patient.lastName}'.trim(),
                    subtitle: '${patient.sessionCount} sesji' +
                        (patient.modalityCode.isNotEmpty ? ' • ${patient.modalityCode}' : ''),
                  ),
                  const SizedBox(height: 32),
                  sessionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: EuphireColors.ember)),
                    error: (e, st) => Center(child: Text('Błąd sesji: $e', style: const TextStyle(color: EuphireColors.ember))),
                    data: (sessionsMap) {
                      final sessions = sessionsMap[patientId] ?? [];
                      final reversedSessions = sessions.reversed.toList();
                      if (reversedSessions.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Brak sesji. Rozpocznij nową.',
                              style: TextStyle(color: EuphireColors.mist),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reversedSessions.length,
                        itemBuilder: (context, index) {
                          final session = reversedSessions[index];
                          final months = ['Sty', 'Lut', 'Mar', 'Kwi', 'Maj', 'Cze', 'Lip', 'Sie', 'Wrz', 'Paź', 'Lis', 'Gru'];
                          final dateStr = '${session.date.day} ${months[session.date.month - 1]}';
                          final timeStr = '${session.date.hour.toString().padLeft(2, '0')}:${session.date.minute.toString().padLeft(2, '0')}';
                          
                          final isCompleted = session.status == SessionStatus.completed;
                          final dotColor = isCompleted ? EuphireColors.aurora : EuphireColors.ember;
                          final statusText = isCompleted ? 'Wnioski gotowe' : 'W trakcie analizy';
                          
                          return InkWell(
                            onTap: () {
                              final destination = isCompleted
                                  ? MaterialPageRoute(builder: (_) => TranscriptScreen(sessionId: session.id))
                                  : MaterialPageRoute(builder: (_) => SessionStatusScreen(sessionId: session.id));
                              Navigator.push(context, destination);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: EuphireColors.obsidianBlack.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: EuphireColors.frostWhite.withValues(alpha: 0.1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Raport z sesji',
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: EuphireColors.frostWhite,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8, height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: dotColor.withValues(alpha: 0.2),
                                                  border: Border.all(color: dotColor),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: dotColor,
                                                      blurRadius: 6,
                                                    )
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                statusText,
                                                style: const TextStyle(
                                                  fontFamily: 'Merriweather',
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 14,
                                                  color: EuphireColors.mist,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontFamily: 'RobotoMono',
                                                  color: EuphireColors.mist,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, color: EuphireColors.mist, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                color: EuphireColors.nocturne,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'rename',
                                                    child: Text('Zmień nazwę', style: TextStyle(color: EuphireColors.frostWhite)),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Usuń sesję', style: TextStyle(color: EuphireColors.magma)),
                                                  ),
                                                ],
                                                onSelected: (value) {
                                                  if (value == 'delete') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        backgroundColor: EuphireColors.nocturne,
                                                        title: const Text('Bezpowrotne usunięcie sesji', style: TextStyle(color: EuphireColors.frostWhite)),
                                                        content: const Text('Czy na pewno chcesz BEZPOWROTNIE usunąć tę sesję, nagranie oraz transkrypcję? Tej operacji nie można cofnąć.', style: TextStyle(color: EuphireColors.mist)),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            child: const Text('Anuluj', style: TextStyle(color: EuphireColors.mist)),
                                                          ),
                                                          TextButton(
                                                            onPressed: () async {
                                                              try {
                                                                await ref.read(sessionsProvider.notifier).deleteSession(patientId, session.id);
                                                                if (context.mounted) {
                                                                  Navigator.pop(context);
                                                                }
                                                              } catch (e) {}
                                                            },
                                                            child: const Text('Usuń bezpowrotnie', style: TextStyle(color: EuphireColors.magma)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  } else if (value == 'rename') {
                                                    final controller = TextEditingController(text: session.modality);
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        backgroundColor: EuphireColors.nocturne,
                                                        title: const Text('Zmień nazwę sesji', style: TextStyle(color: EuphireColors.frostWhite)),
                                                        content: TextField(
                                                          controller: controller,
                                                          style: const TextStyle(color: EuphireColors.frostWhite),
                                                          autofocus: true,
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            child: const Text('Anuluj', style: TextStyle(color: EuphireColors.mist)),
                                                          ),
                                                          TextButton(
                                                            onPressed: () async {
                                                              if (controller.text.trim().isNotEmpty) {
                                                                try {
                                                                  await ref.read(sessionsProvider.notifier).renameSession(patientId, session.id, controller.text.trim());
                                                                  if (context.mounted) Navigator.pop(context);
                                                                } catch (e) {}
                                                              }
                                                            },
                                                            child: const Text('Zapisz', style: TextStyle(color: EuphireColors.ember)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontFamily: 'RobotoMono',
                                              color: EuphireColors.mist.withValues(alpha: 0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: EuphireColors.mist.withValues(alpha: 0.3), height: 1),
                                  const SizedBox(height: 12),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 16,
                                        runSpacing: 12,
                                        children: [
                                          ConstrainedBox(
                                            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 32, height: 32,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: EuphireColors.obsidianBlack,
                                                    border: Border.all(color: EuphireColors.mist.withValues(alpha: 0.3)),
                                                  ),
                                                  child: const Icon(Icons.person, size: 16, color: EuphireColors.mist),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    'NURT: ${session.modality}',
                                                    style: const TextStyle(
                                                      fontFamily: 'RobotoMono',
                                                      fontSize: 13,
                                                      color: EuphireColors.mist,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Zobacz więcej',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: EuphireColors.ember,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(Icons.arrow_forward, size: 18, color: EuphireColors.ember),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
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
