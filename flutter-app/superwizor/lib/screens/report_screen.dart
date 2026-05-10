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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'transcript_screen.dart';

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
        const SizedBox(height: 12),
        _Section(
          title: t.report_section_themes,
          initiallyExpanded: false,
          child: _ThemesContent(themes: payload.mainThemes, t: t),
        ),
        _Section(
          title: t.report_section_alliance,
          initiallyExpanded: false,
          child: _PlainText(text: payload.alliance ?? '—'),
        ),
        _Section(
          title: t.report_section_interventions,
          initiallyExpanded: false,
          child: _InterventionsContent(items: payload.interventions, t: t),
        ),
        _Section(
          title: t.report_section_hitop,
          initiallyExpanded: false,
          child: _HitopContent(items: payload.hitop, t: t),
        ),
        _Section(
          title: t.report_section_risk,
          initiallyExpanded:
              payload.riskLevel == _RiskLevel.high || payload.riskLevel == _RiskLevel.moderate,
          trailing: _RiskBadge(level: payload.riskLevel, t: t),
          child: _RiskContent(payload: payload),
        ),
        _Section(
          title: t.report_section_recommendations,
          initiallyExpanded: false,
          child:
              _RecommendationsContent(items: payload.recommendations, t: t),
        ),
      ],
    );
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
        color: EuphireColors.nocturne,
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
          if (payload.sentiment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: EuphireColors.evergreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sentyment: ${payload.sentiment}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: EuphireColors.nocturne,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          trailing: trailing,
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: EuphireColors.mist,
          collapsedIconColor: EuphireColors.mist,
          children: [child],
        ),
      ),
    );
  }
}

class _PlainText extends StatelessWidget {
  final String text;
  const _PlainText({required this.text});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

class _ThemesContent extends StatelessWidget {
  final List<_Theme> themes;
  final AppLocalizations t;
  const _ThemesContent({required this.themes, required this.t});

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) return _PlainText(text: t.report_empty_themes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final th in themes) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                    child: Text(th.theme,
                        style: Theme.of(context).textTheme.bodyLarge)),
                if (th.salience > 0)
                  Text('${(th.salience * 100).round()}%',
                      style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          if (th.evidence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '„${th.evidence.first}”',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: EuphireColors.mist,
                    ),
              ),
            ),
        ],
      ],
    );
  }
}

