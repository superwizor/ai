// Treść sekcji w świeżej turze musi renderować się jako Markdown.
//
// Zgłoszenie 21.08.2026: odpowiedź w oknie czatu pokazywała surowe
// "**Hipoteza:**", a po zamknięciu i ponownym otwarciu czatu ta sama
// tura wyglądała poprawnie. Powodem były dwie ścieżki renderowania:
// świeża tura szła przez AiChatTurnView (zwykły Text), a rozmowa
// wczytana z notatki przez MarkdownBody. Etykiety statusu są wymogiem
// soczewek, więc model będzie je pisał zawsze — muszą być renderowane.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/services/ai_chat_service.dart';
import 'package:superwizor/widgets/ai_chat_turn_view.dart';

ChatSection _sekcja(String body) => ChatSection(
  title: 'Wzorzec negatywnej uwagi',
  body: body,
  quotes: const [],
  kind: ChatSectionKind.hypothesis,
  userAuthored: false,
);

ChatTurnResult _tura(ChatSection s) => ChatTurnResult(
  conversationId: 'c1',
  outcome: ChatOutcomeKind.answered,
  sections: [s],
  suggestedQuestions: const [],
  refusal: null,
  degradeReason: '',
  quotaRemainingMicroUsd: 0,
  latencyMs: 0,
);

Future<void> _osadz(WidgetTester tester, ChatSection s) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AiChatTurnView(
            turn: _tura(s),
            onAlternativeTap: (_) {},
            onUserFieldChanged: (_, _) {},
          ),
        ),
      ),
    ),
  );
}

/// Zbiera cały tekst widoczny na ekranie.
String _widocznyTekst(WidgetTester tester) {
  final bufor = StringBuffer();
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    bufor.write(w.text.toPlainText());
  }
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    bufor.write(w.data ?? '');
  }
  return bufor.toString();
}

void main() {
  testWidgets('etykiety statusu nie pokazują się jako surowe gwiazdki', (
    tester,
  ) async {
    await _osadz(
      tester,
      _sekcja(
        '**Hipoteza:** Klientka może mieć trudność w dostrzeganiu zmian. '
        '**Obserwacja:** Mówi wprost o braku poprawy.',
      ),
    );
    final tekst = _widocznyTekst(tester);

    expect(
      tekst.contains('**'),
      isFalse,
      reason: 'surowe znaczniki Markdown widoczne dla terapeuty: $tekst',
    );
    expect(tekst.contains('Hipoteza:'), isTrue);
    expect(tekst.contains('Obserwacja:'), isTrue);
  });

  testWidgets('zastrzeżenia renderują się jako lista, nie jako myślniki', (
    tester,
  ) async {
    // Serwer składa caveats jako "- a\n- b" (executor.go, sekcja
    // "Ograniczenia"), więc bez Markdownu terapeuta widzi myślniki.
    await _osadz(tester, _sekcja('- Materiał z jednej sesji\n- Brak danych o parze'));
    final tekst = _widocznyTekst(tester);

    expect(tekst.contains('Materiał z jednej sesji'), isTrue);
    expect(
      tekst.contains('- Materiał'),
      isFalse,
      reason: 'myślnik listy renderowany dosłownie: $tekst',
    );
  });
}
