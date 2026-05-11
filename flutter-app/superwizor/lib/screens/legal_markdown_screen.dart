import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../theme/euphire_theme.dart';

class LegalMarkdownScreen extends StatelessWidget {
  final String assetPath;

  const LegalMarkdownScreen({super.key, required this.assetPath});

  String _titleFor(String path) {
    if (path.contains('dpa')) return 'Umowa powierzenia danych (DPA)';
    if (path.contains('privacy_policy')) return 'Polityka Prywatności';
    if (path.contains('terms')) return 'Regulamin';
    return 'Dokument';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(assetPath)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: EuphireColors.ember));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Nie udało się wczytać dokumentu.', style: TextStyle(color: EuphireColors.magma)));
          }
          return Markdown(
            data: snapshot.data!,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EuphireColors.frostWhite),
              h1: Theme.of(context).textTheme.headlineMedium?.copyWith(color: EuphireColors.ember),
              h2: Theme.of(context).textTheme.titleLarge?.copyWith(color: EuphireColors.mist),
            ),
          );
        },
      ),
    );
  }
}
