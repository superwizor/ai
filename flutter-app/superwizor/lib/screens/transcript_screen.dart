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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../cache/dto/session_details_dto.dart';
import '../cache/dto/transcript_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _loadInitial();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
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
      // Regex that matches common Polish filler words: yyy, eee, yyyy, etc.
      final newText = s.text
          .replaceAll(RegExp(r'\b([yY]{2,}|[eE]{2,}|mhm)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
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
                (ctx, i) => _SegmentTile(
                  segment: _visibleSegments[i],
                  isPlaying: _currentlyPlayingSegment?.startOffsetMs ==
                      _visibleSegments[i].startOffsetMs,
                  search: _search,
                  onTap: () => _onSegmentTap(_visibleSegments[i]),
                  isLast: i == _visibleSegments.length - 1,
                ),
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
    try {
      await _player.seek(Duration(milliseconds: s.startOffsetMs));
      await _player.resume();
    } catch (_) {/* no audio source loaded yet */}
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
}

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption({required this.value, required this.label});
}

class _SegmentTile extends StatelessWidget {
  final SpeakerTurnDto segment;
  final bool isPlaying;
  final String search;
  final VoidCallback onTap;
  final bool isLast;

  const _SegmentTile({
    required this.segment,
    required this.isPlaying,
    required this.search,
    required this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final lowConf = segment.confidenceAvg > 0 && segment.confidenceAvg < 0.7;

    final isSpeaker2 = segment.speakerTag == 2;
    final labelColor = isSpeaker2
        ? EuphireColors.ember
        : EuphireColors.frostWhite.withValues(alpha: 0.5);

    final bgColor = isPlaying
        ? Colors.white.withValues(alpha: 0.08)
        : (isSpeaker2
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.transparent);

    return InkWell(
      onTap: onTap,
      onLongPress: () {
        AppHapticFeedback.selectionClick();
        _showLongPressMenu(context);
      },
      child: Container(
        color: bgColor,
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
                            (segment.speakerLabel.isNotEmpty ? segment.speakerLabel : t.transcript_segment_unknown_speaker).toUpperCase(),
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
                        _formatRange(segment),
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
                      children: _highlight(segment.text, search, theme).map((span) {
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
            if (!isLast)
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
        style: TextStyle(
          backgroundColor: EuphireColors.ember.withValues(alpha: 0.4),
          fontWeight: FontWeight.w600,
        ),
      ));
      from = idx + q.length;
    }
    return out;
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

  void _showLongPressMenu(BuildContext context) {
    final t = AppLocalizations.of(context);
    showEuphireBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(t.transcript_actions_copy),
              onTap: () {
                Clipboard.setData(ClipboardData(text: segment.text));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(t.transcript_actions_copy_with_timestamp),
              onTap: () {
                Clipboard.setData(ClipboardData(
                  text: '[${_formatRange(segment)}] ${segment.text}',
                ));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

