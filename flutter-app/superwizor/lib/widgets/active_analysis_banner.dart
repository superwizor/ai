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

import '../screens/pending_uploads_screen.dart';
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

    // ── Classify rows by state ──────────────────────────────────
    final hasFailure = list.any((u) => u.phase == UploadPhase.failed);
    final hasQuotaBlocked =
        list.any((u) => u.phase == UploadPhase.quotaBlocked);
    final allCompleted = list.every((u) => u.phase == UploadPhase.completed);

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
        : null;

    // ── Determine copy — priority order: failure > quota > retry >
    //    encrypting > converting > uploading > analyzing > mixed ──
    final _BannerContent content;
    if (hasFailure) {
      content = _BannerContent(
        icon: Icons.error_outline_rounded,
        iconColor: EuphireColors.magma,
        headline: 'Przesyłanie wymaga uwagi.',
        body:
            'Sesja nie mogła zostać wgrana. Sprawdź szczegóły — nagranie jest bezpiecznie zapisane na urządzeniu.',
        ctaLabel: 'Sprawdź szczegóły',
        accentColor: EuphireColors.magma,
        borderColor: EuphireColors.magma,
      );
    } else if (hasQuotaBlocked) {
      content = _BannerContent(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: EuphireColors.ember,
        headline: 'Nagranie czeka na wznowienie.',
        body:
            'Pula sesji została wyczerpana. Sesja jest bezpiecznie zapisana i zostanie przetworzona po odnowieniu planu.',
        ctaLabel: 'Zobacz szczegóły',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else if (hasRetrying) {
      // Upload interrupted (e.g. network blip at 50%) — auto-retrying
      content = _BannerContent(
        icon: Icons.refresh_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Przesyłanie zostało przerwane.',
        body:
            'Próba wznowienia nastąpi automatycznie. Nagranie jest bezpieczne.',
        ctaLabel: 'Zobacz szczegóły',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: progress,
      );
    } else if (hasEncrypting) {
      content = _BannerContent(
        icon: Icons.lock_outline_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Przygotowuję nagranie.',
        body:
            'Sesja jest szyfrowana przed przesłaniem na serwer.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else if (hasConverting) {
      content = _BannerContent(
        icon: Icons.transform_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Konwertuję plik audio.',
        body:
            'Format pliku wymaga konwersji. Potrwa to chwilę.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else if (hasActiveUpload) {
      content = _BannerContent(
        icon: Icons.cloud_upload_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Sesja jest przesyłana na serwer.',
        body: 'Plik trafia bezpiecznie na serwer. Możesz kontynuować pracę.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: progress,
      );
    } else if (allCompleted) {
      content = _BannerContent(
        icon: Icons.auto_awesome_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Analiza w toku.',
        body:
            'Sesja jest już na serwerze. Raport pojawi się za kilka minut.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    } else {
      // Mixed / default (uploaded, finalization, etc.)
      content = _BannerContent(
        icon: Icons.auto_awesome_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Przetwarzanie sesji.',
        body: 'Twoja sesja przechodzi kolejne etapy analizy.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _BannerCard(
        content: content,
        count: list.length,
        onTap: () {
          ref.read(analyticsCollectorProvider).track(
            'analysis_banner.tapped',
            properties: {'pending_count': list.length},
          );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PendingUploadsScreen(),
          ));
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
  });
}

// ─── The actual card widget with animations ───────────────────────

class _BannerCard extends StatefulWidget {
  final _BannerContent content;
  final int count;
  final VoidCallback onTap;

  const _BannerCard({
    required this.content,
    required this.count,
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
            color: c.borderColor == EuphireColors.magma
                ? EuphireColors.magma.withValues(alpha: 0.06)
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
                    // Animated activity dot
                    _ActivityIndicator(color: c.iconColor),
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

                const SizedBox(height: 12),

                // CTA button
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.ctaLabel,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: c.accentColor,
                        ),
                      ],
                    ),
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

// ─── Animated activity dot (breathing pulse, not spinner) ─────────

class _ActivityIndicator extends StatefulWidget {
  final Color color;
  const _ActivityIndicator({required this.color});

  @override
  State<_ActivityIndicator> createState() => _ActivityIndicatorState();
}

class _ActivityIndicatorState extends State<_ActivityIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulseScale = 1.0 + (_controller.value * 0.5);
        final pulseOpacity = 0.15 + (_controller.value * 0.15);
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: pulseOpacity),
                  ),
                ),
              ),
              // Inner solid dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 6,
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
