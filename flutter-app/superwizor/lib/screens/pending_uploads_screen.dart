// PendingUploadsScreen — full list view of the offline upload queue.
//
// Shows every row in the queue with its current phase, retry count,
// and per-row actions (retry for failed rows, dismiss for any).
// Watches pendingUploadsStreamProvider so the UI updates live as the
// runner advances rows through their phases.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';
import '../uploads/cancel_upload_action.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import 'session_status_screen.dart';

class PendingUploadsScreen extends ConsumerWidget {
  const PendingUploadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingUploadsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF173E43),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Wgrywanie',
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                color: EuphireColors.frostWhite)),
        iconTheme: const IconThemeData(color: EuphireColors.frostWhite),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Błąd: $e',
              style: const TextStyle(color: EuphireColors.frostWhite)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const _EmptyState();
          }
          // Sort: failed first (needs attention), then by queuedAt asc.
          final sorted = [...rows]..sort((a, b) {
              if (a.phase == UploadPhase.failed &&
                  b.phase != UploadPhase.failed) {
                return -1;
              }
              if (b.phase == UploadPhase.failed &&
                  a.phase != UploadPhase.failed) {
                return 1;
              }
              return a.queuedAt.compareTo(b.queuedAt);
            });
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _UploadRow(upload: sorted[i]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined,
                size: 48, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'Brak plików w kolejce',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: EuphireColors.frostWhite,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Wszystkie sesje zostały wgrane.',
              style: TextStyle(
                  fontFamily: 'Merriweather',
                  color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadRow extends ConsumerWidget {
  const _UploadRow({required this.upload});
  final PendingUpload upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isFailed = upload.phase == UploadPhase.failed;
    final isCompleted = upload.phase == UploadPhase.completed;
    final isQuotaBlocked = upload.phase == UploadPhase.quotaBlocked;
    final color = isFailed
        ? Colors.redAccent.shade200
        : isCompleted
            ? Colors.greenAccent.shade200
            : EuphireColors.ember;

    // Tap-through to the live session/upload screen. When the worker
    // has already resolved a server-side session_id (Option E — every
    // upload row carries one from CreateAudioUpload onward), navigate
    // directly to the session by id. Pre-Option-E rows that never got
    // a session_id (server didn't return one) fall back to driving the
    // status screen off the queue's localId.
    final hasSessionId =
        upload.sessionId != null && upload.sessionId!.isNotEmpty;
    final canTap = !isFailed; // failed rows: actions only, no nav

    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canTap
            ? () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SessionStatusScreen(
                    sessionId: hasSessionId ? upload.sessionId : null,
                    localId: hasSessionId ? null : upload.localId,
                  ),
                ));
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              Icon(_phaseIcon(upload.phase), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _phaseLabel(upload.phase, l),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ),
              Text(
                DateFormat('HH:mm').format(upload.queuedAt.toLocal()),
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _detailLine(upload),
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (isQuotaBlocked) ...[
            const SizedBox(height: 6),
            Text(
              // Meaningful, reworded copy instead of the raw
              // "QUOTA_EXHAUSTED" gRPC message (feat/tokens-exhausted).
              l.stepper_step1_quota_blocked,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 11,
                color: EuphireColors.ember,
              ),
            ),
          ] else if (upload.lastError != null && isFailed) ...[
            const SizedBox(height: 6),
            Text(
              upload.lastError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 10,
                color: Colors.redAccent.shade200,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Resend (un-park / retry) for quota-parked and failed rows.
              if (isFailed || isQuotaBlocked)
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(isQuotaBlocked ? l.upload_resend : 'Ponów'),
                  onPressed: () async {
                    final runner = await ref
                        .read(uploadQueueRunnerProvider.future);
                    await runner?.resend(upload.localId);
                  },
                ),
              // Completed rows just close locally — nothing to cancel.
              if (isCompleted)
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Zamknij'),
                  onPressed: () async {
                    final runner =
                        await ref.read(uploadQueueRunnerProvider.future);
                    await runner?.dismiss(upload.localId);
                  },
                )
              else
                // In-progress / parked / failed → bin = cancel processing
                // (CANCELLED_BY_USER on the server + drop local row).
                TextButton.icon(
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: Text(l.upload_cancel_processing),
                  style: TextButton.styleFrom(
                      foregroundColor: EuphireColors.magma),
                  onPressed: () => confirmAndCancelUpload(
                    context,
                    ref,
                    patientFileId: upload.patientFileId,
                    sessionId: upload.sessionId,
                    localId: upload.localId,
                  ),
                ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _phaseIcon(UploadPhase p) {
    switch (p) {
      case UploadPhase.pending:
      case UploadPhase.created:
        return Icons.schedule;
      case UploadPhase.uploaded:
      case UploadPhase.converted:
        return Icons.cloud_upload_outlined;
      case UploadPhase.completed:
        return Icons.check_circle_outline;
      case UploadPhase.failed:
        return Icons.error_outline;
      case UploadPhase.quotaBlocked:
        return Icons.account_balance_wallet_outlined;
    }
  }

  static String _phaseLabel(UploadPhase p, AppLocalizations l) {
    switch (p) {
      case UploadPhase.pending:
        return 'W kolejce';
      case UploadPhase.created:
        return 'Przesyłam...';
      case UploadPhase.uploaded:
        return 'Przesłano — finalizuję';
      case UploadPhase.converted:
        return 'Konwersja gotowa — finalizuję';
      case UploadPhase.completed:
        return 'Wgrane';
      case UploadPhase.failed:
        return 'Błąd';
      case UploadPhase.quotaBlocked:
        return l.quota_blocked_queue_label;
    }
  }

  static String _detailLine(PendingUpload u) {
    final mb = (u.sizeBytes / 1024 / 1024).toStringAsFixed(1);
    final mins = (u.actualDurationSeconds / 60).toStringAsFixed(0);
    final retry = u.attemptCount > 0 ? ' • próba ${u.attemptCount + 1}' : '';
    return '$mb MB${u.actualDurationSeconds > 0 ? " • $mins min" : ""}$retry';
  }
}
