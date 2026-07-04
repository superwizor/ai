// ClientSessionScreen — read-only transcript viewer for a shared
// session (docs/39). Light palette matching ClientHomeScreen v2.
// Renders speaker turns exactly as the backend grouped them; no
// editing, no reports, no pipeline internals.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import 'client_home_screen.dart' show ClientColors;

final clientTranscriptProvider = FutureProvider.autoDispose
    .family<clinical_pb.ClientGetTranscriptResponse, String>((ref, sessionID) async {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  return clinical.clientGetTranscript(
      clinical_pb.ClientGetTranscriptRequest(sessionId: sessionID));
});

class ClientSessionScreen extends ConsumerWidget {
  const ClientSessionScreen({super.key, required this.session});
  final clinical_pb.ClientSessionInfo session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final transcript = ref.watch(clientTranscriptProvider(session.sessionId));

    return Scaffold(
      backgroundColor: ClientColors.bg,
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
}
