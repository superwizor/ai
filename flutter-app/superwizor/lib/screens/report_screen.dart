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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'transcript_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ReportScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

enum _RiskLevel { high, moderate, low, none, unknown }

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _loading = true;
  String? _error;
  clinical_pb.GetSessionDetailsResponse? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(grpcClientsProvider).clinical.getSessionDetails(
            clinical_pb.GetSessionDetailsRequest(sessionId: widget.sessionId),
          );
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
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
          IconButton(
            tooltip: 'Skopiuj raporty',
            icon: const Icon(Icons.copy),
            onPressed: _data == null ? null : _onCopyPressed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _ReportTabToggle(
            selected: 'report',
            onSelect: (v) {
              if (v == 'transcript') {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => TranscriptScreen(sessionId: widget.sessionId),
                ));
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
                  onPressed: _load, child: Text(t.common_retry)),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(report: report, payload: payload),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: MarkdownBody(
            data: payload.reportMarkdown,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyLarge,
              h1: theme.textTheme.headlineLarge,
              h2: theme.textTheme.headlineMedium,
              h3: theme.textTheme.headlineSmall,
              listBullet: theme.textTheme.bodyLarge,
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
  final clinical_pb.Report report;
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

  static _ReportPayload parse(clinical_pb.Report report) {
    if (report.content.isEmpty) {
      return empty();
    }
    try {
      final json = jsonDecode(report.content) as Map<String, dynamic>;
      return _ReportPayload(
        summary: json['summary_short'] as String?,
        reportMarkdown: (json['report_markdown'] ?? '').toString(),
      );
    } catch (_) {
      return empty();
    }
  }
}


class _ReportTabToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _ReportTabToggle({required this.selected, required this.onSelect});

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
