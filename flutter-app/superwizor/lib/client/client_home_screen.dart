// ClientHomeScreen — the client (patient) panel, v2 (docs/39 + live
// feedback 2026-07-04): a SINGLE light-themed screen modeled on the
// therapist's kartoteka view. Header = client's name, subtitle "Twoja
// terapia", then one merged timeline of shared sessions and notes
// (both directions), newest first. The FAB only composes a note to the
// therapist. Deliberately NO navigation, NO settings — the only exits
// are the logout icon and tapping a session to read its transcript.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart'
    as pb_empty;

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import 'client_session_screen.dart';

// ── Light palette (this surface only — the therapist app stays dark) ─
class ClientColors {
  static const bg = Color(0xFFF7F5F0); // warm off-white
  static const card = Colors.white;
  static const border = Color(0xFFE6E2D8);
  static const ink = Color(0xFF11302F); // deep teal ink
  static const muted = Color(0xFF6E7F7D);
  static const accent = Color(0xFFE8930C); // ember on light
  static const accentSoft = Color(0xFFFBEDD3);
  static const green = Color(0xFF1D7A46);
  static const greenSoft = Color(0xFFE2F2E7);
}

/// One row of the merged timeline: exactly one of [session] / [note].
class ClientTimelineItem {
  final clinical_pb.ClientKartoteka kartoteka;
  final clinical_pb.ClientSessionInfo? session;
  final clinical_pb.ClientNote? note;

  const ClientTimelineItem._(this.kartoteka, {this.session, this.note});

  DateTime get sortDate {
    if (note != null && note!.hasCreatedAt()) {
      return note!.createdAt.toDateTime().toLocal();
    }
    if (session != null) {
      return DateTime.tryParse(session!.sessionDate) ?? DateTime(2000);
    }
    return DateTime(2000);
  }
}

class ClientHome {
  final clinical_pb.ClientOverview overview;
  final List<ClientTimelineItem> items;
  const ClientHome(this.overview, this.items);
}

