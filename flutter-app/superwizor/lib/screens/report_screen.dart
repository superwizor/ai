// ReportScreen — Etap 5b.
//
// 7-section accordion (D3) backed by clinical-svc.GetSessionDetails.
// The proto's `Report.content` is JSON-encoded ReportPayload from the
// LLM worker. We don't know the exact shape pre-MVP (it's wrapped
// inside `content: string`); we render each top-level Report row as
// a section, falling back to a generic display if structure differs.
//
// Risk badge + auto-expand for risk_level in {high, moderate} per
// plan v1.4 §Etap 5b.
//
// We do NOT consume reports.speaker_role_inference (per plan).
//
// Cache: SessionDetailsRepository reads from Hive first (mirroring
// TranscriptScreen — both screens share the same SessionDetailsDto
// row, so navigating between them hits the cache instead of firing
// duplicate GetSessionDetails RPCs). Background refresh on stale.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/dto/report_dto.dart';
import '../cache/dto/session_details_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import '../analytics/analytics_collector.dart';
import '../providers/grpc_provider.dart';
import '../providers/session_details_provider.dart';
import '../providers/patient_contact_provider.dart';
import '../providers/viewed_reports_provider.dart';
import '../repositories/session_details_repository.dart';
import '../theme/euphire_theme.dart';
import '../theme/markdown_quote_style.dart';
import '../utils/action_plan_extractor.dart';
import '../widgets/euphire_segmented_control.dart';
import '../widgets/euphire_toast.dart';
import '../widgets/report_rating_widget.dart';
import 'client_details_screen.dart';
import 'transcript_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ReportScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _loading = true;
  String? _error;
  SessionDetailsDto? _data;
  List<_ReportSection>? _sections;

  final ScrollController _mainScrollController = ScrollController();
  int _activeSectionIndex = 0;
  /// Który raport sesji jest oglądany.
  ///
  /// Do 24.08 ekran brał `reports.first` i dzielił go na sekcje, więc
  /// drugiego raportu nie dało się otworzyć w ogóle. Przy dual-run sesja
  /// ma dwa: produkcyjny i eksperymentalny — i użytkownik widział tylko
  /// jeden, biorąc pigułki sekcji za pigułki raportów.
  int _activeReportIndex = 0;
  String? _editedSummary;
  ScreenTracker? _screenTracker;

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onScroll);
    _mainScrollController.dispose();
    _screenTracker?.stop();
    super.dispose();
  }

  void _onScroll() {
    if (_sections == null || _sections!.isEmpty) return;

    int newActiveIndex = 0;

    if (_mainScrollController.hasClients &&
        _mainScrollController.position.pixels >=
            _mainScrollController.position.maxScrollExtent - 20) {
      newActiveIndex = _sections!.length - 1;
    } else {
      for (int i = 0; i < _sections!.length; i++) {
        final key = _sections![i].key;
        if (key.currentContext != null) {
          final RenderBox box =
              key.currentContext!.findRenderObject() as RenderBox;
          final position = box.localToGlobal(Offset.zero).dy;
          if (position <= 350) {
            newActiveIndex = i;
          }
        }
      }
    }

    if (newActiveIndex != _activeSectionIndex) {
      setState(() {
        _activeSectionIndex = newActiveIndex;
      });
      _scrollToTab(newActiveIndex);
    }
  }

  void _scrollToTab(int index) {
    if (_sections == null) return;
    final tabKey = _sections![index].tabKey;
    if (tabKey.currentContext != null) {
      Scrollable.ensureVisible(
        tabKey.currentContext!,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  Future<void> _loadInitial() async {
    // Cache-first: paint any hit immediately so navigating
    // Transcript → Report (or vice versa) doesn't fire a second
    // GetSessionDetails RPC. The TranscriptScreen-side cache is the
    // same SessionDetailsDto row, keyed by sessionId, so the hit
    // rate is effectively 100% for the common back-and-forth flow.
    final repo = await ref.read(sessionDetailsRepositoryProvider.future);
    if (repo == null) {
      // Cache layer not ready (cold start before auth resolves). Go
      // straight to network — repository will populate cache on a
      // later rebuild.
      await _refreshFromBackend(showLoaderIfEmpty: true);
      return;
    }

    final cached = await repo.getCached(widget.sessionId);
    if (cached.hasData && mounted) {
      _applyData(cached.data!);
      if (cached.isStale) {
        // Schedule a background refresh; the user keeps reading
        // the cached report while we update.
        unawaited(_refreshFromBackend(showLoaderIfEmpty: false));
      }
      return;
    }

    await _refreshFromBackend(showLoaderIfEmpty: true);
  }

  Future<void> _refreshFromBackend({required bool showLoaderIfEmpty}) async {
    try {
      if (showLoaderIfEmpty && mounted) setState(() => _loading = true);

      final repo = await ref.read(sessionDetailsRepositoryProvider.future);
      late final SessionDetailsDto fresh;
      if (repo != null) {
        fresh = await repo.refresh(widget.sessionId);
      } else {
        fresh = await _directFetchFallback();
      }

      if (!mounted) return;
      _applyData(fresh);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Direct gRPC fetch used only when the repository isn't available
  /// yet (cache still opening). Doesn't write to cache — that's the
  /// repository's job and will happen on the next provider rebuild.
  Future<SessionDetailsDto> _directFetchFallback() async {
    final clients = ref.read(grpcClientsProvider);
    final res = await clients.clinical.getSessionDetails(
      clinical_pb.GetSessionDetailsRequest(sessionId: widget.sessionId),
    );
    return SessionDetailsDto.fromProto(res);
  }

  void _applyData(SessionDetailsDto fresh) {
    setState(() {
      _data = fresh;
      // Re-derive sections on each successful fetch — a stale-then-
      // fresh refresh could change the report markdown if the user
      // re-ran analysis.
      _sections = null;
      _loading = false;
      _error = null;
    });

    // Mark the report as viewed — covers auto-navigation from
    // SessionStatusScreen (success cascade) and push notification
    // deep links, which previously skipped markViewed.
    final isRevisit =
        ref.read(viewedReportsProvider).value?.contains(widget.sessionId) ??
        false;
    ref.read(viewedReportsProvider.notifier).markViewed(widget.sessionId);

    // Telemetria czasu na ekranie celuje w raport PRODUKCYJNY i tak ma
    // zostać — `reports.first` jest nim, odkąd DTO stawia produkcyjne
    // przed eksperymentalnymi. Przełączenie na eksperyment nie ma
    // zawyżać metryki „czas nad raportem", bo mierzy ona pracę
    // kliniczną, a nie kalibrację ontologii.
    if (_screenTracker == null && fresh.reports.isNotEmpty) {
      _screenTracker = ref
          .read(analyticsCollectorProvider)
          .trackScreen(
            fresh.reports.first.id,
            widget.sessionId,
            isRevisit: isRevisit,
          );
      _screenTracker!.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    // Zywy sygnal z inboxu: raport eksperymentalny doszedl do TEJ sesji,
    // gdy ekran jest otwarty — cache wlasnie zostal uniewazniony, wiec
    // dociagamy z sieci bez czekania na ponowne wejscie.
    ref.listen<int>(sessionDetailsRevisionProvider(widget.sessionId),
        (prev, next) {
      if (prev != null && next != prev) {
        unawaited(_refreshFromBackend(showLoaderIfEmpty: false));
      }
    });
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(t.report_tab, style: theme.textTheme.titleLarge),
        // Siatka bezpieczeństwa (2026-08-24): ten ekran bywał jedynym
        // route'em po wyścigu nawigacji (auto-push z FCM x kaskada
        // pushReplacement) — wtedy domyślna strzałka wstecz znika i nie
        // ma ŻADNEJ drogi wyjścia. Gdy nie ma czego cofać, dajemy dom.
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(
                tooltip: t.session_status_back_to_records,
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'HomeScreen'),
                    builder: (_) => const HomeScreen(),
                  ),
                  (route) => false,
                ),
              ),

        actions: [
          // Rating sits to the LEFT of the icon buttons (i.e. first in the
          // actions list) — it's report-scoped UI, so it only shows once the
          // GetSessionDetails fetch has resolved a report we can target.
          // Ocena dotyczy raportu, który masz przed sobą — nie zawsze
          // pierwszego. Dla eksperymentalnego znika: nie jest materiałem
          // klinicznym, a oceny zasilają pętlę strojenia preferencji
          // raportu produkcyjnego.
          if (_data != null &&
              _data!.reports.isNotEmpty &&
              !_data!.reports[_activeReportIndex.clamp(0, _data!.reports.length - 1)]
                  .isExperimental)
            ReportRatingWidget(
              reportId: _data!
                  .reports[_activeReportIndex.clamp(0, _data!.reports.length - 1)]
                  .id,
            ),
          IconButton(
            tooltip: t.action_plan_send_button,
            icon: const Icon(Icons.outgoing_mail),
            onPressed: _data == null ? null : _onSendActionPlan,
          ),
          IconButton(
            tooltip: t.report_tooltip_copy_reports,
            icon: const Icon(Icons.copy),
            onPressed: _data == null ? null : _onCopyPressed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: EuphireSegmentedControl(
            // ignore: avoid_hardcoded_strings_in_widgets
            selected: 'report',
            // ignore: avoid_hardcoded_strings_in_widgets
            leftValue: 'transcript',
            leftLabel: t.transcript_tab,
            // ignore: avoid_hardcoded_strings_in_widgets
            rightValue: 'report',
            rightLabel: t.report_tab,
            onSelect: (v) {
              if (v == 'transcript') {
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) =>
                        TranscriptScreen(sessionId: widget.sessionId),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            },
          ),
        ),
      ),
      body: _build(t, theme),
    );
  }

  Widget _build(AppLocalizations t, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.session_load_error_header,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t.session_load_error_body,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _refreshFromBackend(showLoaderIfEmpty: true),
                child: Text(t.common_retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_data == null || _data!.reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.session_loading,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final raporty = _data!.reports;
    final indeks = _activeReportIndex.clamp(0, raporty.length - 1);
    final report = raporty[indeks];
    final payload = _ReportPayload.parse(report);

    _sections ??= _parseSections(payload.reportMarkdown, t);

    return Column(
      children: [
        // Selektor raportu STOI NAD sekcjami, bo to wybór grubszy:
        // najpierw „który raport", potem „która jego część". Pokazuje się
        // wyłącznie wtedy, gdy jest z czego wybierać — przy jednym
        // raporcie byłby szumem.
        if (raporty.length > 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              itemCount: raporty.length,
              separatorBuilder: (ctx, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final r = raporty[i];
                final aktywny = i == indeks;
                return Material(
                  color: aktywny
                      ? EuphireColors.ember.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() {
                      _activeReportIndex = i;
                      // Sekcje są cache'owane przez `??=` i należą do
                      // KONKRETNEGO raportu — bez wyzerowania nowy raport
                      // wyświetliłby się z podziałem poprzedniego.
                      _sections = null;
                      _activeSectionIndex = 0;
                    }),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (r.isExperimental) ...[
                            Icon(
                              Icons.science_outlined,
                              size: 15,
                              color: aktywny
                                  ? EuphireColors.ember
                                  : EuphireColors.frostWhite.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              r.isExperimental
                                  ? t.report_tab_experimental
                                  : t.report_tab_production,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: aktywny
                                    ? EuphireColors.ember
                                    : EuphireColors.frostWhite,
                                fontWeight:
                                    aktywny ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_sections!.length > 1)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _sections!.length,
              separatorBuilder: (ctx, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final s = _sections![i];
                final isActive = i == _activeSectionIndex;
                return Material(
                  key: s.tabKey,
                  color: isActive
                      ? EuphireColors.ember.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      if (s.key.currentContext != null) {
                        Scrollable.ensureVisible(
                          s.key.currentContext!,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text(
                        s.title,
                        style: TextStyle(
                          color: isActive
                              ? EuphireColors.ember
                              : EuphireColors.frostWhite,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _mainScrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCard(report, payload),
                const SizedBox(height: 16),
                ..._sections!.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  // First section (right after Brief) gets a slightly darker bg
                  final isFirstSection = idx == 0;
                  return GestureDetector(
                    key: s.key,
                    onLongPress: () {
                      AppHapticFeedback.selectionClick();
                      _showSectionOptions(context, s, idx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isFirstSection
                              ? Colors.white.withValues(alpha: 0.035)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: isFirstSection
                              ? Border(
                                  left: BorderSide(
                                    color: EuphireColors.mist.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 2,
                                  ),
                                )
                              : null,
                        ),
                        child: MarkdownBody(
                          data: s.content,
                          styleSheet: _reportMarkdownStyle(),
                        ),
                      ),
                    ),
                  );
                }),
                // AI-transparency footer (AI Act): stays pinned under the
                // report content on every generated report.
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 16,
                        color: EuphireColors.frostWhite.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.report_ai_disclaimer,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                            color: EuphireColors.frostWhite.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Extracts the action plan from the report the therapist is currently
  /// viewing (client-side heuristic — see action_plan_extractor.dart) and
  /// opens the note editor prefilled, in action-plan mode (Save /
  /// Save+Send). The send itself is a real SavePatientNote call from the
  /// editor. The patient e-mail availability comes from the cached
  /// patient list.
  ///
  /// We deliberately run extraction client-side rather than via the
  /// server-side GetActionPlanDraft RPC: it works on the exact report
  /// markdown already loaded on this screen (no round-trip / decrypt) and
  /// keeps the heuristic in one place we can iterate on quickly.
  void _onSendActionPlan() {
    final data = _data;
    if (data == null || data.reports.isEmpty) return;
    final l = AppLocalizations.of(context);
    final patientFileId = data.session.patientFileId;

    final reportMarkdown = _ReportPayload.parse(
      data.reports.first,
    ).reportMarkdown;
    final draft = extractActionPlan(
      reportMarkdown,
      sessionDate: data.session.createdAt,
      titlePrefix: l.action_plan_default_title,
    );
    final title = draft.title;
    final text = draft.text;
    final patientEmail = ref.read(patientEmailProvider(patientFileId));
    final patientHasEmail = patientEmail != null && patientEmail.isNotEmpty;

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'NoteEditorScreen'),
        builder: (_) => NoteEditorScreen(
          patientId: patientFileId,
          actionPlanMode: true,
          sourceSessionId: widget.sessionId,
          initialTitle: title,
          initialText: text,
          patientEmail: patientEmail,
          patientHasEmail: patientHasEmail,
        ),
      ),
    );
  }

  Future<void> _onCopyPressed() async {
    final data = _data;
    if (data == null || data.reports.isEmpty) return;
    final t = AppLocalizations.of(context);

    final StringBuffer buffer = StringBuffer();
    for (final report in data.reports) {
      buffer.writeln(
        '=== ${report.title.isNotEmpty ? report.title : t.report_tab} ===',
      );

      final payload = _ReportPayload.parse(report);
      final summaryText = _editedSummary ?? payload.summary;
      if (summaryText != null && summaryText.isNotEmpty) {
        buffer.writeln(
          '\n${t.report_section_summary.toUpperCase()}:\n$summaryText',
        );
      }

      if (payload.reportMarkdown.isNotEmpty) {
        // Include edited sections if available
        if (_sections != null && _sections!.isNotEmpty) {
          buffer.writeln('\n${t.report_tab.toUpperCase()}:');
          for (final section in _sections!) {
            buffer.writeln('\n${section.content}');
          }
        } else {
          buffer.writeln(
            '\n${t.report_tab.toUpperCase()}:\n${payload.reportMarkdown}',
          );
        }
      }

      buffer.writeln('\n');
    }

    // AI-transparency (AI Act): the disclaimer travels with every copy of
    // the report that leaves the app.
    buffer.writeln(t.report_ai_disclaimer);

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) {
      EuphireToast.success(context, message: t.report_toast_reports_copied);
    }
  }

  // ── Summary card with long-press editing ──

  Widget _buildSummaryCard(ReportDto report, _ReportPayload payload) {
    final summaryText =
        _editedSummary ?? payload.summary ?? report.summaryShort;
    final isEdited = _editedSummary != null;

    return GestureDetector(
      onLongPress: () {
        AppHapticFeedback.selectionClick();
        _showSummaryOptions(context, payload, report);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF041416),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: EuphireColors.ember.withValues(alpha: 0.6),
              width: 3,
            ),
            top: isEdited
                ? BorderSide(
                    color: EuphireColors.ember.withValues(alpha: 0.3),
                    width: 1,
                  )
                : BorderSide.none,
            right: isEdited
                ? BorderSide(
                    color: EuphireColors.ember.withValues(alpha: 0.3),
                    width: 1,
                  )
                : BorderSide.none,
            bottom: isEdited
                ? BorderSide(
                    color: EuphireColors.ember.withValues(alpha: 0.3),
                    width: 1,
                  )
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.title.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: EuphireColors.ember.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                  ),
                  if (isEdited)
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: EuphireColors.ember.withValues(alpha: 0.5),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              summaryText,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                height: 1.7,
                color: EuphireColors.frostWhite.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSummaryOptions(
    BuildContext context,
    _ReportPayload payload,
    ReportDto report,
  ) {
    final summaryText =
        _editedSummary ?? payload.summary ?? report.summaryShort;
    final t = AppLocalizations.of(context);

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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  t.report_section_summary,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _OptionTile(
                  icon: Icons.copy_rounded,
                  label: t.report_btn_copy_summary,
                  subtitle: t.report_copy_desc,
                  color: EuphireColors.ember,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: summaryText));
                    Navigator.pop(ctx);
                    EuphireToast.success(
                      context,
                      message: t.report_toast_summary_copied,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _OptionTile(
                  icon: Icons.edit_note_rounded,
                  label: t.report_btn_edit_summary,
                  subtitle: t.report_edit_summary_desc,
                  color: const Color(0xFF5EEDCC),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditSummarySheet(context, summaryText);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSummarySheet(BuildContext context, String currentText) {
    final controller = TextEditingController(text: currentText);
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A2326),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF5EEDCC,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF5EEDCC),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.report_edit_summary_title,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: EuphireColors.frostWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.report_section_summary,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    color: EuphireColors.mist.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                ),
                // ── Text editor ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        height: 1.7,
                        color: EuphireColors.frostWhite,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: t.report_edit_summary_hint,
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.mist.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Actions ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Row(
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
                            t.common_cancel,
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
                            final newContent = controller.text;
                            setState(() {
                              _editedSummary = newContent;
                            });
                            Navigator.pop(ctx);
                            EuphireToast.success(
                              context,
                              message: t.report_toast_summary_updated,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5EEDCC),
                            foregroundColor: EuphireColors.obsidianBlack,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            t.editPatient_save_primary,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  // ── Shared MarkdownStyleSheet ──

  MarkdownStyleSheet _reportMarkdownStyle() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        height: 1.7,
        color: EuphireColors.frostWhite,
      ),
      h1: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: EuphireColors.frostWhite,
        height: 1.4,
      ),
      h2: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: EuphireColors.frostWhite,
        height: 1.4,
      ),
      h3: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: EuphireColors.frostWhite,
        height: 1.4,
      ),
      strong: const TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w700,
        color: EuphireColors.frostWhite,
      ),
      em: TextStyle(
        fontStyle: FontStyle.italic,
        color: EuphireColors.frostWhite.withValues(alpha: 0.9),
      ),
      listBullet: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        color: EuphireColors.ember.withValues(alpha: 0.9),
        fontWeight: FontWeight.w700,
      ),
      listIndent: 14,
      listBulletPadding: const EdgeInsets.only(right: 6),
      blockSpacing: 10,
      // Cytat: wspolny styl z theme/markdown_quote_style.dart. Ten ekran
      // byl jego zrodlem — zapis rozmowy z AI renderowal cytaty domyslnym
      // stylem flutter_markdown (jasny blok w ciemnym motywie), wiec
      // wartosci przeniesiono do wspolnego miejsca zamiast kopiowac.
      blockquote: kQuoteTextStyle,
      blockquoteDecoration: kQuoteDecoration,
      blockquotePadding: kQuotePadding,
    );
  }

  // ── Long-press options for a report section ──

  void _showSectionOptions(
    BuildContext context,
    _ReportSection section,
    int index,
  ) {
    final t = AppLocalizations.of(context);
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
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Header
                Text(
                  section.title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Copy
                _OptionTile(
                  icon: Icons.copy_rounded,
                  label: t.report_btn_copy_section,
                  subtitle: t.report_copy_desc,
                  color: EuphireColors.ember,
                  onTap: () {
                    // Strip markdown headers for cleaner clipboard
                    final clean = section.content.replaceAll(
                      RegExp(r'^#+\s+', multiLine: true),
                      '',
                    );
                    Clipboard.setData(ClipboardData(text: clean));
                    Navigator.pop(ctx);
                    EuphireToast.success(
                      context,
                      message: t.report_toast_section_copied,
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Edit
                _OptionTile(
                  icon: Icons.edit_note_rounded,
                  label: t.report_btn_edit_section,
                  subtitle: t.report_edit_section_desc,
                  color: const Color(0xFF5EEDCC),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditSheet(context, section, index);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit bottom sheet for a report section ──

  void _showEditSheet(BuildContext context, _ReportSection section, int index) {
    final controller = TextEditingController(text: section.content);
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A2326),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF5EEDCC,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF5EEDCC),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.report_edit_section_title,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: EuphireColors.frostWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  section.title,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    color: EuphireColors.mist.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                ),
                // ── Text editor ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        height: 1.7,
                        color: EuphireColors.frostWhite,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: t.report_edit_section_hint,
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.mist.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Actions ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Row(
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
                            t.common_cancel,
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
                            final newContent = controller.text;
                            if (newContent != section.content) {
                              setState(() {
                                _sections![index].content = newContent;
                              });
                            }
                            Navigator.pop(ctx);
                            EuphireToast.success(
                              context,
                              message: t.report_toast_section_updated,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5EEDCC),
                            foregroundColor: EuphireColors.obsidianBlack,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            t.editPatient_save_primary,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
        );
      },
    );
  }
}

// ── Option tile helper for section bottom sheet ──

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payload parsing
// ---------------------------------------------------------------------------

class _ReportPayload {
  final String? summary;
  final String reportMarkdown;

  const _ReportPayload({this.summary, required this.reportMarkdown});

  static _ReportPayload empty() => const _ReportPayload(reportMarkdown: '');

  static _ReportPayload parse(ReportDto report) {
    if (report.content.isEmpty) {
      return empty();
    }
    try {
      final json = jsonDecode(report.content) as Map<String, dynamic>;
      final rawMd = (json['report_markdown'] ?? '').toString();
      // Pipeline: terminate blockquotes first (fixes white-box leak),
      // then separate bold-labeled continuation paragraphs onto their
      // own lines (fixes the run-together "Analiza w Modelu Równowagi"
      // sub-label problem). Order matters — blockquote termination
      // adds blank lines that the label separator relies on as
      // already-blank "prev" lines (idempotency).
      final cleaned = _separateBoldLabels(_terminateBlockquotes(rawMd));
      return _ReportPayload(
        summary: json['summary_short'] as String?,
        reportMarkdown: cleaned,
      );
    } catch (_) {
      return empty();
    }
  }
}

/// flutter_markdown follows CommonMark's "lazy continuation" rule: a
/// `> quote` line followed by an indented continuation line without
/// `>` absorbs that continuation into the blockquote. Inside bullet
/// items (which the LLM produces with structure
///
///   *   **Opis sytuacji i cytat:** prose.
///       > "transcript quote"
///       **Analiza...** more prose...
///
/// ) this means *every paragraph after the quote* inherits the
/// blockquote decoration — looks like a runaway white box swallowing
/// the rest of the bullet. The minimal fix: terminate the blockquote
/// with an explicit blank line so the parser closes it before the
/// next paragraph. Idempotent — re-applying the transform to already-
/// fixed markdown produces no further changes.
String _terminateBlockquotes(String md) {
  final lines = md.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    out.add(lines[i]);
    final trimmed = lines[i].trimLeft();
    final isBlockquote = trimmed.startsWith('>');
    if (!isBlockquote || i + 1 >= lines.length) continue;
    final next = lines[i + 1];
    final nextTrim = next.trimLeft();
    final nextIsBlockquote = nextTrim.startsWith('>');
    final nextIsBlank = next.trim().isEmpty;
    // Only insert a blank line if the next line is neither another
    // blockquote line (multi-line quote) nor already blank.
    if (!nextIsBlockquote && !nextIsBlank) {
      out.add('');
    }
  }
  return out.join('\n');
}

