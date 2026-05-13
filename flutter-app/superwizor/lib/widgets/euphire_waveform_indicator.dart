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
  static const int _barCount = 20;

  final List<double> _samples = List.filled(_barCount, 0.0, growable: true);
  double _smoothedAmplitude = 0.0;
  late AnimationController _tickController;

  @override
  void initState() {
    super.initState();
    _subscribeToAmplitude();

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // One wave per 2 seconds (3 waves total)
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
        width: double.infinity,
        height: 400,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient Radar Rings
            if (widget.isRecording)
              AnimatedBuilder(
                animation: _tickController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _buildRing(1.0 + (_tickController.value * 3.0), 0.3 * (1 - _tickController.value)),
                      _buildRing(1.0 + (((_tickController.value + 0.33) % 1.0) * 3.0), 0.3 * (1 - ((_tickController.value + 0.33) % 1.0))),
                      _buildRing(1.0 + (((_tickController.value + 0.66) % 1.0) * 3.0), 0.3 * (1 - ((_tickController.value + 0.66) % 1.0))),
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
    if (!isRecording) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
      return;
    }

    final barCount = samples.length;
    final maxBarHeight = size.height;
    final minBarHeight = 4.0;
    final barWidth = 4.0;
    final spacing = (size.width - (barCount * barWidth)) / (barCount - 1);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final sample = samples[i];
      final barHeight = minBarHeight + (maxBarHeight - minBarHeight) * sample;

      final x = i * (barWidth + spacing) + barWidth / 2;
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      final opacity = 0.3 + 0.7 * sample;
      paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      paint.strokeWidth = barWidth;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
      
      if (sample > 0.4) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: (0.2 * sample).clamp(0.0, 1.0))
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(Offset(x, y1), Offset(x, y2), glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_HorizontalWaveformPainter oldDelegate) => true;
}
