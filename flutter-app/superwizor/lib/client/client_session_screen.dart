// ClientSessionScreen — read-only transcript viewer for a shared
// session (docs/39). Light palette matching ClientHomeScreen v2.
// Renders speaker turns exactly as the backend grouped them; no
// editing, no reports, no pipeline internals.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import 'client_home_screen.dart' show ClientColors, clientHomeProvider;

final clientTranscriptProvider = FutureProvider.autoDispose
    .family<clinical_pb.ClientGetTranscriptResponse, String>((ref, sessionID) async {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  return clinical.clientGetTranscript(
      clinical_pb.ClientGetTranscriptRequest(sessionId: sessionID));
});

class ClientSessionScreen extends ConsumerWidget {
  const ClientSessionScreen({
    super.key,
    required this.session,
    required this.patientFileId,
  });
  final clinical_pb.ClientSessionInfo session;
  final String patientFileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final transcript = ref.watch(clientTranscriptProvider(session.sessionId));

    return Scaffold(
      backgroundColor: ClientColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ClientColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note),
        label: Text(l10n.client_session_add_note),
        onPressed: () => _addSessionNote(context, ref, l10n),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ClientColors.ink),
        title: Text(
          '${l10n.client_session_title(session.sessionNumber)} · ${session.sessionDate}',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: ClientColors.ink,
          ),
        ),
      ),
      body: transcript.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: ClientColors.accent)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.client_home_error(err.toString()),
                style: const TextStyle(
                    fontFamily: 'Montserrat', color: ClientColors.muted)),
          ),
        ),
        data: (data) {
          final turns = data.transcript.turns;
          if (!data.hasTranscript() || turns.isEmpty) {
            return Center(
              child: Text(l10n.client_session_no_transcript,
                  style: const TextStyle(
                      fontFamily: 'Montserrat', color: ClientColors.muted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: turns.length,
            itemBuilder: (ctx, i) {
              final turn = turns[i];
              final isTherapist =
                  turn.speakerLabel.toLowerCase().startsWith('terapeuta') ||
                      turn.speakerLabel.toLowerCase().startsWith('therapist');
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turn.speakerLabel,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: isTherapist
                            ? ClientColors.accent
                            : ClientColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      turn.text,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: ClientColors.ink,
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Compose a note from the session view. Same two-button contract as
  // the home composer: save a private draft or save-and-send. The note
  // is a plain CLIENT_NOTE on this kartoteka (the panel timeline shows
  // it); its title defaults to the session label for context.
  Future<void> _addSessionNote(
    BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final titleCtrl = TextEditingController(
        text:
            '${l10n.client_session_title(session.sessionNumber)} · ${session.sessionDate}');
    final textCtrl = TextEditingController();

    Future<void> submit(BuildContext dctx, bool send) async {
      if (textCtrl.text.trim().isEmpty && titleCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(dctx).showSnackBar(
            SnackBar(content: Text(l10n.client_note_empty_error)));
        return;
      }
      try {
        final clinical = ref.read(grpcClientsProvider).clinical;
        await clinical.clientCreateNote(clinical_pb.ClientCreateNoteRequest(
          patientFileId: patientFileId,
          title: titleCtrl.text.trim(),
          text: textCtrl.text.trim(),
          sendToTherapist: send,
        ));
        if (dctx.mounted) Navigator.of(dctx).pop(send);
      } catch (e) {
        if (dctx.mounted) {
          ScaffoldMessenger.of(dctx)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }

    final sent = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: ClientColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.client_session_add_note,
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: ClientColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(
                  fontFamily: 'Montserrat', color: ClientColors.ink),
              decoration: InputDecoration(
                hintText: l10n.client_note_title_hint,
                hintStyle: const TextStyle(color: ClientColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              maxLines: 6,
              autofocus: true,
              style: const TextStyle(
                  fontFamily: 'Montserrat', color: ClientColors.ink),
              decoration: InputDecoration(
                hintText: l10n.client_note_text_hint,
                hintStyle: const TextStyle(color: ClientColors.muted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(null),
            child: Text(l10n.client_note_close,
                style: const TextStyle(color: ClientColors.muted)),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: ClientColors.accent,
              side: const BorderSide(color: ClientColors.accent),
            ),
            onPressed: () => submit(dctx, false),
            child: Text(l10n.client_note_save),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ClientColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => submit(dctx, true),
            child: Text(l10n.client_note_save_and_send),
          ),
        ],
      ),
    );

    if (sent != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              sent ? l10n.client_note_sent : l10n.client_note_saved_draft)));
      ref.invalidate(clientHomeProvider);
    }
  }
}
