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
import '../widgets/euphire_toast.dart';
import 'upload_queue_provider.dart';

/// Shows a two-step bottom sheet confirmation and, on confirm, cancels
/// the session + dismisses the local upload. Returns true iff the user
/// confirmed and the cleanup ran.
Future<bool> confirmAndCancelUpload(
  BuildContext context,
  WidgetRef ref, {
  String? patientFileId,
  String? sessionId,
  String? localId,
}) async {
  final l = AppLocalizations.of(context);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _CancelConfirmSheet(l: l),
  );
  if (confirmed != true) return false;

  // 1. Drop the local upload-queue row first so the UI updates instantly.
  if (localId != null) {
    try {
      final runner = await ref.read(uploadQueueRunnerProvider.future);
      await runner?.dismiss(localId);
    } catch (e) {
      debugPrint('[cancel-upload] local dismiss failed: $e');
    }
  }

  // 2. Server-side cancel (best-effort — asynchronously in the background, never blocks).
  if (sessionId != null && sessionId.isNotEmpty) {
    // We do not await the server call so that the UI updates immediately
    // even on slow or offline connections.
    Future(() async {
      try {
        if (patientFileId != null && patientFileId.isNotEmpty) {
          // Cache-aware path: also drops the row from the patient's
          // cached session list so the kartoteka updates immediately.
          await ref
              .read(sessionsProvider.notifier)
              .cancelSession(patientFileId, sessionId);
        } else {
          // No patient context (session-only screen): just fire the RPC.
          await ref.read(grpcClientsProvider).clinical.cancelSession(
                grpc_clinical.CancelSessionRequest(sessionId: sessionId),
              );
        }
      } catch (e) {
        debugPrint('[cancel-upload] Server-side CancelSession failed (continuing): $e');
      }
    });
  }

  if (context.mounted) {
    EuphireToast.success(context, message: l.cancel_session_success);
  }
  return true;
}

/// Two-step cancel confirmation bottom sheet.
/// Step 1: Warning with explanation.
/// Step 2: "Czy na pewno?" double-confirm.
class _CancelConfirmSheet extends StatefulWidget {
  final AppLocalizations l;
  const _CancelConfirmSheet({required this.l});

  @override
  State<_CancelConfirmSheet> createState() => _CancelConfirmSheetState();
}

class _CancelConfirmSheetState extends State<_CancelConfirmSheet> {
  bool _showDoubleConfirm = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _showDoubleConfirm
                ? _buildDoubleConfirm()
                : _buildInitialWarning(),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialWarning() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Icon
        Center(
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: EuphireColors.magma.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cancel_outlined,
              size: 28,
              color: EuphireColors.magma.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.l.cancel_session_confirm_title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: EuphireColors.frostWhite,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Ta sesja jest w trakcie analizy. Usunięcie jej oznacza bezpowrotną utratę nagrania i transkrypcji. Nie będzie można tego cofnąć.',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: EuphireColors.mist.withValues(alpha: 0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EuphireColors.mist,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    widget.l.cancel_session_keep,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showDoubleConfirm = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuphireColors.magma,
                    foregroundColor: EuphireColors.frostWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Usuń z analizy',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoubleConfirm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: EuphireColors.magma.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 28,
              color: EuphireColors.magma,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Na pewno?',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: EuphireColors.magma,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Tej operacji nie można cofnąć. Nagranie i transkrypcja zostaną trwale usunięte.',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: EuphireColors.mist.withValues(alpha: 0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EuphireColors.mist,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'Wróć',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuphireColors.magma,
                    foregroundColor: EuphireColors.frostWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.l.cancel_session_confirm_action,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
