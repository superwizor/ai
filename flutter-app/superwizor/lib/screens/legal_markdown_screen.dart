// legal_markdown_screen.dart — Ekran dokumentów prawnych (EUPHIRE Design System)
//
// Cechy:
//   • Gradient tła backgroundGradient (evergreen → nocturne)
//   • MarkdownStyleSheet dopasowany do EUPHIRE (kolory, czcionki, spacingi)
//   • Selectable text — można zaznaczać fragmenty
//   • Swipe-to-go-back działa (standardowy MaterialPageRoute)
//   • Obsługa błędu wczytania pliku

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/euphire_theme.dart';

class LegalMarkdownScreen extends StatelessWidget {
  final String assetPath;
  final String? title;

  const LegalMarkdownScreen({
    super.key,
    required this.assetPath,
    this.title,
  });

  String _titleFor(String path) {
    if (title != null) return title!;
    if (path.contains('dpa')) return 'DPA / RODO';
    if (path.contains('privacy')) return 'Polityka Prywatności';
    if (path.contains('terms')) return 'Regulamin';
    return 'Dokument';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedTitle = _titleFor(assetPath);

    return Scaffold(
      backgroundColor: EuphireColors.evergreen,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.frostWhite),
        title: Text(
          resolvedTitle,
          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 1.5),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: EuphireColors.ember),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Nie udało się wczytać dokumentu.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: EuphireColors.magma),
                  ),
                ),
              );
            }
            return Markdown(
              data: snapshot.data!,
              selectable: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              styleSheet: _buildStyleSheet(theme),
            );
          },
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme) {
    return MarkdownStyleSheet(
      // Nagłówki
      h1: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: EuphireColors.ember,
        height: 1.3,
      ),
      h2: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: EuphireColors.frostWhite,
        height: 1.3,
      ),
      h3: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: EuphireColors.mist,
        letterSpacing: 0.5,
        height: 1.4,
      ),
      // Akapity
      p: TextStyle(
        fontFamily: 'Merriweather',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: EuphireColors.frostWhite.withValues(alpha: 0.85),
        height: 1.7,
      ),
      pPadding: const EdgeInsets.only(bottom: 12),
      // Listy
      listBullet: TextStyle(
        color: EuphireColors.ember,
        fontSize: 14,
        height: 1.7,
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w400,
      ),
      listIndent: 20,
      // Pogrubienia i kursywa
      strong: const TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w700,
        color: EuphireColors.frostWhite,
      ),
      em: TextStyle(
        fontFamily: 'Merriweather',
        fontStyle: FontStyle.italic,
        color: EuphireColors.frostWhite.withValues(alpha: 0.85),
      ),
      // Separator ---
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: EuphireColors.mist.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      // Kod inline
      code: TextStyle(
        fontFamily: 'RobotoMono',
        fontSize: 13,
        color: EuphireColors.ember,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EuphireColors.mist.withValues(alpha: 0.15)),
      ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: EuphireColors.ember, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      blockquote: TextStyle(
        fontFamily: 'Merriweather',
        fontStyle: FontStyle.italic,
        fontSize: 14,
        color: EuphireColors.frostWhite.withValues(alpha: 0.75),
        height: 1.6,
      ),
    );
  }
}
