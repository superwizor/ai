// RecordingCountdownOverlay — 3→2→1 countdown before recording starts.
//
// Replaces the old "idle → instant recording" jump that briefly flashed
// the yellow mic button. The countdown sets user expectation ("recording
// is about to start") and gives the OS/plugin a breathing window so
// the heavy-init work (AVAudioSession setup, permission prompt fallback,
// wakelock) runs while the user watches a number tick down — not while
// they stare at a frozen UI.
//
// Design: large number in the center with a scale+fade animation per
// tick, an Ember ring pulse behind it, and a "Przygotuj się…" label
// underneath. Uses the Euphire 3-font system (Montserrat number,
// Merriweather subtitle).

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/euphire_theme.dart';

/// Full-screen overlay that counts 3 → 2 → 1, then calls [onComplete].
///
/// The widget is meant to be placed in a Stack that covers the entire
/// recording screen body. It blocks interaction (absorbs taps) and
/// fades itself out on the final tick.
class RecordingCountdownOverlay extends StatefulWidget {
  /// Called when the countdown finishes (after the "1" animation).
  final VoidCallback onComplete;

  const RecordingCountdownOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<RecordingCountdownOverlay> createState() =>
      _RecordingCountdownOverlayState();
}

class _RecordingCountdownOverlayState extends State<RecordingCountdownOverlay>
    with TickerProviderStateMixin {
  int _currentNumber = 3;
  late AnimationController _numberController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  late AnimationController _ringController;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  Timer? _ticker;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    // Number pop: scale 0.3→1.0 with a slight overshoot, then fade out
    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_numberController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_numberController);

    // Ring pulse
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ringScale = Tween<double>(begin: 0.6, end: 1.6).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    _playTick();
  }

  void _playTick() {
    _numberController.forward(from: 0);
    _ringController.forward(from: 0);

    _ticker = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_currentNumber > 1) {
        setState(() => _currentNumber--);
        _playTick();
      } else {
        setState(() => _finished = true);
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _numberController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();

    return AbsorbPointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ring pulse
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _ringScale.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: EuphireColors.ember
                                  .withValues(alpha: _ringOpacity.value),
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Static glow circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EuphireColors.ember.withValues(alpha: 0.08),
                      border: Border.all(
                        color: EuphireColors.ember.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                  ),
                  // Number
                  AnimatedBuilder(
                    animation: _numberController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Text(
                            '$_currentNumber',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: EuphireColors.ember,
                              height: 1.0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Przygotuj się…',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 16,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: EuphireColors.frostWhite.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
