import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../utils/debug_flags.dart';
import '../utils/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import '../analytics/analytics_collector.dart';
import '../providers/sort_filter_provider.dart';
import '../widgets/debug_test_overlay.dart';
import '../widgets/sort_filter_sheet.dart';


import '../models/session.dart';
import '../models/patient.dart';
import '../providers/services_provider.dart';
import '../services/recording_service.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';
import '../providers/current_user_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/patient_avatar_provider.dart';
import '../providers/patient_lifecycle_provider.dart';
import '../providers/viewed_reports_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/add_patient_screen.dart';
import '../widgets/avatar_customize_sheet.dart';


import '../widgets/active_analysis_banner.dart';
import '../widgets/preference_suggestion_banner.dart';
import '../widgets/quota_warning_banner.dart';
import '../widgets/recording_recovery_prompt.dart';
import 'client_details_screen.dart';
import 'menu_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showAddPatientModal(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const AddPatientScreen(),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsCollectorProvider).track("screen.viewed", properties: {"screen_name": "HomeScreen"});
    });

    final patientsAsync = ref.watch(patientsProvider);
    ref.watch(currentUserProvider); // fire backend lookup

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      // Usunięty appBar, zrobimy customowy header dla lepszego UI
      body: DebugTestOverlay(
        child: Stack(
        children: [
          Container(
            color: const Color(0xFF173E43), // Tło: #173e43
          ),
          // Once-per-launch orphaned-recording recovery prompt
          // (docs/28 WS1) — zero-size, only ever shows bottom sheets.
          const RecordingRecoveryGuard(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo bar (pinned) — 7-tap opens debug panel ──
                _DebugTapLogo(
                  onMenuPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const MenuScreen(),
                      ),
                    );
                  },
                ),

                Expanded(
                  child: SingleChildScrollView(
                    // Web/desktop: cap the content to a centered reading column
                    // so it doesn't stretch full-width. Self-gating — on phones
                    // (width < 760) it's a no-op, so the native app is unchanged.
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Greeting: Witaj, [Name] ──────────────────────
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                              child: Builder(
                                builder: (context) {
                                  final userAsync = ref.watch(
                                    currentUserProvider,
                                  );
                                  final displayName = userAsync.whenOrNull(
                                    data: (u) {
                                      if (u == null) return null;
                                      final full =
                                          '${u.firstName} ${u.lastName}'.trim();
                                      return full.isNotEmpty ? full : null;
                                    },
                                  );
                                  return Text.rich(
                                    TextSpan(
                                      text: 'Witaj, ',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: EuphireColors.frostWhite,
                                        height: 1.2,
                                      ),
                                      children: [
                                        if (displayName != null)
                                          TextSpan(
                                            text: displayName,
                                            style: const TextStyle(
                                              fontFamily: 'Merriweather',
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w700,
                                              color: EuphireColors.ember,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ── Subtitle ──────────────────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                'Z kim dzisiaj pracujemy?',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: EuphireColors.mist.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Sugestia AI (feat/report-customization §6) ──
                            const PreferenceSuggestionBanner(),

                            // ── Quota warning (Phase 3 §16.3) ───────────────
                            const QuotaWarningBanner(),

                            // ── Lista Kartotek ──────────────────────────────────
                            patientsAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: EuphireColors.ember,
                                  ),
                                ),
                              ),
                              error: (err, stack) => Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'Błąd: $err',
                                    style: const TextStyle(
                                      color: EuphireColors.ember,
                                    ),
                                  ),
                                ),
                              ),
                              data: (patients) {
                                return _PatientListSection(patients: patients);
                              },
                            ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientModal(context, ref),
        backgroundColor: EuphireColors.ember,
        foregroundColor: EuphireColors.nocturne,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

// ─── PATIENT LIST WITH SEARCH ─────────────────────────────────────

class _PatientListSection extends ConsumerStatefulWidget {
  final List<Patient> patients;
  const _PatientListSection({required this.patients});

  @override
  ConsumerState<_PatientListSection> createState() =>
      _PatientListSectionState();
}

class _PatientListSectionState extends ConsumerState<_PatientListSection> {
  String _query = '';
  bool _showPaused = false;
  bool _showCompleted = false;
  final Set<String> _fetchedPatients = {};
  AudioPlayer? _successPlayer;

  @override
  void dispose() {
    _successPlayer?.dispose();
    super.dispose();
  }

  void _playSuccessSound() async {
    try {
      if (_successPlayer != null) {
        await _successPlayer!.stop();
        await _successPlayer!.dispose();
      }
      final newPlayer = AudioPlayer();
      _successPlayer = newPlayer;
      await newPlayer.play(AssetSource('sounds/SFX_succes.mp3'));
      newPlayer.onPlayerComplete.first.then((_) {
        if (mounted && _successPlayer == newPlayer) {
          newPlayer.dispose();
          _successPlayer = null;
        }
      }).catchError((_) {
        if (mounted && _successPlayer == newPlayer) {
          newPlayer.dispose();
          _successPlayer = null;
        }
      });
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  /// Previous status per patient — used to detect analyzing → hasNewReport.
  final Map<String, _PatientStatus> _prevStatuses = {};

  /// Patients that just transitioned to hasNewReport — triggers pill animation.
  final Set<String> _justCompletedIds = {};

  /// Eagerly fetch sessions for all patients whose session lists
  /// haven't been loaded yet. This ensures badges ("Nowy raport"),
  /// "Ostatnio: X" dates, and session counts are visible immediately
  /// after a cold restart instead of only after tapping into a card.
  void _ensureSessionsFetched() {
    final notifier = ref.read(sessionsProvider.notifier);
    for (final p in widget.patients) {
      if (!_fetchedPatients.contains(p.id)) {
        _fetchedPatients.add(p.id);
        unawaited(notifier.fetchSessions(p.id));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Schedule fetch after the first frame so ref is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSessionsFetched();
    });
  }

  @override
  void didUpdateWidget(covariant _PatientListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New patients may have been added — fetch their sessions too.
    _ensureSessionsFetched();
  }

  /// Detect status transitions and fire celebration.
  void _detectTransitions(
    List<Patient> patients,
    Map<String, List<Session>> sessionsMap,
    Set<String> viewedReports,
    BuildContext context,
  ) {
    for (final p in patients) {
      final sessions = sessionsMap[p.id] ?? [];
      final svc = ref.read(recordingServiceProvider);
      final recId = (svc.state == RecordingState.recording ||
              svc.state == RecordingState.paused ||
              svc.state == RecordingState.interrupted)
          ? svc.patientFileId
          : null;
      final newStatus = _statusFor(p, sessions, viewedReports,
          recordingPatientId: recId);
      final prev = _prevStatuses[p.id];
      _prevStatuses[p.id] = newStatus;

      // Don't fire on initial load (prev == null)
      if (prev == _PatientStatus.analyzing &&
          newStatus == _PatientStatus.hasNewReport) {
        // 🎉 Session just completed!
        _justCompletedIds.add(p.id);
        AppHapticFeedback.heavyImpact();
        // Play success sound (respects user preference)
        if (ref.read(appSettingsProvider).soundEnabled) {
          _playSuccessSound();
        }
        // Celebratory toast with patient name
        final name = '${p.firstName} ${p.lastName}'.trim();
        EuphireToast.success(context, message: 'Raport gotowy, $name 🎉');
      }
    }
  }

  // Compute contextual status for a patient based on their sessions
  static _PatientStatus _statusFor(
    Patient patient,
    List<Session> sessions,
    Set<String> viewedReports, {
    String? recordingPatientId,
  }) {
    // Recording takes top priority — show blue "Nagrywanie" badge
    if (recordingPatientId != null && patient.id == recordingPatientId) {
      return _PatientStatus.recording;
    }
    if (sessions.isEmpty && patient.sessionCount == 0) {
      return _PatientStatus.awaiting;
    }
    if (sessions.isEmpty) {
      return _PatientStatus.active; // has sessions on backend, not loaded yet
    }
    final hasInProgress = sessions.any(
      (s) => s.status == SessionStatus.inProgress,
    );
    if (hasInProgress) return _PatientStatus.analyzing;
    final hasPendingUpload = sessions.any(
      (s) => s.status == SessionStatus.pendingUpload,
    );
    if (hasPendingUpload) return _PatientStatus.uploading;
    final hasError = sessions.any(
      (s) => s.status == SessionStatus.error,
    );
    if (hasError) return _PatientStatus.error;
    // Check for unread completed reports. Primary signal: backend-synced
    // session.reportViewedAt (migration 000059). Fallback: local viewedReports
    // set for the migration window (sessions marked locally but not yet synced).
    final hasUnreadReport = sessions.any(
      (s) =>
          s.status == SessionStatus.completed &&
          s.reportViewedAt == null &&
          !viewedReports.contains(s.id),
    );
    if (hasUnreadReport) return _PatientStatus.hasNewReport;
    final hasCompleted = sessions.any(
      (s) => s.status == SessionStatus.completed,
    );
    if (hasCompleted) return _PatientStatus.active;
    return _PatientStatus.active;
  }

  /// Compute the number of patients that "need attention" (new report,
  /// AI analyzing, or error) — used for the filter badge and bottom sheet.
  int _needsAttentionCount(
    List<Patient> patients,
    Map<String, List<Session>> sessionsMap,
    Set<String> viewedReports,
  ) {
    int count = 0;
    for (final p in patients) {
      final status = _statusFor(p, sessionsMap[p.id] ?? [], viewedReports);
      if (status == _PatientStatus.hasNewReport ||
          status == _PatientStatus.analyzing ||
          status == _PatientStatus.uploading ||
          status == _PatientStatus.error) {
        count++;
      }
    }
    return count;
  }

  /// Collect unique modality codes across the given patients.
  Set<String> _uniqueModalities(List<Patient> patients) {
    final codes = <String>{};
    for (final p in patients) {
      if (p.modalityCode.isNotEmpty) codes.add(p.modalityCode);
    }
    return codes;
  }

  void _openSortFilterSheet(
    BuildContext context, {
    required Set<String> availableModalities,
    required int needsAttentionCount,
  }) {
    AppHapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SortFilterSheet(
        availableModalities: availableModalities,
        needsAttentionCount: needsAttentionCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsMap = ref.watch(sessionsProvider).value ?? {};
    final lifecycleMap = ref.watch(patientLifecycleProvider);
    final viewedReports = ref.watch(viewedReportsProvider).value ?? <String>{};
    final sortFilter = ref.watch(sortFilterProvider).value ?? const SortFilterState();

    // Detect status transitions (analyzing → hasNewReport) and celebrate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _detectTransitions(
          widget.patients,
          sessionsMap,
          viewedReports,
          context,
        );
      }
    });

    // Split by lifecycle
    final activePatients = <Patient>[];
    final completedPatients = <Patient>[];
    final pausedPatients = <Patient>[];

    for (final p in widget.patients) {
      final lifecycle = lifecycleMap[p.id] ?? PatientLifecycle.active;
      switch (lifecycle) {
        case PatientLifecycle.active:
          activePatients.add(p);
        case PatientLifecycle.completed:
          completedPatients.add(p);
        case PatientLifecycle.paused:
          pausedPatients.add(p);
      }
    }

    // Precompute attention count and available modalities (before filtering)
    // so the bottom sheet can display them accurately.
    final attentionCount =
        _needsAttentionCount(activePatients, sessionsMap, viewedReports);
    final availableModalities = _uniqueModalities(activePatients);

    // Sort active patients based on chosen SortMode.
    switch (sortFilter.sortMode) {
      case SortMode.lastActivity:
        activePatients.sort((a, b) {
          // Patients without sessions sort to the TOP (far future date)
          // so newly added clients are immediately visible. Once they
          // have a session, they sort by its date.
          final aDate = (sessionsMap[a.id] ?? []).isNotEmpty
              ? sessionsMap[a.id]!.first.date
              : DateTime(9999);
          final bDate = (sessionsMap[b.id] ?? []).isNotEmpty
              ? sessionsMap[b.id]!.first.date
              : DateTime(9999);
          return bDate.compareTo(aDate);
        });
      case SortMode.leastRecent:
        activePatients.sort((a, b) {
          final aSessions = sessionsMap[a.id] ?? [];
          final bSessions = sessionsMap[b.id] ?? [];
          // Patients with zero sessions go to the bottom in "least recent"
          // mode (they have no history to follow up on).
          final aDate = aSessions.isNotEmpty
              ? aSessions.first.date
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = bSessions.isNotEmpty
              ? bSessions.first.date
              : DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
      case SortMode.alphabetical:
        activePatients.sort((a, b) {
          final aName = '${a.firstName} ${a.lastName}'.trim().toLowerCase();
          final bName = '${b.firstName} ${b.lastName}'.trim().toLowerCase();
          return aName.compareTo(bName);
        });
      case SortMode.mostSessions:
        activePatients.sort((a, b) => b.sessionCount.compareTo(a.sessionCount));
    }
    completedPatients.sort((a, b) => a.firstName.compareTo(b.firstName));
    pausedPatients.sort((a, b) => a.firstName.compareTo(b.firstName));

    // Filter by search query + sort/filter provider state
    List<Patient> applyFilters(List<Patient> list, {bool applyExtras = false}) {
      var result = list;
      // Text search
      if (_query.isNotEmpty) {
        result = result.where((p) {
          final name = '${p.firstName} ${p.lastName}'.trim().toLowerCase();
          return name.contains(_query.toLowerCase());
        }).toList();
      }
      // Extra filters only for active patients
      if (applyExtras) {
        // Needs attention filter
        if (sortFilter.needsAttentionOnly) {
          result = result.where((p) {
            final status =
                _statusFor(p, sessionsMap[p.id] ?? [], viewedReports);
            return status == _PatientStatus.hasNewReport ||
                status == _PatientStatus.analyzing ||
                status == _PatientStatus.uploading ||
                status == _PatientStatus.error;
          }).toList();
        }
        // Modality filter
        if (sortFilter.modalityFilter.isNotEmpty) {
          result = result.where((p) {
            return sortFilter.modalityFilter.contains(p.modalityCode);
          }).toList();
        }
      }
      return result;
    }

    final activeFiltered = applyFilters(activePatients, applyExtras: true);
    final completedFiltered = applyFilters(completedPatients);
    final pausedFiltered = applyFilters(pausedPatients);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search bar + sort/filter icon (always visible) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              // Search field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: EuphireColors.frostWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Szukaj klienta\u2026',
                      hintStyle: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: EuphireColors.mist.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: EuphireColors.mist.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort/filter button with active-filter badge
              GestureDetector(
                onTap: () => _openSortFilterSheet(
                  context,
                  availableModalities: availableModalities,
                  needsAttentionCount: attentionCount,
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: sortFilter.isDefault
                        ? Colors.white.withValues(alpha: 0.07)
                        : EuphireColors.ember.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: sortFilter.isDefault
                        ? null
                        : Border.all(
                            color:
                                EuphireColors.ember.withValues(alpha: 0.25),
                          ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: sortFilter.isDefault
                            ? EuphireColors.mist.withValues(alpha: 0.5)
                            : EuphireColors.ember,
                      ),
                      // Active-filter badge dot
                      if (!sortFilter.isDefault)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: EuphireColors.ember,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (activeFiltered.isEmpty &&
            completedFiltered.isEmpty &&
            pausedFiltered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                widget.patients.isEmpty
                    ? 'Dodaj pierwszego klienta, aby rozpocz\u0105\u0107.'
                    : 'Brak wynik\u00f3w dla \u201e$_query\u201d',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: EuphireColors.mist.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else ...[
          // ── Active analysis banner (replaces the AppBar pill) ──
          const ActiveAnalysisBanner(),
          // ── "TWOJE KARTOTEKI" section header ──
          _SectionLabel(
            label: sortFilter.isDefault
                ? 'TWOJE KARTOTEKI'
                : 'TWOJE KARTOTEKI \u2022 FILTR',
            count: activeFiltered.length,
          ),
          const SizedBox(height: 8),
          // ── Active patients ──
          if (activeFiltered.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              itemCount: activeFiltered.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final patient = activeFiltered[index];
                final sessions = sessionsMap[patient.id] ?? [];
                final lastDate = sessions.isNotEmpty
                    ? sessions.first.date
                    : null;
                final svc = ref.read(recordingServiceProvider);
                final recId = (svc.state == RecordingState.recording ||
                        svc.state == RecordingState.paused ||
                        svc.state == RecordingState.interrupted)
                    ? svc.patientFileId
                    : null;
                return _PatientCompactCard(
                  patient: patient,
                  sessionCount: patient.sessionCount,
                  lastSessionDate: lastDate,
                  status: _statusFor(patient, sessions, viewedReports,
                      recordingPatientId: recId),
                  justCompleted: _justCompletedIds.remove(patient.id),
                );
              },
            ),
          ],
          // ── Paused toggle (above completed) ──
          if (pausedFiltered.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: () => setState(() => _showPaused = !_showPaused),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showPaused
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 18,
                        color: const Color(0xFF60A5FA).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'WSTRZYMANE (${pausedFiltered.length})',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showPaused) ...[
              const SizedBox(height: 6),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                itemCount: pausedFiltered.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final patient = pausedFiltered[index];
                  return _PatientCompactCard(
                    patient: patient,
                    sessionCount: patient.sessionCount,
                    status: _PatientStatus.paused,
                    dimmed: true,
                  );
                },
              ),
            ],
          ],
          // ── Completed toggle (below paused) ──
          if (completedFiltered.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: () => setState(() => _showCompleted = !_showCompleted),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showCompleted
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 18,
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ZAKO\u0143CZONE (${completedFiltered.length})',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showCompleted) ...[
              const SizedBox(height: 6),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                itemCount: completedFiltered.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final patient = completedFiltered[index];
                  final sessions = sessionsMap[patient.id] ?? [];
                  final lastDate = sessions.isNotEmpty
                      ? sessions.first.date
                      : null;
                  return _PatientCompactCard(
                    patient: patient,
                    sessionCount: patient.sessionCount,
                    lastSessionDate: lastDate,
                    status: _PatientStatus.completed,
                    dimmed: true,
                  );
                },
              ),
            ],
          ],
          const SizedBox(height: 100),
        ],
      ],
    );
  }
}

