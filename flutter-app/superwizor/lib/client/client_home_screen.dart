// ClientHomeScreen — the client (patient) panel (docs/39, redesign PR13).
// One merged timeline of shared sessions + notes (both directions), newest
// first, now in the Superwizor design language (Montserrat, Ember accent)
// with a light/dark toggle (dark = the therapist app's Evergreen green).
// Filters narrow the timeline (all / sessions / therapist tasks+notes /
// own notes). Cards carry a management menu: own notes hard-delete, shared
// items hide from the panel only. The FAB composes a note to the therapist.

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
import 'client_theme.dart';

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

  bool get isTherapistNote => note != null && note!.authorRole == 'THERAPIST';
  bool get isOwnNote => note != null && note!.authorRole == 'PATIENT';
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

List<ClientTimelineItem> _applyFilter(
    List<ClientTimelineItem> items, Set<ClientFilter> active) {
  if (active.isEmpty) return items; // nothing selected = show everything
  return items.where((i) {
    if (i.session != null) return active.contains(ClientFilter.sessions);
    if (i.isTherapistNote) return active.contains(ClientFilter.therapist);
    if (i.isOwnNote) return active.contains(ClientFilter.own);
    return false;
  }).toList();
}

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(clientDarkProvider);
    // The client surface runs on its own ThemeData so dialogs/fields/
    // snackbars pick up the palette too.
    return Theme(
      data: clientThemeData(dark),
      child: Builder(builder: (context) => _ClientHomeBody(dark: dark)),
    );
  }
}

class _ClientHomeBody extends ConsumerWidget {
  const _ClientHomeBody({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.cp;
    final home = ref.watch(clientHomeProvider);
    final filter = ref.watch(clientFiltersProvider);
    final user = ref.watch(currentUserProvider).value;
    final displayName =
        [user?.firstName ?? '', user?.lastName ?? ''].join(' ').trim();

    return Scaffold(
      backgroundColor: p.bg,
      floatingActionButton: home.maybeWhen(
        data: (d) => d.overview.kartoteki.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                onPressed: () => _openNoteComposer(context, ref, d.overview),
                icon: const Icon(Icons.edit_note),
                label: Text(l10n.client_note_new,
                    style: const TextStyle(
                        fontFamily: 'Montserrat', fontWeight: FontWeight.w700)),
              ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: p.accent,
          backgroundColor: p.card,
          onRefresh: () async => ref.refresh(clientHomeProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: l10n.client_theme_tooltip,
                            icon: Icon(
                                dark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                color: p.muted,
                                size: 22),
                            onPressed: () =>
                                ref.read(clientDarkProvider.notifier).toggle(),
                          ),
                          IconButton(
                            tooltip: l10n.client_logout,
                            icon: Icon(Icons.logout, color: p.muted, size: 22),
                            onPressed: () => FirebaseAuth.instance.signOut(),
                          ),
                        ],
                      ),
                      Text(
                        displayName.isEmpty ? l10n.client_home_title : displayName,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          height: 1.1,
                          letterSpacing: -0.4,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.client_home_title,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: p.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FilterBar(selected: filter),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              home.when(
                loading: () => SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: p.accent)),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.client_home_error(err.toString()),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Montserrat', color: p.muted),
                      ),
                    ),
                  ),
                ),
                data: (d) {
                  final items = _applyFilter(d.items, filter);
                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            d.items.isEmpty
                                ? l10n.client_home_empty
                                : l10n.client_filter_empty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 15,
                                color: p.muted),
                          ),
                        ),
                      ),
                    );
                  }
                  final manyTherapists = d.overview.kartoteki.length > 1;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 96),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
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
    final p = context.cp;
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    var targetPf = overview.kartoteki.first.patientFileId;

    final sent = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setState) => AlertDialog(
          backgroundColor: p.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.client_note_new,
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: p.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overview.kartoteki.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: targetPf,
                  dropdownColor: p.card,
                  items: overview.kartoteki
                      .map((k) => DropdownMenuItem(
                            value: k.patientFileId,
                            child: Text(k.therapistName,
                                style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                    color: p.ink)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => targetPf = v ?? targetPf),
                ),
              TextField(
                controller: titleCtrl,
                style: TextStyle(fontFamily: 'Montserrat', color: p.ink),
                decoration: InputDecoration(
                  hintText: l10n.client_note_title_hint,
                  hintStyle: TextStyle(color: p.muted),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                maxLines: 6,
                style: TextStyle(fontFamily: 'Montserrat', color: p.ink),
                decoration: InputDecoration(
                  hintText: l10n.client_note_text_hint,
                  hintStyle: TextStyle(color: p.muted),
                ),
              ),
            ],
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(null),
              child: Text('✕', style: TextStyle(color: p.muted)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
              onPressed: () async {
                await _submitNote(context, dctx, ref, targetPf,
                    titleCtrl.text, textCtrl.text, false, l10n);
              },
              child: Text(l10n.client_note_save),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
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
          content: Text(
              sent ? l10n.client_note_sent : l10n.client_note_saved_draft)));
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

