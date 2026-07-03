// ClientFileScreen — a single kartoteka from the client's perspective
// (docs/39): shared sessions + notes (therapist's shared + own), with
// a composer to send a new note to the therapist.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'client_home_screen.dart' show clientOverviewProvider;
import 'client_session_screen.dart';

final clientSessionsProvider = FutureProvider.autoDispose
    .family<clinical_pb.ClientListSessionsResponse, String>((ref, pfID) async {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  return clinical.clientListSessions(
      clinical_pb.ClientListSessionsRequest(patientFileId: pfID));
});

final clientNotesProvider = FutureProvider.autoDispose
    .family<clinical_pb.ClientListNotesResponse, String>((ref, pfID) async {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  return clinical.clientListNotes(
      clinical_pb.ClientListNotesRequest(patientFileId: pfID));
});

class ClientFileScreen extends ConsumerWidget {
  const ClientFileScreen({super.key, required this.kartoteka});
  final clinical_pb.ClientKartoteka kartoteka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: EuphireColors.deepTealBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(kartoteka.therapistName),
          bottom: TabBar(
            indicatorColor: EuphireColors.ember,
            labelColor: EuphireColors.ember,
            unselectedLabelColor: EuphireColors.mist,
            tabs: [
              Tab(text: l10n.client_tab_sessions),
              Tab(text: l10n.client_tab_notes),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: EuphireColors.ember,
          foregroundColor: EuphireColors.obsidianBlack,
          icon: const Icon(Icons.edit_note),
          label: Text(l10n.client_note_new),
          onPressed: () => _openNoteComposer(context, ref),
        ),
        body: TabBarView(
          children: [
            _SessionsTab(pfID: kartoteka.patientFileId),
            _NotesTab(pfID: kartoteka.patientFileId),
          ],
        ),
      ),
    );
  }

  Future<void> _openNoteComposer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: EuphireColors.surfaceTeal,
        title: Text(l10n.client_note_new,
            style: const TextStyle(color: EuphireColors.frostWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: EuphireColors.frostWhite),
              decoration: InputDecoration(
                hintText: l10n.client_note_title_hint,
                hintStyle: const TextStyle(color: EuphireColors.mist),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              style: const TextStyle(color: EuphireColors.frostWhite),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.client_note_text_hint,
                hintStyle: const TextStyle(color: EuphireColors.mist),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('✕'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EuphireColors.ember,
              foregroundColor: EuphireColors.obsidianBlack,
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty &&
                  textCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.client_note_empty_error)));
                return;
              }
              try {
                final clinical = ref.read(grpcClientsProvider).clinical;
                await clinical.clientCreateNote(
                  clinical_pb.ClientCreateNoteRequest(
                    patientFileId: kartoteka.patientFileId,
                    title: titleCtrl.text.trim(),
                    text: textCtrl.text.trim(),
                  ),
                );
                if (dctx.mounted) Navigator.of(dctx).pop(true);
              } catch (e) {
                if (dctx.mounted) {
                  ScaffoldMessenger.of(dctx)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text(l10n.client_note_send),
          ),
        ],
      ),
    );

    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.client_note_sent)));
      ref.invalidate(clientNotesProvider(kartoteka.patientFileId));
      ref.invalidate(clientOverviewProvider);
    }
  }
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab({required this.pfID});
  final String pfID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(clientSessionsProvider(pfID));
    return sessions.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: EuphireColors.ember)),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.client_home_error(err.toString()),
              style: const TextStyle(color: EuphireColors.mist)),
        ),
      ),
      data: (data) {
        if (data.sessions.isEmpty) {
          return Center(
            child: Text(l10n.client_sessions_empty,
                style: const TextStyle(color: EuphireColors.mist)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.sessions.length,
          itemBuilder: (ctx, i) {
            final s = data.sessions[i];
            final minutes = (s.durationSeconds / 60).round();
            return Card(
              color: EuphireColors.surfaceTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: EuphireColors.glassBorder),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                  l10n.client_session_title(s.sessionNumber),
                  style: const TextStyle(color: EuphireColors.frostWhite),
                ),
                subtitle: Text(
                  minutes > 0 ? '${s.sessionDate} · $minutes min' : s.sessionDate,
                  style: const TextStyle(color: EuphireColors.mist),
                ),
                trailing: s.hasTranscript
                    ? const Icon(Icons.article_outlined,
                        color: EuphireColors.ember)
                    : const Icon(Icons.hourglass_empty,
                        color: EuphireColors.mist),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClientSessionScreen(session: s),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.pfID});
  final String pfID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notes = ref.watch(clientNotesProvider(pfID));
    return notes.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: EuphireColors.ember)),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.client_home_error(err.toString()),
              style: const TextStyle(color: EuphireColors.mist)),
        ),
      ),
      data: (data) {
        if (data.notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.client_notes_empty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: EuphireColors.mist)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: data.notes.length,
          itemBuilder: (ctx, i) {
            final n = data.notes[i];
            final mine = n.authorRole == 'PATIENT';
            final unread = !mine && !n.read;
            return Card(
              color: EuphireColors.surfaceTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: unread ? EuphireColors.ember : EuphireColors.glassBorder,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                onExpansionChanged: (open) {
                  if (open && unread) {
                    final clinical = ref.read(grpcClientsProvider).clinical;
                    clinical
                        .clientMarkNoteRead(
                            clinical_pb.ClientMarkNoteReadRequest(noteId: n.id))
                        .then((_) {
                      ref.invalidate(clientNotesProvider(pfID));
                      ref.invalidate(clientOverviewProvider);
                    }).catchError((_) {});
                  }
                },
                iconColor: EuphireColors.ember,
                collapsedIconColor: EuphireColors.mist,
                title: Text(
                  n.title.isEmpty ? '—' : n.title,
                  style: const TextStyle(color: EuphireColors.frostWhite),
                ),
                subtitle: Text(
                  mine
                      ? l10n.client_note_mine
                      : l10n.client_note_from_therapist,
                  style: TextStyle(
                    color: mine ? EuphireColors.mist : EuphireColors.ember,
                    fontSize: 12,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        n.text,
                        style: const TextStyle(
                            color: EuphireColors.frostWhite, height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
