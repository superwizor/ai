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
    showEuphireBottomSheet(
      context: context,
      builder: (_) =>
          AddSessionModal(patientId: patientId, therapistId: therapistId!),
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

          return Padding(
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
                              // For completed sessions go straight to
                              // the transcript view; in-progress ones
                              // land on the stepper screen.
                              final destination = session.status ==
                                      SessionStatus.completed
                                  ? MaterialPageRoute(
                                      builder: (_) => TranscriptScreen(
                                          sessionId: session.id))
                                  : MaterialPageRoute(
                                      builder: (_) => SessionStatusScreen(
                                          sessionId: session.id));
                              Navigator.push(context, destination);
                            },
                            child: EuphireListTile(
                              title: session.modality,
                              subtitle: dateStr,
                              trailingWidget: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: EuphireColors.mist),
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
                                        content: const Text('Czy na pewno chcesz BEZPOWROTNIE usunąć tę sesję, nagranie oraz transkrypcję? Tej operacji nie można cofnąć (wymóg RODO).', style: TextStyle(color: EuphireColors.mist)),
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
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Sesja została usunięta.')),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Wystąpił błąd: $e')),
                                                  );
                                                }
                                              }
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
                                          decoration: const InputDecoration(
                                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: EuphireColors.mist)),
                                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: EuphireColors.ember)),
                                          ),
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
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Wystąpił błąd: $e')),
                                                    );
                                                  }
                                                }
                                              } else {
                                                Navigator.pop(context);
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