// ── Filter bar ───────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});
  final Set<ClientFilter> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      ClientFilter.sessions: l10n.client_filter_sessions,
      ClientFilter.therapist: l10n.client_filter_therapist,
      ClientFilter.own: l10n.client_filter_own,
    };
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in ClientFilter.values) ...[
            _FilterChip(
              label: labels[f]!,
              active: selected.contains(f),
              onTap: () =>
                  ref.read(clientFiltersProvider.notifier).toggle(f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cp;
    return Material(
      color: active ? p.accent : p.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? p.accent : p.border, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? p.onAccent : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Session card ─────────────────────────────────────────────────────

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.item, required this.showTherapist});
  final ClientTimelineItem item;
  final bool showTherapist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.cp;
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
      leading: _LeadingTile(
        bg: p.greenSoft,
        child: Text('#${s.sessionNumber}',
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: p.green)),
      ),
      title: l10n.client_session_title(s.sessionNumber),
      titleTrailing: s.hasTranscript
          ? _Chip(
              text: l10n.client_session_transcript_chip,
              fg: p.green,
              bg: p.greenSoft)
          : null,
      subtitle: meta,
      // Shared item → hide from panel only.
      onManage: () => _hideItem(context, ref, l10n, p,
          kind: 'SESSION', id: s.sessionId),
      manageLabel: l10n.client_action_hide,
      manageIcon: Icons.visibility_off_outlined,
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
    final p = context.cp;
    final n = item.note!;
    final mine = n.authorRole == 'PATIENT';
    final unread = !mine && !n.read;
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
      onTap: () => _openNote(context, ref, l10n, p, unread, isDraft),
      leading: _LeadingTile(
        bg: mine ? p.accentSoft : p.greenSoft,
        child: Text(mine ? '💬' : '📝', style: const TextStyle(fontSize: 20)),
      ),
      title: n.title.isEmpty ? l10n.client_note_from_therapist : n.title,
      titleTrailing: unread
          ? _Chip(text: l10n.client_new_badge, fg: p.onAccent, bg: p.accent)
          : isDraft
              ? _Chip(
                  text: l10n.client_note_draft_badge,
                  fg: p.accent,
                  bg: p.accentSoft)
              : null,
      subtitle: meta,
      snippet: n.text,
      // Own note → hard delete; therapist note → hide from panel.
      onManage: mine
          ? () => _deleteOwnNote(context, ref, l10n, p, n)
          : () => _hideItem(context, ref, l10n, p, kind: 'NOTE', id: n.id),
      manageLabel:
          mine ? l10n.client_action_delete : l10n.client_action_hide,
      manageIcon:
          mine ? Icons.delete_outline : Icons.visibility_off_outlined,
      manageDestructive: mine,
    );
  }

  Future<void> _openNote(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, ClientPalette p, bool unread, bool isDraft) async {
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
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          n.title.isEmpty ? l10n.client_note_from_therapist : n.title,
          style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: p.ink),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            n.text,
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                height: 1.55,
                color: p.ink),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(l10n.client_note_close,
                style: TextStyle(color: p.muted)),
          ),
          if (isDraft)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
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

