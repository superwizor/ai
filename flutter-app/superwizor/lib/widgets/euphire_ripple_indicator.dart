import 'package:flutter/material.dart';

class EuphireRippleIndicator extends StatefulWidget {
  final bool isRecording;
  final Widget child;

  const EuphireRippleIndicator({
    super.key,
    required this.isRecording,
    required this.child,
  });

  @override
  State<EuphireRippleIndicator> createState() => _EuphireRippleIndicatorState();
}

class _EuphireRippleIndicatorState extends State<EuphireRippleIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.isRecording) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(EuphireRippleIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isRecording) ...[
              _buildRipple(theme, 1.0 + (_controller.value * 0.5), 1.0 - _controller.value),
              _buildRipple(theme, 1.0 + (((_controller.value + 0.5) % 1.0) * 0.5), 1.0 - ((_controller.value + 0.5) % 1.0)),
            ],
            widget.child,
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _buildRipple(ThemeData theme, double scale, double opacity) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary.withValues(alpha: opacity * 0.3),
        ),
      ),
    );
  }
}