/// The LLM emits "sub-labeled" paragraphs inside bullet items like:
///
///   *   **Opis sytuacji i cytat:** prose.
///       **Analiza w Modelu Równowagi:** more prose.
///       **Identyfikacja potencjalności:** more prose.
///       **Pozytywna funkcja – Positum:** more prose.
///       **Sygnały niewerbalne:** more prose.
///
/// CommonMark merges consecutive non-blank indented lines into a
/// single paragraph, so all five labels render run-together inline.
/// Fix: inject a blank line before any indented line that begins with
/// a bold label terminated by `:**` — except when the previous line
/// is already blank (idempotency).
///
/// We deliberately require leading whitespace in the regex so this
/// only fires on *continuation* lines inside list items; the first
/// label (which lives on the bullet line itself, prefixed by `*   `
/// or `1. `) is left alone.
String _separateBoldLabels(String md) {
  // Matches an indented line whose first non-whitespace token is a
  // bold label like `**Anything goes here:**` — must end with the
  // ":**" pattern to avoid grabbing every bold-prefixed paragraph.
  final boldLabelLine = RegExp(r'^\s+\*\*[^*\n]+:\*\*');
  final lines = md.split('\n');
  final out = <String>[];
  for (final line in lines) {
    if (boldLabelLine.hasMatch(line)) {
      final prev = out.isEmpty ? '' : out.last;
      if (prev.trim().isNotEmpty) {
        out.add('');
      }
    }
    out.add(line);
  }
  return out.join('\n');
}

