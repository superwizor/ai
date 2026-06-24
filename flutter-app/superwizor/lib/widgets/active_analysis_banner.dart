// ActiveAnalysisBanner — a premium, brand-voice card that replaces the
// tiny "N w toku" pill. Sits above "TWOJE KARTOTEKI" on the home screen
// and surfaces pending uploads / running analyses with clear copy and
// a visible CTA button.
//
// Design principles:
// - Glassmorphism card with a subtle ember-to-transparent gradient edge
// - Animated shimmer pulse on the activity indicator (not spinner)
// - Copy follows brand voice: calm, peer-to-peer, benefit-oriented
// - Prominent amber "Zobacz postęp" button (not hidden affordance)
// - Auto-hides when the queue is empty (SizedBox.shrink)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';

import '../screens/pending_uploads_screen.dart';
import '../screens/session_status_screen.dart';
import '../theme/euphire_theme.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../analytics/analytics_collector.dart';

class ActiveAnalysisBanner extends ConsumerWidget {
  const ActiveAnalysisBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingUploadsStreamProvider);
    final list =
        async.maybeWhen(data: (l) => l, orElse: () => <PendingUpload>[]);

    if (list.isEmpty) return const SizedBox.shrink();

    final t = AppLocalizations.of(context);

    // ── Classify rows by state ──────────────────────────────────
    final failures = list.where((u) => u.phase == UploadPhase.failed).toList();
    final hasFailure = failures.isNotEmpty;
    final quotaBlocked = list.where((u) => u.phase == UploadPhase.quotaBlocked).toList();
    final hasQuotaBlocked = quotaBlocked.isNotEmpty;
    final allCompleted = list.every((u) => u.phase == UploadPhase.completed);
    
    final inProgressCount = list.length - failures.length - quotaBlocked.length;
    final isMixedErrorState = hasFailure && inProgressCount > 0;

    final encrypting =
        list.where((u) => u.phase == UploadPhase.encrypting).toList();
    final converting =
        list.where((u) => u.phase == UploadPhase.converting).toList();
    final uploading = list.where((u) =>
        u.phase == UploadPhase.created ||
        u.phase == UploadPhase.pending).toList();

    // "Retrying" = active upload with a previous error (network blip
    // at 50%, signed URL expired, etc.) — the worker is backing off
    // and will retry automatically. We show this BEFORE the generic
    // "uploading" state so the user sees there was a hiccup.
    final retrying = uploading.where(
        (u) => u.lastError != null && u.attemptCount > 0).toList();
    final hasRetrying = retrying.isNotEmpty;

    final hasEncrypting = encrypting.isNotEmpty;
    final hasConverting = converting.isNotEmpty;
    final hasActiveUpload = uploading.isNotEmpty;

    // Pick the highest-priority upload progress for the bar
    final double? progress = hasActiveUpload
        ? uploading.map((u) => u.uploadProgress).reduce(math.max)
        : hasEncrypting || hasConverting
            ? null  // indeterminate for encrypting/converting
        : null;

    // Session details summary for the badge
    final totalBytes = list.fold<int>(0, (s, u) => s + u.sizeBytes);
    final totalMb = (totalBytes / 1024 / 1024).toStringAsFixed(1);
    // For single upload, show duration; for multiple, show count
    final singleUpload = list.length == 1 ? list.first : null;
    final String detailsBadge;
    if (singleUpload != null) {
      final mins = (singleUpload.actualDurationSeconds / 60).toStringAsFixed(0);
      detailsBadge = '$totalMb MB${singleUpload.actualDurationSeconds > 0 ? ' • $mins min' : ''}';
    } else {
      detailsBadge = '${t.patient_session_count(list.length)} • $totalMb MB';
    }

    // ── Determine copy — priority order: failure > quota > retry >
    //    encrypting > converting > uploading > analyzing > mixed ──
    final _BannerContent content;
    if (isMixedErrorState) {
      content = _BannerContent(
        icon: Icons.error_outline_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_uploading_status(failures.length, inProgressCount),
        body: t.activeAnalysis_uploading_status_desc,
        ctaLabel: t.activeAnalysis_check_details,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: progress,
        isError: true,
      );
    } else if (hasFailure) {
      content = _BannerContent(
        icon: Icons.error_outline_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_upload_attention,
        body: t.activeAnalysis_upload_attention_desc,
        ctaLabel: t.activeAnalysis_check_details,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        isError: true,
      );
    } else if (hasQuotaBlocked) {
      content = _BannerContent(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: EuphireColors.ember,
        headline: t.pending_uploads_quota_card_title,
        body: t.activeAnalysis_quota_blocked_desc,
        ctaLabel: t.activeAnalysis_view_details,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else if (hasRetrying) {
      // Upload interrupted (e.g. network blip at 50%) — auto-retrying
      content = _BannerContent(
        icon: Icons.refresh_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_upload_interrupted,
        body: t.activeAnalysis_upload_interrupted_desc,
        ctaLabel: t.activeAnalysis_view_details,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: progress,
      );
    } else if (hasEncrypting) {
      content = _BannerContent(
        icon: Icons.lock_outline_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_preparing,
        body: t.activeAnalysis_preparing_desc,
        ctaLabel: t.activeAnalysis_view_progress,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else if (hasConverting) {
      content = _BannerContent(
        icon: Icons.transform_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_converting,
        body: t.activeAnalysis_converting_desc,
        ctaLabel: t.activeAnalysis_view_progress,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else if (hasActiveUpload) {
      content = _BannerContent(
        icon: Icons.cloud_upload_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_uploading,
        body: t.activeAnalysis_uploading_desc,
        ctaLabel: t.activeAnalysis_view_progress,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: progress,
      );
    } else if (allCompleted) {
      content = _BannerContent(
        icon: Icons.auto_awesome_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_analyzing,
        body: t.activeAnalysis_analyzing_desc,
        ctaLabel: t.activeAnalysis_view_progress,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else {
      // Mixed / default (uploaded, finalization, etc.)
      content = _BannerContent(
        icon: Icons.auto_awesome_rounded,
        iconColor: EuphireColors.ember,
        headline: t.activeAnalysis_processing,
        body: t.activeAnalysis_processing_desc,
        ctaLabel: t.activeAnalysis_view_progress,
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _BannerCard(
        content: content,
        count: list.length,
        detailsBadge: detailsBadge,
        onTap: () {
          ref.read(analyticsCollectorProvider).track(
            'analysis_banner.tapped',
            properties: {'pending_count': list.length},
          );
          // Smart routing: 1 file → direct to SessionStatusScreen
          if (list.length == 1) {
            final single = list.first;
            final hasSessionId =
                single.sessionId != null && single.sessionId!.isNotEmpty;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SessionStatusScreen(
                sessionId: hasSessionId ? single.sessionId : null,
                localId: hasSessionId ? null : single.localId,
              ),
            ));
          } else {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PendingUploadsScreen(),
            ));
          }
        },
      ),
    );
  }
}

// ─── Data class for banner content ────────────────────────────────

class _BannerContent {
  final IconData icon;
  final Color iconColor;
  final String headline;
  final String body;
  final String ctaLabel;
  final Color accentColor;
  final Color borderColor;
  final bool showProgress;
  final double? progressValue;
  final bool isError;

  const _BannerContent({
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.accentColor,
    required this.borderColor,
    this.showProgress = false,
    this.progressValue,
    this.isError = false,
  });
}

// ─── The actual card widget with animations ───────────────────────

class _BannerCard extends StatefulWidget {
  final _BannerContent content;
  final int count;
  final String detailsBadge;
  final VoidCallback onTap;

  const _BannerCard({
    required this.content,
    required this.count,
    required this.detailsBadge,
    required this.onTap,
  });

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            // Glass surface
            color: c.isError
                ? EuphireColors.ember.withValues(alpha: 0.05)
                : EuphireColors.evergreen.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.borderColor.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: c.accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // ── Shimmer overlay (transparent sweep) ──
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.0 + _shimmerAnimation.value, 0),
                          end: Alignment(_shimmerAnimation.value, 0),
                          colors: [
                            Colors.transparent,
                            c.accentColor.withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Content ──
                child!,
              ],
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + headline row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animated cloud upload icon
                    _AnimatedUploadIcon(
                      color: c.iconColor,
                      isError: c.isError,
                      icon: c.icon,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.headline,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: EuphireColors.frostWhite,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.body,
                            style: TextStyle(
                              fontFamily: 'Merriweather',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: EuphireColors.frostWhite
                                  .withValues(alpha: 0.65),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Progress bar (if uploading)
                if (c.showProgress) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (c.progressValue != null && c.progressValue! > 0)
                          ? c.progressValue!.clamp(0.0, 1.0)
                          : null,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(c.accentColor),
                    ),
                  ),
                  if (c.progressValue != null && c.progressValue! > 0) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(c.progressValue! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              EuphireColors.frostWhite.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 16),

                // Balanced bottom Row
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Session details badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.audiotrack_rounded,
                                size: 14,
                                color: EuphireColors.mist.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.detailsBadge,
                                  style: TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        EuphireColors.mist.withValues(alpha: 0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // CTA button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.accentColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.ctaLabel,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.accentColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: c.accentColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated cloud upload icon ───────────────────────────────────

class _AnimatedUploadIcon extends StatefulWidget {
  final Color color;
  final bool isError;
  final IconData icon;
  const _AnimatedUploadIcon({
    required this.color,
    this.isError = false,
    required this.icon,
  });

  @override
  State<_AnimatedUploadIcon> createState() => _AnimatedUploadIconState();
}

class _AnimatedUploadIconState extends State<_AnimatedUploadIcon>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    // Pulse halo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Arrow slide up (for upload states)
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!widget.isError) {
      _pulseController.repeat(reverse: true);
      _arrowController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For error states, show a static icon without animation
    if (widget.isError) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.12),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          widget.icon,
          size: 18,
          color: widget.color,
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _arrowController]),
      builder: (context, _) {
        final pulseOpacity = 0.08 + (_pulseController.value * 0.12);
        final pulseScale = 1.0 + (_pulseController.value * 0.15);
        // Arrow slides from 0 to -6px then fades out
        final arrowOffset = -6.0 * _arrowController.value;
        final arrowOpacity = _arrowController.value < 0.7
            ? 1.0
            : 1.0 - ((_arrowController.value - 0.7) / 0.3);

        return SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse halo
              Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: pulseOpacity),
                  ),
                ),
              ),
              // Inner icon circle
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.15),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Cloud icon (static)
                    Icon(
                      widget.icon,
                      size: 16,
                      color: widget.color,
                    ),
                    // Animated upload arrow overlay
                    if (widget.icon == Icons.cloud_upload_rounded)
                      Positioned(
                        bottom: 6 + arrowOffset.abs(),
                        child: Opacity(
                          opacity: arrowOpacity.clamp(0.0, 1.0),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 8,
                            color: widget.color.withValues(alpha: 0.7),
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
