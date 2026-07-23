import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/euphire_theme.dart';

class LegalMarkdownScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalMarkdownScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalMarkdownScreen> createState() => _LegalMarkdownScreenState();
}

class _LegalMarkdownScreenState extends State<LegalMarkdownScreen> {
  double _progress = 0.0;
  final ScrollController _scrollController = ScrollController();

  // Created ONCE. Passing `_loadDocument()` inline to FutureBuilder made
  // every rebuild mint a fresh future — and the scroll-progress setState
  // rebuilds on every scrolled frame, so scrolling destroyed the scroll
  // view (spinner flash) and remounted it at the top. That was the
  // "błyska zamiast przewijać" bug on the legal screens (2026-07-23).
  late final Future<String> _docFuture = _loadDocument();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _loadDocument() async {
    final raw = await rootBundle.loadString(widget.assetPath);
    // Strip the first H1 line - it's already shown as the big yellow header
    final lines = raw.split('\n');
    if (lines.isNotEmpty && lines.first.startsWith('# ')) {
      return lines.skip(1).join('\n').trimLeft();
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 8 && details.globalPosition.dx < 50) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              FutureBuilder<String>(
                future: _docFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: EuphireColors.ember,
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        // ignore: avoid_hardcoded_strings_in_widgets
                        'Error loading document.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.magma,
                        ),
                      ),
                    );
                  } else if (snapshot.hasData) {
                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.maxScrollExtent > 0) {
                          setState(() {
                            _progress = (notification.metrics.pixels /
                                    notification.metrics.maxScrollExtent)
                                .clamp(0.0, 1.0);
                          });
                        }
                        return false;
                      },
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            // ── Collapsing header with title ──
                          SliverAppBar(
                            backgroundColor: theme.scaffoldBackgroundColor,
                            elevation: 0,
                            scrolledUnderElevation: 0,
                            pinned: true,
                            automaticallyImplyLeading: false,
                            expandedHeight: 120,
                            collapsedHeight: 56,
                            actions: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.close,
                                  color: onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                            flexibleSpace: LayoutBuilder(
                              builder: (context, constraints) {
                                // Calculate how much we've collapsed (0.0 = fully
                                // expanded, 1.0 = fully collapsed)
                                final expandedHeight = 120.0;
                                final collapsedHeight = 56.0;
                                final currentHeight = constraints.maxHeight;
                                final t = ((expandedHeight - currentHeight) /
                                        (expandedHeight - collapsedHeight))
                                    .clamp(0.0, 1.0);

                                // Interpolate font size: 32 → 18
                                final fontSize = 32.0 - (14.0 * t);
                                // Interpolate padding: 24 → 16
                                final leftPadding = 24.0 - (8.0 * t);
                                // Interpolate vertical position
                                final topPadding = 16.0 + (expandedHeight -
                                    collapsedHeight) * (1 - t) * 0.35;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: leftPadding,
                                    right: 48, // leave space for close button
                                    top: topPadding,
                                  ),
                                  child: Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontFamily: 'Merriweather',
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w700,
                                      fontSize: fontSize,
                                      color: EuphireColors.ember,
                                      height: 1.2,
                                    ),
                                    maxLines: t > 0.7 ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                            // Subtle bottom border when collapsed
                            bottom: PreferredSize(
                              preferredSize: const Size.fromHeight(1),
                              child: Container(
                                height: 1,
                                color: EuphireColors.ember.withValues(alpha: 0.15),
                              ),
                            ),
                          ),

                          // ── Markdown content ──
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: MarkdownBody(
                                data: snapshot.data!,
                                styleSheet: MarkdownStyleSheet(
                                  // ─── Body Text: Merriweather for readability ───
                                  p: TextStyle(
                                    fontFamily: 'Merriweather',
                                    color: onSurface.withValues(alpha: 0.7),
                                    fontSize: 14,
                                    height: 1.7,
                                  ),

                                  // ─── H1: Large ember Merriweather (main titles) ───
                                  h1: TextStyle(
                                    fontFamily: 'Merriweather',
                                    color: EuphireColors.ember,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                  h1Padding:
                                      const EdgeInsets.only(top: 8, bottom: 16),

                                  // ─── H2: Section headers ───
                                  h2: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    height: 1.4,
                                  ),
                                  h2Padding:
                                      const EdgeInsets.only(top: 28, bottom: 12),

                                  // ─── H3: Step titles in Montserrat bold ───
                                  h3: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                  h3Padding:
                                      const EdgeInsets.only(top: 24, bottom: 8),

                                  // ─── Bold text: White Montserrat ───
                                  strong: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),

                                  // ─── Italic: Merriweather italic, slightly accented ───
                                  em: TextStyle(
                                    fontFamily: 'Merriweather',
                                    color: onSurface.withValues(alpha: 0.8),
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),

                                  // ─── Bullet points ───
                                  listBullet: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: EuphireColors.ember,
                                    fontSize: 14,
                                  ),

                                  // ─── Ordered list ───
                                  orderedListAlign: WrapAlignment.start,

                                  // ─── Horizontal rule: subtle divider ───
                                  horizontalRuleDecoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: EuphireColors.ember
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),

                                  // ─── Links ───
                                  a: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: EuphireColors.ember,
                                    decoration: TextDecoration.underline,
                                    decorationColor: EuphireColors.ember.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),

                                  // ─── Spacing ───
                                  pPadding: const EdgeInsets.only(bottom: 12),
                                  listIndent: 24,
                                  listBulletPadding:
                                      const EdgeInsets.only(right: 8),

                                  // ─── Blockquote ───
                                  blockquoteDecoration: BoxDecoration(
                                    color: EuphireColors.ember
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border(
                                      left: BorderSide(
                                        color: EuphireColors.ember
                                            .withValues(alpha: 0.4),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  blockquotePadding: const EdgeInsets.all(16),
                                  blockquote: TextStyle(
                                    fontFamily: 'Merriweather',
                                    color: onSurface.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom padding
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 48),
                          ),
                        ],
                      ),
                     ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
              // ── Top progress bar ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(EuphireColors.ember),
                  minHeight: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
