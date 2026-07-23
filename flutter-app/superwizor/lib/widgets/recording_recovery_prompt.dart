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
import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../providers/recording_recovery_provider.dart';
import '../services/recording_recovery_service.dart';
import '../theme/euphire_theme.dart';
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
    // Manifest-less orphan (empty patientFileId): the kartoteka is
    // unknown, so "send" must route through a patient picker first.
    final needsPatientPick = r.manifest.patientFileId.isEmpty;

    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        topIcon: Icons.settings_backup_restore_rounded,
        header: t.recovery_sheet_header,
        body: t.recovery_sheet_body(
          needsPatientPick
              ? t.recovery_unknown_patient
              : r.manifest.patientAlias,
          dateLabel,
          minutes,
        ),
        primary: EuphireSheetAction(
          label: t.recovery_sheet_send,
          onPressed: () async {
            Navigator.of(ctx).pop();
            if (needsPatientPick) {
              await _recoverWithPatientPick(svc, r);
            } else {
              await _recover(svc, r);
            }
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

  /// Manifest-less path: ask which kartoteka receives the recording,
  /// then recover with the picked patient's id + language.
  Future<void> _recoverWithPatientPick(
      RecordingRecoveryService svc, RecoverableRecording r) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    final patients =
        ref.read(patientsProvider).maybeWhen<List<Patient>>(
              data: (d) => d,
              orElse: () => const [],
            );
    if (patients.isEmpty) {
      EuphireToast.error(context, message: t.recovery_pick_patient_none);
      return;
    }
    final chosen = await showEuphireBottomSheet<Patient>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                t.recovery_pick_patient_header,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: EuphireColors.frostWhite,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final patient in patients)
                    ListTile(
                      leading: const Icon(
                        Icons.folder_shared_outlined,
                        color: EuphireColors.ember,
                      ),
                      title: Text(
                        patient.workingAlias,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(patient),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _recover(
      svc,
      r,
      patientFileId: chosen.id,
      patientLanguageCode:
          chosen.languageCode.isNotEmpty ? chosen.languageCode : null,
    );
  }

  Future<void> _recover(
      RecordingRecoveryService svc, RecoverableRecording r,
      {String? patientFileId, String? patientLanguageCode}) async {
    try {
      await svc.recover(
        r,
        patientFileId: patientFileId,
        patientLanguageCode: patientLanguageCode,
      );
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
