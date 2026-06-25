// Debug State Gallery — Storybook-style preview of every visual state
// the SessionStatusScreen can be in. No real backend, Hive queue, or
// Firestore needed — all data is synthetic.
//
// Each tile renders the real EuphireSessionStatusStepper + a recording
// details card with hardcoded mock data. Tap a tile → full-screen
// isolated preview in the exact layout SessionStatusScreen uses.
//
// TEMPORARY — gated by kDebugMode (same as the pipeline simulator).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../theme/euphire_theme.dart';
import '../widgets/euphire_session_status_stepper.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_action_sheet.dart';

// ─── State Scenario Definitions ──────────────────────────────────────

/// A single scenario you can preview in the gallery.
class _StateScenario {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final SessionStepperPhase phase;
  final bool quotaBlocked;
  final bool showSuccess;
  final bool showFailure;
  final String patientName;
  final int durationSeconds;
  final double? sizeMB;
  final String? uploadStatus;
  final double? uploadProgress;
  final String? errorMessage;
  final bool collapsed;

  const _StateScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.phase,
    this.quotaBlocked = false,
    this.showSuccess = false,
    this.showFailure = false,
    this.patientName = 'Kuba Pacjent',
    this.durationSeconds = 2940, // 49 min
    this.sizeMB = 23.5,
    this.uploadStatus,
    this.uploadProgress,
    this.errorMessage,
    this.collapsed = false,
  });
}

const _scenarios = <_StateScenario>[
  _StateScenario(
    id: 'pending',
    title: 'PENDING',
    subtitle: 'Kolejka — oczekuje na upload',
    icon: Icons.hourglass_top,
    color: Colors.white54,
    phase: SessionStepperPhase.pending,
    uploadStatus: 'queued',
  ),
  _StateScenario(
    id: 'uploading',
    title: 'UPLOADING',
    subtitle: 'HTTP PUT w toku — 45%',
    icon: Icons.cloud_upload,
    color: Colors.blueAccent,
    phase: SessionStepperPhase.uploading,
    uploadStatus: 'uploading',
    uploadProgress: 0.45,
  ),
  _StateScenario(
    id: 'uploaded',
    title: 'UPLOADED',
    subtitle: 'Audio bezpieczne na serwerze',
    icon: Icons.cloud_done,
    color: Colors.cyanAccent,
    phase: SessionStepperPhase.uploaded,
  ),
  _StateScenario(
    id: 'analyzing',
    title: 'ANALYZING',
    subtitle: 'STT + LLM w toku',
    icon: Icons.auto_awesome,
    color: Colors.purpleAccent,
    phase: SessionStepperPhase.analyzing,
  ),
  _StateScenario(
    id: 'done',
    title: 'DONE ✅',
    subtitle: 'Raport gotowy — success cascade',
    icon: Icons.check_circle,
    color: Colors.greenAccent,
    phase: SessionStepperPhase.done,
    showSuccess: true,
    collapsed: true,
  ),
  _StateScenario(
    id: 'failed_upload',
    title: 'FAILED (upload)',
    subtitle: 'Błąd sieci / uploadu',
    icon: Icons.wifi_off_rounded,
    color: Colors.redAccent,
    phase: SessionStepperPhase.failed,
    showFailure: true,
    errorMessage: 'network: SocketException: Connection refused',
  ),
  _StateScenario(
    id: 'failed_pipeline',
    title: 'FAILED (pipeline)',
    subtitle: 'Błąd STT/LLM po stronie serwera',
    icon: Icons.sync_problem_rounded,
    color: Colors.orangeAccent,
    phase: SessionStepperPhase.failed,
    showFailure: true,
    errorMessage: 'gRPC INTERNAL: STT worker timeout after 300s',
  ),
  _StateScenario(
    id: 'quota_blocked',
    title: 'QUOTA BLOCKED 🚫',
    subtitle: 'Brak tokenów — zaparkowany',
    icon: Icons.block,
    color: Colors.amber,
    phase: SessionStepperPhase.pending,
    quotaBlocked: true,
  ),
  _StateScenario(
    id: 'zero_duration',
    title: '0 MIN (kartoteka)',
    subtitle: 'Wejście z kartoteki — brak duration',
    icon: Icons.timer_off,
    color: Colors.tealAccent,
    phase: SessionStepperPhase.uploaded,
    patientName: 'Anna Kowalska',
    durationSeconds: 0,
    sizeMB: null,
  ),
  _StateScenario(
    id: 'home_screen_kartoteka',
    title: 'GŁÓWNA KARTOTEKA',
    subtitle: 'Podgląd wszystkich statusów na liście pacjentów',
    icon: Icons.home_rounded,
    color: Colors.lightGreenAccent,
    phase: SessionStepperPhase.done,
  ),
  _StateScenario(
    id: 'client_details_kartoteka',
    title: 'KARTOTEKA KLIENTA',
    subtitle: 'Podgląd wszystkich statusów na liście sesji',
    icon: Icons.person_rounded,
    color: Colors.blueAccent,
    phase: SessionStepperPhase.done,
  ),
  _StateScenario(
    id: 'minimized_recording',
    title: 'SESJA W TOKU',
    subtitle: 'Pasek nagrywania w tle (zminimalizowany)',
    icon: Icons.mic_none_rounded,
    color: Colors.redAccent,
    phase: SessionStepperPhase.pending,
  ),
];

// ─── Gallery Screen ──────────────────────────────────────────────────

