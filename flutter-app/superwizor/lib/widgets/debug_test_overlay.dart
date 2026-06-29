// Debug panel for testing notification badge & sort behaviour.
//
// Shows a floating pill (🛠) in the bottom-left corner that opens a
// bottom sheet with quick-action buttons. Only renders in debug mode
// (kDebugMode is compile-time const, so it's tree-shaken in release).
//
// TEMPORARY — remove before App Store submission.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/sort_filter_provider.dart';
import '../providers/viewed_reports_provider.dart';
import '../providers/current_user_provider.dart';
import '../providers/patient_provider.dart';
import '../models/session.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../screens/debug_pipeline_simulator_screen.dart';
import '../screens/debug_state_gallery_screen.dart';
import '../utils/debug_flags.dart';
import '../utils/haptics.dart';
import '../providers/services_provider.dart';
import '../services/recording_service.dart';
import '../main.dart';

final showDebugButtonProvider = NotifierProvider<ShowDebugButtonNotifier, bool>(
  () {
    return ShowDebugButtonNotifier();
  },
);

class ShowDebugButtonNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void show() => state = true;
  void hide() => state = false;
}

/// In debug builds, provides access to a debug sheet via a red floating action
/// button in the bottom right corner or via [openDebugSheet] (from the logo gesture).
/// In release builds it renders only its [child] — zero overhead.
class DebugTestOverlay extends ConsumerWidget {
  final Widget child;
  const DebugTestOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showButton = ref.watch(showDebugButtonProvider);
    if (!showButton && !kDebugMode && !kProfileMode) {
      return child;
    }

    return Stack(
      children: [
        child,
        if (showButton)
          Positioned(
            right: 16,
            bottom: 90,
            child: SafeArea(child: _DebugFloatingButton(ref: ref)),
          ),
      ],
    );
  }

  /// Opens the debug sheet programmatically. Called from the 7-tap
  /// gesture handler on the "Superwizor AI" logo in home_screen.dart.
  static void openDebugSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: navigatorKey.currentContext ?? context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DebugSheet(ref: ref),
    );
  }
}

class _DebugFloatingButton extends StatefulWidget {
  final WidgetRef ref;
  const _DebugFloatingButton({required this.ref});

  @override
  State<_DebugFloatingButton> createState() => _DebugFloatingButtonState();
}

