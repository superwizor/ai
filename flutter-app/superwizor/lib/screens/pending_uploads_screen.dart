// PendingUploadsScreen — full list view of the offline upload queue.
//
// Shows every row in the queue with its current phase, retry count,
// and per-row actions (retry for failed rows, dismiss for any).
// Watches pendingUploadsStreamProvider so the UI updates live as the
// runner advances rows through their phases.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';
import '../providers/patient_provider.dart';
import '../uploads/cancel_upload_action.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import 'session_status_screen.dart';

class PendingUploadsScreen extends ConsumerWidget {
  const PendingUploadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(pendingUploadsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: EuphireColors.frostWhite),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.pending_uploads_title,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: EuphireColors.ember,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.pending_uploads_subtitle,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            color: EuphireColors.mist.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(l.pending_uploads_error(e.toString()),
                      style: const TextStyle(color: EuphireColors.frostWhite)),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const _EmptyState();
                  }
                  // Sort: quota-blocked and failed first (needs attention), then by queuedAt asc.
                  final sorted = [...rows]..sort((a, b) {
                      final aPriority = _sortPriority(a.phase);
                      final bPriority = _sortPriority(b.phase);
                      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
                      return a.queuedAt.compareTo(b.queuedAt);
                    });
                  
                  final hasActive = sorted.any((u) => !u.isTerminal && !u.isParked);

                  return Column(
                    children: [
                      if (hasActive)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: _AnimatedHeroCloud(),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: sorted.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _UploadRow(upload: sorted[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _sortPriority(UploadPhase p) {
    switch (p) {
      case UploadPhase.failed:
        return 0;
      case UploadPhase.quotaBlocked:
        return 1;
      default:
        return 2;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined,
                size: 48, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              l.pending_uploads_empty_title,
              style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: EuphireColors.frostWhite,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l.pending_uploads_empty_body,
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

// ─── Animated Hero Cloud ──────────────────────────────────────────

class _AnimatedHeroCloud extends StatefulWidget {
  const _AnimatedHeroCloud();

  @override
  State<_AnimatedHeroCloud> createState() => _AnimatedHeroCloudState();
}

class _AnimatedHeroCloudState extends State<_AnimatedHeroCloud>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _arrowController]),
      builder: (context, _) {
        final pulseOpacity = 0.08 + (_pulseController.value * 0.12);
        final pulseScale = 1.0 + (_pulseController.value * 0.15);
        final arrowOffset = -12.0 * _arrowController.value;
        final arrowOpacity = _arrowController.value < 0.7
            ? 1.0
            : 1.0 - ((_arrowController.value - 0.7) / 0.3);

        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.ember.withValues(alpha: pulseOpacity),
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.ember.withValues(alpha: 0.15),
                  border: Border.all(
                    color: EuphireColors.ember.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      size: 32,
                      color: EuphireColors.ember,
                    ),
                    Positioned(
                      bottom: 12 + arrowOffset.abs(),
                      child: Opacity(
                        opacity: arrowOpacity.clamp(0.0, 1.0),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: EuphireColors.ember.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Network Error Bottom Sheet ──────────────────────────────────

class _BottomSheetNetworkError extends StatelessWidget {
  const _BottomSheetNetworkError({
    required this.upload,
    required this.isResending,
    required this.onResend,
  });

  final PendingUpload upload;
  final bool isResending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rawError = upload.lastError ?? '';
    final lower = rawError.toLowerCase();
    final isNetworkErr = lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('clientexception');

    final title = isNetworkErr ? l.pending_uploads_no_internet_title : l.pending_uploads_error_title;
    final desc = isNetworkErr
        ? l.pending_uploads_no_internet_desc
        : l.pending_uploads_error_desc;
    final icon = isNetworkErr ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
              color: const Color(0xFF40484A).withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EuphireColors.frostWhite.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: EuphireColors.ember.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: EuphireColors.ember, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EuphireColors.frostWhite,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 14,
                height: 1.5,
                color: EuphireColors.mist.withValues(alpha: 0.9),
              ),
            ),
            if (rawError.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: EuphireColors.ember.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: EuphireColors.ember.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: EuphireColors.ember,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _UploadRowState._friendlyError(rawError, l),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // CTA
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isResending ? null : onResend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuphireColors.ember,
                  foregroundColor: EuphireColors.nocturne,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  elevation: 0,
                ),
                child: isResending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: EuphireColors.nocturne,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        l.pending_uploads_btn_resend,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EuphireColors.frostWhite,
                  side: BorderSide(
                    color: EuphireColors.frostWhite.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(
                  l.common_close,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadRow extends ConsumerStatefulWidget {
  const _UploadRow({required this.upload});
  final PendingUpload upload;

  @override
  ConsumerState<_UploadRow> createState() => _UploadRowState();
}

class _UploadRowState extends ConsumerState<_UploadRow> with SingleTickerProviderStateMixin {
  bool _isResending = false;
  late AnimationController _rotationController;

  PendingUpload get upload => widget.upload;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _updateRotationState();
  }

  @override
  void didUpdateWidget(covariant _UploadRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRotationState();
  }

  void _updateRotationState() {
    final p = widget.upload.phase;
    final isActive = p == UploadPhase.encrypting ||
        p == UploadPhase.converting ||
        p == UploadPhase.created ||
        p == UploadPhase.uploaded ||
        p == UploadPhase.converted;
    if (isActive) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isFailed = upload.phase == UploadPhase.failed;
    final isCompleted = upload.phase == UploadPhase.completed;
    final isQuotaBlocked = upload.phase == UploadPhase.quotaBlocked;
    final isRetrying = !isFailed && !isQuotaBlocked &&
        upload.lastError != null && upload.attemptCount > 0;

    // Fetch patient name and session count reactively.
    final patients = ref.watch(patientsProvider).value;
    final patient = patients?.where((p) => p.id == upload.patientFileId).firstOrNull;
    final patientName = patient != null ? '${patient.firstName} ${patient.lastName}' : l.pending_uploads_default_patient_name;
    final sessionNumber = (patient?.sessionCount ?? 0) + 1;

    // Quota-blocked rows get a special premium card
    if (isQuotaBlocked) {
      return _QuotaBlockedCard(
        upload: upload,
        isResending: _isResending,
        onResend: () => _handleResend(context, l),
        onCancel: () => confirmAndCancelUpload(
          context,
          ref,
          patientFileId: upload.patientFileId,
          sessionId: upload.sessionId,
          localId: upload.localId,
        ),
        patientName: patientName,
        sessionNumber: sessionNumber,
      );
    }

    final color = isFailed
        ? EuphireColors.ember
        : isCompleted
            ? Colors.greenAccent.shade200
            : EuphireColors.ember;

    // Tap-through to the live session/upload screen.
    final hasSessionId =
        upload.sessionId != null && upload.sessionId!.isNotEmpty;
    final canTap = !isFailed;

    final iconData = _phaseIcon(upload.phase, isRetrying: isRetrying);
    final isSpinning = upload.phase == UploadPhase.encrypting ||
        upload.phase == UploadPhase.converting ||
        upload.phase == UploadPhase.created ||
        upload.phase == UploadPhase.uploaded ||
        upload.phase == UploadPhase.converted;

    Widget iconWidget = Icon(iconData, color: color, size: 20);
    if (isSpinning) {
      iconWidget = RotationTransition(
        turns: _rotationController,
        child: iconWidget,
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isFailed
            ? () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _BottomSheetNetworkError(
                    upload: upload,
                    isResending: _isResending,
                    onResend: () {
                      Navigator.pop(context);
                      _handleResend(context, l);
                    },
                  ),
                );
              }
            : canTap
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
            color: EuphireColors.frostWhite.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EuphireColors.frostWhite.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _phaseLabel(upload.phase, l, isRetrying: isRetrying),
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
              const SizedBox(height: 10),
              Text(
                '$patientName / Sesja #$sessionNumber',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: EuphireColors.ember,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: EuphireColors.frostWhite.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: EuphireColors.frostWhite.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 15,
                      color: EuphireColors.mist.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _detailLine(upload, l),
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: EuphireColors.mist.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Live upload progress
              if (upload.phase == UploadPhase.created) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: upload.uploadProgress > 0
                              ? upload.uploadProgress.clamp(0.0, 1.0)
                              : null,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF353535),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(EuphireColors.ember),
                        ),
                      ),
                    ),
                    if (upload.uploadProgress > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        '${(upload.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: EuphireColors.mist.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              // Show error text for failed rows AND retrying rows
              if (upload.lastError != null &&
                  (isFailed || upload.attemptCount > 0)) ...[
                const SizedBox(height: 10),
                Text(
                  isFailed
                      ? _friendlyError(upload.lastError!, l).toUpperCase()
                      : '${l.pending_uploads_resending_auto_prefix}${_friendlyError(upload.lastError!, l)}'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isFailed
                        ? EuphireColors.ember
                        : EuphireColors.ember.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel/Delete action on the left
                  if (isCompleted)
                    TextButton.icon(
                      onPressed: () async {
                        final runner = await ref.read(uploadQueueRunnerProvider.future);
                        await runner?.dismiss(upload.localId);
                      },
                      icon: const Icon(Icons.close, size: 18, color: EuphireColors.frostWhite),
                      label: Text(
                        l.common_close,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => confirmAndCancelUpload(
                        context,
                        ref,
                        patientFileId: upload.patientFileId,
                        sessionId: upload.sessionId,
                        localId: upload.localId,
                      ),
                      icon: Icon(
                        isFailed ? Icons.delete_outline_rounded : Icons.cancel_outlined,
                        size: 18,
                        color: EuphireColors.magma,
                      ),
                      label: Text(
                        isFailed ? l.common_delete : l.common_cancel,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.magma,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                  // Retry as primary CTA on the right for failed uploads
                  if (isFailed)
                    ElevatedButton(
                      onPressed: _isResending ? null : () => _handleResend(context, l),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EuphireColors.ember,
                        foregroundColor: EuphireColors.nocturne,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EuphireColors.nocturne,
                              ),
                            )
                          : Text(
                              l.pending_uploads_btn_resend,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
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

  /// Handle resend with proper feedback. After resend(), wait briefly
  /// and check if the row is STILL quota-blocked — if so, show a clear
  /// message telling the user their tokens are still exhausted.
  Future<void> _handleResend(BuildContext context, AppLocalizations l) async {
    if (_isResending) return;
    setState(() => _isResending = true);

    try {
      final runner = await ref.read(uploadQueueRunnerProvider.future);
      if (runner == null) return;

      await runner.resend(upload.localId);

      // Give the tick a moment to process and re-park if quota is still gone
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Re-read the row's current state from the stream
      final currentList = ref.read(pendingUploadsStreamProvider).value;
      final currentRow = currentList
          ?.where((u) => u.localId == upload.localId)
          .firstOrNull;

      if (currentRow != null &&
          currentRow.phase == UploadPhase.quotaBlocked) {
        // Still quota-blocked — show feedback
        if (context.mounted) {
          _showQuotaStillBlockedBottomSheet(context, l);
        }
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showQuotaStillBlockedBottomSheet(BuildContext context, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: const Color(0xFF40484A).withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: EuphireColors.ember,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.pending_uploads_quota_dialog_title,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l.pending_uploads_quota_dialog_body,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 14,
                height: 1.5,
                color: EuphireColors.frostWhite.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: EuphireColors.ember,
                foregroundColor: EuphireColors.nocturne,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(
                l.common_got_it,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Map a user-hostile error string to a friendlier one-liner.
  static String _friendlyError(String raw, AppLocalizations l) {
    final lower = raw.toLowerCase();
    String reason = raw;
    if (lower.contains('socket') || lower.contains('network') ||
        lower.contains('clientexception')) {
      reason = l.pending_uploads_err_reason_no_internet;
    } else if (lower.contains('timeout') || lower.contains('deadline')) {
      reason = l.pending_uploads_err_reason_timeout;
    } else if (lower.contains('expiredtoken') || lower.contains('signedurl')) {
      reason = l.pending_uploads_err_reason_link_expired;
    } else if (lower.contains('unavailable')) {
      reason = l.pending_uploads_err_reason_unavailable;
    } else if (raw.length > 60) {
      reason = '${raw.substring(0, 57)}...';
    }
    return l.pending_uploads_err_reason_prefix(reason);
  }

  static IconData _phaseIcon(UploadPhase p, {bool isRetrying = false}) {
    if (isRetrying) return Icons.sync_rounded;
    switch (p) {
      case UploadPhase.encrypting:
        return Icons.lock_outline_rounded;
      case UploadPhase.converting:
        return Icons.transform_rounded;
      case UploadPhase.pending:
        return Icons.schedule_rounded;
      case UploadPhase.created:
      case UploadPhase.uploaded:
      case UploadPhase.converted:
        return Icons.sync_rounded;
      case UploadPhase.completed:
        return Icons.check_circle_outline_rounded;
      case UploadPhase.failed:
        return Icons.error_outline_rounded;
      case UploadPhase.quotaBlocked:
        return Icons.account_balance_wallet_outlined;
    }
  }

  static String _phaseLabel(UploadPhase p, AppLocalizations l,
      {bool isRetrying = false}) {
    if (isRetrying) return l.pending_uploads_phase_resuming;
    switch (p) {
      case UploadPhase.encrypting:
        return l.pending_uploads_phase_encrypting;
      case UploadPhase.converting:
        return l.pending_uploads_phase_converting;
      case UploadPhase.pending:
        return l.pending_uploads_phase_pending;
      case UploadPhase.created:
        return l.pending_uploads_phase_uploading;
      case UploadPhase.uploaded:
        return l.pending_uploads_phase_uploaded;
      case UploadPhase.converted:
        return l.pending_uploads_phase_converted;
      case UploadPhase.completed:
        return l.pending_uploads_phase_completed;
      case UploadPhase.failed:
        return l.pending_uploads_phase_failed;
      case UploadPhase.quotaBlocked:
        return l.quota_blocked_queue_label;
    }
  }

  static String _detailLine(PendingUpload u, AppLocalizations l) {
    final mb = (u.sizeBytes / 1024 / 1024).toStringAsFixed(1);
    final mins = (u.actualDurationSeconds / 60).toStringAsFixed(0);
    final retry = u.attemptCount > 0 ? l.pending_uploads_detail_attempt(u.attemptCount + 1) : '';
    return '$mb MB${u.actualDurationSeconds > 0 ? " • $mins min" : ""}$retry';
  }
}

// ─── Premium Quota-Blocked Card ──────────────────────────────────

class _QuotaBlockedCard extends StatelessWidget {
  final PendingUpload upload;
  final bool isResending;
  final VoidCallback onResend;
  final VoidCallback onCancel;
  final String patientName;
  final int sessionNumber;

  const _QuotaBlockedCard({
    required this.upload,
    required this.isResending,
    required this.onResend,
    required this.onCancel,
    required this.patientName,
    required this.sessionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mb = (upload.sizeBytes / 1024 / 1024).toStringAsFixed(1);
    final mins = (upload.actualDurationSeconds / 60).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EuphireColors.ember.withValues(alpha: 0.08),
            const Color(0xFF202020),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF40484A),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: EuphireColors.ember.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: icon + title + time ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pulsing wallet icon
                _PulsingIcon(color: EuphireColors.ember),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.pending_uploads_quota_card_title,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.frostWhite,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$patientName / Sesja #$sessionNumber',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.ember,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.pending_uploads_quota_card_desc,
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: EuphireColors.frostWhite
                              .withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Session metadata ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF40484A).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.audiotrack_rounded,
                    size: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$mb MB',
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
                  ),
                  if (upload.actualDurationSeconds > 0) ...[
                    Text(
                      '  •  $mins min',
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 11,
                        color: EuphireColors.mist.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('HH:mm, d MMM', Localizations.localeOf(context).languageCode)
                        .format(upload.queuedAt.toLocal()),
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Action buttons ──
            Row(
              children: [
                // Primary CTA: Wyślij ponownie
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isResending ? null : onResend,
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isResending
                              ? EuphireColors.ember.withValues(alpha: 0.08)
                              : EuphireColors.ember.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: EuphireColors.ember
                                .withValues(alpha: isResending ? 0.15 : 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isResending)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: EuphireColors.ember
                                      .withValues(alpha: 0.6),
                                ),
                              )
                            else
                              Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: EuphireColors.ember,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              isResending
                                  ? l.pending_uploads_btn_checking
                                  : l.pending_uploads_btn_send_again,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isResending
                                    ? EuphireColors.ember
                                        .withValues(alpha: 0.5)
                                    : EuphireColors.ember,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Secondary: Usuń
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: EuphireColors.magma.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: EuphireColors.magma.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: EuphireColors.magma.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.common_delete,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  EuphireColors.magma.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pulsing icon for quota card ─────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  final Color color;
  const _PulsingIcon({required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final glow = 0.15 + _ctrl.value * 0.2;
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: glow),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: 18,
            color: widget.color,
          ),
        );
      },
    );
  }
}
