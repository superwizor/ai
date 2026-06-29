// Debug Pipeline Simulator — walks through SessionStepperPhase states
// so you can visually verify the stepper UI without a real backend.
//
// Two modes:
//   1. Auto (default): pending → uploaded → analyzing → done at 4s intervals
//   2. Manual: tap-to-advance each phase
//
// Also supports "failure path": pending → uploaded → failed
//
// TEMPORARY — gated by DebugFlags.simulationsEnabled (runtime toggle).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/euphire_theme.dart';
import '../utils/debug_flags.dart';
import '../widgets/euphire_session_status_stepper.dart';

/// Standalone screen that simulates the session processing pipeline
/// by cycling through [SessionStepperPhase] values without hitting
/// Firestore or gRPC.
class DebugPipelineSimulatorScreen extends StatefulWidget {
  /// When true, automatically advances phases with timers.
  final bool autoAdvance;

  /// When true, the pipeline will end in "failed" instead of "done".
  final bool simulateFailure;

  const DebugPipelineSimulatorScreen({
    super.key,
    this.autoAdvance = true,
    this.simulateFailure = false,
  });

  @override
  State<DebugPipelineSimulatorScreen> createState() =>
      _DebugPipelineSimulatorScreenState();
}

class _DebugPipelineSimulatorScreenState
    extends State<DebugPipelineSimulatorScreen> {
  SessionStepperPhase _phase = SessionStepperPhase.pending;
  Timer? _autoTimer;
  int _stepIndex = 0;
  bool _collapsed = false;
  final _log = <_LogEntry>[];

  // The happy path sequence
  late final List<SessionStepperPhase> _sequence;

  @override
  void initState() {
    super.initState();
    _sequence = widget.simulateFailure
        ? [
            SessionStepperPhase.pending,
            SessionStepperPhase.uploaded,
            SessionStepperPhase.transcribing,
            SessionStepperPhase.analyzing,
            SessionStepperPhase.failed,
          ]
        : [
            SessionStepperPhase.pending,
            SessionStepperPhase.uploaded,
            SessionStepperPhase.transcribing,
            SessionStepperPhase.analyzing,
            SessionStepperPhase.done,
          ];
    _addLog('Symulacja rozpoczęta', 'pending');
    if (widget.autoAdvance) _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _startAutoAdvance() {
    // Staggered delays per step to feel realistic:
    //   pending→uploaded: 3s (upload to GCS)
    //   uploaded→transcribing: 4s (STT worker submits)
    //   transcribing→analyzing: 5s (Chirp returns, finalize)
    //   analyzing→done/failed: 8s (LLM processing)
    const delays = [3, 4, 5, 8];
    _advanceWithDelay(delays, 0);
  }

  void _advanceWithDelay(List<int> delays, int idx) {
    if (idx >= delays.length) return;
    _autoTimer = Timer(Duration(seconds: delays[idx]), () {
      _advance();
      _advanceWithDelay(delays, idx + 1);
    });
  }

  void _advance() {
    if (_stepIndex >= _sequence.length - 1) return;
    _stepIndex++;
    final next = _sequence[_stepIndex];
    setState(() => _phase = next);
    _addLog(_descriptionFor(next), next.name);

    if (next == SessionStepperPhase.done) {
      // Simulate the success cascade: collapse the stepper after a beat
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _collapsed = true);
      });
    }
  }

  void _reset() {
    _autoTimer?.cancel();
    setState(() {
      _stepIndex = 0;
      _phase = SessionStepperPhase.pending;
      _collapsed = false;
      _log.clear();
    });
    _addLog('Symulacja zresetowana', 'pending');
    if (widget.autoAdvance) _startAutoAdvance();
  }

  void _addLog(String message, String status) {
    setState(() {
      _log.add(
        _LogEntry(time: DateTime.now(), message: message, status: status),
      );
    });
  }

  String _descriptionFor(SessionStepperPhase phase) {
    return switch (phase) {
      SessionStepperPhase.pending => 'Oczekiwanie na upload...',
      SessionStepperPhase.uploading => 'Przesyłanie audio na serwer...',
      SessionStepperPhase.uploaded => 'Audio przesłane na serwer (GCS)',
      SessionStepperPhase.transcribing =>
        'STT worker → Chirp transkrypcja (batch)',
      SessionStepperPhase.analyzing =>
        'Transkrypcja gotowa → LLM worker analizuje',
      SessionStepperPhase.done => '✅ Raport gotowy — success cascade',
      SessionStepperPhase.failed =>
        '❌ Pipeline error — failure sheet triggered',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: EuphireColors.evergreen,
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: EuphireColors.frostWhite,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pipeline Simulator',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepOrange.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            widget.simulateFailure
                                ? 'Ścieżka: FAILURE'
                                : 'Ścieżka: HAPPY PATH',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              color: widget.simulateFailure
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reset button
                    IconButton(
                      icon: const Icon(
                        Icons.replay,
                        color: Colors.deepOrange,
                        size: 22,
                      ),
                      onPressed: _reset,
                      tooltip: 'Reset symulacji',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Current phase indicator ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _colorForPhase(_phase).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _colorForPhase(_phase).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconForPhase(_phase),
                      color: _colorForPhase(_phase),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Faza: ${_phase.name.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _colorForPhase(_phase),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      '${_stepIndex + 1}/${_sequence.length}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── The actual stepper widget under test ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: EuphireSessionStatusStepper(
                  phase: _phase,
                  collapsed: _collapsed,
                ),
              ),

              const SizedBox(height: 16),

              // ── Manual advance button (always visible) ──
              if (_stepIndex < _sequence.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _autoTimer?.cancel();
                        _advance();
                      },
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: Text(
                        'Następny krok → ${_sequence[_stepIndex + 1].name}',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange.withValues(
                          alpha: 0.15,
                        ),
                        foregroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.deepOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(
                color: Colors.white12,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),

              // ── Pipeline log ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.terminal,
                      size: 14,
                      color: Colors.deepOrange.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PIPELINE LOG',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.deepOrange.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  reverse: true,
                  itemCount: _log.length,
                  itemBuilder: (ctx, i) {
                    final entry = _log[_log.length - 1 - i];
                    final timeStr =
                        '${entry.time.hour.toString().padLeft(2, '0')}:'
                        '${entry.time.minute.toString().padLeft(2, '0')}:'
                        '${entry.time.second.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono, monospace',
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: _colorForStatus(entry.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.message,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForPhase(SessionStepperPhase phase) {
    return switch (phase) {
      SessionStepperPhase.pending => Colors.white54,
      SessionStepperPhase.uploading => Colors.blueAccent,
      SessionStepperPhase.uploaded => Colors.cyanAccent,
      SessionStepperPhase.transcribing => Colors.lightBlueAccent,
      SessionStepperPhase.analyzing => Colors.purpleAccent,
      SessionStepperPhase.done => Colors.greenAccent,
      SessionStepperPhase.failed => Colors.redAccent,
    };
  }

  IconData _iconForPhase(SessionStepperPhase phase) {
    return switch (phase) {
      SessionStepperPhase.pending => Icons.hourglass_top,
      SessionStepperPhase.uploading => Icons.cloud_upload,
      SessionStepperPhase.uploaded => Icons.cloud_done,
      SessionStepperPhase.transcribing => Icons.record_voice_over,
      SessionStepperPhase.analyzing => Icons.auto_awesome,
      SessionStepperPhase.done => Icons.check_circle,
      SessionStepperPhase.failed => Icons.error,
    };
  }

  Color _colorForStatus(String status) {
    return switch (status) {
      'pending' => Colors.white38,
      'uploaded' => Colors.cyanAccent,
      'analyzing' => Colors.purpleAccent,
      'done' => Colors.greenAccent,
      'failed' => Colors.redAccent,
      _ => Colors.white24,
    };
  }
}

class _LogEntry {
  final DateTime time;
  final String message;
  final String status;
  const _LogEntry({
    required this.time,
    required this.message,
    required this.status,
  });
}
