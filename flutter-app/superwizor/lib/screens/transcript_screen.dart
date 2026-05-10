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
// Cache: TranscriptCacheStore reads first; backend fetch in background.
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

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/services_provider.dart';
import '../services/transcript_cache_store.dart';
import '../services/transcript_pdf_exporter.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import 'report_screen.dart';

class TranscriptScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const TranscriptScreen({super.key, required this.sessionId});

  @override
  ConsumerState<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends ConsumerState<TranscriptScreen> {
  CachedTranscript? _data;
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
    final cached = await ref.read(transcriptCacheProvider).load(widget.sessionId);
    if (cached != null && mounted) {
      setState(() {
        _data = cached;
        _loading = false;
      });
    }
    await _refreshFromBackend(showLoaderIfEmpty: cached == null);
  }

  Future<void> _refreshFromBackend({required bool showLoaderIfEmpty}) async {
    try {
      if (showLoaderIfEmpty && mounted) setState(() => _loading = true);
      final clients = ref.read(grpcClientsProvider);
      final res = await clients.clinical.getSessionDetails(
        clinical_pb.GetSessionDetailsRequest(sessionId: widget.sessionId),
      );

      final segments = res.transcript.segments
          .map((s) => CachedSegment(
                speakerTag: s.speakerTag,
                speakerLabel: s.speakerLabel,
                startOffsetMs: s.startOffsetMs,
                endOffsetMs: s.endOffsetMs,
                text: s.text,
                confidence: s.confidence,
              ))
          .toList();
      final speakerLabels = Map<String, String>.from(res.session.speakerLabelMapping);

      final fresh = CachedTranscript(
        sessionId: widget.sessionId,
        segments: segments,
        speakerLabels: speakerLabels,
        cachedAt: DateTime.now(),
      );
      await ref.read(transcriptCacheProvider).save(fresh);

      if (!mounted) return;
      setState(() {
        _data = fresh;
        _patientName = '';
        _sessionDate = res.session.createdAt.toDateTime();
        _sessionDuration = Duration(seconds: res.session.durationSeconds);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  CachedSegment? get _currentlyPlayingSegment {
    final data = _data;
    if (data == null) return null;
    final ms = _playbackPosition.inMilliseconds;
    for (final s in data.segments) {
      if (ms >= s.startOffsetMs && ms < s.endOffsetMs) return s;
    }
    return null;
  }

  List<CachedSegment> get _visibleSegments {
    final data = _data;
    if (data == null) return const [];
    final q = _search.toLowerCase();
    return data.segments.where((s) {
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
            tooltip: t.transcript_actions_export,
            icon: const Icon(Icons.ios_share),
            onPressed: _data == null ? null : _onExportPressed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _TabToggle(
            selected: 'transcript',
            onSelect: (v) {
              if (v == 'report') {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => ReportScreen(sessionId: widget.sessionId),
                ));
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
    if (data.segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.session_loading,
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ),
      );
    }
    return Column(
      children: [
        _buildFilterRow(t, data),
        const Divider(height: 1, color: EuphireColors.nocturne),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _visibleSegments.length,
            itemBuilder: (ctx, i) => _SegmentTile(
              segment: _visibleSegments[i],
              isPlaying: _currentlyPlayingSegment?.startOffsetMs ==
                  _visibleSegments[i].startOffsetMs,
              search: _search,
              onTap: () => _onSegmentTap(_visibleSegments[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: EuphireColors.nocturne,
      highlightColor: EuphireColors.nocturne.withValues(alpha: 0.5),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (ctx, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, _) => Container(
          height: 80,
          decoration: BoxDecoration(
            color: EuphireColors.nocturne,
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

  Widget _buildFilterRow(AppLocalizations t, CachedTranscript data) {
    final filters = <_FilterOption>[
      _FilterOption(value: 'all', label: t.transcript_filter_all),
      ...data.speakerLabels.entries
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
                  backgroundColor: EuphireColors.nocturne,
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

  Future<void> _onSegmentTap(CachedSegment s) async {
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
        transcript: _data!,
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
}

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption({required this.value, required this.label});
}

class _SegmentTile extends StatelessWidget {
  final CachedSegment segment;
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
    final lowConf = segment.confidence > 0 && segment.confidence < 0.7;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showLongPressMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EuphireColors.nocturne,
          border: isPlaying
              ? const Border(
                  left: BorderSide(color: EuphireColors.ember, width: 3))
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  segment.speakerLabel.isNotEmpty
                      ? segment.speakerLabel
                      : t.transcript_segment_unknown_speaker,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _speakerColor(segment.speakerTag),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(_formatRange(segment),
                    style: theme.textTheme.labelSmall),
                if (lowConf)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: t.transcript_low_confidence_tooltip,
                      child: const Icon(Icons.help_outline,
                          size: 14, color: EuphireColors.mist),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: lowConf ? FontStyle.italic : FontStyle.normal,
                ),
                children: _highlight(segment.text, search, theme),
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

  String _formatRange(CachedSegment s) {
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EuphireColors.nocturne,
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

class _TabToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _TabToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'transcript', label: Text(t.transcript_tab)),
          ButtonSegment(value: 'report', label: Text(t.report_tab)),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onSelect(s.first),
      ),
    );
  }
}
