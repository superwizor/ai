// Shared "cancel processing" flow for the quota-UX bin icon
// (feat/tokens-exhausted, 2026-05-30).
//
// Three surfaces use it identically — the "Wgrywanie" list, the
// "Bezpieczna analiza w toku" status screen, and the kartoteka-level
// PendingQuotaSessionsWidget — so the confirm dialog + RPC + local
// cleanup live here once.
//
// Order of operations on confirm:
//   1. If a server session exists ([sessionId] set), call clinical-svc
//      CancelSession via SessionsNotifier — the server flips the row to
//      CANCELLED_BY_USER, releases the held billing token, and hides it
//      from ListSessions.
//   2. If a local upload-queue row exists ([localId] set), remove it so
//      the parked audio stops showing in "Wgrywanie".
//
// A CancelSession failure does NOT block the local cleanup: we still
// drop the queue row so the user isn't trapped, and log the error. The
// server's orphan reaper / reservation TTL are the backstop.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_provider.dart';
import '../theme/euphire_theme.dart';
import 'upload_queue_provider.dart';

/// Shows the confirm dialog and, on confirm, cancels the session +
/// dismisses the local upload. Returns true iff the user confirmed and
/// the cleanup ran.
Future<bool> confirmAndCancelUpload(
  BuildContext context,
  WidgetRef ref, {
  String? patientFileId,
  String? sessionId,
  String? localId,
}) async {
  final l = AppLocalizations.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: EuphireColors.surfaceTeal,
      title: Text(
        l.cancel_session_confirm_title,
        style: const TextStyle(
          color: EuphireColors.frostWhite,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        l.cancel_session_confirm_body,
        style: const TextStyle(
          color: EuphireColors.mist,
          fontFamily: 'Merriweather',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel_session_keep,
              style: const TextStyle(color: EuphireColors.mist)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.cancel_session_confirm_action,
              style: const TextStyle(color: EuphireColors.magma)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  // 1. Server-side cancel (best-effort — never blocks local cleanup).
  if (sessionId != null && sessionId.isNotEmpty) {
    try {
      if (patientFileId != null && patientFileId.isNotEmpty) {
        // Cache-aware path: also drops the row from the patient's
        // cached session list so the kartoteka updates immediately.
        await ref
            .read(sessionsProvider.notifier)
            .cancelSession(patientFileId, sessionId);
      } else {
        // No patient context (session-only screen): just fire the RPC.
        // ListSessions will exclude the CANCELLED_BY_USER row on the
        // next kartoteka load.
        await ref.read(grpcClientsProvider).clinical.cancelSession(
              grpc_clinical.CancelSessionRequest(sessionId: sessionId),
            );
      }
    } catch (e) {
      debugPrint('[cancel-upload] CancelSession failed (continuing): $e');
    }
  }

  // 2. Drop the local upload-queue row.
  if (localId != null) {
    final runner = await ref.read(uploadQueueRunnerProvider.future);
    await runner?.dismiss(localId);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.cancel_session_success),
      duration: const Duration(seconds: 2),
    ));
  }
  return true;
}