/// Fetches the overview and, per kartoteka, its shared sessions +
/// visible notes — merged into one date-sorted timeline.
final clientHomeProvider =
    FutureProvider.autoDispose<ClientHome>((ref) async {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  final overview = await clinical.clientGetMyOverview(pb_empty.Empty());

  final items = <ClientTimelineItem>[];
  await Future.wait(overview.kartoteki.map((k) async {
    final results = await Future.wait([
      clinical.clientListSessions(
          clinical_pb.ClientListSessionsRequest(patientFileId: k.patientFileId)),
      clinical.clientListNotes(
          clinical_pb.ClientListNotesRequest(patientFileId: k.patientFileId)),
    ]);
    final sessions = results[0] as clinical_pb.ClientListSessionsResponse;
    final notes = results[1] as clinical_pb.ClientListNotesResponse;
    items.addAll(
        sessions.sessions.map((s) => ClientTimelineItem._(k, session: s)));
    items.addAll(notes.notes.map((n) => ClientTimelineItem._(k, note: n)));
  }));
  items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
  return ClientHome(overview, items);
});

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(clientHomeProvider);
    final user = ref.watch(currentUserProvider).value;
    final displayName =
        [user?.firstName ?? '', user?.lastName ?? ''].join(' ').trim();

    return Scaffold(
      backgroundColor: ClientColors.bg,
      floatingActionButton: home.maybeWhen(
        data: (d) => d.overview.kartoteki.isEmpty
            ? null
            : FloatingActionButton(
                backgroundColor: ClientColors.accent,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: () => _openNoteComposer(context, ref, d.overview),
                child: const Icon(Icons.add, size: 30),
              ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: ClientColors.accent,
          onRefresh: () async => ref.refresh(clientHomeProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: l10n.client_logout,
                            icon: const Icon(Icons.logout,
                                color: ClientColors.muted, size: 22),
                            onPressed: () => FirebaseAuth.instance.signOut(),
                          ),
                        ],
                      ),
                      Text(
                        displayName.isEmpty ? l10n.client_home_title : displayName,
                        style: const TextStyle(
                          fontFamily: 'Merriweather',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                          fontSize: 34,
                          height: 1.1,
                          color: ClientColors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.client_home_title, // "Twoja terapia"
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          color: ClientColors.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              home.when(
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: ClientColors.accent),
                  ),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.client_home_error(err.toString()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Montserrat',
                            color: ClientColors.muted),
                      ),
                    ),
                  ),
                ),
                data: (d) {
                  if (d.items.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l10n.client_home_empty,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 15,
                                color: ClientColors.muted),
                          ),
                        ),
                      ),
                    );
                  }
                  final manyTherapists = d.overview.kartoteki.length > 1;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                    sliver: SliverList.builder(
                      itemCount: d.items.length,
                      itemBuilder: (ctx, i) {
                        final item = d.items[i];
                        return item.session != null
                            ? _SessionCard(
                                item: item, showTherapist: manyTherapists)
                            : _NoteCard(
                                item: item, showTherapist: manyTherapists);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNoteComposer(
    BuildContext context,
    WidgetRef ref,
    clinical_pb.ClientOverview overview,
  ) async {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    var targetPf = overview.kartoteki.first.patientFileId;

    final sent = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setState) => AlertDialog(
          backgroundColor: ClientColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.client_note_new,
              style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: ClientColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overview.kartoteki.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: targetPf,
                  items: overview.kartoteki
                      .map((k) => DropdownMenuItem(
                            value: k.patientFileId,
                            child: Text(k.therapistName,
                                style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                    color: ClientColors.ink)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => targetPf = v ?? targetPf),
                ),
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
                style: const TextStyle(
                    fontFamily: 'Montserrat', color: ClientColors.ink),
                decoration: InputDecoration(
                  hintText: l10n.client_note_text_hint,
                  hintStyle: const TextStyle(color: ClientColors.muted),
                ),
              ),
            ],
          ),
          // Two actions (docs/39 live-feedback): save a private draft or
          // save-and-deliver to the therapist in one go.
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(null),
              child: const Text('✕',
                  style: TextStyle(color: ClientColors.muted)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ClientColors.accent,
                side: const BorderSide(color: ClientColors.accent),
              ),
              onPressed: () async {
                await _submitNote(context, dctx, ref, targetPf,
                    titleCtrl.text, textCtrl.text, false, l10n);
              },
              child: Text(l10n.client_note_save),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ClientColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _submitNote(context, dctx, ref, targetPf,
                    titleCtrl.text, textCtrl.text, true, l10n);
              },
              child: Text(l10n.client_note_save_and_send),
            ),
          ],
        ),
      ),
    );

    if (sent != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sent
              ? l10n.client_note_sent
              : l10n.client_note_saved_draft)));
      ref.invalidate(clientHomeProvider);
    }
  }

  Future<void> _submitNote(
    BuildContext outerCtx,
    BuildContext dctx,
    WidgetRef ref,
    String targetPf,
    String title,
    String text,
    bool send,
    AppLocalizations l10n,
  ) async {
    if (title.trim().isEmpty && text.trim().isEmpty) {
      ScaffoldMessenger.of(dctx)
          .showSnackBar(SnackBar(content: Text(l10n.client_note_empty_error)));
      return;
    }
    try {
      final clinical = ref.read(grpcClientsProvider).clinical;
      await clinical.clientCreateNote(
        clinical_pb.ClientCreateNoteRequest(
          patientFileId: targetPf,
          title: title.trim(),
          text: text.trim(),
          sendToTherapist: send,
        ),
      );
      if (dctx.mounted) Navigator.of(dctx).pop(send);
    } catch (e) {
      if (dctx.mounted) {
        ScaffoldMessenger.of(dctx)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

// ── Session card (mirrors the therapist timeline card, light) ───────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, required this.showTherapist});
  final ClientTimelineItem item;
  final bool showTherapist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = item.session!;
    final minutes = (s.durationSeconds / 60).round();
    final date = DateTime.tryParse(s.sessionDate);
    final dateStr = date != null
        ? DateFormat('d MMM', Localizations.localeOf(context).languageCode)
            .format(date)
        : s.sessionDate;
    final meta = [
      dateStr,
      if (minutes > 0) '$minutes min',
      if (showTherapist) item.kartoteka.therapistName,
    ].join('  ·  ');

    return _CardShell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientSessionScreen(
            session: s,
            patientFileId: item.kartoteka.patientFileId,
          ),
        ),
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ClientColors.greenSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '#${s.sessionNumber}',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: ClientColors.green,
          ),
        ),
      ),
      title: l10n.client_session_title(s.sessionNumber),
      titleTrailing: s.hasTranscript
          ? _Chip(
              text: l10n.client_session_transcript_chip,
              fg: ClientColors.green,
              bg: ClientColors.greenSoft)
          : null,
      subtitle: meta,
    );
  }
}

