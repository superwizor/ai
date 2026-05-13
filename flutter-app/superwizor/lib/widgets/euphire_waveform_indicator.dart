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
    with SingleTickerProviderStateMixin {
  StreamSubscription<double>? _amplitudeSub;
  static const int _barCount = 60;

  final List<double> _samples = List.filled(_barCount, 0.0, growable: true);
  double _smoothedAmplitude = 0.0;
  late AnimationController _tickController;

  @override
  void initState() {
    super.initState();
    _subscribeToAmplitude();

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Ring pulse duration
    )..addListener(_onTick);

    if (widget.isRecording) {
      _tickController.repeat();
    }
  }

  DateTime _lastTick = DateTime.now();

  void _onTick() {
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds < 50) return;
    _lastTick = now;

    if (!mounted) return;

    setState(() {
      _samples.removeAt(0);
      _samples.add(_smoothedAmplitude);
    });
  }

  @override
  void didUpdateWidget(EuphireWaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !oldWidget.isRecording) {
      _tickController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _smoothedAmplitude = 0.0;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !widget.isRecording) {
          _tickController.stop();
          // Clear samples on stop
          setState(() {
            _samples.fillRange(0, _barCount, 0.0);
          });
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
      double raw = amplitudeValue.clamp(0.0, 1.0);
      raw = math.pow(raw, 0.7).toDouble();
      const double alpha = 0.35;
      _smoothedAmplitude = alpha * raw + (1.0 - alpha) * _smoothedAmplitude;
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 288,
        height: 288,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Radar Rings
            if (widget.isRecording)
              AnimatedBuilder(
                animation: _tickController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildRing(1.0 + (_tickController.value * 0.1), 0.2 * (1 - _tickController.value)),
                      _buildRing(1.1 + (_tickController.value * 0.15), 0.1 * (1 - _tickController.value)),
                      _buildRing(1.25 + (_tickController.value * 0.2), 0.05 * (1 - _tickController.value)),
                    ],
                  );
                },
              )
            else
              Stack(
                alignment: Alignment.center,
                children: [
                  _buildRing(1.0, 0.2),
                  _buildRing(1.1, 0.1),
                  _buildRing(1.25, 0.05),
                ],
              ),

            // Core Button Gradient and Shadow
            Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00383D), Color(0xFF001D20)],
                ),
                border: Border.all(
                  color: EuphireColors.ember.withValues(alpha: widget.isRecording ? 0.4 : 0.2),
                  width: 1,
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
                    color: EuphireColors.ember.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: widget.isRecording ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: EuphireColors.ember,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.formattedDuration,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      fontSize: 24,
                      color: EuphireColors.ember,
                    ),
                  ),
                ],
              ),
            ),

            // Circular Waveform Layer
            if (widget.isRecording)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CircularWaveformPainter(
                    samples: _samples,
                    color: EuphireColors.ember,
                    isRecording: widget.isRecording,
                    innerRadius: 112, // 224 / 2
                  ),
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
        width: 224,
        height: 224,
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

class _CircularWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final bool isRecording;
  final double innerRadius;

  _CircularWaveformPainter({
    required this.samples,
    required this.color,
    required this.isRecording,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRecording) return;

    final center = Offset(size.width / 2, size.height / 2);
    final barCount = samples.length;
    final maxBarHeight = 32.0; // Extend outwards up to 32px
    final minBarHeight = 2.0;
    final barWidth = 3.0;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final sample = samples[i];
      final barHeight = minBarHeight + (maxBarHeight - minBarHeight) * sample;

      final angle = (i * 2 * math.pi) / barCount - (math.pi / 2); // Start from top

      final x1 = center.dx + innerRadius * math.cos(angle);
      final y1 = center.dy + innerRadius * math.sin(angle);
      final x2 = center.dx + (innerRadius + barHeight) * math.cos(angle);
      final y2 = center.dy + (innerRadius + barHeight) * math.sin(angle);

      final opacity = 0.3 + 0.7 * sample;
      paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      paint.strokeWidth = barWidth;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

      if (sample > 0.4) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: (0.2 * sample).clamp(0.0, 1.0))
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CircularWaveformPainter oldDelegate) => true;
}
