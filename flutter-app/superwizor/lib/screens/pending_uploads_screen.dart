// PendingUploadsScreen — full list view of the offline upload queue.
//
// Shows every row in the queue with its current phase, retry count,
// and per-row actions (retry for failed rows, dismiss for any).
// Watches pendingUploadsStreamProvider so the UI updates live as the
// runner advances rows through their phases.

import 'dart:async';

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
          // Sort: quota-blocked and failed first (needs attention), then by queuedAt asc.
          final sorted = [...rows]..sort((a, b) {
              final aPriority = _sortPriority(a.phase);
              final bPriority = _sortPriority(b.phase);
              if (aPriority != bPriority) return aPriority.compareTo(bPriority);
              return a.queuedAt.compareTo(b.queuedAt);
            });
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _UploadRow(upload: sorted[i]),
          );
        },
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

class _UploadRow extends ConsumerStatefulWidget {
  const _UploadRow({required this.upload});
  final PendingUpload upload;

  @override
  ConsumerState<_UploadRow> createState() => _UploadRowState();
}

class _UploadRowState extends ConsumerState<_UploadRow> {
  bool _isResending = false;

  PendingUpload get upload => widget.upload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isFailed = upload.phase == UploadPhase.failed;
    final isCompleted = upload.phase == UploadPhase.completed;
    final isQuotaBlocked = upload.phase == UploadPhase.quotaBlocked;
    final isRetrying = !isFailed && !isQuotaBlocked &&
        upload.lastError != null && upload.attemptCount > 0;

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
      );
    }

    final color = isFailed
        ? Colors.redAccent.shade200
        : isCompleted
            ? Colors.greenAccent.shade200
            : EuphireColors.ember;

    // Tap-through to the live session/upload screen.
    final hasSessionId =
        upload.sessionId != null && upload.sessionId!.isNotEmpty;
    final canTap = !isFailed;

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
              Icon(_phaseIcon(upload.phase, isRetrying: isRetrying),
                  color: color, size: 18),
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
          const SizedBox(height: 8),
          Text(
            _detailLine(upload),
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          // Live upload progress
          if (upload.phase == UploadPhase.created) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: upload.uploadProgress > 0
                    ? upload.uploadProgress.clamp(0.0, 1.0)
                    : null,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(EuphireColors.ember),
              ),
            ),
            if (upload.uploadProgress > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${(upload.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
          // Show error text for failed rows AND retrying rows so
          // the user sees what caused the hiccup (e.g. "network:
          // SocketException"). Red for failed, amber for retrying.
          if (upload.lastError != null &&
              (isFailed || upload.attemptCount > 0)) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isFailed) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 12,
                      color: EuphireColors.ember.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    isFailed
                        ? upload.lastError!
                        : 'Wznawiam automatycznie: ${_friendlyError(upload.lastError!)}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10,
                      color: isFailed
                          ? Colors.redAccent.shade200
                          : EuphireColors.ember.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Retry for failed rows
              if (isFailed)
                TextButton.icon(
                  icon: _isResending
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EuphireColors.ember,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(_isResending ? 'Ponawiam...' : 'Ponów'),
                  onPressed: _isResending
                      ? null
                      : () => _handleResend(context, l),
                ),
              // Completed rows just close locally
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
          _showQuotaStillBlockedDialog(context);
        }
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showQuotaStillBlockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EuphireColors.nocturne,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: EuphireColors.ember.withValues(alpha: 0.3),
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: EuphireColors.ember,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pula nadal wyczerpana',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: EuphireColors.frostWhite,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Twoje tokeny nie zostały jeszcze odnowione. '
          'Sesja pozostanie bezpiecznie zapisana i zostanie przetworzona '
          'po odnowieniu planu.',
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 13,
            height: 1.5,
            color: EuphireColors.frostWhite.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Rozumiem',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: EuphireColors.ember,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Map a user-hostile error string to a friendlier one-liner.
  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('socket') || lower.contains('network') ||
        lower.contains('clientexception')) {
      return 'brak połączenia z internetem';
    }
    if (lower.contains('timeout') || lower.contains('deadline')) {
      return 'serwer nie odpowiedział w terminie';
    }
    if (lower.contains('expiredtoken') || lower.contains('signedurl')) {
      return 'link do przesyłania wygasł';
    }
    if (lower.contains('unavailable')) {
      return 'serwer chwilowo niedostępny';
    }
    // Truncate raw technical strings to something reasonable
    if (raw.length > 60) return '${raw.substring(0, 57)}...';
    return raw;
  }

  static IconData _phaseIcon(UploadPhase p, {bool isRetrying = false}) {
    if (isRetrying) return Icons.refresh_rounded;
    switch (p) {
      case UploadPhase.encrypting:
        return Icons.lock_outline;
      case UploadPhase.converting:
        return Icons.transform;
      case UploadPhase.pending:
        return Icons.schedule;
      case UploadPhase.created:
        return Icons.cloud_upload_outlined;
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

  static String _phaseLabel(UploadPhase p, AppLocalizations l,
      {bool isRetrying = false}) {
    if (isRetrying) return 'Wznawianie przesyłania...';
    switch (p) {
      case UploadPhase.encrypting:
        return 'Szyfrowanie nagrania...';
      case UploadPhase.converting:
        return 'Konwersja pliku audio...';
      case UploadPhase.pending:
        return 'W kolejce';
      case UploadPhase.created:
        return 'Przesyłam na serwer...';
      case UploadPhase.uploaded:
        return 'Przesłano — finalizuję...';
      case UploadPhase.converted:
        return 'Konwersja gotowa — finalizuję...';
      case UploadPhase.completed:
        return 'Wgrane';
      case UploadPhase.failed:
        return 'Nie udało się wgrać';
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

// ─── Premium Quota-Blocked Card ──────────────────────────────────

class _QuotaBlockedCard extends StatelessWidget {
  final PendingUpload upload;
  final bool isResending;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  const _QuotaBlockedCard({
    required this.upload,
    required this.isResending,
    required this.onResend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
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
            EuphireColors.nocturne.withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(
          color: EuphireColors.ember.withValues(alpha: 0.25),
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
                      const Text(
                        'Nagranie czeka na wznowienie.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.frostWhite,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pula sesji została wyczerpana. '
                        'Sesja jest bezpiecznie zapisana i zostanie '
                        'przetworzona po odnowieniu planu.',
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
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
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
                    DateFormat('HH:mm, d MMM', 'pl')
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
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isResending
                              ? EuphireColors.ember.withValues(alpha: 0.08)
                              : EuphireColors.ember.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
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
                                  ? 'Sprawdzam...'
                                  : 'Wyślij ponownie',
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: EuphireColors.magma.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
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
                            'Usuń',
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