// ── Note card ────────────────────────────────────────────────────────

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.item, required this.showTherapist});
  final ClientTimelineItem item;
  final bool showTherapist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final n = item.note!;
    final mine = n.authorRole == 'PATIENT';
    final unread = !mine && !n.read;
    // A client note not yet delivered to the therapist (000068 draft).
    final isDraft = mine && !n.hasSentToTherapistAt();
    final created =
        n.hasCreatedAt() ? n.createdAt.toDateTime().toLocal() : null;
    final dateStr = created != null
        ? DateFormat('d MMM · HH:mm',
                Localizations.localeOf(context).languageCode)
            .format(created)
        : '';
    final meta = [
      mine
          ? (isDraft ? l10n.client_note_mine_draft : l10n.client_note_mine_sent)
          : l10n.client_note_from_therapist,
      dateStr,
      if (showTherapist && !mine) item.kartoteka.therapistName,
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return _CardShell(
      highlighted: unread || isDraft,
      onTap: () => _openNote(context, ref, l10n, unread, isDraft),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ClientColors.accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(mine ? '💬' : '📝', style: const TextStyle(fontSize: 20)),
      ),
      title: n.title.isEmpty ? l10n.client_note_from_therapist : n.title,
      titleTrailing: unread
          ? _Chip(
              text: l10n.client_new_badge,
              fg: Colors.white,
              bg: ClientColors.accent)
          : isDraft
              ? _Chip(
                  text: l10n.client_note_draft_badge,
                  fg: ClientColors.accent,
                  bg: ClientColors.accentSoft)
              : null,
      subtitle: meta,
      snippet: n.text,
    );
  }

  Future<void> _openNote(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, bool unread, bool isDraft) async {
    final n = item.note!;
    if (unread) {
      final clinical = ref.read(grpcClientsProvider).clinical;
      clinical
          .clientMarkNoteRead(
              clinical_pb.ClientMarkNoteReadRequest(noteId: n.id))
          .then((_) => ref.invalidate(clientHomeProvider))
          .catchError((_) {});
    }
    final send = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: ClientColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          n.title.isEmpty ? l10n.client_note_from_therapist : n.title,
          style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: ClientColors.ink),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            n.text,
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                height: 1.55,
                color: ClientColors.ink),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(l10n.client_note_close,
                style: const TextStyle(color: ClientColors.muted)),
          ),
          // "Wyślij do terapeuty" — only on the client's own drafts.
          if (isDraft)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ClientColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(l10n.client_note_send),
            ),
        ],
      ),
    );

    if (send == true && context.mounted) {
      try {
        final clinical = ref.read(grpcClientsProvider).clinical;
        await clinical
            .clientSendNote(clinical_pb.ClientSendNoteRequest(noteId: n.id));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.client_note_sent)));
        }
        ref.invalidate(clientHomeProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}

// ── Shared card chrome ───────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.titleTrailing,
    this.snippet,
    this.onTap,
    this.highlighted = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? titleTrailing;
  final String? snippet;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ClientColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    highlighted ? ClientColors.accent : ClientColors.border,
                width: highlighted ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: ClientColors.ink,
                              ),
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 8),
                            titleTrailing!,
                          ],
                        ],
                      ),
                      if (snippet != null && snippet!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          snippet!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            height: 1.4,
                            color: ClientColors.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: ClientColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.fg, required this.bg});
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