class DebugStateGalleryScreen extends StatelessWidget {
  const DebugStateGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      icon: const Icon(Icons.arrow_back_ios,
                          color: EuphireColors.frostWhite, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'State Gallery',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.amberAccent.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${_scenarios.length} stanów — tap to preview',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Grid of scenarios ──
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _scenarios.length,
                  itemBuilder: (context, i) =>
                      _ScenarioTile(scenario: _scenarios[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scenario Tile (miniature preview) ───────────────────────────────

class _ScenarioTile extends StatelessWidget {
  final _StateScenario scenario;
  const _ScenarioTile({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ScenarioPreviewScreen(scenario: scenario),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scenario.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scenario.color.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title
            Row(
              children: [
                Icon(scenario.icon, color: scenario.color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    scenario.title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scenario.color,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              scenario.subtitle,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            // ── Mini stepper or bar preview ──
            Expanded(
              child: ClipRect(
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: 0.55,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 400, // render at real size, scale down
                      child: scenario.id == 'minimized_recording'
                          ? const _MockMinimizedRecordingBar(
                              patientName: 'Kuba Pacjent',
                              durationString: '00:07',
                              isRecording: true,
                            )
                          : EuphireSessionStatusStepper(
                              phase: scenario.phase,
                              collapsed: scenario.collapsed,
                              quotaBlocked: scenario.quotaBlocked,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-Screen Preview ─────────────────────────────────────────────

class _ScenarioPreviewScreen extends StatelessWidget {
  final _StateScenario scenario;
  const _ScenarioPreviewScreen({required this.scenario});

  @override
  Widget build(BuildContext context) {
    if (scenario.id == 'home_screen_kartoteka') {
      return _HomeScreenPreviewWrapper(scenario: scenario);
    }
    if (scenario.id == 'client_details_kartoteka') {
      return _ClientDetailsPreviewWrapper(scenario: scenario);
    }
    if (scenario.id == 'minimized_recording') {
      return _MinimizedRecordingPreviewWrapper(scenario: scenario);
    }

    final now = DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(now);
    final formattedDate = DateFormat('d MMMM yyyy', 'pl').format(now);
    final minutes = (scenario.durationSeconds / 60).toStringAsFixed(0);
    final formattedSize = scenario.sizeMB != null
        ? '${scenario.sizeMB!.toStringAsFixed(1)} MB'
        : null;

    final isNetworkError = scenario.id == 'failed_upload';
    final isProcessingError = scenario.id == 'failed_pipeline';

    return Scaffold(
      backgroundColor: EuphireColors.evergreen,
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header with debug info ──
              _buildDebugHeader(context),

              // ── Recording Details Card (same as real screen) ──
              if (!scenario.showSuccess)
                _buildRecordingDetailsCard(
                  scenario.patientName,
                  formattedTime,
                  formattedDate,
                  minutes,
                  formattedSize,
                  scenario.durationSeconds,
                ),

              // ── Main content ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: scenario.showSuccess
                              ? _buildSuccessPreview()
                              : scenario.showFailure
                                  ? _buildFailurePreview()
                                  : _buildProcessingPreview(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom buttons (same layout as real screen) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scenario.quotaBlocked || isNetworkError) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final conn = await Connectivity().checkConnectivity();
                            final online = conn.any((r) => r != ConnectivityResult.none);
                            if (!online) {
                              if (context.mounted) {
                                await showEuphireBottomSheet<void>(
                                  context: context,
                                  builder: (context) => EuphireActionSheet(
                                    header: 'Brak internetu',
                                    body: 'Połączenie sieciowe jest obecnie niedostępne. Plik zostanie wysłany automatycznie, gdy tylko odzyskasz połączenie z internetem.',
                                    primary: EuphireSheetAction(
                                      label: 'Rozumiem',
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    topIcon: Icons.wifi_off_rounded,
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Symulacja ponownego wysyłania (online)...'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(scenario.quotaBlocked
                              ? 'Wyślij ponownie'
                              : 'Ponów'),
                          style: FilledButton.styleFrom(
                            backgroundColor: EuphireColors.ember,
                            foregroundColor: EuphireColors.obsidianBlack,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isProcessingError) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final mailId = 'MOCK-SESSION-ID-1234';
                            final patientName = scenario.patientName;
                            final dateStr = formattedDate;
                            final timeStr = formattedTime;
                            final durationText = '$minutes min';
                            final lastErrorStr = scenario.errorMessage ?? 'gRPC INTERNAL: STT worker timeout after 300s';
                            
                            final bodyText = 'Cześć,\n\n'
                                'Napotkałem problem podczas analizy sesji w aplikacji. Oto szczegóły diagnostyczne:\n\n'
                                '• Pacjent/Kartoteka: $patientName\n'
                                '• Data i godzina: $dateStr, $timeStr\n'
                                '• Długość nagrania: $durationText\n'
                                '• Identyfikator sesji (Session ID): $mailId\n'
                                '• Kod błędu: $lastErrorStr\n\n'
                                'Proszę o pomoc w rozwiązaniu problemu.';

                            // Copy to clipboard
                            try {
                              await Clipboard.setData(ClipboardData(text: bodyText));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Skopiowano dane diagnostyczne do schowka!'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              // ignored in mock
                            }

                            final mailUrl = Uri.parse(
                              'mailto:kontakt@superwizor.ai'
                              '?subject=${Uri.encodeComponent('Problem z analizą sesji ($mailId)')}'
                              '&body=${Uri.encodeComponent(bodyText)}',
                            );

                            try {
                              await launchUrl(mailUrl, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              // ignored in mock
                            }
                          },
                          icon: const Icon(Icons.mail_outline_rounded, size: 20),
                          label: const Text('Napisz do nas (kontakt@superwizor.ai)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: EuphireColors.ember,
                            foregroundColor: EuphireColors.obsidianBlack,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (scenario.showFailure) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                          label: const Text('Usuń sesję'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EuphireColors.magma,
                            side: BorderSide(
                              color:
                                  EuphireColors.magma.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: const Text('Wróć do galerii'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EuphireColors.mist,
                          side: BorderSide(
                            color: EuphireColors.mist.withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  // ── Debug header (shows scenario metadata) ──

  Widget _buildDebugHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scenario.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scenario.color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: EuphireColors.frostWhite, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Icon(scenario.icon, color: scenario.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW: ${scenario.title}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scenario.color,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  scenario.subtitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          // Phase badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scenario.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              scenario.phase.name,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: scenario.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recording Details Card (identical layout to real screen) ──

  Widget _buildRecordingDetailsCard(
    String patientName,
    String formattedTime,
    String formattedDate,
    String minutes,
    String? formattedSize,
    int durationSeconds,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: EuphireColors.ember.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  patientName,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$formattedTime  •  $formattedDate',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              // Duration — hidden when 0 (same logic as real screen)
              if (durationSeconds > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$minutes min',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: EuphireColors.mist.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              if (formattedSize != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.audiotrack_rounded,
                      size: 14,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedSize,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: EuphireColors.mist.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Processing View ──

  Widget _buildProcessingPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // ── Header text ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bezpieczna analiza w toku.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: EuphireColors.ember,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Twoje nagranie jest szyfrowane i przetwarzane lokalnie. '
              'Analiza trwa kilka minut.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: EuphireColors.mist.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        // ── Stepper ──
        EuphireSessionStatusStepper(
          phase: scenario.phase,
          collapsed: scenario.collapsed,
          quotaBlocked: scenario.quotaBlocked,
          activeStepContent: _buildMockActiveStepContent(),
        ),
        const SizedBox(height: 32),
        // Reassurance Text
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              scenario.phase == SessionStepperPhase.pending || scenario.phase == SessionStepperPhase.uploading
                  ? 'Możesz zamknąć aplikację. Przesyłanie trwa w tle.'
                  : 'Możesz zamknąć aplikację. Analiza trwa w tle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 12,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget? _buildMockActiveStepContent() {
    if (scenario.quotaBlocked) return null;

    if (!(scenario.phase == SessionStepperPhase.pending ||
        scenario.phase == SessionStepperPhase.uploading)) {
      return null;
    }

    final isUploading = scenario.phase == SessionStepperPhase.uploading;
    final mb = scenario.sizeMB?.toStringAsFixed(1) ?? '0.0';
    final mins = (scenario.durationSeconds / 60).toStringAsFixed(0);
    const cType = 'audio/flac';
    final time = DateFormat('HH:mm').format(DateTime.now());
    final progress = scenario.uploadProgress ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Details sub-card (compact single line) first
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: EuphireColors.obsidianBlack.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.audiotrack_rounded,
                  size: 13,
                  color: EuphireColors.mist.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$mb MB  •  $mins min  •  $cType  •  $time',
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10,
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          if (isUploading) ...[
            // Progress Bar Row (lower)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(EuphireColors.ember),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: EuphireColors.mist.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Spinner for pending (lower, text removed)
            Row(
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(EuphireColors.ember),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Success View ──

  Widget _buildSuccessPreview() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: EuphireColors.ember,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: EuphireColors.ember.withValues(alpha: 0.25),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 64,
              color: EuphireColors.obsidianBlack,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Gotowe!',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: EuphireColors.frostWhite,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wysyłamy wnioski do Ciebie.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: EuphireColors.mist.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Failure View ──

  Widget _buildFailurePreview() {
    // Classify: failed_upload scenario is a network error, failed_pipeline is a processing error
    final isNetworkError = scenario.id == 'failed_upload';

    final (IconData icon, String title, String body) = isNetworkError
        ? (
            Icons.wifi_off_rounded,
            'Przesyłanie zatrzymane',
            'Wygląda na to, że połączenie z siecią zostało przerwane. '
                'Twoje nagranie jest bezpieczne na urządzeniu — '
                'żaden fragment danych nie został utracony. '
                'Przesyłanie wznowi się automatycznie po '
                'przywróceniu połączenia.',
          )
        : (
            Icons.sync_problem_rounded,
            'Analiza napotkała problem',
            'Wystąpił problem po stronie serwera podczas analizy Twojego nagrania. '
                'Kliknij przycisk poniżej, aby napisać do nas na kontakt@superwizor.ai i automatycznie dołączyć dane diagnostyczne.',
          );

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: EuphireColors.ember.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: EuphireColors.ember.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 40,
              color: EuphireColors.ember.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: EuphireColors.frostWhite,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: EuphireColors.mist.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),

          // ── Debug: raw error ──
          if (scenario.errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.bug_report,
                    size: 14,
                    color: Colors.redAccent.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'lastError: ${scenario.errorMessage}',
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 9,
                        color: Colors.redAccent.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mock HomeScreen (Główna Kartoteka) Preview Stateful Wrapper ──

class _HomeScreenPreviewWrapper extends StatefulWidget {
  final _StateScenario scenario;
  const _HomeScreenPreviewWrapper({required this.scenario});

  @override
  State<_HomeScreenPreviewWrapper> createState() => _HomeScreenPreviewWrapperState();
}

class _HomeScreenPreviewWrapperState extends State<_HomeScreenPreviewWrapper> {
  bool _stateUpload = true;
  bool _stateFailure = false;
  bool _stateQuota = false;
  bool _stateRetry = false;
  bool _stateAnalyzing = false;
  double _progress = 0.20;
  bool _isPanelExpanded = true;
  bool _isPanelVisible = true;

  @override
  Widget build(BuildContext context) {
    // Determine mixed state and priority
    final hasActiveProgress = _stateUpload || _stateRetry || _stateAnalyzing;
    final isMixedErrorState = _stateFailure && hasActiveProgress;

    // Pick highest priority banner content
    Widget? bannerWidget;
    if (isMixedErrorState) {
      int activeCount = 0;
      if (_stateUpload) activeCount++;
      if (_stateRetry) activeCount++;
      if (_stateAnalyzing) activeCount++;
      bannerWidget = _MockActiveAnalysisBanner(
        icon: Icons.error_outline_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Błędy przesyłania: 1. (Pozostałe w toku: $activeCount)',
        body: 'Wykryliśmy problem z częścią nagrań. Pozostałe sesje przesyłają się dalej.',
        ctaLabel: 'Sprawdź szczegóły',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: _stateUpload || _stateRetry,
        progressValue: _progress,
        isError: true,
        detailsBadge: '${activeCount + 1} sesje • 160.0 MB',
        onTap: () {
          final target = _scenarios.firstWhere((s) => s.id == 'uploading');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ScenarioPreviewScreen(scenario: target)),
          );
        },
      );
    } else if (_stateFailure) {
      bannerWidget = _MockActiveAnalysisBanner(
        icon: Icons.error_outline_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Przesyłanie wymaga uwagi.',
        body: 'Sesja nie mogła zostać wgrana. Sprawdź szczegóły.',
        ctaLabel: 'Sprawdź szczegóły',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        isError: true,
        detailsBadge: '50.0 MB • 30 min',
        onTap: () {
          final target = _scenarios.firstWhere((s) => s.id == 'failed_upload');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ScenarioPreviewScreen(scenario: target)),
          );
        },
      );
    } else if (_stateQuota) {
      bannerWidget = _MockActiveAnalysisBanner(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: EuphireColors.ember,
        headline: 'Brak dostępnych minut.',
        body: 'Osiągnięto limit planu. Twój plik czeka bezpiecznie na odnowienie lub zmianę limitu.',
        ctaLabel: 'Zobacz szczegóły',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        detailsBadge: '50.0 MB • 30 min',
        onTap: () {
          final target = _scenarios.firstWhere((s) => s.id == 'quota_blocked');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ScenarioPreviewScreen(scenario: target)),
          );
        },
      );
    } else if (_stateRetry) {
      bannerWidget = _MockActiveAnalysisBanner(
        icon: Icons.refresh_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Przesyłanie przerwane.',
        body: 'Nastąpiła krótka przerwa w połączeniu. Spróbujemy przesłać plik ponownie za chwilę.',
        ctaLabel: 'Zobacz szczegóły',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: _progress,
        detailsBadge: '50.0 MB • 30 min',
        onTap: () {
          final target = _scenarios.firstWhere((s) => s.id == 'failed_upload');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ScenarioPreviewScreen(scenario: target)),
          );
        },
      );
    } else if (_stateUpload) {
      bannerWidget = _MockActiveAnalysisBanner(
        icon: Icons.cloud_upload_rounded,
        iconColor: EuphireColors.ember,
        headline: 'Sesja jest przesyłana na serwer.',
        body: 'Plik trafia bezpiecznie na serwer. Możesz kontynuować pracę.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        showProgress: true,
        progressValue: _progress,
        detailsBadge: '160.0 MB • 3 sesje',
        onTap: () {
          final target = _scenarios.firstWhere((s) => s.id == 'uploading');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ScenarioPreviewScreen(scenario: target)),
          );
        },
      );
    } else if (_stateAnalyzing) {
      bannerWidget = _MockActiveAnalysisBanner(
        icon: Icons.auto_awesome_rounded,
        iconColor: EuphireColors.ember,
        headline: 'AI analizuje Twoją sesję.',
        body: 'Przepisujemy nagranie i przygotowujemy strukturę raportu klinicznego.',
        ctaLabel: 'Zobacz postęp',
        accentColor: EuphireColors.ember,
        borderColor: EuphireColors.ember,
        detailsBadge: '45 min • AI analizuje',
        onTap: () {
          final target = _scenarios.firstWhere((s) => s.id == 'analyzing');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ScenarioPreviewScreen(scenario: target)),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildDebugHeader(context),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 760),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (bannerWidget != null) ...[
                                      bannerWidget,
                                      const SizedBox(height: 12),
                                    ],
                                    const Text(
                                      'KARTOTEKA PACJENTÓW (MOCKUP)',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: EuphireColors.frostWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Prezentacja wszystkich możliwych statusów pacjenta na liście.',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                        color: EuphireColors.mist.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const _MockPatientCompactCard(
                                      patientName: 'Jan Kowalski',
                                      initials: 'JK',
                                      avatarColor: Color(0xFFE11D48), // rose
                                      sessionCount: 12,
                                      lastSessionDateString: 'Dzisiaj',
                                      status: 'recording',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Anna Nowak',
                                      initials: 'AN',
                                      avatarColor: Color(0xFF0D9488), // teal
                                      sessionCount: 8,
                                      lastSessionDateString: 'Wczoraj',
                                      status: 'hasNewReport',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Michał Wiśniewski',
                                      initials: 'MW',
                                      avatarColor: Color(0xFF2563EB), // blue
                                      sessionCount: 5,
                                      lastSessionDateString: '24 Cze',
                                      status: 'analyzing',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Marta Wójcik',
                                      initials: 'MW',
                                      avatarColor: Color(0xFFD97706), // amber
                                      sessionCount: 15,
                                      lastSessionDateString: '22 Cze',
                                      status: 'uploading',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Piotr Kowalczyk',
                                      initials: 'PK',
                                      avatarColor: Color(0xFF7C3AED), // purple
                                      sessionCount: 3,
                                      lastSessionDateString: '18 Cze',
                                      status: 'uploadFailed',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Zofia Kamińska',
                                      initials: 'ZK',
                                      avatarColor: Color(0xFFDB2777), // pink
                                      sessionCount: 22,
                                      lastSessionDateString: '15 Cze',
                                      status: 'error',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Paweł Lewandowski',
                                      initials: 'PL',
                                      avatarColor: Color(0xFF0284C7), // sky
                                      sessionCount: 4,
                                      lastSessionDateString: '10 Cze',
                                      status: 'active',
                                    ),
                                    const SizedBox(height: 8),
                                    const _MockPatientCompactCard(
                                      patientName: 'Alicja Zielińska',
                                      initials: 'AZ',
                                      avatarColor: Color(0xFF16A34A), // green
                                      sessionCount: 0,
                                      lastSessionDateString: null,
                                      status: 'awaiting',
                                      dimmed: true,
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isPanelVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(16, 10, 76, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1E21).withValues(alpha: 0.95),
                      border: const Border(
                        top: BorderSide(color: Colors.white10),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'AUDYT STANÓW KARTOTEKI PACJENTÓW',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: EuphireColors.frostWhite,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isPanelExpanded ? Icons.keyboard_arrow_down_rounded : Icons.tune_rounded,
                                color: EuphireColors.mist,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPanelExpanded = !_isPanelExpanded;
                                });
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: EuphireColors.mist,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPanelVisible = false;
                                });
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                          if (_isPanelExpanded) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFilterChip('Przesyłanie', _stateUpload, (v) => setState(() => _stateUpload = v)),
                                  _buildFilterChip('Błąd (Failure)', _stateFailure, (v) => setState(() => _stateFailure = v)),
                                  _buildFilterChip('Brak minut (Quota)', _stateQuota, (v) => setState(() => _stateQuota = v)),
                                  _buildFilterChip('Auto-retry (Retry)', _stateRetry, (v) => setState(() => _stateRetry = v)),
                                  _buildFilterChip('AI analizuje', _stateAnalyzing, (v) => setState(() => _stateAnalyzing = v)),
                                ],
                              ),
                            ),
                            if (_stateUpload || _stateRetry) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Postęp: ',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 11,
                                      color: EuphireColors.mist,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _progress,
                                      activeColor: EuphireColors.ember,
                                      inactiveColor: Colors.white10,
                                      onChanged: (val) {
                                        setState(() {
                                          _progress = val;
                                        });
                                      },
                                    ),
                                  ),
                                  Text(
                                    '${(_progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontFamily: 'RobotoMono',
                                      fontSize: 11,
                                      color: EuphireColors.frostWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white10),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Wróć do galerii',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: EuphireColors.mist,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                  ),
                ),
              ),
              if (!_isPanelVisible)
                Positioned(
                  left: 16,
                  bottom: 90,
                  child: _buildRestoreButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPanelVisible = true;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F1E21).withValues(alpha: 0.9),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.tune_rounded,
          color: EuphireColors.ember,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? EuphireColors.obsidianBlack : EuphireColors.frostWhite,
        ),
      ),
      selected: isSelected,
      selectedColor: EuphireColors.ember,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      onSelected: onSelected,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildDebugHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: widget.scenario.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.scenario.color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: EuphireColors.frostWhite, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Icon(widget.scenario.icon, color: widget.scenario.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW: ${widget.scenario.title}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.scenario.color,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  widget.scenario.subtitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockActiveAnalysisBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String headline;
  final String body;
  final String ctaLabel;
  final Color accentColor;
  final Color borderColor;
  final bool showProgress;
  final double? progressValue;
  final bool isError;
  final String detailsBadge;
  final VoidCallback onTap;

  const _MockActiveAnalysisBanner({
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.accentColor,
    required this.borderColor,
    this.showProgress = false,
    this.progressValue,
    this.isError = false,
    required this.detailsBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isError
            ? EuphireColors.ember.withValues(alpha: 0.05)
            : EuphireColors.evergreen.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline,
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
                            body,
                            style: TextStyle(
                              fontFamily: 'Merriweather',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: EuphireColors.frostWhite.withValues(alpha: 0.65),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showProgress) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  if (progressValue != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(progressValue! * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: EuphireColors.frostWhite.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.audiotrack_rounded,
                                size: 14,
                                color: EuphireColors.mist.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  detailsBadge,
                                  style: TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: EuphireColors.mist.withValues(alpha: 0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ctaLabel,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ],
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

  // ── Mock ClientDetailsScreen (Kartoteka Klienta) Preview ──

class _MockPendingUploadCard extends StatelessWidget {
  final bool isFailed;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MockPendingUploadCard({
    required this.isFailed,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = EuphireColors.ember;
    final bgColor = isFailed
        ? EuphireColors.ember.withValues(alpha: 0.06)
        : EuphireColors.frostWhite.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: isFailed
                      ? Icon(Icons.error_outline_rounded, color: color, size: 18)
                      : CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isFailed ? color : EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          color: isFailed ? color.withValues(alpha: 0.8) : EuphireColors.mist,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isFailed ? color : EuphireColors.mist,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientDetailsPreviewWrapper extends StatefulWidget {
  final _StateScenario scenario;
  final int? initialActiveState;
  const _ClientDetailsPreviewWrapper({
    required this.scenario,
    this.initialActiveState,
  });

  @override
  State<_ClientDetailsPreviewWrapper> createState() => _ClientDetailsPreviewWrapperState();
}

class _ClientDetailsPreviewWrapperState extends State<_ClientDetailsPreviewWrapper> {
  late int _activeState;
  bool _isRecording = true;
  int _seconds = 6;
  Timer? _timer;
  bool _isPanelExpanded = true;
  bool _isPanelVisible = true;

  @override
  void initState() {
    super.initState();
    _activeState = widget.initialActiveState ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeState == 1 && _isRecording) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final hh = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return totalSeconds >= 3600 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDuration = _formatDuration(_seconds);

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildDebugHeader(context),
                  Expanded(
                    child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: EuphireColors.mist,
                                        size: 22,
                                      ),
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: EuphireColors.mist,
                                        size: 22,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Próbny Pacjent',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFFFB300),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Nad czym dzisiaj pracujemy?',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                    color: EuphireColors.mist.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                if (_activeState == 1)
                                  _MockActiveRecordingCard(
                                    durationString: formattedDuration,
                                    isRecording: _isRecording,
                                    onTap: () {
                                      final target = _scenarios.firstWhere((s) => s.id == 'minimized_recording');
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _ScenarioPreviewScreen(scenario: target),
                                        ),
                                      );
                                    },
                                  ),
                                if (_activeState == 2)
                                  _MockPendingUploadCard(
                                    isFailed: false,
                                    title: 'Przetwarzanie',
                                    subtitle: 'Wysyłanie audio...',
                                    onTap: () {
                                      final target = _scenarios.firstWhere((s) => s.id == 'uploading');
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _ScenarioPreviewScreen(scenario: target),
                                        ),
                                      );
                                    },
                                  ),
                                if (_activeState == 3 || _activeState == 4)
                                  _MockPendingUploadCard(
                                    isFailed: true,
                                    title: 'Wymaga uwagi',
                                    subtitle: 'Przesyłanie przerwane',
                                    onTap: () {
                                      final target = _scenarios.firstWhere((s) => s.id == 'failed_upload');
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _ScenarioPreviewScreen(scenario: target),
                                        ),
                                      );
                                    },
                                  ),

                                const SizedBox(height: 12),

                                if (_activeState == 4) ...[
                                  _MockSessionCard(
                                    sessionNumber: 6,
                                    title: 'Debug session',
                                    dateString: '25 cze',
                                    timeString: '18:45 – 19:30',
                                    durationString: '45 min',
                                    status: 'inProgress',
                                  ),
                                ],

                                const _MockSessionCard(
                                  sessionNumber: 5,
                                  title: 'Sesja 5',
                                  dateString: 'Dzisiaj',
                                  timeString: '16:30 – 17:15',
                                  durationString: '45 min',
                                  status: 'completed_new',
                                ),
                                const _MockSessionCard(
                                  sessionNumber: 4,
                                  title: 'Sesja 4',
                                  dateString: 'Dzisiaj',
                                  timeString: '14:00',
                                  durationString: null,
                                  status: 'inProgress',
                                ),
                                const _MockSessionCard(
                                  sessionNumber: 3,
                                  title: 'Sesja 3',
                                  dateString: 'Wczoraj',
                                  timeString: '11:20',
                                  durationString: null,
                                  status: 'pendingUpload',
                                ),
                                const _MockSessionCard(
                                  sessionNumber: 2,
                                  title: 'Sesja 2',
                                  dateString: '24 Cze',
                                  timeString: '09:15',
                                  durationString: null,
                                  status: 'error',
                                ),
                                const _MockSessionCard(
                                  sessionNumber: 1,
                                  title: 'Sesja 1',
                                  dateString: '20 Cze',
                                  timeString: '15:00 – 15:50',
                                  durationString: '50 min',
                                  status: 'completed_read',
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_activeState == 1)
                      _MockMinimizedRecordingBar(
                        patientName: 'Próbny Pacjent',
                        durationString: formattedDuration,
                        isRecording: _isRecording,
                        onTap: () {
                          final target = _scenarios.firstWhere((s) => s.id == 'minimized_recording');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ScenarioPreviewScreen(scenario: target),
                            ),
                          );
                        },
                      ),

                    if (_isPanelVisible)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.fromLTRB(16, 10, 76, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E21).withValues(alpha: 0.95),
                          border: const Border(
                            top: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'AUDYT STANÓW KARTOTEKI SESJI',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: EuphireColors.frostWhite,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isPanelExpanded ? Icons.keyboard_arrow_down_rounded : Icons.tune_rounded,
                                    color: EuphireColors.mist,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPanelExpanded = !_isPanelExpanded;
                                    });
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: EuphireColors.mist,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPanelVisible = false;
                                    });
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          if (_isPanelExpanded) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStateButton(0, 'Zwykły'),
                                  _buildStateButton(1, 'Sesja w toku'),
                                  _buildStateButton(2, 'Przetwarzanie'),
                                  _buildStateButton(3, 'Wymaga uwagi'),
                                  _buildStateButton(4, 'Wymaga uwagi + AI'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_activeState == 1) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isRecording = !_isRecording;
                                      });
                                    },
                                    icon: Icon(
                                      _isRecording ? Icons.pause : Icons.play_arrow,
                                      size: 14,
                                      color: EuphireColors.ember,
                                    ),
                                    label: Text(
                                      _isRecording ? 'Wstrzymaj' : 'Wznów',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        color: EuphireColors.ember,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _seconds = 0;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.replay,
                                      size: 14,
                                      color: EuphireColors.mist,
                                    ),
                                    label: const Text(
                                      'Resetuj',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        color: EuphireColors.mist,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white10),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Wróć do galerii',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: EuphireColors.mist,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
              if (!_isPanelVisible)
                Positioned(
                  left: 16,
                  bottom: 90,
                  child: _buildRestoreButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPanelVisible = true;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F1E21).withValues(alpha: 0.9),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.tune_rounded,
          color: EuphireColors.ember,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildStateButton(int stateValue, String label) {
    final isSelected = _activeState == stateValue;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? EuphireColors.obsidianBlack : EuphireColors.frostWhite,
        ),
      ),
      selected: isSelected,
      selectedColor: EuphireColors.ember,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeState = stateValue;
          });
        }
      },
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildDebugHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: widget.scenario.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.scenario.color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: EuphireColors.frostWhite, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Icon(widget.scenario.icon, color: widget.scenario.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW: ${widget.scenario.title}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.scenario.color,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  widget.scenario.subtitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.scenario.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.scenario.phase.name,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: widget.scenario.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockActiveRecordingCard extends StatelessWidget {
  final String durationString;
  final bool isRecording;
  final VoidCallback onTap;

  const _MockActiveRecordingCard({
    required this.durationString,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EuphireColors.ember.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EuphireColors.ember.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: EuphireColors.ember.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: EuphireColors.ember.withValues(alpha: 0.08),
          highlightColor: EuphireColors.ember.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _MockPulsingRecordingDot(isRecording: isRecording),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sesja w toku...',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Wróć do trwającej sesji',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: EuphireColors.mist.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  durationString,
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: EuphireColors.ember,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: EuphireColors.mist,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mock widgets for state gallery preview ──────────────────────────

class _MockPatientCompactCard extends StatefulWidget {
  final String patientName;
  final String initials;
  final Color avatarColor;
  final int sessionCount;
  final String? lastSessionDateString;
  final String status;
  final bool dimmed;

  const _MockPatientCompactCard({
    required this.patientName,
    required this.initials,
    required this.avatarColor,
    required this.sessionCount,
    this.lastSessionDateString,
    required this.status,
    this.dimmed = false,
  });

  @override
  State<_MockPatientCompactCard> createState() => _MockPatientCompactCardState();
}

class _MockPatientCompactCardState extends State<_MockPatientCompactCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.status == 'hasNewReport') {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.dimmed ? 0.55 : 1.0;

    final (String statusLabel, Color statusColor, bool showPill) = switch (widget.status) {
      'recording' => ('Zapisywanie', const Color(0xFF60A5FA), true),
      'hasNewReport' => ('Nowy raport', const Color(0xFF4ADE80), true),
      'analyzing' => ('Analiza', EuphireColors.ember, true),
      'uploading' => ('Wysyłanie', Colors.orangeAccent, true),
      'uploadFailed' => ('Błąd wysyłania', EuphireColors.ember, true),
      'error' => ('Błąd', Colors.redAccent, true),
      'active' => ('Aktywny', EuphireColors.ember, false),
      _ => ('Oczekuje', EuphireColors.mist, false),
    };

    final Widget subtitle;
    if (widget.lastSessionDateString != null) {
      subtitle = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Sesje: ${widget.sessionCount}  •  Ostatnia: '),
            TextSpan(
              text: widget.lastSessionDateString!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: EuphireColors.mist.withValues(alpha: 0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      subtitle = Text(
        'Nowy klient (brak sesji)',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: EuphireColors.mist.withValues(alpha: 0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D6068).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final int initialActiveState = switch (widget.status) {
                'recording' => 1,
                'uploading' => 2,
                'uploadFailed' => 3,
                'analyzing' => 4,
                _ => 0,
              };
              final target = _scenarios.firstWhere((s) => s.id == 'client_details_kartoteka');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ClientDetailsPreviewWrapper(
                    scenario: target,
                    initialActiveState: initialActiveState,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.avatarColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.initials,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientName,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: EuphireColors.frostWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        subtitle,
                      ],
                    ),
                  ),
                  // Status pill
                  if (showPill)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final isNewReport = widget.status == 'hasNewReport';
                        final isUploading = widget.status == 'uploading';
                        final isAnalyzing = widget.status == 'analyzing';
                        final isError = widget.status == 'error' || widget.status == 'uploadFailed';
                        final scale = isNewReport ? _pulseAnimation.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isNewReport
                                  ? [
                                      BoxShadow(
                                        color: statusColor.withValues(
                                          alpha: 0.25 * (_pulseAnimation.value - 1.0) / 0.15,
                                        ),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : isError
                                      ? [
                                          BoxShadow(
                                            color: statusColor.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                              border: isError
                                  ? Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isUploading || isAnalyzing)
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: statusColor,
                                    ),
                                  )
                                else if (widget.status == 'recording')
                                  const _MockRecordingDots()
                                else if (isError)
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 12,
                                    color: statusColor,
                                  )
                                else
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusColor,
                                    ),
                                  ),
                                const SizedBox(width: 5),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (showPill) const SizedBox(width: 4),
                  // Options icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 22,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _MockSessionCard extends StatelessWidget {
  final int sessionNumber;
  final String title;
  final String dateString;
  final String timeString;
  final String? durationString;
  final String status;

  const _MockSessionCard({
    required this.sessionNumber,
    required this.title,
    required this.dateString,
    required this.timeString,
    this.durationString,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final metaStr = durationString != null
        ? '$dateString  •  $timeString  •  $durationString'
        : '$dateString  •  $timeString';

    final isViewed = status == 'completed_read';
    final isInProgress = status == 'inProgress';
    final isPendingUpload = status == 'pendingUpload';
    final isError = status == 'error';

    final (statusText, dotColor) = switch (status) {
      'completed_new' => ('Nowy raport', const Color(0xFF4ADE80)),
      'completed_read' => ('Raport gotowy', EuphireColors.mist),
      'inProgress' => ('AI analizuje...', EuphireColors.ember),
      'pendingUpload' => ('Wysyłanie', Colors.orangeAccent),
      'error' => ('Błąd', EuphireColors.magma),
      _ => ('', EuphireColors.mist),
    };

    final showBadge = !isViewed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? EuphireColors.magma.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: isError
            ? [
                BoxShadow(
                  color: EuphireColors.magma.withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final String? scenarioId = switch (status) {
              'completed_new' => 'done',
              'inProgress' => 'analyzing',
              'pendingUpload' => 'uploading',
              'error' => 'failed_pipeline',
              'completed_read' => 'done',
              _ => null,
            };
            if (scenarioId != null) {
              final target = _scenarios.firstWhere((s) => s.id == scenarioId);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ScenarioPreviewScreen(scenario: target),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: isInProgress || isPendingUpload
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: dotColor,
                          ),
                        )
                      : isError
                          ? Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: dotColor,
                            )
                          : Text(
                              '#$sessionNumber',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: dotColor,
                              ),
                            ),
                ),
                const SizedBox(width: 14),
                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metaStr,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          color: EuphireColors.mist.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status pill
                if (showBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: isError
                          ? Border.all(
                              color: dotColor.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isInProgress || isPendingUpload)
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: dotColor,
                            ),
                          )
                        else if (isError)
                          Icon(
                            Icons.error_outline_rounded,
                            size: 12,
                            color: dotColor,
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          ),
                        const SizedBox(width: 5),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: dotColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showBadge) const SizedBox(width: 4),
                // Option context menu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 22,
                    color: EuphireColors.mist.withValues(alpha: 0.4),
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

class _MockRecordingDots extends StatefulWidget {
  const _MockRecordingDots();

  @override
  State<_MockRecordingDots> createState() => _MockRecordingDotsState();
}

class _MockRecordingDotsState extends State<_MockRecordingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.25) % 1.0;
            final bounce = phase < 0.5
                ? (phase * 2.0)
                : (1.0 - (phase - 0.5) * 2.0);
            final dy = -3.0 * Curves.easeOut.transform(bounce);
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 2.5 : 0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.6 + 0.4 * bounce),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Mock Minimized Recording Bar & Pulsing Dot ─────────────────────────

class _MockMinimizedRecordingBar extends StatelessWidget {
  final String patientName;
  final String durationString;
  final bool isRecording;
  final VoidCallback? onTap;

  const _MockMinimizedRecordingBar({
    required this.patientName,
    required this.durationString,
    required this.isRecording,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _MockPulsingRecordingDot(
                    isRecording: isRecording,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isRecording ? 'Sesja w toku...' : 'Nagrywanie wstrzymane',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.mist.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patientName,
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    durationString,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
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
    );
  }
}

class _MockPulsingRecordingDot extends StatefulWidget {
  final bool isRecording;
  const _MockPulsingRecordingDot({required this.isRecording});

  @override
  State<_MockPulsingRecordingDot> createState() => _MockPulsingRecordingDotState();
}

class _MockPulsingRecordingDotState extends State<_MockPulsingRecordingDot>
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
  void didUpdateWidget(covariant _MockPulsingRecordingDot oldWidget) {
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

// ─── Minimized Recording Preview Wrapper ─────────────────────────────────

class _MinimizedRecordingPreviewWrapper extends StatefulWidget {
  final _StateScenario scenario;
  const _MinimizedRecordingPreviewWrapper({required this.scenario});

  @override
  State<_MinimizedRecordingPreviewWrapper> createState() =>
      _MinimizedRecordingPreviewWrapperState();
}

class _MinimizedRecordingPreviewWrapperState
    extends State<_MinimizedRecordingPreviewWrapper> {
  bool _isRecording = true;
  int _seconds = 7;
  Timer? _timer;
  bool _isPanelVisible = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final hh = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return totalSeconds >= 3600 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDuration = _formatDuration(_seconds);

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Debug Header ──
                  _buildDebugHeader(context),

              // ── Mock Screen Content (Kuba Pacjent) ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row of patient page (Back, edit icon)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: EuphireColors.mist,
                              size: 22,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: EuphireColors.mist,
                              size: 22,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Patient name
                      const Text(
                        'Kuba Pacjent',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFFFB300), // Amber-orange
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nad czym dzisiaj pracujemy?',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          color: EuphireColors.mist.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Minimized Recording Bar ──
                      _MockMinimizedRecordingBar(
                        patientName: 'Kuba Pacjent',
                        durationString: formattedDuration,
                        isRecording: _isRecording,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kliknięto powrót do trwającej sesji!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const Spacer(),

                      // ── Interactive Control Panel ──
                      if (_isPanelVisible)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 76, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'PANEL KONTROLNY PREVIEW',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: EuphireColors.frostWhite,
                                        letterSpacing: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: EuphireColors.mist,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPanelVisible = false;
                                      });
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isRecording = !_isRecording;
                                      });
                                    },
                                    icon: Icon(
                                      _isRecording
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                                    label: Text(
                                      _isRecording ? 'Wstrzymaj' : 'Wznów',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _isRecording
                                          ? EuphireColors.magma
                                          : Colors.greenAccent[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _seconds = 0;
                                      });
                                    },
                                    icon: const Icon(Icons.replay_rounded),
                                    label: const Text('Resetuj czas'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: EuphireColors.frostWhite,
                                      side: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Wróć do galerii'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: EuphireColors.mist,
                                side: const BorderSide(
                                  color: Colors.white10,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              ],
            ),
          if (!_isPanelVisible)
            Positioned(
              left: 16,
              bottom: 90,
              child: _buildRestoreButton(),
            ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildRestoreButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPanelVisible = true;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F1E21).withValues(alpha: 0.9),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.tune_rounded,
          color: EuphireColors.ember,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildDebugHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: widget.scenario.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.scenario.color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: EuphireColors.frostWhite, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Icon(widget.scenario.icon, color: widget.scenario.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW: ${widget.scenario.title}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.scenario.color,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  widget.scenario.subtitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.scenario.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.scenario.phase.name,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: widget.scenario.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

