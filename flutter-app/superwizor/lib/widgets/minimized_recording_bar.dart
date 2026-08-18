import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../services/recording_service.dart';
import '../providers/services_provider.dart';
import '../theme/euphire_theme.dart';
import '../screens/recording_screen.dart';
import '../main.dart'; // to access navigatorKey

class RecordingScreenVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setVisible(bool visible) {
    state = visible;
  }
}

final recordingScreenVisibleProvider =
    NotifierProvider<RecordingScreenVisibleNotifier, bool>(
  () => RecordingScreenVisibleNotifier(),
);

class ActiveRecordingOverlay extends ConsumerWidget {
  final Widget child;
  const ActiveRecordingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(recordingScreenVisibleProvider);
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MinimizedRecordingBarWrapper(
            recordingScreenVisible: isVisible,
          ),
        ),
      ],
    );
  }
}

class _MinimizedRecordingBarWrapper extends ConsumerStatefulWidget {
  final bool recordingScreenVisible;
  const _MinimizedRecordingBarWrapper({required this.recordingScreenVisible});

  @override
  ConsumerState<_MinimizedRecordingBarWrapper> createState() =>
      _MinimizedRecordingBarWrapperState();
}

class _MinimizedRecordingBarWrapperState
    extends ConsumerState<_MinimizedRecordingBarWrapper> {
  StreamSubscription<RecordingState>? _stateSub;
  StreamSubscription<Duration>? _durSub;
  RecordingState _state = RecordingState.idle;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final svc = ref.read(recordingServiceProvider);
    _state = svc.state;
    _duration = svc.currentDuration;

    _stateSub = svc.stateStream.listen((s) {
      if (mounted) {
        setState(() => _state = s);
      }
    });
    _durSub = svc.durationStream.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecordingOrPaused = _state == RecordingState.recording ||
        _state == RecordingState.paused ||
        _state == RecordingState.interrupted;

    final shouldShow = isRecordingOrPaused && !widget.recordingScreenVisible;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: shouldShow
          ? _buildBar(context)
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  Widget _buildBar(BuildContext context) {
    final t = AppLocalizations.of(context);
    final svc = ref.read(recordingServiceProvider);
    final patientAlias = svc.patientAlias ?? '';
    final formattedDuration = _formatDuration(_duration);

    return SafeArea(
      key: const ValueKey('bar'),
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F353A), Color(0xFF0A2326)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'RecordingScreen'),
                    builder: (_) => RecordingScreen(
                      patientFileId: svc.patientFileId ?? '',
                      therapistId: svc.therapistId ?? '',
                      patientAlias: svc.patientAlias ?? '',
                      reportLanguage: svc.reportLanguage ?? 'pl-PL',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _PulsingRecordingDot(
                      isRecording: _state == RecordingState.recording,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _state == RecordingState.paused
                                ? t.minimized_recording_paused
                                : _state == RecordingState.interrupted
                                    ? t.minimized_recording_interrupted
                                    : t.minimized_recording_active,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: EuphireColors.mist.withValues(alpha: 0.7),
                            ),
                          ),
                          if (patientAlias.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              patientAlias,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: EuphireColors.frostWhite,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDuration,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: EuphireColors.ember,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.fullscreen_rounded,
                      color: EuphireColors.mist,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }
}

class _PulsingRecordingDot extends StatefulWidget {
  final bool isRecording;
  const _PulsingRecordingDot({required this.isRecording});

  @override
  State<_PulsingRecordingDot> createState() => _PulsingRecordingDotState();
}

class _PulsingRecordingDotState extends State<_PulsingRecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isRecording) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingRecordingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
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
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isRecording) ...[
              _buildRipple(1.0 + (_controller.value * 1.5), 1.0 - _controller.value),
              _buildRipple(1.0 + (((_controller.value + 0.5) % 1.0) * 1.5), 1.0 - ((_controller.value + 0.5) % 1.0)),
            ],
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording ? EuphireColors.magma : EuphireColors.mist,
                boxShadow: widget.isRecording
                    ? [
                        BoxShadow(
                          color: EuphireColors.magma.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRipple(double scale, double opacity) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EuphireColors.magma.withValues(alpha: opacity * 0.4),
        ),
      ),
    );
  }
}
