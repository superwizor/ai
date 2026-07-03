// ClientHomeScreen — the client (patient) panel's landing view
// (docs/39, web-only MVP). Lists the client's kartoteki (usually one)
// with shared/unread counters; tapping opens the sessions+notes tabs.
//
// Deliberately minimal chrome: no recording, no billing, no therapist
// settings. The _AuthGate routes role=PATIENT here before any
// therapist surface is reachable.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart'
    as pb_empty;
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'client_file_screen.dart';

final clientOverviewProvider =
    FutureProvider.autoDispose<clinical_pb.ClientOverview>((ref) async {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  return clinical.clientGetMyOverview(pb_empty.Empty());
});

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(clientOverviewProvider);

    return Scaffold(
      backgroundColor: EuphireColors.deepTealBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.client_home_title),
        actions: [
          IconButton(
            tooltip: l10n.client_logout,
            icon: const Icon(Icons.logout, color: EuphireColors.mist),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: EuphireColors.ember,
          onRefresh: () async => ref.refresh(clientOverviewProvider.future),
          child: overview.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: EuphireColors.ember),
            ),
            error: (err, _) => ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.client_home_error(err.toString()),
                    style: const TextStyle(color: EuphireColors.mist),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            data: (data) {
              if (data.kartoteki.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.client_home_empty,
                        style: const TextStyle(color: EuphireColors.mist),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.client_home_subtitle,
                      style: const TextStyle(color: EuphireColors.mist),
                    ),
                  ),
                  ...data.kartoteki.map((k) => _KartotekaCard(k: k)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KartotekaCard extends ConsumerWidget {
  const _KartotekaCard({required this.k});
  final clinical_pb.ClientKartoteka k;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: EuphireColors.surfaceTeal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EuphireColors.glassBorder),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          l10n.client_kartoteka_therapist(k.therapistName),
          style: const TextStyle(
            color: EuphireColors.frostWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          l10n.client_kartoteka_counts(k.sharedSessions, k.sharedNotes),
          style: const TextStyle(color: EuphireColors.mist),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (k.unreadNotes > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: EuphireColors.ember,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.client_unread_badge(k.unreadNotes),
                  style: const TextStyle(
                    color: EuphireColors.obsidianBlack,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: EuphireColors.mist),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientFileScreen(kartoteka: k),
            ),
          );
        },
      ),
    );
  }
}