// ── Delete / hide actions (shared by both card types) ────────────────

Future<void> _deleteOwnNote(BuildContext context, WidgetRef ref,
    AppLocalizations l10n, ClientPalette p, clinical_pb.ClientNote n) async {
  final ok = await _confirm(context, p,
      title: l10n.client_delete_confirm_title,
      body: l10n.client_delete_confirm_body,
      confirmLabel: l10n.client_confirm_delete,
      cancelLabel: l10n.client_confirm_cancel,
      destructive: true);
  if (ok != true || !context.mounted) return;
  try {
    await ref
        .read(grpcClientsProvider)
        .clinical
        .clientDeleteNote(clinical_pb.ClientDeleteNoteRequest(noteId: n.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.client_deleted_toast)));
    }
    ref.invalidate(clientHomeProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

Future<void> _hideItem(BuildContext context, WidgetRef ref,
    AppLocalizations l10n, ClientPalette p,
    {required String kind, required String id}) async {
  final ok = await _confirm(context, p,
      title: l10n.client_hide_confirm_title,
      body: l10n.client_hide_confirm_body,
      confirmLabel: l10n.client_confirm_hide,
      cancelLabel: l10n.client_confirm_cancel,
      destructive: false);
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(grpcClientsProvider).clinical.clientHideItem(
        clinical_pb.ClientHideItemRequest(itemKind: kind, itemId: id));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.client_hidden_toast)));
    }
    ref.invalidate(clientHomeProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

Future<bool?> _confirm(BuildContext context, ClientPalette p,
    {required String title,
    required String body,
    required String confirmLabel,
    required String cancelLabel,
    required bool destructive}) {
  return showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: p.ink)),
      content: Text(body,
          style: TextStyle(
              fontFamily: 'Montserrat', fontSize: 14, height: 1.5, color: p.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          child: Text(cancelLabel, style: TextStyle(color: p.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? const Color(0xFFD84515) : p.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

// ── Shared card chrome ───────────────────────────────────────────────

class _LeadingTile extends StatelessWidget {
  const _LeadingTile({required this.bg, required this.child});
  final Color bg;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: child,
      );
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.titleTrailing,
    this.snippet,
    this.onTap,
    this.highlighted = false,
    this.onManage,
    this.manageLabel,
    this.manageIcon,
    this.manageDestructive = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? titleTrailing;
  final String? snippet;
  final VoidCallback? onTap;
  final bool highlighted;
  final VoidCallback? onManage;
  final String? manageLabel;
  final IconData? manageIcon;
  final bool manageDestructive;

  @override
  Widget build(BuildContext context) {
    final p = context.cp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted
                    ? p.accent.withValues(alpha: 0.55)
                    : p.border,
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
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: p.ink,
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
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            height: 1.4,
                            color: p.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onManage != null)
                  _ManageButton(
                    onManage: onManage!,
                    label: manageLabel ?? '',
                    icon: manageIcon ?? Icons.more_horiz,
                    destructive: manageDestructive,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageButton extends StatelessWidget {
  const _ManageButton({
    required this.onManage,
    required this.label,
    required this.icon,
    required this.destructive,
  });
  final VoidCallback onManage;
  final String label;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.cp;
    return PopupMenuButton<int>(
      icon: Icon(Icons.more_vert, color: p.muted, size: 20),
      color: p.card,
      tooltip: '',
      onSelected: (_) => onManage(),
      itemBuilder: (ctx) => [
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: destructive ? const Color(0xFFD84515) : p.ink),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color:
                          destructive ? const Color(0xFFD84515) : p.ink)),
            ],
          ),
        ),
      ],
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
