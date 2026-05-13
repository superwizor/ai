import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/euphire_theme.dart';

class LegalMarkdownScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalMarkdownScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  Future<String> _loadDocument() async {
    final raw = await rootBundle.loadString(assetPath);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Close button row ───
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ─── Title Block ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  title,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: EuphireColors.ember,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ─── Markdown Content ───
              Expanded(
                child: FutureBuilder<String>(
                  future: _loadDocument(),
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
                          'Error loading document.',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: EuphireColors.magma,
                          ),
                        ),
                      );
                    } else if (snapshot.hasData) {
                      return Markdown(
                        data: snapshot.data!,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
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
                          h1Padding: const EdgeInsets.only(top: 8, bottom: 16),

                          // ─── H2: Section headers ───
                          h2: TextStyle(
                            fontFamily: 'Montserrat',
                            color: onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.4,
                          ),
                          h2Padding: const EdgeInsets.only(top: 28, bottom: 12),

                          // ─── H3: Step titles in Montserrat bold ───
                          h3: TextStyle(
                            fontFamily: 'Montserrat',
                            color: onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                          h3Padding: const EdgeInsets.only(top: 24, bottom: 8),

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
                                color: EuphireColors.ember.withValues(alpha: 0.3),
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
                          listBulletPadding: const EdgeInsets.only(right: 8),

                          // ─── Blockquote ───
                          blockquoteDecoration: BoxDecoration(
                            color: EuphireColors.ember.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: EuphireColors.ember.withValues(alpha: 0.4),
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
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
