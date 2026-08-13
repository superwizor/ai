import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/euphire_theme.dart';
import '../utils/haptics.dart';
import '../widgets/euphire_toast.dart';
import '../widgets/offline_banner.dart';
import '../providers/services_provider.dart';
import '../services/recording_service.dart';

import '../analytics/analytics_collector.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../models/patient.dart';
import '../models/session.dart';
import '../providers/current_user_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/grpc_provider.dart';
import '../providers/kartoteka_filters_provider.dart';
import '../providers/patient_notes_provider.dart';
import '../providers/viewed_reports_provider.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../repositories/clinical_notes_repository.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../uploads/cancel_upload_action.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../widgets/client_invite_sheet.dart';
import '../widgets/edit_patient_modal.dart';
import '../widgets/pending_quota_sessions_widget.dart';
import 'new_session_screen.dart';
import 'recording_screen.dart';
import 'session_status_screen.dart';
import 'report_screen.dart';

class ClientDetailsScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String clientName;

  const ClientDetailsScreen({
    super.key,
    required this.patientId,
    required this.clientName,
  });

  @override
  ConsumerState<ClientDetailsScreen> createState() =>
      _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _recordAnim; // mini-FAB #1 (closer to main FAB)
  late Animation<double> _noteAnim; // action card #2 (middle)
  late Animation<double> _uploadAnim; // action card #3 (higher up)
  late Animation<double> _bannerAnim; // security banner from top
  late AnimationController _pulseController; // mic icon pulse
  late Animation<double> _pulseScale;
  bool _hasCollapsedExtendedFab = false; // first-session extended FAB state

  StreamSubscription<RecordingState>? _recStateSub;
  StreamSubscription<Duration>? _recDurSub;
  Timer? _statusPollTimer;
  RecordingState _activeRecState = RecordingState.idle;
  Duration _activeRecDuration = Duration.zero;
  String? _activeRecPatientId;

  bool get _isExpanded =>
      _fabController.status == AnimationStatus.completed ||
      _fabController.status == AnimationStatus.forward;

  @override
  void initState() {
    super.initState();
    // Force a fresh ListSessions fetch ONCE on screen entry (not on every
    // rebuild). The SWR cached-read path can return a pre-completion
    // snapshot when an upload finished while the user was elsewhere.
    //
    // This used to live in build() — which re-ran it on every rebuild. A
    // rename's optimistic state update triggers a rebuild, which fired a
    // forceRefresh that raced the in-flight UpdateSession and overwrote the
    // new title with the still-stale server name. Running it once here
    // removes that race (the ref.listen on pendingUploads below still
    // refreshes when an upload completes).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(analyticsCollectorProvider)
            .track(
              "screen.viewed",
              properties: {"screen_name": "ClientDetailsScreen"},
            );
        unawaited(
          ref.read(sessionsProvider.notifier).forceRefresh(widget.patientId),
        );
      }
    });
    // Status poll: server-side ANALYZING → COMPLETED transitions have no
    // push channel to the session LIST (only SessionStatusScreen listens
    // per-session). After the offline queue flushed several uploads at
    // once, cards sat on "AI analizuje…" forever unless the user left
    // and re-entered (2026-07-23). While any visible session is
    // non-terminal, re-fetch every 20 s; idle otherwise.
    _statusPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final sessions =
          ref.read(sessionsProvider).asData?.value[widget.patientId] ?? [];
      final hasLive = sessions.any(
        (s) =>
            s.status == SessionStatus.inProgress ||
            s.status == SessionStatus.pendingUpload,
      );
      if (hasLive) {
        unawaited(
          ref.read(sessionsProvider.notifier).forceRefresh(widget.patientId),
        );
      }
    });

    final recSvc = ref.read(recordingServiceProvider);
    _activeRecState = recSvc.state;
    _activeRecDuration = recSvc.currentDuration;
    _activeRecPatientId = recSvc.patientFileId;

    _recStateSub = recSvc.stateStream.listen((s) {
      if (mounted) {
        setState(() {
          _activeRecState = s;
          _activeRecPatientId = recSvc.patientFileId;
        });
      }
    });
    _recDurSub = recSvc.durationStream.listen((d) {
      if (mounted) {
        setState(() {
          _activeRecDuration = d;
          _activeRecPatientId = recSvc.patientFileId;
        });
      }
    });

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Staggered: record appears first, note second, upload third, banner last
    _recordAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _noteAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.08, 0.65, curve: Curves.easeOutCubic),
    );
    _uploadAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.16, 0.80, curve: Curves.easeOutCubic),
    );
    _bannerAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );

    // Mic pulse: 2 gentle beats when FAB opens
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fabController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat(reverse: true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            _pulseController.reverse().then((_) {
              if (mounted) _pulseController.stop();
            });
          }
        });
      } else if (status == AnimationStatus.reverse) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pulseController.dispose();
    _recStateSub?.cancel();
    _recDurSub?.cancel();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  void _toggleFab() {
    if (_isExpanded) {
      _fabController.reverse();
    } else {
      _fabController.forward();
    }
  }

  void _closeFab() {
    if (_isExpanded) _fabController.reverse();
  }

  /// Resolves therapistId, patient alias, and patient languageCode.
  /// Returns null if therapistId is unavailable.
  Future<({String therapistId, String alias, String languageCode})?>
  _resolveSessionContext() async {
    var therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) {
      try {
        final user = await ref.read(currentUserProvider.future);
        therapistId = user?.id;
      } catch (e) {
        // network / auth error — fall through with null
      }
    }
    if (!mounted) return null;
    if (therapistId == null) {
      final l = AppLocalizations.of(context);
      EuphireToast.info(context, message: l.clientDetails_profile_not_loaded);
      return null;
    }
    final patientsState =
        ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? [];
    final patient = patientsState.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () => Patient(id: widget.patientId, workingAlias: 'Brak'),
    );
    final alias = patient.workingAlias;
    // BCP47 language code for downstream reportLanguage parameters
    // (2026-05-15 fix: EN-patient → Polish-report regression). Empty
    // string when missing; callers fall back to 'pl-PL'.
    return (
      therapistId: therapistId,
      alias: alias,
      languageCode: patient.languageCode,
    );
  }

  Future<void> _onRecordTapped() async {
    _closeFab();
    final ctx = await _resolveSessionContext();
    if (ctx == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'RecordingScreen'),
        builder: (_) => RecordingScreen(
          patientFileId: widget.patientId,
          therapistId: ctx.therapistId,
          patientAlias: ctx.alias,
          reportLanguage: ctx.languageCode.isNotEmpty
              ? ctx.languageCode
              : 'pl-PL',
        ),
      ),
    );
  }

  Future<void> _onUploadTapped() async {
    _closeFab();
    final ctx = await _resolveSessionContext();
    if (ctx == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'NewSessionScreen'),
        builder: (_) => NewSessionScreen(
          patientFileId: widget.patientId,
          therapistId: ctx.therapistId,
          patientAlias: ctx.alias,
          autoPickFile: true,
          // BCP47 from PatientFile.patientLanguageCode →
          // CreateAudioUploadRequest.reportLanguage so EN-patient
          // reports don't silently default to Polish. Empty → 'pl-PL'.
          patientLanguageCode: ctx.languageCode.isNotEmpty
              ? ctx.languageCode
              : 'pl-PL',
        ),
      ),
    );
  }

  void _onNoteTapped() {
    _closeFab();
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'NoteEditorScreen'),
        builder: (_) => NoteEditorScreen(patientId: widget.patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final patientAsync = ref.watch(patientsProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final pendingUploads = ref.watch(
      pendingUploadsForPatientProvider(widget.patientId),
    );

    // Quota-blocked local uploads for this patient → the dedicated
    // "Sesje oczekujące na przetworzenie" banner is the single
    // representation. In that case suppress the duplicate server-side
    // PENDING_UPLOAD "Oczekiwanie na audio" cards entirely. When there
    // are NO local quota rows (e.g. after a reinstall that lost the
    // cached audio), the server cards still render so the therapist can
    // cancel the stranded sessions explicitly (feat/tokens-exhausted).
    final hasLocalQuotaBlocked = ref
        .watch(pendingUploadsStreamProvider)
        .maybeWhen(
          data: (list) => list.any(
            (u) =>
                u.patientFileId == widget.patientId &&
                u.phase == UploadPhase.quotaBlocked,
          ),
          orElse: () => false,
        );

    // (forceRefresh on entry moved to initState — it must run once, not on
    // every rebuild, or it races/overwrites optimistic edits like rename.)

    // Auto-refresh hook: when any in-flight upload for THIS patient
    // transitions to a terminal state (drops from
    // pendingUploadsForPatientProvider, which excludes completed +
    // failed), invalidate sessionsProvider so the freshly-created
    // session row appears immediately. Without this, the user has
    // to manually pull-to-refresh or navigate away+back to see the
    // session after long-audio chunking finishes server-side.
    //
    // Note: we deliberately treat the first emission (prev=null) as
    // prevLen=0 and still react when the list shrinks. Combined with
    // the forceRefresh on entry above, this catches the case "an
    // upload completes while the user is mid-navigation".
    ref.listen<List<PendingUpload>>(
      pendingUploadsForPatientProvider(widget.patientId),
      (prev, next) {
        final prevLen = prev?.length ?? 0;
        if (prevLen > next.length) {
          // At least one row left the active set — either completed
          // (good, refresh) or failed (also refresh so any partial
          // status the server may have stamped surfaces). Use the
          // force variant so we don't trust the cache here either.
          ref.read(sessionsProvider.notifier).forceRefresh(widget.patientId);
        }
      },
    );

    return Scaffold(
      backgroundColor: EuphireColors.obsidianBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.mist),
        actions: [
          patientAsync.when(
            data: (patients) {
              final patient = patients.firstWhere(
                (p) => p.id == widget.patientId,
                orElse: () => Patient(id: widget.patientId, workingAlias: ''),
              );
              if (patient.workingAlias.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4, top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // docs/39: invite the client to their panel.
                    IconButton(
                      tooltip: AppLocalizations.of(context).invite_client_title,
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          color: EuphireColors.mist),
                      onPressed: () =>
                          showClientInviteSheet(context, patient: patient),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: EuphireColors.mist),
                      onPressed: () {
                        showEuphireBottomSheet(
                          context: context,
                          builder: (_) => EditPatientModal(patient: patient),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: patientAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: EuphireColors.ember),
        ),
        error: (e, st) => Center(
          child: Text(
            l.clientDetails_error(e.toString()),
            style: const TextStyle(color: EuphireColors.ember),
          ),
        ),
        data: (patients) {
          final patient = patients.firstWhere(
            (p) => p.id == widget.patientId,
            orElse: () => Patient(
              id: widget.patientId,
              workingAlias: l.common_not_found,
            ),
          );

          return SizedBox.expand(
            child: Stack(
              children: [
                // ── Main content ──
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Offline banner (tryb samolotowy, 2026-07-23):
                        // the kartoteka renders from the encrypted cache
                        // offline — say so, same as the home list. ──
                        const OfflineBanner(),
                        // ── Patient name header (matches home screen style) ──
                        Text.rich(
                          TextSpan(
                            text: patient.workingAlias,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: EuphireColors.ember,
                              height: 1.2,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.clientDetails_subtitle,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: EuphireColors.mist.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Billing quota signals (Phase 3 §16):
                        //   Pending sessions stuck on quota — patient-scoped,
                        //   stays here. The cross-patient QuotaWarningBanner
                        //   lives one level up in home_screen so it is visible
                        //   before drilling into a specific kartoteka.
                        PendingQuotaSessionsWidget(
                          patientFileId: widget.patientId,
                        ),
                        const SizedBox(height: 16),
                        sessionsAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: EuphireColors.ember,
                            ),
                          ),
                          error: (e, st) => Center(
                            child: Text(
                              l.clientDetails_session_error(e.toString()),
                              style: const TextStyle(
                                color: EuphireColors.ember,
                              ),
                            ),
                          ),
                          data: (sessionsMap) {
                            final sessions =
                                sessionsMap[widget.patientId] ?? [];
                            // When a quota banner is showing for this
                            // patient, hide the duplicate PENDING_UPLOAD
                            // "Oczekiwanie na audio" cards — the banner is
                            // the single representation of the quota-blocked
                            // uploads. (Reinstall case: no local rows →
                            // hasLocalQuotaBlocked false → cards stay, so
                            // they remain cancellable.)
                            // Sort by date descending (most recent first)
                            final filteredSessions =
                                sessions
                                    .where(
                                      (s) =>
                                          !(hasLocalQuotaBlocked &&
                                              s.status ==
                                                  SessionStatus.pendingUpload),
                                    )
                                    .toList()
                                  ..sort((a, b) => b.date.compareTo(a.date));
                            // Dedup: if a pending upload already has a
                            // sessionId AND that session is in the server
                            // list, drop the placeholder. The Hive-queue
                            // placeholder is for the gap BEFORE the
                            // session row exists in ListSessions; once
                            // it does (Option E: from CreateAudioUpload
                            // onward, in PENDING_UPLOAD status), the
                            // server-side card supersedes.
                            //
                            // Option E note: under Option E the server
                            // returns a PENDING_UPLOAD card for every
                            // active upload, so this dedup turns the
                            // Hive placeholder into a "fallback for
                            // legacy / offline" affordance — Hive shows
                            // it only when ListSessions hasn't been
                            // refreshed yet.
                            final knownSessionIds = sessions
                                .map((s) => s.id)
                                .toSet();
                            final visiblePending = pendingUploads
                                .where(
                                  (u) => u.sessionId == null
                                      ? true
                                      : !knownSessionIds.contains(u.sessionId),
                                )
                                .toList(growable: false);

                            final hasActiveRecording =
                                (_activeRecState == RecordingState.recording ||
                                    _activeRecState == RecordingState.paused ||
                                    _activeRecState ==
                                        RecordingState.interrupted) &&
                                _activeRecPatientId == widget.patientId;

                            // Notes are part of the timeline AND the
                            // empty-state decision — a kartoteka with notes
                            // but no sessions must still render the timeline
                            // (else notes added as the first action vanish
                            // until a session exists).
                            final notes = ref.watch(
                              patientNotesProvider(widget.patientId),
                            );

                            if (filteredSessions.isEmpty &&
                                visiblePending.isEmpty &&
                                !hasActiveRecording &&
                                notes.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 120.0,
                                    left: 32.0,
                                    right: 32.0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: EuphireColors.frostWhite
                                              .withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 32,
                                          color: EuphireColors.mist,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        l.clientDetails_start_work,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Merriweather',
                                          fontSize: 20,
                                          fontStyle: FontStyle.italic,
                                          color: EuphireColors.frostWhite
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        l.clientDetails_start_work_desc,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                          color: EuphireColors.mist,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            // Placeholders sit at the TOP of the list:
                            // newest activity first, matching the
                            // reversed real-sessions ordering below.
                            //
                            // Notes are interleaved chronologically:
                            // build a merged list of sessions + notes
                            // sorted by date/createdAt descending.
                            // (`notes` is fetched above, before the
                            // empty-state guard, so notes-only kartoteki
                            // still render.)

                            // Build a unified timeline of sessions and
                            // notes, sorted newest-first.
                            final List<_TimelineItem> timeline = [];
                            for (final s in filteredSessions) {
                              timeline.add(
                                _TimelineItem.session(
                                  s,
                                  filteredSessions.length -
                                      filteredSessions.indexOf(s),
                                ),
                              );
                            }
                            for (final n in notes) {
                              timeline.add(_TimelineItem.note(n));
                            }
                            timeline.sort(
                              (a, b) => b.sortDate.compareTo(a.sortDate),
                            );

                            // Kartoteka filters (Companion-app mirror):
                            // applied AFTER numbering so session numbers
                            // stay stable regardless of active chips.
                            // Pending uploads + the live-recording card
                            // count as sessions-in-the-making.
                            final kartFilters = ref.watch(
                              kartotekaFiltersProvider(widget.patientId),
                            );
                            final sessionsVisible = kartFilters.isEmpty ||
                                kartFilters
                                    .contains(KartotekaFilter.sessions);
                            final visibleTimeline = _applyKartotekaFilter(
                              timeline,
                              kartFilters,
                            );
                            final shownPending = sessionsVisible
                                ? visiblePending
                                : visiblePending
                                    .where((_) => false)
                                    .toList(growable: false);
                            final showRecording =
                                hasActiveRecording && sessionsVisible;

                            final totalCount =
                                (showRecording ? 1 : 0) +
                                shownPending.length +
                                visibleTimeline.length;

                            final filterBar = Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 16.0),
                              child: _KartotekaFilterBar(
                                patientId: widget.patientId,
                                selected: kartFilters,
                              ),
                            );

                            if (totalCount == 0) {
                              // Everything hidden by the active chips —
                              // keep the bar visible so the user can
                              // un-toggle, and say why the list is empty.
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  filterBar,
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 48.0,
                                      horizontal: 32.0,
                                    ),
                                    child: Text(
                                      l.clientDetails_filter_empty,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 14,
                                        color: EuphireColors.mist,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            final list = ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: totalCount,
                              itemBuilder: (context, index) {
                                int offset = 0;
                                if (showRecording) {
                                  if (index == 0) {
                                    return _ActiveRecordingCard(
                                      patientId: widget.patientId,
                                      duration: _activeRecDuration,
                                      state: _activeRecState,
                                      onTap: () {
                                        final svc = ref.read(
                                          recordingServiceProvider,
                                        );
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            settings: const RouteSettings(name: 'RecordingScreen'),
                                            builder: (_) => RecordingScreen(
                                              patientFileId:
                                                  svc.patientFileId ?? '',
                                              therapistId:
                                                  svc.therapistId ?? '',
                                              patientAlias:
                                                  svc.patientAlias ?? '',
                                              reportLanguage:
                                                  svc.reportLanguage ?? 'pl-PL',
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  offset = 1;
                                }
                                final adjustedIdx = index - offset;
                                if (adjustedIdx < shownPending.length) {
                                  return _PendingUploadCard(
                                    upload: shownPending[adjustedIdx],
                                  );
                                }
                                final timelineIdx =
                                    adjustedIdx - shownPending.length;
                                final item = visibleTimeline[timelineIdx];

                                if (item.isNote) {
                                  return Dismissible(
                                    key: ValueKey('note_${item.note!.id}'),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) async {
                                      final l = AppLocalizations.of(context);
                                      return await showModalBottomSheet<bool>(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        builder: (ctx) => Container(
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF0A2326),
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(32),
                                            ),
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.white10,
                                              ),
                                            ),
                                          ),
                                          child: SafeArea(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    24,
                                                    20,
                                                    24,
                                                    16,
                                                  ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Center(
                                                    child: Container(
                                                      width: 40,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white24,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              2,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    l.note_delete_confirm,
                                                    style: const TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: EuphireColors
                                                          .frostWhite,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                false,
                                                              ),
                                                          style: TextButton.styleFrom(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 14,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              side: BorderSide(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            l.note_sheet_cancel,
                                                            style: const TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  EuphireColors
                                                                      .mist,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                true,
                                                              ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                EuphireColors
                                                                    .magma,
                                                            foregroundColor:
                                                                EuphireColors
                                                                    .frostWhite,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 14,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            l.note_delete_action,
                                                            style: const TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    onDismissed: (_) {
                                      AppHapticFeedback.heavyImpact();
                                      ref
                                          .read(
                                            patientNotesMapProvider.notifier,
                                          )
                                          .deleteNote(
                                            widget.patientId,
                                            item.note!.id,
                                          );
                                      final l = AppLocalizations.of(context);
                                      EuphireToast.success(
                                        context,
                                        message: l.note_deleted,
                                      );
                                    },
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 24),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: EuphireColors.magma.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: EuphireColors.magma.withValues(
                                          alpha: 0.8,
                                        ),
                                        size: 24,
                                      ),
                                    ),
                                    child: _NoteCard(
                                      note: item.note!,
                                      patientId: widget.patientId,
                                    ),
                                  );
                                }

                                final session = item.session!;
                                // Option E (2026-05-25): server-side
                                // PENDING_UPLOAD sessions render with
                                // the same placeholder style as the
                                // Hive-queue-driven _PendingUploadCard.
                                if (session.status ==
                                    SessionStatus.pendingUpload) {
                                  return _PendingUploadServerCard(
                                    session: session,
                                    patientId: widget.patientId,
                                  );
                                }
                                return _SessionCard(
                                  session: session,
                                  patientId: widget.patientId,
                                  sessionNumber: item.sessionNumber,
                                );
                              },
                            );
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [filterBar, list],
                            );
                          },
                        ),
                        // Bottom padding so FAB doesn't cover last card
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // ── Scrim (dark overlay when FAB expanded) ──
                AnimatedBuilder(
                  animation: _fabController,
                  builder: (_, _) {
                    if (_fabController.value == 0) {
                      return const SizedBox.shrink();
                    }
                    return GestureDetector(
                      onTap: _closeFab,
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.5 * _fabController.value,
                        ),
                      ),
                    );
                  },
                ),

                // ── Security banner (slides from top, organic gradient) ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _bannerAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1.0),
                        end: Offset.zero,
                      ).animate(_bannerAnim),
                      child: ClipPath(
                        clipper: const _ArcBottomClipper(arcDip: 18),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF0D3B34),
                                Color(0xFF0A302A),
                                Color(0x000A302A),
                              ],
                              stops: [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                18,
                                24,
                                44,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.shield_rounded,
                                      color: EuphireColors.frostWhite,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      '${AppLocalizations.of(context).clientDetails_encryption_notice_part1}'
                                      '${AppLocalizations.of(context).clientDetails_encryption_notice_part2}',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: EuphireColors.frostWhite
                                            .withValues(alpha: 0.85),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Speed Dial action cards + FAB ──
                // Guard: hide the entire FAB when a recording is active
                // (any patient). The therapist can browse kartoteki via
                // the back button, but must NOT be able to start a second
                // recording or upload. The minimized recording bar
                // provides the return path to the active session.
                if (!(_activeRecState == RecordingState.recording ||
                    _activeRecState == RecordingState.paused ||
                    _activeRecState == RecordingState.interrupted))
                  Positioned(
                    right: 16,
                    bottom: 16,
                    // No left constraint — FAB extends freely to the left
                    // Action cards get explicit width from the builder
                    child: Builder(
                      builder: (ctx) {
                        final l = AppLocalizations.of(ctx);
                        // Detect first session
                        final currentSessions =
                            sessionsAsync.whenOrNull(
                              data: (map) => map[widget.patientId],
                            ) ??
                            [];
                        final isFirstSession =
                            currentSessions.isEmpty &&
                            !_hasCollapsedExtendedFab &&
                            !_isExpanded;

                        // Fixed extended width so it wraps the text perfectly without
                        // unnecessary negative space, clamped to avoid overflow.
                        final screenWidth = MediaQuery.of(ctx).size.width;
                        final extendedWidth = 285.0.clamp(
                          200.0,
                          screenWidth - 32.0,
                        );

                        return AnimatedBuilder(
                          animation: _fabController,
                          builder: (_, _) => Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // ── Action Card #3: Upload file (highest) ──
                              // Web: hidden — recording/file upload are native-only
                              // for now (see new_session web-upload deferral).
                              if (!kIsWeb)
                                SizeTransition(
                                  sizeFactor: _uploadAnim,
                                  axisAlignment: 1.0,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: SizedBox(
                                      width: screenWidth - 48,
                                      child: _buildActionCard(
                                        animation: _uploadAnim,
                                        icon: Icons.upload_file_rounded,
                                        label: l.clientDetails_upload_file_btn,
                                        subtitle:
                                            l.clientDetails_upload_recording,
                                        onTap: _onUploadTapped,
                                        isPrimary: false,
                                        cardColor: const Color(0xFF142D2B),
                                      ),
                                    ),
                                  ),
                                ),

                              // ── Action Card #2: Add note (middle) ──
                              SizeTransition(
                                sizeFactor: _noteAnim,
                                axisAlignment: 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SizedBox(
                                    width: screenWidth - 48,
                                    child: _buildActionCard(
                                      animation: _noteAnim,
                                      icon: Icons.edit_note_rounded,
                                      label: AppLocalizations.of(
                                        context,
                                      ).note_add_label,
                                      subtitle: AppLocalizations.of(
                                        context,
                                      ).note_add_subtitle,
                                      onTap: _onNoteTapped,
                                      isPrimary: false,
                                      cardColor: const Color(0xFF0B1E20),
                                    ),
                                  ),
                                ),
                              ),

                              // ── Action Card #1: Record (closer to main) ──
                              // Web: hidden — session recording is native-only.
                              if (!kIsWeb)
                                SizeTransition(
                                  sizeFactor: _recordAnim,
                                  axisAlignment: 1.0,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: SizedBox(
                                      width: screenWidth - 48,
                                      child: _buildActionCard(
                                        animation: _recordAnim,
                                        icon: Icons.mic_rounded,
                                        label: l.clientDetails_record_btn,
                                        subtitle:
                                            l.clientDetails_record_new_session,
                                        onTap: _onRecordTapped,
                                        isPrimary: true,
                                      ),
                                    ),
                                  ),
                                ),

                              // ── Main FAB (extended pill or circle) ──
                              GestureDetector(
                                onTap: () {
                                  if (isFirstSession) {
                                    setState(
                                      () => _hasCollapsedExtendedFab = true,
                                    );
                                    Future.delayed(
                                      const Duration(milliseconds: 380),
                                      _toggleFab,
                                    );
                                  } else {
                                    _toggleFab();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOutCubic,
                                  height: 56,
                                  width: isFirstSession ? extendedWidth : 56,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: EuphireColors.ember,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: EuphireColors.emberGlow,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Extended label (slides right & fades)
                                      AnimatedOpacity(
                                        opacity: isFirstSession ? 1.0 : 0.0,
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child: AnimatedSlide(
                                          offset: isFirstSession
                                              ? Offset.zero
                                              : const Offset(0.3, 0),
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInCubic,
                                          child: SizedBox(
                                            width: extendedWidth,
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    l.clientDetails_start_first_analysis,
                                                    style: TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: EuphireColors
                                                          .obsidianBlack,
                                                      letterSpacing: 0.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.add_rounded,
                                                  size: 22,
                                                  color: EuphireColors
                                                      .obsidianBlack
                                                      .withValues(alpha: 0.6),
                                                ),
                                                const SizedBox(width: 16),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Circle icon (appears when collapsed)
                                      AnimatedOpacity(
                                        opacity: isFirstSession ? 0.0 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: AnimatedRotation(
                                          turns: _fabController.value * 0.125,
                                          duration: Duration.zero,
                                          child: Icon(
                                            Icons.add,
                                            size: 28,
                                            color: EuphireColors.obsidianBlack,
                                          ),
                                        ),
                                      ),
                                    ],
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
          );
        },
      ),
    );
  }

  /// Builds an animated full-width action card for the speed dial.
  Widget _buildActionCard({
    required Animation<double> animation,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
    Color? cardColor,
  }) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color:
                  cardColor ??
                  (isPrimary ? EuphireColors.ember : const Color(0xFF0F1F21)),
              borderRadius: BorderRadius.circular(14),
              border: isPrimary
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: isPrimary
                  ? [
                      ...EuphireColors.emberGlow,
                      BoxShadow(
                        color: EuphireColors.ember.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Icon circle — with pulse on primary
                ScaleTransition(
                  scale: isPrimary
                      ? _pulseScale
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isPrimary
                          ? EuphireColors.frostWhite
                          : EuphireColors.frostWhite.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Text column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: isPrimary
                              ? EuphireColors.obsidianBlack
                              : EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isPrimary
                              ? EuphireColors.obsidianBlack.withValues(
                                  alpha: 0.6,
                                )
                              : EuphireColors.mist.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isPrimary
                      ? EuphireColors.obsidianBlack.withValues(alpha: 0.4)
                      : EuphireColors.mist.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Session Card (extracted from inline builder) ────────────────────

/// Card shown for an in-flight upload before its sessions row exists
/// server-side. Long-audio "Wgraj Plik z Dysku" can take several
/// minutes between PUT and CompleteAudioUpload finishing its ffmpeg
/// chunking — without this card the user sees an empty session list
/// during that window. Disappears the instant the queue row reaches
/// `completed` and the real `_SessionCard` takes its place.
///
/// Intentionally non-clickable: tapping a row that has no session_id
/// yet would have nowhere meaningful to navigate to (the
/// `SessionStatusScreen` is keyed on session_id). When `sessionId` is
/// populated (which happens at the very end of the upload, briefly
/// before the row flips to `completed`), the card becomes tappable
/// and routes to the status screen.
class _PendingUploadCard extends StatelessWidget {
  final PendingUpload upload;

  const _PendingUploadCard({required this.upload});

  String _statusLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    switch (upload.phase) {
      case UploadPhase.encrypting:
        return l.clientDetails_status_processing;
      case UploadPhase.converting:
        return l.clientDetails_status_converting;
      case UploadPhase.pending:
        return l.clientDetails_status_queued;
      case UploadPhase.created:
        return l.clientDetails_status_uploading;
      case UploadPhase.uploaded:
        return l.clientDetails_status_processing_audio;
      case UploadPhase.converted:
        return l.clientDetails_status_finalizing;
      case UploadPhase.failed:
        return l.clientDetails_status_interrupted;
      case UploadPhase.completed:
      case UploadPhase.quotaBlocked:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sessionId = upload.sessionId;
    final hasSessionId = sessionId != null && sessionId.isNotEmpty;
    final isFailed = upload.phase == UploadPhase.failed;

    final color = EuphireColors.ember;
    final bgColor = isFailed
        ? EuphireColors.ember.withValues(alpha: 0.06)
        : EuphireColors.frostWhite.withValues(alpha: 0.05);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'SessionStatusScreen'),
            builder: (_) => SessionStatusScreen(
              sessionId: hasSessionId ? sessionId : null,
              localId: hasSessionId ? null : upload.localId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: isFailed
                  ? Icon(Icons.error_outline_rounded, color: color, size: 18)
                  : CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFailed
                        ? l.clientDetails_status_requires_attention
                        : l.clientDetails_status_processing_label,
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isFailed ? color : EuphireColors.frostWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusLabel(context),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: isFailed
                          ? color.withValues(alpha: 0.8)
                          : EuphireColors.mist,
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
    );
  }
}

/// Server-side PENDING_UPLOAD session card. Visually identical to
/// the Hive-queue-driven _PendingUploadCard so the user gets the
/// same affordance regardless of which device started the upload.
/// Tapping routes to SessionStatusScreen (we have a real sessionId
/// from the server). Option E (2026-05-25,
/// docs/14_INGESTION_EARLY_SESSION_CREATION.md).
///
/// Carries a delete (Usuń) action that cancels the server session
/// (CancelSession → CANCELLED_BY_USER), so the therapist can clear a
/// stuck/quota-blocked PENDING_UPLOAD — including the
/// reinstall-lost-the-local-audio case where there is no local queue
/// row to dismiss (feat/tokens-exhausted).
class _PendingUploadServerCard extends ConsumerWidget {
  final Session session;
  final String patientId;

  const _PendingUploadServerCard({
    required this.session,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'SessionStatusScreen'),
            builder: (_) => SessionStatusScreen(sessionId: session.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EuphireColors.frostWhite.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EuphireColors.ember.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: EuphireColors.ember,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.sessionNumber > 0
                        ? '${l.clientDetails_session_title} ${session.sessionNumber}'
                        : l.clientDetails_status_new_session,
                    style: const TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.clientDetails_status_waiting_audio,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: EuphireColors.mist,
                    ),
                  ),
                ],
              ),
            ),
            // Delete (Usuń) → cancel the server session. Works even with
            // no local audio (reinstall case).
            IconButton(
              icon: const Icon(Icons.delete_rounded, size: 22),
              color: EuphireColors.magma,
              tooltip: l.upload_cancel_processing,
              onPressed: () => confirmAndCancelUpload(
                context,
                ref,
                patientFileId: patientId,
                sessionId: session.id,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final Session session;
  final String patientId;
  final int sessionNumber;

  const _SessionCard({
    required this.session,
    required this.patientId,
    this.sessionNumber = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final d = session.date;
    final dateStr = DateFormat('d MMM', locale).format(d);
    final durationMin = session.duration.inMinutes;

    // Rich metadata line: "11 Maj / 11:00 - 11:56 / 54 min"
    String metaStr;
    if (durationMin > 0) {
      final startTime = d.subtract(session.duration);
      final startStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      metaStr =
          '$dateStr  \u2022  $startStr \u2013 $endStr  \u2022  $durationMin min';
    } else {
      final timeStr =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      metaStr = '$dateStr  \u2022  $timeStr';
    }

    final isCompleted = session.status == SessionStatus.completed;
    final viewedReports = ref.watch(viewedReportsProvider).value ?? <String>{};
    final isViewed = session.reportViewedAt != null || viewedReports.contains(session.id);

    // Contextual status — Euphire palette only
    final isInProgress = session.status == SessionStatus.inProgress;
    final isPendingUpload = session.status == SessionStatus.pendingUpload;
    final isError = session.status == SessionStatus.error;

    final (statusText, dotColor) = switch (session.status) {
      SessionStatus.completed => (
        isViewed
            ? l.clientDetails_status_ready
            : l.clientDetails_status_new_report,
        isViewed ? EuphireColors.mist : const Color(0xFF4ADE80),
      ),
      SessionStatus.inProgress => (
        l.clientDetails_status_analyzing,
        EuphireColors.ember,
      ),
      SessionStatus.pendingUpload => (
        l.clientDetails_status_uploading_label,
        Colors.orangeAccent,
      ),
      SessionStatus.error => (
        l.clientDetails_status_error,
        EuphireColors.magma,
      ),
    };

    // Show the badge pill for all actionable states including pendingUpload
    final showBadge =
        (isCompleted && !isViewed) ||
        isInProgress ||
        isPendingUpload ||
        isError;

    // session.name is non-null ONLY when the user explicitly renamed the
    // session. For new sessions the backend stores NULL → Flutter computes
    // the localized title from the DB-authoritative session_number.
    final sn = session.sessionNumber;
    final title =
        session.name ??
        (sn > 0
            ? '${l.clientDetails_session_title} $sn'
            : l.clientDetails_session_title);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        // Mark as viewed when opening a completed report
        if (isCompleted) {
          ref.read(viewedReportsProvider.notifier).markViewed(session.id);
        }
        // Completed sessions open on the REPORT by default (feedback
        // 2026-07-20) — the transcript stays one toggle away.
        final destination = isCompleted
            ? MaterialPageRoute(
                settings: const RouteSettings(name: 'ReportScreen'),
                builder: (_) => ReportScreen(sessionId: session.id),
              )
            : MaterialPageRoute(
                settings: const RouteSettings(name: 'SessionStatusScreen'),
                builder: (_) => SessionStatusScreen(sessionId: session.id),
              );
        Navigator.push(context, destination);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: Row(
          children: [
            // ── Session number badge ──
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: isInProgress || isPendingUpload
                  // Spinner inside the number badge for active states
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dotColor,
                      ),
                    )
                  : isError
                  ? Icon(Icons.error_outline_rounded, size: 18, color: dotColor)
                  : Text(
                      sn > 0 ? '#$sn' : '#',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: dotColor,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            // ── Title + meta ──
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
            // ── Status pill (only for actionable states) ──
            if (showBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: isError
                      ? Border.all(color: dotColor.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spinner for uploading/analyzing, icon for error, dot for others
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
            // ── Context menu ──
            GestureDetector(
              onTap: () => _showSessionOptionsSheet(
                context,
                ref,
                session,
                patientId,
                title,
              ),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Icon(
                  Icons.more_vert,
                  color: EuphireColors.mist.withValues(alpha: 0.5),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    Session session,
    String patientId,
    String currentTitle,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SessionOptionsSheet(
        session: session,
        patientId: patientId,
        currentTitle: currentTitle,
      ),
    );
  }
}

// ─── Session Options Bottom Sheet (unified, no nesting) ──────────────

class _SessionOptionsSheet extends ConsumerStatefulWidget {
  final Session session;
  final String patientId;
  final String currentTitle;

  const _SessionOptionsSheet({
    required this.session,
    required this.patientId,
    required this.currentTitle,
  });

  @override
  ConsumerState<_SessionOptionsSheet> createState() =>
      _SessionOptionsSheetState();
}

class _SessionOptionsSheetState extends ConsumerState<_SessionOptionsSheet> {
  late TextEditingController _titleCtrl;
  bool _saving = false;
  // docs/39: local mirror of sessions.shared_with_client_at so the
  // toggle flips instantly; the server refresh confirms it.
  late bool _shared;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.currentTitle);
    _shared = widget.session.sharedWithClient;
  }

  Future<void> _toggleShare(bool value) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _sharing = true;
      _shared = value;
    });
    try {
      await ref.read(grpcClientsProvider).clinical.shareSessionWithClient(
            clinical_pb.ShareSessionWithClientRequest(
              sessionId: widget.session.id,
              shared: value,
            ),
          );
      // Pull the authoritative shared_with_client_at into the list.
      await ref
          .read(sessionsProvider.notifier)
          .fetchSessions(widget.patientId);
      if (mounted) setState(() => _sharing = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sharing = false;
          _shared = !value; // roll back
        });
        EuphireToast.error(context, message: l.share_toggle_error);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty || newTitle == widget.currentTitle) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final l = AppLocalizations.of(context);
    try {
      await ref
          .read(sessionsProvider.notifier)
          .renameSession(widget.patientId, widget.session.id, newTitle);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Server didn't accept the rename — surface it (was silently
      // swallowed before) and keep the sheet open so the user can retry.
      if (mounted) {
        setState(() => _saving = false);
        EuphireToast.error(context, message: l.session_rename_error);
      }
    }
  }

  void _deleteWarning() {
    // Capture stable references BEFORE popping. Once the options sheet is
    // popped, THIS State (its `ref` / `context` / `mounted`) is disposed —
    // so the confirm sheet must not touch them. This was the real reason
    // "Tak, usuń" did nothing: the old code popped first, then the confirm
    // button read a DISPOSED `ref`, so deleteSession never even ran (and my
    // earlier server-refresh fix never executed). notifier/rootContext are
    // valid for the whole lifetime of the confirm sheet.
    final notifier = ref.read(sessionsProvider.notifier);
    final l = AppLocalizations.of(context);
    final patientId = widget.patientId;
    final sessionId = widget.session.id;
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    Navigator.pop(context);
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: EuphireColors.magma.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      size: 28,
                      color: EuphireColors.magma.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.clientDetails_delete_session_title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l.clientDetails_delete_session_desc,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
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
                          l.common_cancel,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: EuphireColors.mist,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close the confirm sheet first, then delete via the
                          // CAPTURED notifier (the widget's `ref` is gone now).
                          Navigator.pop(ctx);
                          try {
                            await notifier.deleteSession(patientId, sessionId);
                          } catch (e) {
                            if (rootContext.mounted) {
                              EuphireToast.error(
                                rootContext,
                                message: l.session_delete_error,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EuphireColors.magma,
                          foregroundColor: EuphireColors.frostWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Text(
                          l.clientDetails_btn_yes_delete,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasChanges =
        _titleCtrl.text.trim().isNotEmpty &&
        _titleCtrl.text.trim() != widget.currentTitle;

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

                // ── Icon ──
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EuphireColors.ember.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: EuphireColors.ember.withValues(alpha: 0.2),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_calendar_rounded,
                      color: EuphireColors.ember,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ──
                Text(
                  l.clientDetails_manage_session,
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
                  l.clientDetails_manage_session_desc,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ── Inline title field ──
                TextField(
                  controller: _titleCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: EuphireColors.frostWhite,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l.clientDetails_session_title_label,
                    labelStyle: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                      height: 1.1,
                    ),
                    floatingLabelStyle: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EuphireColors.ember.withValues(alpha: 0.9),
                      height: 1.1,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: EuphireColors.ember,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Save button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: hasChanges && !_saving ? _onSave : null,
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
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                l.clientDetails_btn_save_title,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Share with client (docs/39) ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _shared,
                    onChanged: _sharing ? null : _toggleShare,
                    activeThumbColor: EuphireColors.ember,
                    title: Text(
                      l.share_session_label,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    subtitle: Text(
                      l.share_with_client_desc,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: EuphireColors.mist.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Delete option ──
                InkWell(
                  onTap: _deleteWarning,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                              Text(
                                l.clientDetails_btn_delete_session,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: EuphireColors.magma,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.clientDetails_btn_delete_session_desc,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  color: EuphireColors.magma.withValues(
                                    alpha: 0.7,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Timeline item (union of Session | PatientNote) ──────────────────

class _TimelineItem {
  final Session? session;
  final PatientNote? note;
  final int sessionNumber;

  _TimelineItem._({this.session, this.note, this.sessionNumber = 0});

  factory _TimelineItem.session(Session s, int number) =>
      _TimelineItem._(session: s, sessionNumber: number);

  factory _TimelineItem.note(PatientNote n) => _TimelineItem._(note: n);

  bool get isNote => note != null;

  DateTime get sortDate => isNote ? note!.createdAt : session!.date;
}

/// Companion-app filter semantics (client_home_screen._applyFilter):
/// empty set = show everything; otherwise an item is visible iff its
/// category chip is active. Client notes are PatientNote rows authored
/// by the PATIENT (sent from the client panel); everything else note-
/// shaped is the therapist's own (free notes + action plans).
List<_TimelineItem> _applyKartotekaFilter(
    List<_TimelineItem> items, Set<KartotekaFilter> active) {
  if (active.isEmpty) return items;
  return items.where((i) {
    if (!i.isNote) return active.contains(KartotekaFilter.sessions);
    return i.note!.isClientNote
        ? active.contains(KartotekaFilter.clientNotes)
        : active.contains(KartotekaFilter.ownNotes);
  }).toList();
}

// ─── Kartoteka filter bar ─────────────────────────────────────────────
// Visual mirror of the Companion app's _FilterBar (pill chips, single
// horizontal row), restyled with the therapist palette.

class _KartotekaFilterBar extends ConsumerWidget {
  const _KartotekaFilterBar({required this.patientId, required this.selected});
  final String patientId;
  final Set<KartotekaFilter> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final labels = {
      KartotekaFilter.sessions: l.clientDetails_filter_sessions,
      KartotekaFilter.clientNotes: l.clientDetails_filter_client_notes,
      KartotekaFilter.ownNotes: l.clientDetails_filter_own_notes,
    };
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in KartotekaFilter.values) ...[
            _KartotekaFilterChip(
              label: labels[f]!,
              active: selected.contains(f),
              onTap: () => ref
                  .read(kartotekaFiltersProvider(patientId).notifier)
                  .toggle(f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _KartotekaFilterChip extends StatelessWidget {
  const _KartotekaFilterChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? EuphireColors.frostWhite.withValues(alpha: 0.14)
          : EuphireColors.frostWhite.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? EuphireColors.frostWhite.withValues(alpha: 0.5)
                  : EuphireColors.frostWhite.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? EuphireColors.frostWhite : EuphireColors.mist,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Note Card ────────────────────────────────────────────────────────

class _NoteCard extends ConsumerWidget {
  final PatientNote note;
  final String patientId;

  const _NoteCard({required this.note, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = note.createdAt;
    final dateStr = DateFormat(
      'd MMM',
      Localizations.localeOf(context).languageCode,
    ).format(d);
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final metaStr = '$dateStr  \u2022  $timeStr';
    final l = AppLocalizations.of(context);
    final displayTitle = note.title.isNotEmpty ? note.title : l.note_untitled;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _NoteViewScreen(note: note, patientId: patientId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EuphireColors.mist.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Emoji badge ──
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: EuphireColors.ember.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(note.isClientNote ? '💬' : '📝',
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 14),
            // ── Title + preview + meta ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.frostWhite,
                          ),
                        ),
                      ),
                      // docs/39: a note the client sent from their panel.
                      if (note.isClientNote) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: note.isNewClientNote
                                ? EuphireColors.ember.withValues(alpha: 0.9)
                                : EuphireColors.aurora
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.isNewClientNote
                                ? l.note_from_client_new
                                : l.note_from_client,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: note.isNewClientNote
                                  ? EuphireColors.obsidianBlack
                                  : EuphireColors.aurora,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (note.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: EuphireColors.frostWhite.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    metaStr,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: EuphireColors.mist.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            // ── Options menu (bottom sheet) ──
            IconButton(
              onPressed: () =>
                  _showNoteOptionsSheet(context, ref, patientId, note),
              icon: Icon(
                Icons.more_vert,
                color: EuphireColors.mist.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    String patientId,
    PatientNote note,
  ) {
    final l = AppLocalizations.of(context);
    final d = note.createdAt;
    final dateStr = DateFormat(
      'd MMM yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(d);
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final displayTitle = note.title.isNotEmpty ? note.title : l.note_untitled;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──
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
                const SizedBox(height: 20),

                // ── Note header (emoji + title + date) ──
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: EuphireColors.ember.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text('📝', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: EuphireColors.frostWhite,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$dateStr  •  $timeStr',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: EuphireColors.mist.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 8),

                // ── Action: Edit (client notes are read-only) ──
                if (!note.isClientNote)
                  _NoteOptionTile(
                    icon: Icons.edit_rounded,
                    iconColor: EuphireColors.ember,
                    title: l.note_edit_label,
                    subtitle: l.clientDetails_edit_note_subtitle,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'NoteEditorScreen'),
                          builder: (_) => NoteEditorScreen(
                            patientId: patientId,
                            existingNote: note,
                          ),
                        ),
                      );
                    },
                  ),

                // ── Action: Copy ──
                _NoteOptionTile(
                  icon: Icons.copy_rounded,
                  iconColor: EuphireColors.mist,
                  title: l.clientDetails_copy_content,
                  subtitle: l.clientDetails_copy_content_desc,
                  onTap: () {
                    Navigator.pop(ctx);
                    final content = [
                      if (note.title.isNotEmpty) note.title,
                      note.text.isNotEmpty
                          ? note.text
                          : l.clientDetails_no_content,
                    ].join('\n\n');
                    Clipboard.setData(ClipboardData(text: content));
                    EuphireToast.success(
                      context,
                      message: l.common_copied_to_clipboard,
                    );
                  },
                ),

                // ── Action: Share in the client panel (docs/39) ──
                if (!note.isClientNote)
                  _NoteOptionTile(
                    icon: note.sharedWithClient
                        ? Icons.link_off_rounded
                        : Icons.ios_share_rounded,
                    iconColor: EuphireColors.ember,
                    title: note.sharedWithClient
                        ? l.unshare_with_client
                        : l.share_with_client,
                    subtitle: note.sharedWithClient
                        ? l.share_note_shared_at(
                            _formatSentDate(note.sharedWithClientAt!, context),
                          )
                        : l.share_with_client_desc,
                    trailing: note.sharedWithClient
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l.share_shared_badge,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF81C784),
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleNoteShare(context, ref, l, patientId, note);
                    },
                  ),

                // The e-mail "Wyślij do klienta" (D6 fallback) is removed
                // 2026-07-04: in-panel sharing ("Udostępnij w panelu
                // klienta") is now the content channel — the client
                // reads notes in the app, not by e-mail.

                const SizedBox(height: 4),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 4),

                // ── Action: Delete (destructive) ──
                _NoteOptionTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: EuphireColors.magma,
                  title: l.note_delete_action,
                  subtitle: l.clientDetails_delete_note_desc,
                  titleColor: EuphireColors.magma,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(context, ref, l);
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSentDate(DateTime dt, BuildContext context) {
    return DateFormat(
      'd MMM yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(dt);
  }

  /// docs/39: toggles ShareNoteWithClient, then refreshes the notes so
  /// the sheet state (shared badge) reflects the server truth.
  Future<void> _toggleNoteShare(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String patientId,
    PatientNote note,
  ) async {
    final clinical = ref.read(grpcClientsProvider).clinical;
    final notifier = ref.read(patientNotesMapProvider.notifier);
    try {
      await clinical.shareNoteWithClient(
        clinical_pb.ShareNoteWithClientRequest(
          noteId: note.id,
          shared: !note.sharedWithClient,
        ),
      );
      await notifier.refreshNotes(patientId);
      if (context.mounted) {
        EuphireToast.success(
          context,
          message: note.sharedWithClient
              ? l.share_toggled_off
              : l.share_toggled_on,
        );
      }
    } catch (_) {
      if (context.mounted) {
        EuphireToast.error(context, message: l.share_toggle_error);
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),
                Text(
                  l.note_delete_confirm,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  note.title.isNotEmpty ? note.title : note.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Text(
                          l.note_sheet_cancel,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: EuphireColors.mist,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          AppHapticFeedback.heavyImpact();
                          ref
                              .read(patientNotesMapProvider.notifier)
                              .deleteNote(patientId, note.id);
                          EuphireToast.success(
                            context,
                            message: l.note_deleted,
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EuphireColors.magma,
                          foregroundColor: EuphireColors.frostWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l.note_delete_action,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// ─── Note Option Tile (used in the note options bottom sheet) ────────

class _NoteOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NoteOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: EuphireColors.ember.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              // ── Icon circle ──
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              // ── Text ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: EuphireColors.mist.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Trailing ──
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: EuphireColors.mist.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Note Editor Screen (full page, create or edit) ──────────────────

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String patientId;
  final PatientNote? existingNote;

  /// Optional seed values (used only when [existingNote] is null), e.g. an
  /// action-plan draft from GetActionPlanDraft.
  final String? initialTitle;
  final String? initialText;

  /// When true, renders the action-plan bottom bar (Save / Save+Send) and
  /// enables the real SavePatientNote send flow.
  final bool actionPlanMode;

  /// Source session the action plan was extracted from (server metadata,
  /// stored on PatientNote.source_session_id).
  final String? sourceSessionId;

  /// Patient e-mail (PatientFile.patientEmail), when on file. Used to mask
  /// the address in the confirm sheet. Null when none is on file.
  final String? patientEmail;

  /// Whether the patient has an e-mail on file server-side. Drives the
  /// send-gate. Defaults to (patientEmail != null && non-empty) when not
  /// explicitly provided.
  final bool? patientHasEmail;

  const NoteEditorScreen({
    super.key,
    required this.patientId,
    this.existingNote,
    this.initialTitle,
    this.initialText,
    this.actionPlanMode = false,
    this.sourceSessionId,
    this.patientEmail,
    this.patientHasEmail,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late FocusNode _bodyFocus;
  bool _saved = false;
  // Tracks the server note id once it exists, so a retry (e.g. after a
  // failed e-mail send) UPDATES the same note instead of creating a
  // duplicate. Seeded from an existing note; updated from each save.
  String _noteId = '';

  bool get _isEditing => widget.existingNote != null;
  bool get _hasContent =>
      _titleCtrl.text.trim().isNotEmpty || _bodyCtrl.text.trim().isNotEmpty;
  bool get _hasChanges {
    if (!_isEditing) return _hasContent;
    return _titleCtrl.text.trim() != widget.existingNote!.title ||
        _bodyCtrl.text.trim() != widget.existingNote!.text;
  }

  @override
  void initState() {
    super.initState();
    // When creating a new note we may be seeded from an extracted draft
    // (e.g. an action plan pulled from a report); fall back to empty.
    _titleCtrl = TextEditingController(
      text: widget.existingNote?.title ?? widget.initialTitle ?? '',
    );
    _bodyCtrl = TextEditingController(
      text: widget.existingNote?.text ?? widget.initialText ?? '',
    );
    _bodyFocus = FocusNode();
    _noteId = widget.existingNote?.id ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  bool _saving = false;

  /// Persists the note via the server-backed provider (create/update),
  /// without toasting or popping. Returns false when there's nothing to
  /// save. Marks the editor as saved so the discard guard won't fire.
  Future<bool> _persist() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) return false;
    final notifier = ref.read(patientNotesMapProvider.notifier);
    if (_isEditing) {
      await notifier.updateNote(
        widget.patientId,
        widget.existingNote!.id,
        title,
        body,
      );
    } else {
      await notifier.addNote(widget.patientId, title, body);
    }
    AppHapticFeedback.mediumImpact();
    _saved = true;
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      if (!await _persist()) return;
      if (!mounted) return;
      EuphireToast.success(context, message: l.note_saved);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) EuphireToast.error(context, message: l.note_save_error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Action-plan "Zapisz i wyślij": persist the note, then POST it to the
  /// client's panel via ShareNoteWithClient (docs/39). This REPLACED the
  /// old e-mail delivery (SavePatientNote send_to_patient=true → action-
  /// plan e-mail): action plans now land in the client panel, no e-mail.
  Future<void> _saveAndSend() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final clinical = ref.read(grpcClientsProvider).clinical;
      final repo = ClinicalNotesRepository(clinical);
      // Persist first (no e-mail). The returned id is what we share.
      final resp = await repo.savePatientNote(
        widget.patientId,
        noteId: _noteId,
        title: _titleCtrl.text.trim(),
        text: _bodyCtrl.text.trim(),
        kind: widget.actionPlanMode ? NoteKind.actionPlan : NoteKind.freeNote,
        sourceSessionId: widget.sourceSessionId ?? '',
        sendToPatient: false,
      );
      _saved = true;
      if (resp.note.id.isNotEmpty) _noteId = resp.note.id;
      // Post it to the client panel. Idempotent (shared=true); the client
      // sees it live via the Firestore inbox mirror (docs/39).
      await clinical.shareNoteWithClient(
        clinical_pb.ShareNoteWithClientRequest(
          noteId: _noteId,
          shared: true,
        ),
      );
      if (mounted) {
        await ref
            .read(patientNotesMapProvider.notifier)
            .refreshNotes(widget.patientId);
      }
      if (!mounted) return;
      AppHapticFeedback.mediumImpact();
      EuphireToast.success(context, message: l.share_toggled_on);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) EuphireToast.error(context, message: l.note_save_error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_saved || !_hasChanges) return true;
    final l = AppLocalizations.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),
                Text(
                  l.note_discard_title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l.note_discard_body,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, 'discard'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Text(
                          l.note_discard_action,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: EuphireColors.mist,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx, 'save');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EuphireColors.ember,
                          foregroundColor: EuphireColors.nocturne,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l.note_discard_save,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == 'save') {
      _save();
      return false;
    }
    return result == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF071A1D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: EuphireColors.frostWhite,
            ),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            widget.actionPlanMode
                ? l.action_plan_default_title
                : (_isEditing ? l.note_edit_label : l.note_sheet_title),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: EuphireColors.frostWhite,
            ),
          ),
          centerTitle: true,
          // In action-plan mode the bottom bar carries the Save / Save+Send
          // actions, so we drop the redundant AppBar save button.
          actions: widget.actionPlanMode
              ? null
              : [
                  TextButton(
                    onPressed: _save,
                    child: Text(
                      l.note_sheet_save,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: EuphireColors.ember,
                      ),
                    ),
                  ),
                ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 375 ? 20 : 24,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // ── Title field ──
                  TextField(
                    controller: _titleCtrl,
                    // Don't autofocus when the title is prefilled (action-plan
                    // mode): a focused single-line field scrolls the cursor to
                    // the end, clipping the first char of a long title.
                    autofocus:
                        !_isEditing &&
                        (widget.initialTitle == null ||
                            widget.initialTitle!.isEmpty),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _bodyFocus.requestFocus(),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: MediaQuery.of(context).size.width < 375
                          ? 20
                          : 22,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: l.note_title_hint,
                      hintStyle: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: MediaQuery.of(context).size.width < 375
                            ? 20
                            : 22,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.mist.withValues(alpha: 0.3),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  // ── Body field ──
                  Expanded(
                    child: TextField(
                      controller: _bodyCtrl,
                      focusNode: _bodyFocus,
                      maxLines: null,
                      expands: true,
                      maxLength: 5000,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      // In action-plan mode, show a "Done" key so the user can
                      // dismiss the keyboard and reach the Save / Send buttons
                      // in the bottom bar — without this, iOS has no way to
                      // close the keyboard for a multiline + expands field.
                      textInputAction: widget.actionPlanMode
                          ? TextInputAction.done
                          : TextInputAction.newline,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        color: EuphireColors.frostWhite,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: l.note_body_hint,
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.mist.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        counterStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          color: EuphireColors.mist.withValues(alpha: 0.3),
                        ),
                      ),
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) {
                            if (currentLength < 4500) return null;
                            return Text(
                              '$currentLength/$maxLength',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: currentLength > 4800
                                    ? EuphireColors.magma.withValues(alpha: 0.8)
                                    : EuphireColors.mist.withValues(alpha: 0.4),
                              ),
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: widget.actionPlanMode
            ? _buildActionPlanBar(l)
            : null,
      ),
    );
  }

  /// Action-plan bottom bar: "Zapisz" (save only) + "Zapisz i wyślij"
  /// (primary, ember). Sits below the editor text fields.
  Widget _buildActionPlanBar(AppLocalizations l) {
    // "Zapisz i wyślij" posts the plan to the client panel (docs/39), so
    // it no longer needs a patient e-mail — enabled whenever not saving.
    final canSend = !_saving;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : _save,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Text(
                      l.action_plan_save_only,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: EuphireColors.mist,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSend ? _saveAndSend : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.ember,
                      foregroundColor: EuphireColors.nocturne,
                      disabledBackgroundColor: EuphireColors.ember.withValues(
                        alpha: 0.25,
                      ),
                      disabledForegroundColor: EuphireColors.nocturne
                          .withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l.action_plan_save_and_send,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Note View Screen (beautiful read-only presentation) ─────────────

class _NoteViewScreen extends ConsumerWidget {
  final PatientNote note;
  final String patientId;

  const _NoteViewScreen({required this.note, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final d = note.createdAt;
    final dateStr = DateFormat(
      'd MMMM yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(d);
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final displayTitle = note.title.isNotEmpty ? note.title : l.note_untitled;

    return Scaffold(
      backgroundColor: const Color(0xFF071A1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: EuphireColors.frostWhite,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Client notes are read-only for the therapist (docs/39).
          if (!note.isClientNote)
            IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: EuphireColors.ember,
                size: 22,
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'NoteEditorScreen'),
                    builder: (_) => NoteEditorScreen(
                      patientId: patientId,
                      existingNote: note,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Emoji ──
              const Text('📝', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 16),
              // ── Title ──
              Text(
                displayTitle,
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: EuphireColors.frostWhite,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              // ── Date pill ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: EuphireColors.ember.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$dateStr  •  $timeStr',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: EuphireColors.ember.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // ── Divider ──
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 28),
              // ── Body ──
              if (note.text.isNotEmpty)
                Text(
                  note.text,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                    height: 1.7,
                  ),
                )
              else
                Text(
                  l.clientDetails_no_content,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: EuphireColors.mist.withValues(alpha: 0.4),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom clipper: shallow arc at the bottom edge ─────────────────────

class _ArcBottomClipper extends CustomClipper<Path> {
  final double arcDip; // how much the center dips below the edges

  const _ArcBottomClipper({required this.arcDip});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Top edge — straight
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    // Right edge — down to the arc start point
    path.lineTo(size.width, size.height - arcDip);
    // Bottom edge — shallow arc curving down in the center
    path.quadraticBezierTo(
      size.width / 2, // control point X: center
      size.height + arcDip, // control point Y: dips below
      0, // end X: left edge
      size.height - arcDip, // end Y: same height as start
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ArcBottomClipper oldClipper) =>
      oldClipper.arcDip != arcDip;
}

class _ActiveRecordingCard extends StatelessWidget {
  final String patientId;
  final Duration duration;
  final RecordingState state;
  final VoidCallback onTap;

  const _ActiveRecordingCard({
    required this.patientId,
    required this.duration,
    required this.state,
    required this.onTap,
  });

  String _formatDuration(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = state == RecordingState.paused;
    final formattedDuration = _formatDuration(duration);
    final l = AppLocalizations.of(context);

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
                _CardPulsingDot(isRecording: state == RecordingState.recording),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaused
                            ? l.active_session_card_paused_title
                            : l.active_session_card_title,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaused
                            ? l.active_session_card_paused_subtitle
                            : l.active_session_card_subtitle,
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
                  formattedDuration,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
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

class _CardPulsingDot extends StatefulWidget {
  final bool isRecording;
  const _CardPulsingDot({required this.isRecording});

  @override
  State<_CardPulsingDot> createState() => _CardPulsingDotState();
}

class _CardPulsingDotState extends State<_CardPulsingDot>
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
  void didUpdateWidget(covariant _CardPulsingDot oldWidget) {
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
              _buildRipple(
                1.0 + (_controller.value * 2.0),
                1.0 - _controller.value,
              ),
              _buildRipple(
                1.0 + (((_controller.value + 0.5) % 1.0) * 2.0),
                1.0 - ((_controller.value + 0.5) % 1.0),
              ),
            ],
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording
                    ? EuphireColors.magma
                    : EuphireColors.mist,
                boxShadow: widget.isRecording
                    ? [
                        BoxShadow(
                          color: EuphireColors.magma.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
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
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EuphireColors.magma.withValues(alpha: opacity * 0.4),
        ),
      ),
    );
  }
}