class _InterventionsContent extends StatelessWidget {
  final List<_Intervention> items;
  final AppLocalizations t;
  const _InterventionsContent({required this.items, required this.t});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _PlainText(text: t.report_empty_interventions);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.type, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                if (i.description.isNotEmpty)
                  Text(i.description, style: theme.textTheme.bodyMedium),
                if (i.patientResponse.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reakcja pacjenta: ${i.patientResponse}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: EuphireColors.mist)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HitopContent extends StatelessWidget {
  final List<_Hitop> items;
  final AppLocalizations t;
  const _HitopContent({required this.items, required this.t});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _PlainText(text: t.report_empty_hitop);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final h in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(h.code, style: theme.textTheme.bodyLarge)),
                Text(
                  h.score.toStringAsFixed(2),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: EuphireColors.ember,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RiskContent extends StatelessWidget {
  final _ReportPayload payload;
  const _RiskContent({required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (payload.riskConcerns.isNotEmpty) ...[
          Text('Sygnały:', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final c in payload.riskConcerns)
            Text('• $c', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
        ],
        if (payload.riskActions.isNotEmpty) ...[
          Text('Rekomendowane działania:', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final a in payload.riskActions)
            Text('• $a', style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _RecommendationsContent extends StatelessWidget {
  final List<String> items;
  final AppLocalizations t;
  const _RecommendationsContent({required this.items, required this.t});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _PlainText(text: t.report_empty_recommendations);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 6, color: EuphireColors.ember),
                ),
                Expanded(child: Text(r, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final _RiskLevel level;
  final AppLocalizations t;
  const _RiskBadge({required this.level, required this.t});

  @override
  Widget build(BuildContext context) {
    if (level == _RiskLevel.unknown) return const SizedBox.shrink();
    final color = switch (level) {
      _RiskLevel.high => EuphireColors.magma,
      _RiskLevel.moderate => EuphireColors.ember,
      _RiskLevel.low || _RiskLevel.none => EuphireColors.mist,
      _ => EuphireColors.mist,
    };
    final label = switch (level) {
      _RiskLevel.high => t.risk_level_high,
      _RiskLevel.moderate => t.risk_level_moderate,
      _RiskLevel.low => t.risk_level_low,
      _RiskLevel.none => t.risk_level_none,
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payload parsing
// ---------------------------------------------------------------------------

class _ReportPayload {
  final String? summary;
  final String sentiment;
  final List<_Theme> mainThemes;
  final String? alliance;
  final List<_Intervention> interventions;
  final List<_Hitop> hitop;
  final List<String> recommendations;
  final _RiskLevel riskLevel;
  final List<String> riskConcerns;
  final List<String> riskActions;

  const _ReportPayload({
    required this.sentiment,
    required this.mainThemes,
    required this.interventions,
    required this.hitop,
    required this.recommendations,
    required this.riskLevel,
    required this.riskConcerns,
    required this.riskActions,
    this.summary,
    this.alliance,
  });

  static _ReportPayload empty() => const _ReportPayload(
        sentiment: '',
        mainThemes: [],
        interventions: [],
        hitop: [],
        recommendations: [],
        riskLevel: _RiskLevel.unknown,
        riskConcerns: [],
        riskActions: [],
      );

  static _ReportPayload parse(clinical_pb.Report report) {
    if (report.content.isEmpty) {
      return _ReportPayload(
        sentiment: report.sentimentLabel,
        mainThemes: const [],
        interventions: const [],
        hitop: const [],
        recommendations: const [],
        riskLevel: _riskFromString(report.riskLevel),
        riskConcerns: const [],
        riskActions: const [],
      );
    }
    try {
      final json = jsonDecode(report.content) as Map<String, dynamic>;
      return _ReportPayload(
        summary: json['summary_short'] as String?,
        sentiment: (json['sentiment'] ?? report.sentimentLabel).toString(),
        mainThemes: ((json['main_themes'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_Theme.fromJson)
            .toList(),
        alliance: json['therapeutic_alliance_observations'] as String?,
        interventions: ((json['interventions_observed'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_Intervention.fromJson)
            .toList(),
        hitop: ((json['hitop_dimensions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_Hitop.fromJson)
            .toList(),
        recommendations:
            ((json['recommendations_for_next_session'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(),
        riskLevel: _riskFromString(
            ((json['risk_assessment'] as Map?)?['level'] ?? report.riskLevel)
                .toString()),
        riskConcerns: ((json['risk_assessment'] as Map?)?['concerns'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        riskActions:
            ((json['risk_assessment'] as Map?)?['recommended_actions'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
      );
    } catch (_) {
      return empty();
    }
  }

  static _RiskLevel _riskFromString(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return _RiskLevel.high;
      case 'moderate':
        return _RiskLevel.moderate;
      case 'low':
        return _RiskLevel.low;
      case 'none':
        return _RiskLevel.none;
      default:
        return _RiskLevel.unknown;
    }
  }
}

class _Theme {
  final String theme;
  final double salience;
  final List<String> evidence;
  const _Theme({required this.theme, required this.salience, required this.evidence});

  static _Theme fromJson(Map<String, dynamic> json) => _Theme(
        theme: (json['theme'] ?? '').toString(),
        salience: ((json['salience'] ?? 0) as num).toDouble(),
        evidence: ((json['evidence_quotes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class _Intervention {
  final String type;
  final String description;
  final String patientResponse;
  const _Intervention(
      {required this.type,
      required this.description,
      required this.patientResponse});

  static _Intervention fromJson(Map<String, dynamic> json) => _Intervention(
        type: (json['intervention_type'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        patientResponse: (json['patient_response'] ?? '').toString(),
      );
}

class _Hitop {
  final String code;
  final double score;
  final double confidence;
  const _Hitop({required this.code, required this.score, required this.confidence});

  static _Hitop fromJson(Map<String, dynamic> json) => _Hitop(
        code: (json['dimension_code'] ?? '').toString(),
        score: ((json['score'] ?? 0) as num).toDouble(),
        confidence: ((json['confidence'] ?? 0) as num).toDouble(),
      );
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