class _ReportSection {
  final String title;
  String content;
  final GlobalKey key;
  final GlobalKey tabKey;
  _ReportSection({
    required this.title,
    required this.content,
    required this.key,
    required this.tabKey,
  });
}

List<_ReportSection> _parseSections(String md, AppLocalizations t) {
  final lines = md.split('\n');

  // Ograniczamy parsowanie do nagłówków poziomu 1 i 2, o ile takie występują.
  // Zapobiega to łapaniu potnagłówków (###) wygenerowanych przez LLM jako osobne zakładki.
  bool hasLevel1or2 = lines.any((l) => RegExp(r'^#{1,2}\s').hasMatch(l));
  final headerRegex = hasLevel1or2
      ? RegExp(r'^#{1,2}\s+(.*)')
      : RegExp(r'^#+\s+(.*)');

  if (!lines.any((l) => headerRegex.hasMatch(l))) {
    return [
      _ReportSection(
        title: t.report_tab,
        content: md,
        key: GlobalKey(),
        tabKey: GlobalKey(),
      ),
    ];
  }

  final sections = <_ReportSection>[];
  String currentTitle = t.report_intro_title;
  StringBuffer currentContent = StringBuffer();

  for (final line in lines) {
    final match = headerRegex.firstMatch(line);
    if (match != null) {
      if (currentContent.toString().trim().isNotEmpty) {
        sections.add(
          _ReportSection(
            title: currentTitle,
            content: currentContent.toString().trim(),
            key: GlobalKey(),
            tabKey: GlobalKey(),
          ),
        );
      }
      currentTitle = match.group(1)!.replaceAll(RegExp(r'\*'), '').trim();
      currentContent = StringBuffer();
      currentContent.writeln(line);
    } else {
      currentContent.writeln(line);
    }
  }
  if (currentContent.toString().trim().isNotEmpty) {
    sections.add(
      _ReportSection(
        title: currentTitle,
        content: currentContent.toString().trim(),
        key: GlobalKey(),
        tabKey: GlobalKey(),
      ),
    );
  }

  return sections;
}
