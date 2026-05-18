import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/euphire_theme.dart';

class EuphireWaveformIndicator extends StatefulWidget {
  final bool isRecording;
  final Stream<double>? amplitudeStream;
  final String formattedDuration;

  const EuphireWaveformIndicator({
    super.key,
    required this.isRecording,
    this.amplitudeStream,
    required this.formattedDuration,
  });

  @override
  State<EuphireWaveformIndicator> createState() =>
      _EuphireWaveformIndicatorState();
}

class _EuphireWaveformIndicatorState extends State<EuphireWaveformIndicator>
    with TickerProviderStateMixin {
  StreamSubscription<double>? _amplitudeSub;
  static const int _barCount = 20;

  final List<double> _samples = List.filled(_barCount, 0.0, growable: true);
  double _smoothedAmplitude = 0.0;
  late AnimationController _tickController;

  /// Controls smooth fade-in/out on resume/pause.
  /// 1.0 = fully recording, 0.0 = fully paused.
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _subscribeToAmplitude();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      reverseDuration: const Duration(milliseconds: 1200),
      value: widget.isRecording ? 1.0 : 0.0,
    )..addListener(() {
        // Needed so ring opacity updates every frame during fade.
        if (mounted) setState(() {});
      });

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // One wave per 2 seconds (3 waves total)
    )..addListener(_onTick);

    if (widget.isRecording) {
      _tickController.repeat();
    }
  }

  DateTime _lastTick = DateTime.now();

  static final math.Random _rng = math.Random();

  void _onTick() {
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds < 50) return;
    _lastTick = now;

    if (!mounted) return;

    setState(() {
      _samples.removeAt(0);
      // Add micro-variation (±12%) per sample to break the "rectangle"
      // effect.  Without this, groups of 4 bars (50 ms tick vs 200 ms
      // amplitude poll) share the exact same height → flat block.
      // The variation is proportional to the amplitude so silence stays
      // flat and speech looks organically wavy.
      final jitter = 1.0 + (_rng.nextDouble() - 0.5) * 0.24;
      _samples.add((_smoothedAmplitude * jitter).clamp(0.0, 1.0));
    });
  }

  @override
  void didUpdateWidget(EuphireWaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !oldWidget.isRecording) {
      // ── Resume ──
      if (!_tickController.isAnimating) _tickController.repeat();
      _fadeController.forward();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      // ── Pause ──
      // Kill amplitude immediately so new bars pushed by _onTick
      // are flat (zero).  Existing "live" bars stay in _samples and
      // naturally scroll off the left edge over ~1 s (20 bars × 50 ms).
      // Rings fade via _fadeController.  Tick controller keeps running
      // until the fade completes.
      _smoothedAmplitude = 0.0;
      _fadeController.reverse().then((_) {
        if (mounted && !widget.isRecording) {
          _tickController.stop();
          setState(() => _samples.fillRange(0, _barCount, 0.0));
        }
      });
    }

    if (widget.amplitudeStream != oldWidget.amplitudeStream) {
      _subscribeToAmplitude();
    }
  }

  void _subscribeToAmplitude() {
    _amplitudeSub?.cancel();
    final stream = widget.amplitudeStream;
    if (stream == null) return;

    _amplitudeSub = stream.listen((amplitudeValue) {
      if (!mounted || !widget.isRecording) return;
      // The source signal is already noise-gated and quadratic-scaled
      // in RecordingService — no additional pow() transform needed.
      //
      // OLD: pow(raw, 0.7) — exponent < 1 _inflated_ small values
      // (noise at 0.1 → 0.2), killing dynamic range.
      final raw = amplitudeValue.clamp(0.0, 1.0);
      // Smoothing: alpha 0.55 reacts fast to speech transients
      // but still damps per-frame jitter. Higher = more responsive.
      const double alpha = 0.55;
      _smoothedAmplitude = alpha * raw + (1.0 - alpha) * _smoothedAmplitude;
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _tickController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // fade: 1.0 during recording, animates to 0.0 on pause.
    final fade = _fadeController.value;
    // Show rings when recording OR during fade-out (fade > 0).
    final showRings = widget.isRecording || fade > 0.01;

    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 400,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient Radar Rings — visible during recording AND
            // during fade-out so existing rings gracefully complete.
            if (showRings)
              AnimatedBuilder(
                animation: _tickController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _buildRing(1.0 + (_tickController.value * 3.0), 0.3 * (1 - _tickController.value) * fade),
                      _buildRing(1.0 + (((_tickController.value + 0.33) % 1.0) * 3.0), 0.3 * (1 - ((_tickController.value + 0.33) % 1.0)) * fade),
                      _buildRing(1.0 + (((_tickController.value + 0.66) % 1.0) * 3.0), 0.3 * (1 - ((_tickController.value + 0.66) % 1.0)) * fade),
                    ],
                  );
                },
              )
            else
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _buildRing(1.0, 0.1),
                ],
              ),

            // Core Button Gradient and Shadow
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00383D), Color(0xFF001D20)],
                ),
                border: Border.all(
                  color: EuphireColors.ember.withValues(alpha: widget.isRecording ? 0.4 : 0.2),
                  width: 2,
                ),
                boxShadow: [
                  // Outer Glow
                  if (widget.isRecording)
                    BoxShadow(
                      color: EuphireColors.ember.withValues(alpha: 0.15),
                      blurRadius: 30,
                    ),
                  // Inner Shadow (simulated)
                  BoxShadow(
                    color: EuphireColors.evergreen.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Horizontal Waveform
                  SizedBox(
                    height: 60,
                    width: 120,
                    child: CustomPaint(
                      painter: _HorizontalWaveformPainter(
                        samples: _samples,
                        color: Colors.white, // Białt waveform
                        isRecording: widget.isRecording,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.isRecording ? "Nagrywanie trwa" : "Nagrywanie wstrzymane",
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      color: EuphireColors.mist,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.formattedDuration,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      fontSize: 28,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRing(double scale, double opacity) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: EuphireColors.ember.withValues(alpha: opacity.clamp(0.0, 1.0)),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _HorizontalWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final bool isRecording;

  _HorizontalWaveformPainter({
    required this.samples,
    required this.color,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {

    final barCount = samples.length;
    final maxBarHeight = size.height;
    const minBarHeight = 2.0; // Was 4 — thinner silence bars
    const barWidth = 4.5;
    final spacing = (size.width - (barCount * barWidth)) / (barCount - 1);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final sample = samples[i];
      final barHeight = minBarHeight + (maxBarHeight - minBarHeight) * sample;

      final x = i * (barWidth + spacing);
      final y = (size.height - barHeight) / 2;

      final opacity = 0.3 + 0.7 * sample;
      paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(rrect, paint);

      // Glow on moderate-to-loud speech (threshold lowered from 0.4)
      if (sample > 0.2) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: (0.15 + 0.15 * sample).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 4 * sample);
        canvas.drawRRect(rrect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_HorizontalWaveformPainter oldDelegate) => true;
}