class _DebugFloatingButtonState extends State<_DebugFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          AppHapticFeedback.heavyImpact();
          DebugTestOverlay.openDebugSheet(context, widget.ref);
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: const Center(
            child: Icon(
              Icons.bug_report_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Debug bottom sheet ────────────────────────────────────────────

class _DebugSheet extends StatelessWidget {
  final WidgetRef ref;
  const _DebugSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final viewedReportsAsync = ref.watch(viewedReportsProvider);
    final sortFilterAsync = ref.watch(sortFilterProvider);
    final sessionsAsync = ref.watch(sessionsProvider);

    final viewedReports = viewedReportsAsync.value ?? <String>{};
    final sortFilter = sortFilterAsync.value ?? const SortFilterState();
    final sessionsMap = sessionsAsync.value ?? {};

    // Count total sessions and completed sessions
    int totalSessions = 0;
    int completedSessions = 0;
    int unreadReports = 0;
    final sessionDetails = <_SessionDebugInfo>[];

    for (final entry in sessionsMap.entries) {
      for (final session in entry.value) {
        totalSessions++;
        if (session.status == SessionStatus.completed) {
          completedSessions++;
          final isViewed = viewedReports.contains(session.id);
          if (!isViewed) unreadReports++;
          sessionDetails.add(
            _SessionDebugInfo(
              patientId: entry.key,
              sessionId: session.id,
              status: session.status,
              isViewed: isViewed,
              date: session.date,
            ),
          );
        }
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.deepOrange, width: 2)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.bug_report,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DEBUG PANEL — Badges & Sortowanie',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Everything below scrolls
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── State overview ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatRow(
                            label: 'Viewed reports',
                            value: '${viewedReports.length}',
                          ),
                          _StatRow(
                            label: 'Unread reports',
                            value: '$unreadReports',
                            highlight: unreadReports > 0,
                          ),
                          _StatRow(
                            label: 'Total sessions',
                            value: '$totalSessions',
                          ),
                          _StatRow(
                            label: 'Completed',
                            value: '$completedSessions',
                          ),
                          _StatRow(
                            label: 'Sort mode',
                            value: sortFilter.sortMode.name,
                          ),
                          _StatRow(
                            label: 'Needs attention filter',
                            value: sortFilter.needsAttentionOnly ? 'ON' : 'off',
                            highlight: sortFilter.needsAttentionOnly,
                          ),
                          if (sortFilter.modalityFilter.isNotEmpty)
                            _StatRow(
                              label: 'Modality filter',
                              value: sortFilter.modalityFilter.join(', '),
                            ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 1),

                    // ── Action buttons ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Column(
                        children: [
                          _ActionButton(
                            icon: Icons.visibility_off,
                            label: 'Reset WSZYSTKIE badge (czyść viewed)',
                            subtitle:
                                'Każdy completed raport pokaże "Nowy raport"',
                            color: Colors.redAccent,
                            onTap: () async {
                              final user = ref.read(currentUserProvider).value;
                              if (user == null) return;
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.remove('viewed_reports_${user.id}');
                              // Force rebuild by invalidating the provider
                              ref.invalidate(viewedReportsProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✅ Viewed reports wyczyszczone — zrób hot restart',
                                    ),
                                    backgroundColor: Colors.deepOrange,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _ActionButton(
                            icon: Icons.check_circle_outline,
                            label: 'Oznacz WSZYSTKIE jako przeczytane',
                            subtitle: 'Każdy completed report → "Gotowy"',
                            color: Colors.greenAccent,
                            onTap: () async {
                              final notifier = ref.read(
                                viewedReportsProvider.notifier,
                              );
                              for (final entry in sessionsMap.entries) {
                                for (final session in entry.value) {
                                  if (session.status ==
                                      SessionStatus.completed) {
                                    await notifier.markViewed(session.id);
                                  }
                                }
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✅ Wszystkie raporty oznaczone jako viewed',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _ActionButton(
                            icon: Icons.sort,
                            label: 'Reset sortowania i filtrów',
                            subtitle: 'Przywróć domyślne: Ostatnia aktywność',
                            color: Colors.blueAccent,
                            onTap: () {
                              ref.read(sortFilterProvider.notifier).reset();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Sort/filter zresetowany do domyślnych',
                                  ),
                                  backgroundColor: Colors.blueAccent,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _ActionButton(
                            icon: Icons.graphic_eq,
                            label: 'Test: czy „alarm" psuje nagranie?',
                            subtitle:
                                'Nagrywa 6s, w połowie gra dźwięk przypomnienia, mierzy skutek',
                            color: Colors.deepOrange,
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final svc = ref.read(recordingServiceProvider);
                              Navigator.pop(context);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('🎙️ Test nagrywania… (~6 s)'),
                                  backgroundColor: Colors.deepOrange,
                                  duration: Duration(seconds: 6),
                                ),
                              );
                              final result = await _recordingIntegrityProbe(
                                svc,
                              );
                              messenger.hideCurrentSnackBar();
                              // The debug sheet's `context` was popped above, so
                              // it's unmounted — show the result on the root
                              // navigator instead (otherwise the dialog silently
                              // never appears).
                              final rootCtx = navigatorKey.currentContext;
                              if (rootCtx == null || !rootCtx.mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(result),
                                    backgroundColor: Colors.deepOrange,
                                    duration: const Duration(seconds: 12),
                                  ),
                                );
                                return;
                              }
                              await showDialog<void>(
                                context: rootCtx,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1A1A2E),
                                  title: const Text(
                                    'Integralność nagrywania',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  content: Text(
                                    result,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'RobotoMono',
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _ActionButton(
                            icon: Icons.delete_sweep,
                            label: 'Wyczyść CAŁY SharedPreferences',
                            subtitle: '⚠️ Nuclear option — czyści wszystko',
                            color: Colors.red,
                            onTap: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.clear();
                              ref.invalidate(viewedReportsProvider);
                              ref.invalidate(sortFilterProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '💣 SharedPreferences wyczyszczony — hot restart!',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 1),

                    // ── Recording simulation buttons (debug-only) ──
                    if (kDebugMode || DebugFlags.simulationsEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SYMULACJE — NAGRYWANIE',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.orange.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Testuje ekran nagrywania i wstrzymania (np. połączenie)',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Consumer(
                              builder: (context, ref, child) {
                                final service = ref.watch(
                                  recordingServiceProvider,
                                );
                                final active =
                                    service.state == RecordingState.recording ||
                                    service.state == RecordingState.paused ||
                                    service.state == RecordingState.interrupted;
                                return Column(
                                  children: [
                                    _ActionButton(
                                      icon: Icons.phone_paused_rounded,
                                      label:
                                          service.state ==
                                              RecordingState.interrupted
                                          ? 'Wyłącz symulację wstrzymania'
                                          : 'Symuluj wstrzymanie nagrywania',
                                      subtitle: active
                                          ? 'Przełącza stan aktywnego nagrywania (połączenie)'
                                          : '⚠️ Uruchom najpierw nagrywanie z ekranu pacjenta',
                                      color: active
                                          ? Colors.orangeAccent
                                          : Colors.grey,
                                      onTap: () {
                                        if (active) {
                                          Navigator.pop(context);
                                          if (service.state ==
                                              RecordingState.interrupted) {
                                            service.debugForceState(
                                              RecordingState.recording,
                                            );
                                          } else {
                                            service.debugForceState(
                                              RecordingState.interrupted,
                                            );
                                          }
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '⚠️ Uruchom najpierw nagrywanie z ekranu pacjenta',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.deepOrange,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                    ],

                    // ── Session simulation buttons (debug-only) ──
                    if (kDebugMode || DebugFlags.simulationsEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SYMULACJE STANÓW — SESJE',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.purple.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (ctx) {
                                // Get first patient to inject sessions into
                                final patients =
                                    ref.watch(patientsProvider).value ?? [];
                                if (patients.isEmpty) {
                                  return Text(
                                    'Brak pacjentów — dodaj pacjenta aby symulować',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  );
                                }
                                final firstPatient = patients.first;
                                const debugSessionId = 'debug-sim-session-001';

                                // Check if debug session already exists
                                final existingSessions =
                                    sessionsMap[firstPatient.id] ?? [];
                                final debugSession = existingSessions
                                    .where((s) => s.id == debugSessionId)
                                    .firstOrNull;

                                return Column(
                                  children: [
                                    // Target patient info
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Colors.purple.withValues(
                                              alpha: 0.6,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Cel: ${firstPatient.firstName} ${firstPatient.lastName}',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 11,
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (debugSession != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _colorForStatus(
                                                  debugSession.status,
                                                ).withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                debugSession.status.name,
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: _colorForStatus(
                                                    debugSession.status,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    _ActionButton(
                                      icon: Icons.auto_awesome,
                                      label: 'Symuluj: AI analizuje',
                                      subtitle:
                                          'Wrzuca sesję inProgress → kafelek "AI analizuje"',
                                      color: Colors.purpleAccent,
                                      onTap: () {
                                        ref
                                            .read(sessionsProvider.notifier)
                                            .debugInjectSession(
                                              patientId: firstPatient.id,
                                              sessionId: debugSessionId,
                                              status: SessionStatus.inProgress,
                                            );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '🔄 Fake "AI analizuje" injected',
                                            ),
                                            backgroundColor: Colors.purple,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.cloud_upload,
                                      label: 'Symuluj: Upload pending',
                                      subtitle:
                                          'Wrzuca sesję pendingUpload → "Wgrywanie pliku"',
                                      color: Colors.orangeAccent,
                                      onTap: () {
                                        ref
                                            .read(sessionsProvider.notifier)
                                            .debugInjectSession(
                                              patientId: firstPatient.id,
                                              sessionId: debugSessionId,
                                              status:
                                                  SessionStatus.pendingUpload,
                                            );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '☁️ Fake "pendingUpload" injected',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.error_outline,
                                      label: 'Symuluj: Błąd analizy',
                                      subtitle:
                                          'Wrzuca sesję error → kafelek "Błąd analizy"',
                                      color: Colors.redAccent,
                                      onTap: () {
                                        ref
                                            .read(sessionsProvider.notifier)
                                            .debugInjectSession(
                                              patientId: firstPatient.id,
                                              sessionId: debugSessionId,
                                              status: SessionStatus.error,
                                            );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '❌ Fake "error" injected',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.celebration,
                                      label:
                                          'Symuluj: inProgress → completed (10s)',
                                      subtitle:
                                          'Injektuje inProgress, po 10s → completed → 🎉',
                                      color: Colors.tealAccent,
                                      onTap: () {
                                        final notifier = ref.read(
                                          sessionsProvider.notifier,
                                        );
                                        // Step 1: inject inProgress
                                        notifier.debugInjectSession(
                                          patientId: firstPatient.id,
                                          sessionId: debugSessionId,
                                          status: SessionStatus.inProgress,
                                        );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '⏳ inProgress → za 10s completed...',
                                            ),
                                            backgroundColor: Colors.teal,
                                            duration: Duration(seconds: 10),
                                          ),
                                        );
                                        // Step 2: after 10 seconds, flip to completed
                                        Future.delayed(
                                          const Duration(seconds: 10),
                                          () {
                                            notifier.debugTransitionSession(
                                              firstPatient.id,
                                              debugSessionId,
                                              SessionStatus.completed,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    if (debugSession != null)
                                      _ActionButton(
                                        icon: Icons.delete_outline,
                                        label: 'Usuń debug sesję',
                                        subtitle:
                                            'Czyści fake session z widoku',
                                        color: Colors.grey,
                                        onTap: () {
                                          ref
                                              .read(sessionsProvider.notifier)
                                              .debugRemoveSession(
                                                firstPatient.id,
                                                debugSessionId,
                                              );
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '🗑 Debug session usunięta',
                                              ),
                                              backgroundColor: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white12, height: 1),

                      // ── Upload simulation buttons (debug-only) ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SYMULACJE STANÓW — UPLOAD',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.cyan.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (ctx) {
                                final patients =
                                    ref.watch(patientsProvider).value ?? [];
                                if (patients.isEmpty) {
                                  return Text(
                                    'Brak pacjentów — dodaj pacjenta aby symulować upload',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  );
                                }
                                final firstPatient = patients.first;
                                final user = ref
                                    .watch(currentUserProvider)
                                    .value;
                                final therapistId =
                                    user?.id ?? 'debug-therapist';

                                return Column(
                                  children: [
                                    _ActionButton(
                                      icon: Icons.cloud_upload_outlined,
                                      label: 'Symuluj: Upload 100 MB (30s)',
                                      subtitle:
                                          'Fake upload z animowanym progress barem 0→100%',
                                      color: Colors.cyanAccent,
                                      onTap: () async {
                                        const localId = 'debug-upload-100mb';
                                        final runner = await ref.read(
                                          uploadQueueRunnerProvider.future,
                                        );
                                        if (runner == null) return;

                                        final fakeUpload = PendingUpload(
                                          localId: localId,
                                          therapistId: therapistId,
                                          patientFileId: firstPatient.id,
                                          patientLanguageCode: 'pl-PL',
                                          sourceKind:
                                              UploadSourceKind.plainFile,
                                          sourcePath: '/debug/fake-100mb.flac',
                                          contentType: 'audio/flac',
                                          sizeBytes: 104857600, // 100 MB
                                          chunkCount: 1,
                                          actualDurationSeconds: 3600,
                                          needsServerSideConversion: false,
                                          phase: UploadPhase
                                              .created, // uploading phase
                                          idempotencyKey: localId,
                                          queuedAt: DateTime.now().toUtc(),
                                          nextAttemptAt: DateTime.now()
                                              .toUtc()
                                              .add(
                                                const Duration(hours: 24),
                                              ), // never due
                                          uploadProgress: 0.0,
                                        );
                                        runner.debugInjectRow(fakeUpload);

                                        // Animate progress 0→1 over 30 seconds
                                        const totalSteps = 60;
                                        const intervalMs = 500; // 30s total
                                        int step = 0;
                                        Timer.periodic(
                                          const Duration(
                                            milliseconds: intervalMs,
                                          ),
                                          (timer) {
                                            step++;
                                            final fraction = step / totalSteps;
                                            if (step >= totalSteps) {
                                              timer.cancel();
                                              // Clean up the fake row
                                              runner.debugDismissRow(localId);
                                              debugPrint(
                                                '[debug] 100MB upload simulation complete',
                                              );
                                              return;
                                            }
                                            runner.debugSetProgress(
                                              localId,
                                              fraction,
                                            );
                                          },
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '📤 Upload 100MB symulacja — 30s progress',
                                              ),
                                              backgroundColor: Colors.cyan,
                                              duration: Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.error,
                                      label: 'Symuluj: Upload failed',
                                      subtitle:
                                          'Fake upload z phase=failed i błędem',
                                      color: Colors.red,
                                      onTap: () async {
                                        const localId = 'debug-upload-failed';
                                        final runner = await ref.read(
                                          uploadQueueRunnerProvider.future,
                                        );
                                        if (runner == null) return;

                                        final fakeUpload = PendingUpload(
                                          localId: localId,
                                          therapistId: therapistId,
                                          patientFileId: firstPatient.id,
                                          patientLanguageCode: 'pl-PL',
                                          sourceKind:
                                              UploadSourceKind.plainFile,
                                          sourcePath: '/debug/fake-failed.flac',
                                          contentType: 'audio/flac',
                                          sizeBytes: 52428800, // 50 MB
                                          chunkCount: 1,
                                          actualDurationSeconds: 1800,
                                          needsServerSideConversion: false,
                                          phase: UploadPhase.failed,
                                          idempotencyKey: localId,
                                          queuedAt: DateTime.now().toUtc(),
                                          nextAttemptAt: DateTime.now().toUtc(),
                                          lastError:
                                              'debug.simulated_network_error',
                                          terminatedAt: DateTime.now().toUtc(),
                                        );
                                        runner.debugInjectRow(fakeUpload);

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '💥 Upload failed injected — sprawdź pending uploads',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.block,
                                      label: 'Symuluj: Quota exceeded',
                                      subtitle:
                                          'Fake upload z phase=quotaBlocked',
                                      color: Colors.amber,
                                      onTap: () async {
                                        const localId = 'debug-upload-quota';
                                        final runner = await ref.read(
                                          uploadQueueRunnerProvider.future,
                                        );
                                        if (runner == null) return;

                                        final fakeUpload = PendingUpload(
                                          localId: localId,
                                          therapistId: therapistId,
                                          patientFileId: firstPatient.id,
                                          patientLanguageCode: 'pl-PL',
                                          sourceKind:
                                              UploadSourceKind.plainFile,
                                          sourcePath: '/debug/fake-quota.flac',
                                          contentType: 'audio/flac',
                                          sizeBytes: 31457280, // 30 MB
                                          chunkCount: 1,
                                          actualDurationSeconds: 900,
                                          needsServerSideConversion: false,
                                          phase: UploadPhase.quotaBlocked,
                                          idempotencyKey: localId,
                                          queuedAt: DateTime.now().toUtc(),
                                          nextAttemptAt: DateTime.now().toUtc(),
                                          lastError: 'QUOTA_EXHAUSTED',
                                        );
                                        runner.debugInjectRow(fakeUpload);

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '🚫 Quota blocked injected — sprawdź pending uploads',
                                              ),
                                              backgroundColor: Colors.amber,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.wifi_off,
                                      label: 'Symuluj: Upload pada w 50%',
                                      subtitle:
                                          'Upload rośnie do 50%, potem fail (network_timeout)',
                                      color: Colors.deepOrange,
                                      onTap: () async {
                                        const localId =
                                            'debug-upload-interrupted';
                                        final runner = await ref.read(
                                          uploadQueueRunnerProvider.future,
                                        );
                                        if (runner == null) return;

                                        final fakeUpload = PendingUpload(
                                          localId: localId,
                                          therapistId: therapistId,
                                          patientFileId: firstPatient.id,
                                          patientLanguageCode: 'pl-PL',
                                          sourceKind:
                                              UploadSourceKind.plainFile,
                                          sourcePath:
                                              '/debug/fake-interrupted.flac',
                                          contentType: 'audio/flac',
                                          sizeBytes: 73400320, // 70 MB
                                          chunkCount: 1,
                                          actualDurationSeconds: 2700,
                                          needsServerSideConversion: false,
                                          phase: UploadPhase.created,
                                          idempotencyKey: localId,
                                          queuedAt: DateTime.now().toUtc(),
                                          nextAttemptAt: DateTime.now()
                                              .toUtc()
                                              .add(const Duration(hours: 24)),
                                          uploadProgress: 0.0,
                                        );
                                        runner.debugInjectRow(fakeUpload);

                                        // Animate 0→50% over 8 seconds, then fail
                                        const totalSteps = 16;
                                        const intervalMs = 500;
                                        int step = 0;
                                        Timer.periodic(
                                          const Duration(
                                            milliseconds: intervalMs,
                                          ),
                                          (timer) {
                                            step++;
                                            final fraction =
                                                (step / totalSteps) * 0.5;
                                            if (step >= totalSteps) {
                                              timer.cancel();
                                              // Flip to failed state
                                              runner.debugInjectRow(
                                                PendingUpload(
                                                  localId: localId,
                                                  therapistId: therapistId,
                                                  patientFileId:
                                                      firstPatient.id,
                                                  patientLanguageCode: 'pl-PL',
                                                  sourceKind: UploadSourceKind
                                                      .plainFile,
                                                  sourcePath:
                                                      '/debug/fake-interrupted.flac',
                                                  contentType: 'audio/flac',
                                                  sizeBytes: 73400320,
                                                  chunkCount: 1,
                                                  actualDurationSeconds: 2700,
                                                  needsServerSideConversion:
                                                      false,
                                                  phase: UploadPhase.failed,
                                                  idempotencyKey: localId,
                                                  queuedAt: DateTime.now()
                                                      .toUtc(),
                                                  nextAttemptAt: DateTime.now()
                                                      .toUtc(),
                                                  uploadProgress: 0.5,
                                                  lastError:
                                                      'network_timeout: connection lost at 50%',
                                                  terminatedAt: DateTime.now()
                                                      .toUtc(),
                                                ),
                                              );
                                              debugPrint(
                                                '[debug] Upload interrupted at 50%',
                                              );
                                              return;
                                            }
                                            runner.debugSetProgress(
                                              localId,
                                              fraction,
                                            );
                                          },
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '⚡ Upload rośnie do 50%, fail za ~8s',
                                              ),
                                              backgroundColor:
                                                  Colors.deepOrange,
                                              duration: Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.playlist_add,
                                      label: 'Symuluj: 3 uploady naraz',
                                      subtitle:
                                          'Testuje kolejkę z wieloma plikami jednocześnie',
                                      color: Colors.lightBlueAccent,
                                      onTap: () async {
                                        final runner = await ref.read(
                                          uploadQueueRunnerProvider.future,
                                        );
                                        if (runner == null) return;
                                        final patients =
                                            ref.read(patientsProvider).value ??
                                            [];
                                        if (patients.isEmpty) return;

                                        // Use up to 3 different patients or repeat the first one
                                        final configs =
                                            <
                                              (
                                                String localId,
                                                String patientId,
                                                int sizeBytes,
                                                int durationSec,
                                                int animMs,
                                              )
                                            >[
                                              (
                                                'debug-multi-1',
                                                patients[0].id,
                                                52428800,
                                                1800,
                                                400,
                                              ),
                                              (
                                                'debug-multi-2',
                                                patients.length > 1
                                                    ? patients[1].id
                                                    : patients[0].id,
                                                31457280,
                                                900,
                                                600,
                                              ),
                                              (
                                                'debug-multi-3',
                                                patients.length > 2
                                                    ? patients[2].id
                                                    : patients[0].id,
                                                83886080,
                                                2400,
                                                300,
                                              ),
                                            ];

                                        for (final (
                                              localId,
                                              patientId,
                                              sizeBytes,
                                              dur,
                                              _,
                                            )
                                            in configs) {
                                          runner.debugInjectRow(
                                            PendingUpload(
                                              localId: localId,
                                              therapistId: therapistId,
                                              patientFileId: patientId,
                                              patientLanguageCode: 'pl-PL',
                                              sourceKind:
                                                  UploadSourceKind.plainFile,
                                              sourcePath:
                                                  '/debug/$localId.flac',
                                              contentType: 'audio/flac',
                                              sizeBytes: sizeBytes,
                                              chunkCount: 1,
                                              actualDurationSeconds: dur,
                                              needsServerSideConversion: false,
                                              phase: UploadPhase.created,
                                              idempotencyKey: localId,
                                              queuedAt: DateTime.now().toUtc(),
                                              nextAttemptAt: DateTime.now()
                                                  .toUtc()
                                                  .add(
                                                    const Duration(hours: 24),
                                                  ),
                                              uploadProgress: 0.0,
                                            ),
                                          );
                                        }

                                        // Animate each at different speeds (staggered finish)
                                        for (final (localId, _, _, _, animMs)
                                            in configs) {
                                          int step = 0;
                                          const totalSteps = 50;
                                          Timer.periodic(
                                            Duration(milliseconds: animMs),
                                            (timer) {
                                              step++;
                                              if (step >= totalSteps) {
                                                timer.cancel();
                                                runner.debugDismissRow(localId);
                                                debugPrint(
                                                  '[debug] Multi-upload $localId completed',
                                                );
                                                return;
                                              }
                                              runner.debugSetProgress(
                                                localId,
                                                step / totalSteps,
                                              );
                                            },
                                          );
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '📦 3 uploady naraz — różne prędkości',
                                              ),
                                              backgroundColor: Colors.lightBlue,
                                              duration: Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionButton(
                                      icon: Icons.cleaning_services,
                                      label: 'Wyczyść debug uploads',
                                      subtitle:
                                          'Usuń wszystkie fake uploady z pamięci',
                                      color: Colors.grey,
                                      onTap: () async {
                                        final runner = await ref.read(
                                          uploadQueueRunnerProvider.future,
                                        );
                                        if (runner == null) return;

                                        for (final id in [
                                          'debug-upload-100mb',
                                          'debug-upload-failed',
                                          'debug-upload-quota',
                                          'debug-upload-interrupted',
                                          'debug-multi-1',
                                          'debug-multi-2',
                                          'debug-multi-3',
                                        ]) {
                                          runner.debugDismissRow(id);
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '🧹 Debug uploads wyczyszczone',
                                              ),
                                              backgroundColor: Colors.grey,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white12, height: 1),

                      // ── Pipeline stepper simulation (debug-only) ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SYMULACJE — PIPELINE STEPPER',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.teal.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Testuje ekran z 4 krokami po wysłaniu nagrania',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ActionButton(
                              icon: Icons.check_circle_outline,
                              label: 'Pipeline: Happy Path (auto)',
                              subtitle:
                                  'pending → uploaded → analyzing → done (16s total)',
                              color: Colors.greenAccent,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DebugPipelineSimulatorScreen(
                                          autoAdvance: true,
                                          simulateFailure: false,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            _ActionButton(
                              icon: Icons.error_outline,
                              label: 'Pipeline: Failure Path (auto)',
                              subtitle:
                                  'pending → uploaded → analyzing → FAILED (16s)',
                              color: Colors.redAccent,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DebugPipelineSimulatorScreen(
                                          autoAdvance: true,
                                          simulateFailure: true,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            _ActionButton(
                              icon: Icons.touch_app,
                              label: 'Pipeline: Manual (krok po kroku)',
                              subtitle:
                                  'Ręcznie klikaj → next step, testuj każdy stan',
                              color: Colors.tealAccent,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DebugPipelineSimulatorScreen(
                                          autoAdvance: false,
                                          simulateFailure: false,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            _ActionButton(
                              icon: Icons.grid_view_rounded,
                              label: 'State Gallery: Wszystkie stany',
                              subtitle:
                                  '11 kafelków — podgląd każdego stanu bez nagrywania',
                              color: Colors.amberAccent,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DebugStateGalleryScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ] // end kDebugMode simulation sections
                    else ...[
                      // Release-mode info banner
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Symulacje stanów dostępne tylko w trybie debug\n(uruchom aplikację przez emulator lub macOS)',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (sessionDetails.isNotEmpty) ...[
                      const Divider(color: Colors.white12, height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Text(
                          'COMPLETED SESSIONS (${sessionDetails.length})',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          itemCount: sessionDetails.length,
                          itemBuilder: (context, index) {
                            final info = sessionDetails[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    info.isViewed
                                        ? Icons.check_circle
                                        : Icons.new_releases,
                                    size: 14,
                                    color: info.isViewed
                                        ? Colors.green
                                        : Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${info.sessionId.substring(0, 8)}… ${info.date.day}/${info.date.month}',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (info.isViewed) {
                                        // Can't "unview" easily with current API, skip
                                        return;
                                      }
                                      ref
                                          .read(viewedReportsProvider.notifier)
                                          .markViewed(info.sessionId);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: info.isViewed
                                            ? Colors.green.withValues(
                                                alpha: 0.15,
                                              )
                                            : Colors.amber.withValues(
                                                alpha: 0.15,
                                              ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        info.isViewed ? 'viewed' : 'TAP → view',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: info.isViewed
                                              ? Colors.green
                                              : Colors.amber,
                                        ),
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

                    const SizedBox(height: 16),
                  ], // end scrollable Column children
                ), // end Column
              ), // end SingleChildScrollView
            ), // end Flexible
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────

Color _colorForStatus(SessionStatus status) {
  switch (status) {
    case SessionStatus.inProgress:
      return Colors.purpleAccent;
    case SessionStatus.pendingUpload:
      return Colors.orangeAccent;
    case SessionStatus.completed:
      return Colors.greenAccent;
    case SessionStatus.error:
      return Colors.redAccent;
  }
}

/// On-device reproduction of the "does the reminder bell damage the recording"
/// question (see piotrak@yahoo.com truncated-transcript investigation):
///   1. start a throwaway recording,
///   2. capture ~3 s,
///   3. play the reminder sound EXACTLY as the feature does (the "alarm"),
///   4. capture ~3 s more,
///   5. stop and measure — did iOS interrupt capture? is the FLAC short?
///
/// Compares the wall-clock timer to the actual FLAC byte count (16 kHz mono
/// FLAC ≈ 13 KiB/s) and reports `hadInterruption` + the state transitions, so
/// the tester can SEE whether the audible reminder truncates/corrupts capture.
/// The throwaway session dir is deleted afterwards. Auto-pause is intentionally
/// NOT tested here: it is a clean pause→finish (no resume), so it cannot corrupt.
Future<String> _recordingIntegrityProbe(RecordingService svc) async {
  if (svc.state == RecordingState.recording ||
      svc.state == RecordingState.paused ||
      svc.state == RecordingState.interrupted) {
    return 'Aktywne nagrywanie w toku — zakończ je najpierw i spróbuj ponownie.';
  }
  final id = 'debug-integrity-${DateTime.now().microsecondsSinceEpoch}';
  final states = <String>[];
  StreamSubscription<RecordingState>? sub;
  String? path;
  final player = AudioPlayer();
  try {
    sub = svc.stateStream.listen((s) => states.add(s.name));
    await svc.start(id);
    await Future<void>.delayed(const Duration(seconds: 3));
    final tMid = svc.currentDuration;

    // Fire the reminder sound on the SAME asset/path the feature uses.
    try {
      await player.play(AssetSource('sounds/Dźwięk zakończenia sesji.mp3'));
    } catch (_) {
      /* asset/play failure is itself a finding */
    }

    await Future<void>.delayed(const Duration(seconds: 3));
    final tEnd = svc.currentDuration;
    final hadInt = svc.hadInterruption;
    final stateAtStop = svc.state.name;

    path = await svc.stop();

    int bytes = 0;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) bytes = await f.length();
    }
    final expectKB = tEnd.inMilliseconds / 1000.0 * 13.0; // ~13 KiB/s
    final actualKB = bytes / 1024.0;
    final truncated = expectKB > 0 && actualKB < expectKB * 0.6;

    final verdict = (truncated || hadInt)
        ? '⚠️ DŹWIĘK USZKODZIŁ NAGRANIE'
              '${truncated ? "\n   • audio ucięte (plik za krótki)" : ""}'
              '${hadInt ? "\n   • iOS przerwał przechwytywanie" : ""}'
        : '✅ Nagranie nienaruszone — dźwięk nie przeszkodził';

    return [
      'timer: po 3s=${(tMid.inMilliseconds / 1000).toStringAsFixed(1)}s, '
          'koniec=${(tEnd.inMilliseconds / 1000).toStringAsFixed(1)}s',
      'stany: ${states.isEmpty ? "—" : states.join(" → ")}',
      'stan przy stop: $stateAtStop',
      'hadInterruption: $hadInt  →  ${hadInt ? "audio/x-flac" : "audio/flac"}',
      'plik: ${actualKB.toStringAsFixed(0)} KB '
          '(oczek. ~${expectKB.toStringAsFixed(0)} KB)',
      '',
      verdict,
    ].join('\n');
  } catch (e) {
    return 'błąd sondy: $e';
  } finally {
    await sub?.cancel();
    await player.dispose();
    // Remove the throwaway <docs>/sessions/<id>/ dir.
    if (path != null) {
      try {
        final dir = File(path).parent;
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {
        /* best-effort */
      }
    }
  }
}

class _SessionDebugInfo {
  final String patientId;
  final String sessionId;
  final SessionStatus status;
  final bool isViewed;
  final DateTime date;

  const _SessionDebugInfo({
    required this.patientId,
    required this.sessionId,
    required this.status,
    required this.isViewed,
    required this.date,
  });
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? Colors.amber
                  : Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
