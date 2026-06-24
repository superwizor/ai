// RecordingRecoveryGuard — zero-size widget mounted on the home screen
// that surfaces orphaned recordings found by the once-per-launch scan
// (docs/28 WS1) and walks the user through send / later / delete.
//
// "Orphaned" = the app died mid-recording (classically: killed while
// backgrounded during a phone call) leaving raw.flac + manifest.json on
// disk with no upload-queue row. Recovery hands the partial FLAC to the
// durable upload queue — the same pipeline a normal stop uses — so the
// session still gets its transcript + report.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../analytics/analytics_collector.dart';
import '../l10n/app_localizations.dart';
import '../providers/recording_recovery_provider.dart';
import '../services/recording_recovery_service.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_toast.dart';

class RecordingRecoveryGuard extends ConsumerStatefulWidget {
  const RecordingRecoveryGuard({super.key});

  @override
  ConsumerState<RecordingRecoveryGuard> createState() =>
      _RecordingRecoveryGuardState();
}

class _RecordingRecoveryGuardState
    extends ConsumerState<RecordingRecoveryGuard> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(orphanedRecordingsProvider, (previous, next) {
      final orphans = next.value;
      if (_handled || orphans == null || orphans.isEmpty) return;
      _handled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptSequentially(orphans);
      });
    });
    return const SizedBox.shrink();
  }

  Future<void> _promptSequentially(List<RecoverableRecording> orphans) async {
    for (final orphan in orphans) {
      if (!mounted) return;
      await _promptOne(orphan);
    }
  }

  Future<void> _promptOne(RecoverableRecording r) async {
    final svc = await ref.read(recordingRecoveryServiceProvider.future);
    if (svc == null || !mounted) return;
    final t = AppLocalizations.of(context);
    final analytics = ref.read(analyticsCollectorProvider);
    analytics.track("recording.orphan_found", properties: {
      "est_duration_seconds": r.estimatedDuration.inSeconds,
      "size_bytes": r.sizeBytes,
      "age_hours": DateTime.now()
          .toUtc()
          .difference(r.manifest.startedAtUtc)
          .inHours,
    });

    final dateLabel = DateFormat('d MMMM y', Localizations.localeOf(context).toString())
        .format(r.manifest.startedAtUtc.toLocal());
    final minutes = r.estimatedDuration.inMinutes.clamp(1, 130);

    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        topIcon: Icons.settings_backup_restore_rounded,
        header: t.recovery_sheet_header,
        body: t.recovery_sheet_body(
          r.manifest.patientAlias,
          dateLabel,
          minutes,
        ),
        primary: EuphireSheetAction(
          label: t.recovery_sheet_send,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _recover(svc, r);
          },
        ),
        secondary: EuphireSheetAction(
          label: t.recovery_sheet_later,
          onPressed: () {
            analytics.track("recording.orphan_postponed");
            Navigator.of(ctx).pop();
          },
        ),
        destructive: EuphireSheetAction(
          label: t.recovery_sheet_delete,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _confirmDiscard(svc, r);
          },
        ),
      ),
    );
  }

  Future<void> _recover(
      RecordingRecoveryService svc, RecoverableRecording r) async {
    try {
      await svc.recover(r);
      ref
          .read(analyticsCollectorProvider)
          .track("recording.orphan_recovered");
      if (!mounted) return;
      EuphireToast.success(
        context,
        message: AppLocalizations.of(context).recovery_enqueued_snackbar,
      );
    } catch (e) {
      debugPrint('[recovery] recover failed: $e');
    }
  }

  Future<void> _confirmDiscard(
      RecordingRecoveryService svc, RecoverableRecording r) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.recovery_delete_confirm_header,
        body: t.recovery_delete_confirm_body,
        primary: EuphireSheetAction(
          label: t.common_cancel,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        destructive: EuphireSheetAction(
          label: t.recovery_delete_confirm_destructive,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await svc.discard(r);
            ref
                .read(analyticsCollectorProvider)
                .track("recording.orphan_discarded");
          },
        ),
      ),
    );
  }
}
