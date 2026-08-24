// ignore_for_file: avoid_hardcoded_strings_in_widgets

// TranscriptScreen — Etap 5a.
//
// Layout:
//   [AppBar with toggle Transcript/Report]
//   [Audio player (sticky)]
//   [Filter chips per speaker]
//   [Search box]
//   [Segments list — chronological, NOT chat bubbles]
//
// Sources:
//   - Transcript + speaker labels: clinical-svc.GetSessionDetails
//     (segments are pre-labelled by the post-processor; we never
//     consume reports.speaker_role_inference)
//   - Audio file: signed download URL from clinical-svc (TBD field;
//     for MVP we wire to GetSessionDetails.session.audioUploadId
//     resolution as a follow-up; playback gracefully degrades to
//     "no audio" if the URL isn't available)
//
// Cache: SessionDetailsRepository reads from Hive first; gRPC fetch
// happens in the background on stale hits.
// PDF export: Etap 5a.8 with PHI confirmation sheet (D2 — in MVP).
// Security: FLAG_SECURE not yet wired (flutter_windowmanager isn't in
// deps; can be added when iOS detection is ready). The Scaffold
// `secure` flag below is a placeholder for that future hook.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/haptics.dart';
import '../utils/transcript_fillers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fixnum/fixnum.dart';

import '../cache/dto/session_details_dto.dart';
import '../cache/dto/transcript_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import '../providers/grpc_provider.dart';
import '../providers/viewed_reports_provider.dart';
import '../repositories/session_details_repository.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_segmented_control.dart';
import '../widgets/euphire_toast.dart';
import 'report_screen.dart';

class TranscriptScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const TranscriptScreen({super.key, required this.sessionId});

  @override
  ConsumerState<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends ConsumerState<TranscriptScreen> {
  SessionDetailsDto? _data;
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  String _search = '';
  bool _removeFillers = false;
  Duration _playbackPosition = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  late final AudioPlayer _player;
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  final Map<int, GlobalKey> _tileKeys = {};
  int? _highlightedIndex;
  Timer? _highlightTimer;
  String? _lastSearchQuery;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _loadInitial();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  GlobalKey _getKeyForIndex(int index) {
    return _tileKeys.putIfAbsent(index, () => GlobalKey());
  }

  int _findOriginalIndex(SpeakerTurnDto segment) {
    final data = _data;
    if (data == null) return -1;
    return data.transcript.turns.indexWhere((t) => t.startOffsetMs == segment.startOffsetMs);
  }

  void _scrollToSegment(SpeakerTurnDto segment) {
    final index = _findOriginalIndex(segment);
    debugPrint('[TranscriptScreen] _scrollToSegment: target index in full list = $index');
    if (index == -1) {
      debugPrint('[TranscriptScreen] Warning: Segment index not found in full list.');
      return;
    }

    debugPrint('[TranscriptScreen] Clearing search text and filter...');
    final lastSearch = _search;
    _searchController.clear();
    
    _highlightTimer?.cancel();
    setState(() {
      _search = '';
      _filter = 'all';
      _highlightedIndex = index;
      _lastSearchQuery = lastSearch;
    });

    // Highlight is active for 5.0 seconds (user requested it to stay longer)
    _highlightTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() {
          _highlightedIndex = null;
          _lastSearchQuery = null;
        });
      }
    });

    debugPrint('[TranscriptScreen] Scheduling post-frame scroll...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        debugPrint('[TranscriptScreen] Error: _scrollController has no clients.');
        return;
      }

      final key = _getKeyForIndex(index);
      final context = key.currentContext;
      if (context != null) {
        debugPrint('[TranscriptScreen] Context found, animating smooth scroll...');
        Scrollable.ensureVisible(
          context,
          alignment: 0.2,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
        debugPrint('[TranscriptScreen] ensureVisible animation triggered.');
      } else {
        debugPrint('[TranscriptScreen] Warning: context for index $index is null.');
      }
    });
  }

  Future<void> _loadInitial() async {
    // Cache-first: paint any hit immediately so the screen is never
    // blank during the network refresh. The repository handles soft
    // TTL — we just respect whatever it hands us and trigger a
    // background refresh if it flags isStale.
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
        // the cached transcript while we update.
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
        // Last-resort fallback — repo isn't available (rare; usually
        // means we're racing the cache-open on cold start). Bypass
        // the cache; the next rebuild will populate it.
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
      _loading = false;
      _error = null;
    });
    // Mark the report as viewed — covers auto-navigation from
    // SessionStatusScreen (success cascade) and push notification
    // deep links, which previously skipped markViewed.
    ref.read(viewedReportsProvider.notifier).markViewed(widget.sessionId);
  }

  SpeakerTurnDto? get _currentlyPlayingSegment {
    final data = _data;
    if (data == null) return null;
    final ms = _playbackPosition.inMilliseconds;
    for (final s in data.transcript.turns) {
      if (ms >= s.startOffsetMs && ms < s.endOffsetMs) return s;
    }
    return null;
  }

  List<SpeakerTurnDto> get _visibleSegments {
    final data = _data;
    if (data == null) return const [];
    final q = _search.toLowerCase();
    return data.transcript.turns.where((s) {
      if (_filter != 'all' && s.speakerTag.toString() != _filter) return false;
      if (q.isNotEmpty && !s.text.toLowerCase().contains(q)) return false;
      return true;
    }).map((s) {
      if (!_removeFillers) return s;
      // Logika mieszka w utils/transcript_fillers.dart, żeby dało się ją
      // przetestować — tu była nietestowalna i przepuściła błąd z $1.
      final newText = stripFillers(s.text);
      return SpeakerTurnDto(
        speakerTag: s.speakerTag,
        speakerLabel: s.speakerLabel,
        startOffsetMs: s.startOffsetMs,
        endOffsetMs: s.endOffsetMs,
        text: newText,
        segmentCount: s.segmentCount,
        confidenceAvg: s.confidenceAvg,
      );
    }).toList(growable: false);
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
        title: Text(t.transcript_tab, style: theme.textTheme.titleLarge),
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
          IconButton(
            tooltip: t.sessionDetails_copy_transcript,
            icon: const Icon(Icons.content_copy_rounded),
            onPressed: _data == null ? null : _onCopyPressed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: EuphireSegmentedControl(
            selected: 'transcript',
            leftValue: 'transcript',
            leftLabel: t.transcript_tab,
            rightValue: 'report',
            rightLabel: t.report_tab,
            onSelect: (v) {
              if (v == 'report') {
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) => ReportScreen(sessionId: widget.sessionId),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            },
          ),
        ),
      ),
      body: _buildBody(t, theme),
    );
  }

  Widget _buildBody(AppLocalizations t, ThemeData theme) {
    if (_loading && _data == null) return _buildLoading();
    if (_error != null && _data == null) return _buildError(t);
    final data = _data!;
    if (data.transcript.turns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.session_loading,
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ),
      );
    }
    return SelectionArea(
      child: CustomScrollView(
        controller: _scrollController,
        cacheExtent: _search.isNotEmpty || _highlightedIndex != null ? 99999.0 : null,
        slivers: [
          SliverToBoxAdapter(
            child: SelectionContainer.disabled(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildFilterRow(t, data),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final segment = _visibleSegments[i];
                  final originalIndex = _findOriginalIndex(segment);
                  final isTileHighlighted = _highlightedIndex == originalIndex;
                  return _SegmentTile(
                    key: originalIndex != -1 ? _getKeyForIndex(originalIndex) : null,
                    segment: segment,
                    isPlaying: _currentlyPlayingSegment?.startOffsetMs ==
                        segment.startOffsetMs,
                    search: isTileHighlighted ? (_search.isNotEmpty ? _search : (_lastSearchQuery ?? '')) : _search,
                    isHighlighted: isTileHighlighted,
                    onTap: () => _onSegmentTap(segment),
                    onLongPress: (s) => _showSegmentOptions(s),
                    isLast: i == _visibleSegments.length - 1,
                  );
                },
                childCount: _visibleSegments.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (ctx, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, _) => Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.session_load_error_header,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(t.session_load_error_body,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
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

  Widget _buildFilterRow(AppLocalizations t, SessionDetailsDto data) {
    final filters = <_FilterOption>[
      _FilterOption(value: 'all', label: t.transcript_filter_all),
      ...data.session.speakerLabelMapping.entries
          .map((e) => _FilterOption(value: e.key, label: e.value)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: EuphireColors.nocturne,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.transcript_search_hint,
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: EuphireColors.frostWhite.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: EuphireColors.frostWhite.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: EuphireColors.frostWhite,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (_search.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: EuphireColors.frostWhite.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.transcript_search_helper_hint,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: EuphireColors.frostWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (ctx, i) {
                final f = filters[i];
                final selected = _filter == f.value;
                return GestureDetector(
                  onTap: () {
                    AppHapticFeedback.selectionClick();
                    setState(() => _filter = f.value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: selected ? 20 : 24,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? EuphireColors.ember
                          : EuphireColors.nocturne,
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? null
                          : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_rounded, size: 14, color: EuphireColors.obsidianBlack),
                          ),
                        Text(
                          f.label,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            color: selected ? EuphireColors.obsidianBlack : EuphireColors.frostWhite.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (ctx, _) => const SizedBox(width: 8),
              itemCount: filters.length,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              t.transcript_remove_fillers,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                color: EuphireColors.frostWhite.withValues(alpha: 0.8),
              ),
            ),
            value: _removeFillers,
            onChanged: (val) {
              setState(() {
                _removeFillers = val;
              });
            },
            activeThumbColor: EuphireColors.ember,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Future<void> _onSegmentTap(SpeakerTurnDto s) async {
    debugPrint('[TranscriptScreen] Tap on segment: ${s.startOffsetMs} ms, text: "${s.text}"');
    
    // Start audio playback asynchronously without blocking UI navigation
    unawaited(() async {
      try {
        debugPrint('[TranscriptScreen] Seeking player to ${s.startOffsetMs} ms...');
        await _player.seek(Duration(milliseconds: s.startOffsetMs));
        debugPrint('[TranscriptScreen] Resuming player...');
        await _player.resume();
        debugPrint('[TranscriptScreen] Player resumed successfully.');
      } catch (e, stack) {
        debugPrint('[TranscriptScreen] Audio playback failed/no source (expected locally): $e\n$stack');
      }
    }());

    if (_search.isNotEmpty) {
      debugPrint('[TranscriptScreen] Search is active ("$_search"), starting scroll navigation...');
      _scrollToSegment(s);
    } else {
      debugPrint('[TranscriptScreen] Search is empty, not scrolling.');
    }
  }



  Future<void> _onCopyPressed() async {
    final data = _data;
    if (data == null) return;
    
    final t = AppLocalizations.of(context);
    final StringBuffer buffer = StringBuffer();
    for (final s in data.transcript.turns) {
      final speaker = s.speakerLabel.isNotEmpty ? s.speakerLabel : t.transcript_default_speaker_label;
      buffer.writeln('$speaker: ${s.text}');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      EuphireToast.success(context, message: t.sessionDetails_toast_transcript_copied);
    }
  }

  void _showSegmentOptions(SpeakerTurnDto segment) {
    final t = AppLocalizations.of(context);
    showEuphireBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: EuphireColors.mist.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Centered Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: EuphireColors.ember,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Opcje wypowiedzi",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: EuphireColors.frostWhite,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Wybierz czynność dla zaznaczonego bloku tekstu.",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: EuphireColors.mist.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Copy Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.white.withValues(alpha: 0.02),
                leading: const Icon(Icons.copy_rounded, color: EuphireColors.frostWhite),
                title: Text(
                  t.transcript_actions_copy,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: segment.text));
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
              
              // Copy with Time Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.white.withValues(alpha: 0.02),
                leading: const Icon(Icons.access_time_rounded, color: EuphireColors.frostWhite),
                title: Text(
                  t.transcript_actions_copy_with_timestamp,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: '[${_formatRange(segment)}] ${segment.text}',
                  ));
                  Navigator.of(ctx).pop();
                },
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              
              // Edit Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: EuphireColors.ember.withValues(alpha: 0.2)),
                ),
                tileColor: EuphireColors.ember.withValues(alpha: 0.03),
                leading: const Icon(Icons.edit_note_rounded, color: EuphireColors.ember),
                title: const Text(
                  "Edytuj treść i mówcę",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: EuphireColors.ember,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showEditSegmentSheet(segment);
                },
              ),
              const SizedBox(height: 8),
              
              // Split Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: EuphireColors.ember.withValues(alpha: 0.2)),
                ),
                tileColor: EuphireColors.ember.withValues(alpha: 0.03),
                leading: const Icon(Icons.call_split_rounded, color: EuphireColors.ember),
                title: const Text(
                  "Podziel wypowiedź",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: EuphireColors.ember,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showSplitSegmentSheet(segment);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSegmentSheet(SpeakerTurnDto segment) {
    final textController = TextEditingController(text: segment.text);
    int selectedSpeakerTag = segment.speakerTag;

    final turns = _data?.transcript.turns ?? [];
    final speakers = <int, String>{};
    for (final t in turns) {
      speakers[t.speakerTag] = t.speakerLabel;
    }
    if (speakers.isEmpty) {
      speakers[1] = "Osoba 1";
      speakers[2] = "Osoba 2";
    }

    showEuphireBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: EuphireColors.mist.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Centered Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: EuphireColors.ember,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Edycja wypowiedzi",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: EuphireColors.frostWhite,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Popraw treść wypowiedzi lub zmień przypisaną osobę.",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: EuphireColors.mist.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Przypisz rolę:",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: speakers.entries.map((entry) {
                        final isSelected = selectedSpeakerTag == entry.key;
                        final isTherapist = entry.value.toLowerCase().contains("terap");
                        final icon = isTherapist ? Icons.psychology_rounded : Icons.person_rounded;
                        return ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(
                            icon,
                            size: 16,
                            color: isSelected ? EuphireColors.obsidianBlack : Colors.white54,
                          ),
                          label: Text(entry.value),
                          selected: isSelected,
                          selectedColor: EuphireColors.ember,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? EuphireColors.ember : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? EuphireColors.obsidianBlack
                                : EuphireColors.frostWhite,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() {
                                selectedSpeakerTag = entry.key;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Treść wypowiedzi:",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: textController,
                      maxLines: 5,
                      minLines: 2,
                      autofocus: false,
                      style: const TextStyle(
                        color: EuphireColors.frostWhite,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: EuphireColors.ember),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              "Anuluj",
                              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _executeEdit(segment, textController.text.trim(), selectedSpeakerTag);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EuphireColors.ember,
                              foregroundColor: EuphireColors.obsidianBlack,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Zapisz",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSplitSegmentSheet(SpeakerTurnDto segment) {
    final words = segment.text.split(' ');
    int? selectedSplitIndex;
    int firstPartSpeakerTag = segment.speakerTag;
    int secondPartSpeakerTag = segment.speakerTag == 1 ? 2 : 1;

    final turns = _data?.transcript.turns ?? [];
    final speakers = <int, String>{};
    for (final t in turns) {
      speakers[t.speakerTag] = t.speakerLabel;
    }
    if (!speakers.containsKey(1)) {
      speakers[1] = "Osoba 1";
    }
    if (!speakers.containsKey(2)) {
      speakers[2] = "Osoba 2";
    }

    showEuphireBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildSpeakerSelector({
              required int selectedTag,
              required Map<int, String> speakers,
              required Function(int) onSelected,
            }) {
              return Wrap(
                spacing: 8,
                children: speakers.entries.map((entry) {
                  final isSelected = selectedTag == entry.key;
                  final isTherapist = entry.value.toLowerCase().contains("terap");
                  final icon = isTherapist ? Icons.psychology_rounded : Icons.person_rounded;
                  return ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: isSelected ? EuphireColors.obsidianBlack : Colors.white54,
                    ),
                    label: Text(entry.value),
                    selected: isSelected,
                    selectedColor: EuphireColors.ember,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? EuphireColors.ember : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? EuphireColors.obsidianBlack
                          : EuphireColors.frostWhite,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    onSelected: (selected) {
                      if (selected) onSelected(entry.key);
                    },
                  );
                }).toList(),
              );
            }

            final hasSelectedSplit = selectedSplitIndex != null;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: EuphireColors.mist.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Centered Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const Icon(
                              Icons.call_split_rounded,
                              color: EuphireColors.ember,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Podział wypowiedzi",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: EuphireColors.frostWhite,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasSelectedSplit
                                ? "Zweryfikuj podział i przypisz właściwych mówców."
                                : "Stuknij w słowo, od którego ma się rozpocząć nowa wypowiedź.",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: EuphireColors.mist.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Interactive Words Area
                    if (!hasSelectedSplit) ...[
                      const Text(
                        "Tekst wypowiedzi (wybierz miejsce podziału):",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 10,
                          children: List.generate(words.length, (index) {
                            return InkWell(
                              onTap: () {
                                if (index == 0) return; // Cannot split before first word
                                setSheetState(() {
                                  selectedSplitIndex = index;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  words[index],
                                  style: const TextStyle(
                                    color: EuphireColors.frostWhite,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ] else ...[
                      // Visual Split Preview
                      const Text(
                        "Podgląd podziału:",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Card 1
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "Część 1",
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: EuphireColors.frostWhite,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              words.sublist(0, selectedSplitIndex).join(' '),
                              style: const TextStyle(
                                color: EuphireColors.frostWhite,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Kto wypowiada Część 1?",
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            buildSpeakerSelector(
                              selectedTag: firstPartSpeakerTag,
                              speakers: speakers,
                              onSelected: (tag) {
                                setSheetState(() {
                                  firstPartSpeakerTag = tag;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Split Point Indicator
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: EuphireColors.ember.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: EuphireColors.ember.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cut_rounded, size: 14, color: EuphireColors.ember),
                                SizedBox(width: 6),
                                Text(
                                  "MIEJSCE PODZIAŁU",
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: EuphireColors.ember,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Card 2
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: EuphireColors.ember.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EuphireColors.ember.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: EuphireColors.ember.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "Część 2",
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: EuphireColors.ember,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              words.sublist(selectedSplitIndex!).join(' '),
                              style: const TextStyle(
                                color: EuphireColors.frostWhite,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Kto wypowiada Część 2?",
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            buildSpeakerSelector(
                              selectedTag: secondPartSpeakerTag,
                              speakers: speakers,
                              onSelected: (tag) {
                                setSheetState(() {
                                  secondPartSpeakerTag = tag;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      // Reset split button
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              selectedSplitIndex = null;
                            });
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text(
                            "Zmień miejsce podziału",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: selectedSplitIndex == null
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await _executeSplit(
                                    segment: segment,
                                    splitWordIndex: selectedSplitIndex!,
                                    firstPartSpeakerTag: firstPartSpeakerTag,
                                    secondPartSpeakerTag: secondPartSpeakerTag,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EuphireColors.ember,
                            foregroundColor: EuphireColors.obsidianBlack,
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Podziel wypowiedzi",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            "Anuluj",
                            style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeEdit(SpeakerTurnDto segment, String newText, int newSpeakerTag) async {
    if (newText.isEmpty) return;

    _showLoadingDialog();

    try {
      final clients = ref.read(grpcClientsProvider);
      final resp = await clients.clinical.editTranscriptSegment(
        clinical_pb.EditTranscriptSegmentRequest(
          sessionId: widget.sessionId,
          startOffsetMs: Int64(segment.startOffsetMs),
          newText: newText,
          newSpeakerTag: newSpeakerTag,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      setState(() {
        _data = SessionDetailsDto(
          session: _data!.session,
          transcript: TranscriptDto.fromProto(resp.transcript),
          reports: _data!.reports,
        );
      });

      EuphireToast.success(context, message: "Wypowiedź została edytowana");

      final repo = await ref.read(sessionDetailsRepositoryProvider.future);
      if (repo != null) {
        unawaited(repo.refresh(widget.sessionId));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        EuphireToast.error(context, message: "Nie udało się zapisać zmian: $e");
      }
    }
  }

  Future<void> _executeSplit({
    required SpeakerTurnDto segment,
    required int splitWordIndex,
    required int firstPartSpeakerTag,
    required int secondPartSpeakerTag,
  }) async {
    _showLoadingDialog();

    try {
      final clients = ref.read(grpcClientsProvider);
      final resp = await clients.clinical.splitTranscriptSegment(
        clinical_pb.SplitTranscriptSegmentRequest(
          sessionId: widget.sessionId,
          startOffsetMs: Int64(segment.startOffsetMs),
          splitWordIndex: splitWordIndex,
          firstPartSpeakerTag: firstPartSpeakerTag,
          secondPartSpeakerTag: secondPartSpeakerTag,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      setState(() {
        _data = SessionDetailsDto(
          session: _data!.session,
          transcript: TranscriptDto.fromProto(resp.transcript),
          reports: _data!.reports,
        );
      });

      EuphireToast.success(context, message: "Wypowiedź została podzielona");

      final repo = await ref.read(sessionDetailsRepositoryProvider.future);
      if (repo != null) {
        unawaited(repo.refresh(widget.sessionId));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        EuphireToast.error(context, message: "Nie udało się podzielić wypowiedzi: $e");
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: EuphireColors.obsidianBlack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(EuphireColors.ember),
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption({required this.value, required this.label});
}

class _SegmentTile extends StatefulWidget {
  final SpeakerTurnDto segment;
  final bool isPlaying;
  final String search;
  final bool isHighlighted;
  final VoidCallback onTap;
  final Function(SpeakerTurnDto) onLongPress;
  final bool isLast;

  const _SegmentTile({
    super.key,
    required this.segment,
    required this.isPlaying,
    required this.search,
    required this.isHighlighted,
    required this.onTap,
    required this.onLongPress,
    required this.isLast,
  });

  @override
  State<_SegmentTile> createState() => _SegmentTileState();
}

class _SegmentTileState extends State<_SegmentTile> {
  @override
  void didUpdateWidget(covariant _SegmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      // Trigger a nice tactile physical tick/feedback when highlighted
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final lowConf = widget.segment.confidenceAvg > 0 && widget.segment.confidenceAvg < 0.7;

    final isSpeaker2 = widget.segment.speakerTag == 2;
    final labelColor = isSpeaker2
        ? EuphireColors.ember
        : EuphireColors.frostWhite.withValues(alpha: 0.5);

    // Keep background normal - do not make it yellowish/amber
    final bgColor = widget.isPlaying
        ? Colors.white.withValues(alpha: 0.08)
        : (isSpeaker2
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.transparent);

    return InkWell(
      onTap: widget.onTap,
      onLongPress: () {
        AppHapticFeedback.selectionClick();
        widget.onLongPress(widget.segment);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800), // Slightly longer for a beautiful spring bounce
        curve: widget.isHighlighted ? Curves.elasticOut : Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            left: BorderSide(
              color: widget.isHighlighted ? EuphireColors.ember : Colors.transparent,
              width: widget.isHighlighted ? 6.0 : 0.0,
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Speaker label + timestamp row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (widget.segment.speakerLabel.isNotEmpty ? widget.segment.speakerLabel : t.transcript_segment_unknown_speaker).toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: labelColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (lowConf)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: t.transcript_low_confidence_tooltip,
                                child: Icon(Icons.help_outline_rounded,
                                    size: 12,
                                    color: EuphireColors.mist.withValues(alpha: 0.5)),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _formatRange(widget.segment),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.frostWhite.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Transcript text ──
                  Text.rich(
                    TextSpan(
                      children: _highlight(widget.segment.text, widget.search, theme).map((span) {
                        return TextSpan(
                          text: span.text,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: EuphireColors.frostWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            fontStyle: lowConf ? FontStyle.italic : FontStyle.normal,
                            height: 1.6,
                          ).merge(span.style),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.isLast)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlight(String text, String query, ThemeData theme) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final out = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    int from = 0;
    while (true) {
      final idx = lower.indexOf(q, from);
      if (idx < 0) {
        out.add(TextSpan(text: text.substring(from)));
        break;
      }
      if (idx > from) out.add(TextSpan(text: text.substring(from, idx)));
      out.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: const TextStyle(
          backgroundColor: EuphireColors.ember,
          color: EuphireColors.obsidianBlack,
          fontWeight: FontWeight.w600,
        ),
      ));
      from = idx + q.length;
    }
    return out;
  }
}

String _formatRange(SpeakerTurnDto s) {
  String fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  return '${fmt(s.startOffsetMs)} — ${fmt(s.endOffsetMs)}';
}

