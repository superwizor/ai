import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Waveform indicator reagujący na prawdziwy dźwięk z mikrofonu.
///
/// Zasada działania:
/// - Trzymamy bufor ostatnich N próbek amplitudy (sliding window).
/// - Każdy pasek odpowiada jednej próbce z bufora.
/// - Nowa próbka wchodzi z prawej → stare przesuwają się w lewo.
/// - Efekt: fala "płynie" od prawej do lewej jak prawdziwy waveform w DAW.
/// - W ciszy paski minimalnie oddychają (idle noise).
class EuphireWaveformIndicator extends StatefulWidget {
  final bool isRecording;
  final Stream<double>? amplitudeStream;

  const EuphireWaveformIndicator({
    super.key,
    required this.isRecording,
    this.amplitudeStream,
  });

  @override
  State<EuphireWaveformIndicator> createState() =>
      _EuphireWaveformIndicatorState();
}

class _EuphireWaveformIndicatorState extends State<EuphireWaveformIndicator>
    with SingleTickerProviderStateMixin {
  StreamSubscription<double>? _amplitudeSub;

  static const int _barCount = 30;

  /// Bufor próbek amplitudy — indeks 0 = najstarsza, indeks last = najnowsza.
  final List<double> _samples = List.filled(_barCount, 0.0, growable: true);

  /// Smoothed amplitude (EMA) żeby uniknąć skoków między próbkami
  double _smoothedAmplitude = 0.0;

  late AnimationController _tickController;

  @override
  void initState() {
    super.initState();
    _subscribeToAmplitude();

    // Tick co ~60ms — przesuwa bufor i odświeża UI
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);

    if (widget.isRecording) {
      _tickController.repeat();
    }
  }

  DateTime _lastTick = DateTime.now();

  void _onTick() {
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds < 60) return;
    _lastTick = now;

    if (!mounted) return;

    setState(() {
      // Przesuń bufor: usuń najstarszą próbkę, dodaj najnowszą na koniec
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
      // Wygaś falę
      _smoothedAmplitude = 0.0;
      // Daj jeszcze kilka ticków żeby fala ładnie opadła
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !widget.isRecording) {
          _tickController.stop();
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

      // amplitudeValue is already mapped to 0.0..1.0 in RecordingService
      double raw = amplitudeValue.clamp(0.0, 1.0);

      // Krzywa potęgowa — żeby ciche dźwięki były bardziej widoczne
      raw = math.pow(raw, 0.7).toDouble();

      // Exponential Moving Average — wygładzanie
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
    final theme = Theme.of(context);
    final baseColor = widget.isRecording
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary.withValues(alpha: 0.3);

    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _WaveformPainter(
          samples: _samples,
          color: baseColor,
          isRecording: widget.isRecording,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final bool isRecording;

  _WaveformPainter({
    required this.samples,
    required this.color,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = samples.length;
    final maxBarWidth = 5.0;
    final gap = 3.0;
    final totalWidth = barCount * (maxBarWidth + gap) - gap;
    final startX = (size.width - totalWidth) / 2;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.9;
    final minBarHeight = 4.0;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final sample = samples[i];

      // Wysokość paseczka proporcjonalna do amplitudy
      final barHeight = minBarHeight + (maxBarHeight - minBarHeight) * sample;
      final halfBar = barHeight / 2;

      final x = startX + i * (maxBarWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, centerY - halfBar, x + maxBarWidth, centerY + halfBar),
        const Radius.circular(3),
      );

      // Kolor z gradientem jasności w zależności od amplitudy
      final opacity = 0.4 + 0.6 * sample;
      paint.color = color.withValues(alpha: opacity);

      canvas.drawRRect(rect, paint);

      // Glow effect dla głośnych próbek
      if (isRecording && sample > 0.4) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.15 * sample)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}