// ─── Section label helper ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: EuphireColors.mist.withValues(alpha: 0.5),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: EuphireColors.mist.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Patient status enum ──────────────────────────────────────────────────

enum _PatientStatus {
  recording, // blue      — session recording in progress
  active, // ember     — in therapy
  hasNewReport, // green     — unread report available
  analyzing, // ember     — AI processing
  uploading, // orange    — file upload in progress
  error, // red       — analysis failed
  completed, // mist      — therapy finished
  paused, // mist dim  — on hold
  awaiting, // mist dim  — no sessions yet
}

// ─── COMPACT PATIENT CARD ─────────────────────────────────────────

class _PatientCompactCard extends ConsumerStatefulWidget {
  final Patient patient;
  final int sessionCount;
  final DateTime? lastSessionDate;
  final _PatientStatus status;
  final bool dimmed;
  final bool justCompleted;

  const _PatientCompactCard({
    required this.patient,
    required this.sessionCount,
    this.lastSessionDate,
    this.status = _PatientStatus.awaiting,
    this.dimmed = false,
    this.justCompleted = false,
  });

  @override
  ConsumerState<_PatientCompactCard> createState() =>
      _PatientCompactCardState();
}

class _PatientCompactCardState extends ConsumerState<_PatientCompactCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String get _initials {
    final f = widget.patient.firstName;
    final l = widget.patient.lastName;
    if (f.isEmpty && l.isEmpty) return '?';
    final first = f.isNotEmpty ? f.characters.first.toUpperCase() : '';
    final last = l.isNotEmpty ? l.characters.first.toUpperCase() : '';
    return '$first$last'.trim();
  }

  String get _name =>
      '${widget.patient.firstName} ${widget.patient.lastName}'.trim();

  static const _months = [
    'Sty',
    'Lut',
    'Mar',
    'Kwi',
    'Maj',
    'Cze',
    'Lip',
    'Sie',
    'Wrz',
    'Pa\u017a',
    'Lis',
    'Gru',
  ];

  // Returns a list of InlineSpans for the subtitle with the date part
  // rendered in a slightly bolder weight for visual emphasis.
  List<InlineSpan> _subtitleSpans({required bool full}) {
    if (widget.lastSessionDate != null) {
      final d = widget.lastSessionDate!;
      final dateStr = '${d.day} ${_months[d.month - 1]}';
      if (full) {
        return [
          TextSpan(text: 'Sesje: ${widget.sessionCount} \u2022 Ostatnio: '),
          TextSpan(
            text: dateStr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ];
      } else {
        return [
          const TextSpan(text: 'Ostatnio: '),
          TextSpan(
            text: dateStr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ];
      }
    }
    if (widget.sessionCount > 0) {
      return [TextSpan(text: 'Sesje: ${widget.sessionCount}')];
    }
    return [
      TextSpan(
        text: full ? 'Oczekuje na pierwsz\u0105 sesj\u0119' : 'Nowy klient',
      ),
    ];
  }

  // Status pill config
  (String label, Color color, bool show) get _statusConfig =>
      switch (widget.status) {
        _PatientStatus.recording => (
          'Nagrywanie',
          const Color(0xFF60A5FA),
          true,
        ),
        _PatientStatus.hasNewReport => (
          'Nowy raport',
          const Color(0xFF4ADE80),
          true,
        ),
        _PatientStatus.analyzing => ('AI analizuje', EuphireColors.ember, true),
        _PatientStatus.uploading => ('Wgrywanie...', Colors.orangeAccent, true),
        _PatientStatus.error => ('Błąd analizy', Colors.redAccent, true),
        _PatientStatus.active => ('Aktywny', EuphireColors.ember, false),
        _PatientStatus.completed => (
          'Zako\u0144czony',
          EuphireColors.mist,
          false,
        ),
        _PatientStatus.paused => ('Wstrzymany', EuphireColors.mist, false),
        _PatientStatus.awaiting => ('Nowy', EuphireColors.mist, false),
      };

  void _showOptions(BuildContext context) {
    AppHapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _PatientOptionsMenu(patientId: widget.patient.id, patientName: _name),
    );
  }

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
    if (widget.justCompleted) {
      _startPulseAndStop();
    }
  }

  /// Pulse 3 times (~4s total) then stop gracefully.
  void _startPulseAndStop() {
    var count = 0;
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        count++;
        // 3 full cycles = 6 half-cycles (forward + reverse)
        if (count >= 6) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PatientCompactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.justCompleted && !_pulseController.isAnimating) {
      _startPulseAndStop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read custom avatar config (label + color)
    final avatarConfigs = ref.watch(patientAvatarProvider);
    final avatarConfig =
        avatarConfigs[widget.patient.id] ?? const PatientAvatarConfig();
    final color = avatarConfig.color;
    final avatarLabel = avatarConfig.customLabel ?? _initials;

    final opacity = widget.dimmed ? 0.55 : 1.0;
    final (statusLabel, statusColor, showPill) = _statusConfig;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            AppHapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientDetailsScreen(
                  patientId: widget.patient.id,
                  clientName: _name,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6068).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // ── Avatar circle with initials — tappable for customization ──
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => AvatarCustomizeSheet(
                        patientId: widget.patient.id,
                        defaultInitials: _initials,
                      ),
                    );
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _AvatarLabel(label: avatarLabel, size: 15),
                  ),
                ),
                const SizedBox(width: 14),
                // ── Name + subtitle ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final useFull = w > 160;
                          return Text.rich(
                            TextSpan(children: _subtitleSpans(full: useFull)),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: EuphireColors.mist.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // ── Status pill (with pulse animation for hasNewReport) ──
                if (showPill)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final isNewReport =
                          widget.status == _PatientStatus.hasNewReport;
                      final isUploading =
                          widget.status == _PatientStatus.uploading;
                      final isAnalyzing =
                          widget.status == _PatientStatus.analyzing;
                      final isError =
                          widget.status == _PatientStatus.error;
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
                                        alpha:
                                            0.25 *
                                            (_pulseAnimation.value - 1.0) /
                                            0.15,
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
                              // Spinner for uploading/analyzing, dot for others
                              if (isUploading || isAnalyzing)
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: statusColor,
                                  ),
                                )
                              else if (widget.status == _PatientStatus.recording)
                                const _RecordingDotsBadge()
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                if (showPill) const SizedBox(width: 4),
                // ── Three dots menu ──
                GestureDetector(
                  onTap: () => _showOptions(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 22,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
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

// ─── BOTTOM SHEET: OPCJE PACJENTA (EDYTUJ / USUŃ) ────────────────

class _PatientOptionsMenu extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  const _PatientOptionsMenu({
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<_PatientOptionsMenu> createState() =>
      _PatientOptionsMenuState();
}

class _PatientOptionsMenuState extends ConsumerState<_PatientOptionsMenu> {
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final patients = ref.read(patientsProvider).value ?? [];
    Patient? patient;
    try {
      patient = patients.firstWhere((p) => p.id == widget.patientId);
    } catch (_) {}
    _firstNameCtrl = TextEditingController(text: patient?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: patient?.lastName ?? '');
    // Pre-fill the e-mail from the patient (was empty before — so this sheet
    // showed a blank e-mail AND, on save, sent "" which CLEARED the address).
    _emailCtrl = TextEditingController(text: patient?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _deleteWarning() {
    Navigator.pop(context); // close options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeletePatientWarningSheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  Future<void> _onSave() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    if (firstName.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(patientsProvider.notifier)
          .updatePatientUser(
            widget.patientId,
            firstName,
            lastName,
            // Must pass the e-mail — omitting it sent "" and wiped the address.
            email: _emailCtrl.text.trim(),
          );
      if (mounted) {
        AppHapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        EuphireToast.error(context, message: 'Błąd: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLifecycle =
        ref.watch(patientLifecycleProvider)[widget.patientId] ??
        PatientLifecycle.active;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Ikona — inicjały pacjenta z ołówkiem
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // Compute initials for the customize sheet
                      final patients = ref.read(patientsProvider).value ?? [];
                      Patient? patient;
                      try {
                        patient = patients.firstWhere((p) => p.id == widget.patientId);
                      } catch (_) {}
                      final f = patient?.firstName ?? '';
                      final l = patient?.lastName ?? '';
                      final first = f.isNotEmpty ? f.characters.first.toUpperCase() : '';
                      final last = l.isNotEmpty ? l.characters.first.toUpperCase() : '';
                      final initials = '$first$last'.trim();

                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => AvatarCustomizeSheet(
                          patientId: widget.patientId,
                          defaultInitials: initials.isEmpty ? '?' : initials,
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Builder(
                          builder: (ctx) {
                            final avatarConfigs = ref.watch(patientAvatarProvider);
                            final avatarConfig =
                                avatarConfigs[widget.patientId] ?? const PatientAvatarConfig();
                            // Compute initials
                            final patients = ref.read(patientsProvider).value ?? [];
                            Patient? patient;
                            try {
                              patient = patients.firstWhere((p) => p.id == widget.patientId);
                            } catch (_) {}
                            final f = patient?.firstName ?? '';
                            final l = patient?.lastName ?? '';
                            final first = f.isNotEmpty ? f.characters.first.toUpperCase() : '';
                            final last = l.isNotEmpty ? l.characters.first.toUpperCase() : '';
                            final initials = '$first$last'.trim();
                            final label = avatarConfig.customLabel ?? (initials.isEmpty ? '?' : initials);

                            return Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: avatarConfig.color,
                                boxShadow: [
                                  BoxShadow(
                                    color: avatarConfig.color.withValues(alpha: 0.35),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: EuphireColors.frostWhite,
                                ),
                              ),
                            );
                          },
                        ),
                        // ── Pencil overlay ──
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A2326),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: EuphireColors.ember.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: EuphireColors.ember,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  widget.patientName,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _editing ? 'Edytuj kartotekę' : 'Zarządzaj kartoteką klienta',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ── Inline editing OR lifecycle + actions ──
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _editing
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildActionsView(currentLifecycle),
                  secondChild: _buildEditView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsView(PatientLifecycle currentLifecycle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Lifecycle segment toggle ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              _LifecycleSegment(
                label: 'Aktywna',
                icon: Icons.person_rounded,
                selected: currentLifecycle == PatientLifecycle.active,
                onTap: () => ref
                    .read(patientLifecycleProvider.notifier)
                    .setLifecycle(widget.patientId, PatientLifecycle.active),
              ),
              const SizedBox(width: 4),
              _LifecycleSegment(
                label: 'Zakończona',
                icon: Icons.check_circle_outline_rounded,
                selected: currentLifecycle == PatientLifecycle.completed,
                accentColor: const Color(0xFF4ADE80),
                onTap: () => ref
                    .read(patientLifecycleProvider.notifier)
                    .setLifecycle(widget.patientId, PatientLifecycle.completed),
              ),
              const SizedBox(width: 4),
              _LifecycleSegment(
                label: 'Wstrzymana',
                icon: Icons.pause_circle_outline_rounded,
                selected: currentLifecycle == PatientLifecycle.paused,
                accentColor: const Color(0xFF60A5FA),
                onTap: () => ref
                    .read(patientLifecycleProvider.notifier)
                    .setLifecycle(widget.patientId, PatientLifecycle.paused),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        InkWell(
          onTap: () => setState(() => _editing = true),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EuphireColors.ember.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: EuphireColors.ember,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edytuj dane',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zmień imię, nazwisko, email',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: EuphireColors.mist.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: EuphireColors.mist,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        InkWell(
          onTap: _deleteWarning,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: EuphireColors.magma.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: EuphireColors.magma.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EuphireColors.magma.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: EuphireColors.magma,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usuń kartotekę',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.magma,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Skasuj historię, sesje i notatki',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: EuphireColors.magma.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: EuphireColors.magma.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEditView() {
    final canSave = !_saving && _firstNameCtrl.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── First Name ──
        _GlassField(
          controller: _firstNameCtrl,
          label: 'Imię (wymagane)',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        // ── Last Name / Alias ──
        _GlassField(controller: _lastNameCtrl, label: 'Inicjał lub pseudonim'),
        const SizedBox(height: 12),
        // ── Email ──
        _GlassField(
          controller: _emailCtrl,
          label: 'E-mail klienta',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _editing = false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Text(
                  'Wróć',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: canSave ? _onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuphireColors.ember,
                  foregroundColor: EuphireColors.obsidianBlack,
                  disabledBackgroundColor: EuphireColors.ember.withValues(
                    alpha: 0.3,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EuphireColors.obsidianBlack,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Zapisz',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Inline glass text field for patient options ──

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _GlassField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: EuphireColors.frostWhite,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: EuphireColors.mist.withValues(alpha: 0.7),
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: EuphireColors.ember.withValues(alpha: 0.9),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: EuphireColors.ember, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ── Lifecycle segment button ──

class _LifecycleSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  const _LifecycleSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accentColor = EuphireColors.ember,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          AppHapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: accentColor.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? accentColor
                    : EuphireColors.mist.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? accentColor
                      : EuphireColors.mist.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DELETE FLOW DLA PACJENTA: 1. WARNING SHEET Z TOGGLE ──────────

class _DeletePatientWarningSheet extends StatefulWidget {
  final String patientId;
  final String patientName;
  const _DeletePatientWarningSheet({
    required this.patientId,
    required this.patientName,
  });

  @override
  State<_DeletePatientWarningSheet> createState() =>
      _DeletePatientWarningSheetState();
}

class _DeletePatientWarningSheetState
    extends State<_DeletePatientWarningSheet> {
  bool _understands = false;

  void _onProceed() {
    Navigator.pop(context); // zamyka warning sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeletePatientConfirmSheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.magma.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: EuphireColors.magma,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Usunięcie klienta: ${widget.patientName}',
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  color: EuphireColors.frostWhite,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Cała dokumentacja kliniczna — sesje, notatki AI oraz nagrania audio — zostanie trwale i bezpowrotnie usunięta z baz medycznych.\nZgodnie z RODO (prawo do zapomnienia).',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: EuphireColors.mist.withValues(alpha: 0.8),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rozumiem, to nieodwracalne.',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: EuphireColors.magma,
                      ),
                    ),
                  ),
                  Switch(
                    value: _understands,
                    onChanged: (v) => setState(() => _understands = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: EuphireColors.magma,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedOpacity(
                opacity: _understands ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _understands ? _onProceed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.magma,
                      disabledBackgroundColor: EuphireColors.magma,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Kontynuuj kasowanie',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DELETE FLOW DLA PACJENTA: 2. CONFIRM SHEET (Wpisz USUWAM) ────

class _DeletePatientConfirmSheet extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  const _DeletePatientConfirmSheet({
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<_DeletePatientConfirmSheet> createState() =>
      _DeletePatientConfirmSheetState();
}

class _DeletePatientConfirmSheetState
    extends ConsumerState<_DeletePatientConfirmSheet> {
  final _ctrl = TextEditingController();
  bool _confirmed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim().toLowerCase() == 'usuwam';
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  Future<void> _delete() async {
    if (!_confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(patientsProvider.notifier)
          .deletePatientUser(widget.patientId);
      if (mounted) {
        AppHapticFeedback.heavyImpact();
        Navigator.of(context).pop(); // zamknij po sukcesie
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        EuphireToast.error(context, message: 'Błąd usunięcia: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aby potwierdzić, wpisz:',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'usuwam',
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    color: EuphireColors.magma,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'wpisz tutaj…',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _confirmed
                            ? EuphireColors.magma
                            : EuphireColors.mist.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: _confirmed ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _confirmed && !_deleting ? _delete : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EuphireColors.magma,
                        disabledBackgroundColor: EuphireColors.magma,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _deleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Usuń klienta',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Anuluj.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
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

// ── Avatar label that centers both text and emoji correctly ──

class _AvatarLabel extends StatelessWidget {
  final String label;
  final double size;

  const _AvatarLabel({required this.label, required this.size});

  static bool _isEmoji(String text) {
    // Check if the string contains emoji (non-Latin, non-digit characters
    // outside basic ASCII). Emoji codepoints start at 0x1F000+ or are
    // regional indicators, variation selectors, etc.
    final runes = text.runes;
    for (final rune in runes) {
      if (rune > 0x2600) return true; // emoji range
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isEmoji = _isEmoji(label);
    if (isEmoji) {
      // For emoji: use platform font, center with FittedBox
      return SizedBox(
        width: size * 2,
        height: size * 2,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: size * 1.4, height: 1.0),
          ),
        ),
      );
    }
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: EuphireColors.frostWhite,
      ),
    );
  }
}

// ─── 7-TAP DEBUG LOGO ─────────────────────────────────────────────

/// Logo bar with hidden 7-tap gesture to open the debug panel.
/// Resets tap counter after 2s of inactivity. Tree-shaken in release.
class _DebugTapLogo extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const _DebugTapLogo({required this.onMenuPressed});

  @override
  ConsumerState<_DebugTapLogo> createState() => _DebugTapLogoState();
}

class _DebugTapLogoState extends ConsumerState<_DebugTapLogo> {
  int _tapCount = 0;
  Timer? _resetTimer;
  AudioPlayer? _player;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _playDebugSound() async {
    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
      }
      final newPlayer = AudioPlayer();
      _player = newPlayer;
      await newPlayer.play(AssetSource('sounds/SFX_debug_mode.mp3'));
      newPlayer.onPlayerComplete.first.then((_) {
        if (mounted && _player == newPlayer) {
          newPlayer.dispose();
          _player = null;
        }
      }).catchError((_) {
        if (mounted && _player == newPlayer) {
          newPlayer.dispose();
          _player = null;
        }
      });
    } catch (e) {
      debugPrint('Error playing debug sound: $e');
    }
  }

  void _onLogoTap() {
    _tapCount++;
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      _tapCount = 0;
    });

    if (_tapCount >= 7) {
      _tapCount = 0;
      _resetTimer?.cancel();
      AppHapticFeedback.vibrate();

      final isCurrentlyShown = ref.read(showDebugButtonProvider);
      if (!isCurrentlyShown) {
        // Only play activation sound when turning it ON
        if (ref.read(appSettingsProvider).soundEnabled) {
          _playDebugSound();
        }
      }

      // Toggle the debug floating button and runtime simulation flag
      ref.read(showDebugButtonProvider.notifier).toggle();
      DebugFlags.simulationsEnabled = !isCurrentlyShown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onLogoTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/svg/Brandmark_whiteSam_sygnet_euphire.svg',
                  height: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Superwizor AI',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.8,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.menu,
              color: EuphireColors.frostWhite,
              size: 24,
            ),
            onPressed: widget.onMenuPressed,
          ),
        ],
      ),
    );
  }
}

// ─── RECORDING DOTS BADGE ──────────────────────────────────────────

/// Three small blue dots that sequentially bounce up, creating a
/// wave animation to indicate an active recording session.
class _RecordingDotsBadge extends StatefulWidget {
  const _RecordingDotsBadge();

  @override
  State<_RecordingDotsBadge> createState() => _RecordingDotsBadgeState();
}

class _RecordingDotsBadgeState extends State<_RecordingDotsBadge>
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
            // Each dot has a staggered phase offset (0.0, 0.25, 0.5)
            final phase = (_controller.value + i * 0.25) % 1.0;
            // Bounce: 0→0.5 = up, 0.5→1.0 = down
            final bounce = phase < 0.5
                ? (phase * 2.0) // 0→1 (going up)
                : (1.0 - (phase - 0.5) * 2.0); // 1→0 (going down)
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
                    color: const Color(0xFF60A5FA)
                        .withValues(alpha: 0.6 + 0.4 * bounce),
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
