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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/dto/report_dto.dart';
import '../cache/dto/session_details_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../repositories/session_details_repository.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_segmented_control.dart';
import '../widgets/report_rating_widget.dart';
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
    super.dispose();
  }

  void _onScroll() {
    if (_sections == null || _sections!.isEmpty) return;

    int newActiveIndex = 0;

    if (_mainScrollController.hasClients &&
        _mainScrollController.position.pixels >= _mainScrollController.position.maxScrollExtent - 20) {
      newActiveIndex = _sections!.length - 1;
    } else {
      for (int i = 0; i < _sections!.length; i++) {
        final key = _sections![i].key;
        if (key.currentContext != null) {
          final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.report_tab, style: theme.textTheme.titleLarge),
        actions: [
          // Rating sits to the LEFT of Copy (i.e. first in the actions
          // list) — it's report-scoped UI, so it only shows once the
          // GetSessionDetails fetch has resolved a report we can target.
          if (_data != null && _data!.reports.isNotEmpty)
            ReportRatingWidget(reportId: _data!.reports.first.id),
          IconButton(
            tooltip: 'Skopiuj raporty',
            icon: const Icon(Icons.copy),
            onPressed: _data == null ? null : _onCopyPressed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: EuphireSegmentedControl(
            selected: 'report',
            leftValue: 'transcript',
            leftLabel: t.transcript_tab,
            rightValue: 'report',
            rightLabel: t.report_tab,
            onSelect: (v) {
              if (v == 'transcript') {
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) => TranscriptScreen(sessionId: widget.sessionId),
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
              Text(t.session_load_error_header,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(t.session_load_error_body,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => _refreshFromBackend(showLoaderIfEmpty: true),
                  child: Text(t.common_retry)),
            ],
          ),
        ),
      );
    }
    if (_data == null || _data!.reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.session_loading,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center),
        ),
      );
    }

    final report = _data!.reports.first;
    final payload = _ReportPayload.parse(report);
    
    _sections ??= _parseSections(payload.reportMarkdown);

    return Column(
      children: [
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
                          color: isActive ? EuphireColors.ember : EuphireColors.frostWhite,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
                _SummaryCard(report: report, payload: payload),
                const SizedBox(height: 16),
                ..._sections!.map((s) => Padding(
                  key: s.key,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: MarkdownBody(
                      data: s.content,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyLarge,
                        h1: theme.textTheme.headlineLarge,
                        h2: theme.textTheme.headlineMedium,
                        h3: theme.textTheme.headlineSmall,
                        listBullet: theme.textTheme.bodyLarge,
                        // Style transcript quotes (the LLM wraps them in
                        // `> ...` blockquotes per the call-2 prompt).
                        // Default flutter_markdown gives blockquotes a
                        // white background which looks broken on our
                        // dark theme — restyle to match the surrounding
                        // card with an ember accent bar on the left.
                        blockquote: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border(
                            left: BorderSide(
                              color: EuphireColors.ember.withValues(alpha: 0.7),
                              width: 3,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onCopyPressed() async {
    final data = _data;
    if (data == null || data.reports.isEmpty) return;
    
    final StringBuffer buffer = StringBuffer();
    for (final report in data.reports) {
      buffer.writeln('=== ${report.title.isNotEmpty ? report.title : "Raport"} ===');
      
      final payload = _ReportPayload.parse(report);
      if (payload.summary != null && payload.summary!.isNotEmpty) {
        buffer.writeln('\nPODSUMOWANIE:\n${payload.summary}');
      }
      
      if (payload.reportMarkdown.isNotEmpty) {
        buffer.writeln('\nRAPORT KLINICZNY:\n${payload.reportMarkdown}');
      }
      
      buffer.writeln('\n');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skopiowano raporty do schowka.')),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final ReportDto report;
  final _ReportPayload payload;

  const _SummaryCard({required this.report, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.title.isNotEmpty)
            Text(report.title, style: theme.textTheme.headlineMedium),
          if (report.title.isNotEmpty) const SizedBox(height: 8),
          Text(
            payload.summary ?? report.summaryShort,
            style: theme.textTheme.bodyLarge,
          ),

        ],
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

  const _ReportPayload({
    this.summary,
    required this.reportMarkdown,
  });

  static _ReportPayload empty() => const _ReportPayload(
        reportMarkdown: '',
      );

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
  final String content;
  final GlobalKey key;
  final GlobalKey tabKey;
  _ReportSection({
    required this.title, 
    required this.content, 
    required this.key, 
    required this.tabKey,
  });
}

List<_ReportSection> _parseSections(String md) {
  final headerRegex = RegExp(r'^#+\s+(.*)');
  if (!md.split('\n').any((l) => headerRegex.hasMatch(l))) {
    return [_ReportSection(title: 'Raport', content: md, key: GlobalKey(), tabKey: GlobalKey())];
  }
  
  final lines = md.split('\n');
  final sections = <_ReportSection>[];
  String currentTitle = 'Wstęp';
  StringBuffer currentContent = StringBuffer();
  
  for (final line in lines) {
    final match = headerRegex.firstMatch(line);
    if (match != null) {
      if (currentContent.toString().trim().isNotEmpty) {
         sections.add(_ReportSection(
           title: currentTitle, 
           content: currentContent.toString().trim(), 
           key: GlobalKey(),
           tabKey: GlobalKey()
         ));
      }
      currentTitle = match.group(1)!.replaceAll(RegExp(r'\*'), '').trim();
      currentContent = StringBuffer();
      currentContent.writeln(line);
    } else {
      currentContent.writeln(line);
    }
  }
  if (currentContent.toString().trim().isNotEmpty) {
    sections.add(_ReportSection(
      title: currentTitle, 
      content: currentContent.toString().trim(), 
      key: GlobalKey(),
      tabKey: GlobalKey()
    ));
  }
  
  return sections;
}
