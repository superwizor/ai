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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../cache/dto/session_details_dto.dart';
import '../cache/dto/transcript_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/services_provider.dart';
import '../repositories/session_details_repository.dart';
import '../services/transcript_pdf_exporter.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_segmented_control.dart';
import 'report_screen.dart';

class TranscriptScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const TranscriptScreen({super.key, required this.sessionId});

  @override
  ConsumerState<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends ConsumerState<TranscriptScreen> {
  SessionDetailsDto? _data;
  String? _patientName;
  DateTime? _sessionDate;
  Duration _sessionDuration = Duration.zero;
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  String _search = '';
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
      _patientName = '';
      _sessionDate = fresh.session.createdAt.toLocal();
      _sessionDuration = Duration(seconds: fresh.session.durationSeconds);
      _loading = false;
      _error = null;
    });
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
            tooltip: 'Skopiuj transkrypcję',
            icon: const Icon(Icons.copy),
            onPressed: _data == null ? null : _onCopyPressed,
          ),
          IconButton(
            tooltip: t.transcript_actions_export,
            icon: const Icon(Icons.ios_share),
            onPressed: _data == null ? null : _onExportPressed,
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildFilterRow(t, data),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SegmentTile(
                segment: _visibleSegments[i],
                isPlaying: _currentlyPlayingSegment?.startOffsetMs ==
                    _visibleSegments[i].startOffsetMs,
                search: _search,
                onTap: () => _onSegmentTap(_visibleSegments[i]),
              ),
              childCount: _visibleSegments.length,
            ),
          ),
        ),
      ],
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
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (ctx, i) {
                final f = filters[i];
                final selected = _filter == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f.value),
                  selectedColor: EuphireColors.ember,
                  labelStyle: TextStyle(
                    color: selected
                        ? EuphireColors.obsidianBlack
                        : EuphireColors.frostWhite,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                );
              },
              separatorBuilder: (ctx, _) => const SizedBox(width: 8),
              itemCount: filters.length,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: t.transcript_search_hint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
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

  Future<void> _onExportPressed() async {
    final t = AppLocalizations.of(context);
    final confirmed = await showEuphireBottomSheet<bool>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.transcript_export_phi_header,
        body: t.transcript_export_phi_body,
        primary: EuphireSheetAction(
          label: t.transcript_export_phi_primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        secondary: EuphireSheetAction(
          label: t.transcript_export_phi_secondary,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
    );
    if (confirmed != true || _data == null) return;

    final exporter = ref.read(transcriptPdfExporterProvider);
    final strings = PdfStrings(
      title: t.transcript_pdf_title,
      metaPatient: (n) => t.transcript_pdf_meta_patient(n),
      metaDate: (d) => t.transcript_pdf_meta_date(d),
      metaDuration: (d) => t.transcript_pdf_meta_duration(d),
      footer: t.transcript_pdf_footer,
    );
    final meta = TranscriptPdfMeta(
      sessionId: widget.sessionId,
      patientName: _patientName ?? '',
      sessionDate: _sessionDate ?? DateTime.now(),
      duration: _sessionDuration,
    );
    try {
      final file = await exporter.export(
        transcript: _data!.transcript,
        meta: meta,
        strings: strings,
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _onCopyPressed() async {
    final data = _data;
    if (data == null) return;
    
    final StringBuffer buffer = StringBuffer();
    for (final s in data.transcript.turns) {
      final speaker = s.speakerLabel.isNotEmpty ? s.speakerLabel : "Głos";
      buffer.writeln('$speaker: ${s.text}');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skopiowano transkrypcję do schowka.')),
      );
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

  const _SegmentTile({
    required this.segment,
    required this.isPlaying,
    required this.search,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    // SpeakerTurnDto exposes confidenceAvg (the word-weighted mean
    // across the underlying TranscriptSegments) rather than a single
    // confidence scalar — same usage, just named for what it is.
    final lowConf = segment.confidenceAvg > 0 && segment.confidenceAvg < 0.7;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showLongPressMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: isPlaying
              ? Border(
                  left: BorderSide(color: EuphireColors.ember, width: 3))
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${segment.speakerLabel.isNotEmpty ? segment.speakerLabel : t.transcript_segment_unknown_speaker} ',
                          style: TextStyle(
                            color: _speakerColor(segment.speakerTag),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        TextSpan(
                          text: '[${_formatRange(segment)}] -> ',
                          style: TextStyle(
                            color: EuphireColors.mist,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ..._highlight(segment.text, search, theme).map((span) {
                          // Copy style from highlight and apply simplifications
                          return TextSpan(
                            text: (span).text,
                            style: TextStyle(
                              color: EuphireColors.frostWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              fontStyle: lowConf ? FontStyle.italic : FontStyle.normal,
                              height: 1.5,
                            ).merge(span.style),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                if (lowConf)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2),
                    child: Tooltip(
                      message: t.transcript_low_confidence_tooltip,
                      child: Icon(Icons.help_outline,
                          size: 14, color: EuphireColors.mist),
                    ),
                  ),
              ],
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

  Color _speakerColor(int tag) {
    switch (tag) {
      case 1:
        return EuphireColors.ember;
      case 2:
        return EuphireColors.aurora;
      case 3:
        return EuphireColors.mist;
      default:
        return EuphireColors.frostWhite;
    }
  }

  String _formatRange(SpeakerTurnDto s) {
    String fmt(int ms) {
      final d = Duration(milliseconds: ms);
      final m = d.inMinutes.toString().padLeft(2, '0');
      final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$sec';
    }

    return '${fmt(s.startOffsetMs)} – ${fmt(s.endOffsetMs)}';
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
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(t.transcript_actions_play_from_here),
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

