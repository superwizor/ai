import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;

import '../cache/dto/report_dto.dart';
import '../cache/dto/transcript_dto.dart';
import '../providers/session_details_provider.dart';

class SessionDetailsScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String patientName;
  final String date;
  final String modality;

  const SessionDetailsScreen({
    super.key,
    required this.sessionId,
    required this.patientName,
    required this.date,
    required this.modality,
  });

  @override
  ConsumerState<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends ConsumerState<SessionDetailsScreen> {
  int _selectedSectionIndex = 0;

  void _copyAllReports(BuildContext context, List<ReportDto> reports) {
    final buffer = StringBuffer();
    for (final section in reports) {
      buffer.writeln('### ${section.title}');
      buffer.writeln(section.content);
      buffer.writeln('');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skopiowano wszystkie raporty do schowka!')),
    );
  }
  
  void _copyTranscript(BuildContext context, TranscriptDto transcript) {
    final buffer = StringBuffer();
    for (final segment in transcript.segments) {
      buffer.writeln('${segment.speakerLabel}: ${segment.text}');
      buffer.writeln('');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skopiowano transkrypcję do schowka!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionDetailsAsync = ref.watch(sessionDetailsProvider(widget.sessionId));
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.secondary),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(180),
            child: Column(
              children: [
                Text(
                  'Sesja ${widget.date}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.patientName,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                sessionDetailsAsync.when(
                  data: (data) {
                    final wordsCount = data.transcript.segments.fold<int>(0, (prev, element) => prev + element.text.split(' ').length);
                    // Bierzemy sentyment z pierwszego raportu, jeśli istnieje.
                    final sentiment = data.reports.isNotEmpty ? data.reports.first.sentimentLabel : 'Nieznany';
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatItem('MODALNOŚĆ', widget.modality),
                        _buildDivider(),
                        _buildStatItem('SENTYMENT', sentiment.isNotEmpty ? sentiment : 'Neutralny'),
                        _buildDivider(),
                        _buildStatItem('SŁOWA', wordsCount.toString()),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem('MODALNOŚĆ', widget.modality),
                      _buildDivider(),
                      _buildStatItem('STATUS', 'Nowa'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TabBar(
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.secondary,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Analizy'),
                    Tab(text: 'Transkrypcje'),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                if (tabController.index != 0) return const SizedBox.shrink();
                
                return sessionDetailsAsync.maybeWhen(
                  data: (data) {
                    if (data.reports.isEmpty) return const SizedBox.shrink();
                    return FloatingActionButton(
                      onPressed: () => _copyAllReports(context, data.reports),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: const Icon(Icons.copy_all),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
            );
          },
        ),
        body: sessionDetailsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => TabBarView(
            children: [
              _buildComingSoonPlaceholder(
                theme,
                icon: Icons.analytics_outlined,
                title: 'Raporty AI — wkrótce',
                subtitle: 'Analiza sesji i automatyczne raporty będą dostępne\nw kolejnej aktualizacji.',
              ),
              _buildComingSoonPlaceholder(
                theme,
                icon: Icons.subtitles_outlined,
                title: 'Transkrypcja — wkrótce',
                subtitle: 'Automatyczna transkrypcja z rozpoznawaniem mówców\nbędzie dostępna w kolejnej aktualizacji.',
              ),
            ],
          ),
          data: (data) {
            final hasReports = data.reports.isNotEmpty;
            final hasTranscript = data.transcript.segments.isNotEmpty;

            return TabBarView(
              children: [
                // Analizy Tab
                if (!hasReports)
                  _buildComingSoonPlaceholder(
                    theme,
                    icon: Icons.analytics_outlined,
                    title: 'Raporty AI — wkrótce',
                    subtitle: 'Analiza sesji i automatyczne raporty będą dostępne\nw kolejnej aktualizacji.',
                  )
                else
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      // Poziomy pasek nawigacji raportów (Pille)
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: data.reports.length,
                          itemBuilder: (context, index) {
                            final isActive = _selectedSectionIndex == index;
                            final section = data.reports[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: InkWell(
                                onTap: () => setState(() => _selectedSectionIndex = index),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    border: Border.all(
                                      color: isActive 
                                          ? theme.colorScheme.primary 
                                          : theme.colorScheme.secondary.withValues(alpha: 0.1),
                                      width: isActive ? 1.5 : 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isActive ? [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ] : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      section.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isActive 
                                            ? theme.colorScheme.secondary 
                                            : theme.colorScheme.secondary.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Glassmorphic kontener na treść
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24.0),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _selectedSectionIndex < data.reports.length 
                                        ? data.reports[_selectedSectionIndex].content 
                                        : '',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.9),
                                      height: 1.8,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100), // Miejsce na FAB
                    ],
                  ),
                
                // Transkrypcje Tab
                if (!hasTranscript)
                  _buildComingSoonPlaceholder(
                    theme,
                    icon: Icons.subtitles_outlined,
                    title: 'Transkrypcja — wkrótce',
                    subtitle: 'Automatyczna transkrypcja z rozpoznawaniem mówców\nbędzie dostępna w kolejnej aktualizacji.',
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: RichText(
                              text: TextSpan(
                                children: data.transcript.segments.map((segment) {
                                  return TextSpan(
                                    text: '${segment.speakerLabel}: ${segment.text}\n\n',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.8),
                                      height: 1.5,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _copyTranscript(context, data.transcript),
                          icon: const Icon(Icons.copy),
                          label: const Text('Skopiuj transkrypcję'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.surface,
                            foregroundColor: theme.colorScheme.secondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            color: theme.colorScheme.secondary.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.secondary.withValues(alpha: 0.8),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
    );
  }

  Widget _buildComingSoonPlaceholder(ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
