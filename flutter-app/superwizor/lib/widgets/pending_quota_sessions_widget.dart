// PendingQuotaSessions — Kartoteka-level widget that surfaces sessions
// whose audio is sitting locally because billing said "no tokens".
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.4.2.
//
// Source of truth: upload_queue (Hive) — entries with phase=failed whose
// lastError indicates QUOTA_EXHAUSTED. We don't have a dedicated "quota
// hold" phase yet; the failed-with-quota-marker pattern survives restarts.
//
// Two actions per row:
//   - Resume processing → runner.retryFailed(localId)
//   - Delete            → confirm dialog → runner.dismiss(localId)
//
// Hidden when there are no quota-failed uploads for this patient.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_quota_provider.dart';
import '../services/billing_quota_state.dart';
import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';
import '../uploads/cancel_upload_action.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';

class PendingQuotaSessionsWidget extends ConsumerWidget {
  const PendingQuotaSessionsWidget({super.key, required this.patientFileId});

  final String patientFileId;

  bool _isQuotaFailure(PendingUpload u) {
    // Primary: the dedicated quota-hold phase (feat/tokens-exhausted).
    if (u.phase == UploadPhase.quotaBlocked) return true;
    // Legacy: rows persisted to Hive before the dedicated phase
    // existed, where a quota error was folded into `failed` with a
    // marker in lastError. Kept so an in-flight upgrade doesn't strand
    // an already-parked recording.
    final err = (u.lastError ?? '').toLowerCase();
    if (u.phase != UploadPhase.failed) return false;
    return err.contains('quota_exhausted') ||
        err.contains('quota exhausted') ||
        err.contains('resourceexhausted') ||
        err.contains('resource_exhausted');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUploads = ref.watch(pendingUploadsStreamProvider);
    final quotaState = ref.watch(billingQuotaProvider);

    return allUploads.maybeWhen(
      data: (list) {
        final stuck = list
            .where((u) => u.patientFileId == patientFileId && _isQuotaFailure(u))
            .toList(growable: false);
        if (stuck.isEmpty) return const SizedBox.shrink();

        final l = AppLocalizations.of(context);
        final q = quotaState.maybeWhen<QuotaState?>(data: (s) => s, orElse: () => null);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: EuphireColors.surfaceTeal,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: EuphireColors.ember, width: 4)),
            boxShadow: EuphireColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hourglass_top, color: EuphireColors.ember, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.billing_pending_sessions_title(stuck.length),
                        style: const TextStyle(
                          color: EuphireColors.frostWhite,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < stuck.length; i++) ...[
                  if (i > 0)
                    Divider(
                      color: EuphireColors.glassBorder,
                      height: 28,
                    ),
                  _PendingRow(upload: stuck[i]),
                ],
                if (q != null) ...[
                  const Divider(color: EuphireColors.glassBorder, height: 20),
                  Text(
                    l.billing_tokens_available_required(
                      q.tokensRemaining,
                      stuck.length,
                    ),
                    style: TextStyle(
                      color: EuphireColors.mist,
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.upload});

  final PendingUpload upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final queuedLocal = upload.queuedAt.toLocal();
    final dateStr = '${queuedLocal.day.toString().padLeft(2, '0')}.${queuedLocal.month.toString().padLeft(2, '0')}.${queuedLocal.year}';
    final timeStr = '${queuedLocal.hour.toString().padLeft(2, '0')}:${queuedLocal.minute.toString().padLeft(2, '0')}';
    final durMin = (upload.actualDurationSeconds / 60).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.billing_pending_session_card_meta(dateStr, timeStr, durMin),
            style: const TextStyle(
              color: EuphireColors.frostWhite,
              fontFamily: 'Merriweather',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.billing_pending_session_subtitle,
            style: TextStyle(
              color: EuphireColors.mist,
              fontFamily: 'RobotoMono',
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _resume(context, ref),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l.billing_resume_processing),
                style: TextButton.styleFrom(
                  foregroundColor: EuphireColors.ember,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: Text(l.billing_delete_local_audio),
                style: TextButton.styleFrom(
                  foregroundColor: EuphireColors.magma,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final runner = await ref.read(uploadQueueRunnerProvider.future);
    if (runner == null) return;
    await runner.retryFailed(upload.localId);
    if (context.mounted) {
      EuphireToast.success(context, message: AppLocalizations.of(context).billing_resume_processing);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Cancel the server session (CANCELLED_BY_USER + token release) and
    // drop the local parked row, behind a single confirm dialog.
    await confirmAndCancelUpload(
      context,
      ref,
      patientFileId: upload.patientFileId,
      sessionId: upload.sessionId,
      localId: upload.localId,
    );
  }
}
