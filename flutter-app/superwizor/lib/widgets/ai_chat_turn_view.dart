// Renders one guardrailed chat turn.
//
// The presentation rules here are not styling choices; they come from
// ADR docs/kronikarz/62 section 9 and article 50 of the AI Act:
//
//   - Generated clinical material (hypotheses) is visibly MARKED as AI
//     output awaiting the therapist's judgement. It does not look like a
//     retrieved fact, because it is not one.
//   - Every hypothesis carries expandable evidence. The therapist can see
//     what the claim rests on without leaving the screen — a hypothesis
//     whose grounding is three taps away is a hypothesis nobody checks.
//   - Therapist-owned fields are visually distinct and empty. The model
//     had no field to write them into; the UI must not blur that.
//   - A refusal offers a way forward. A refusal that only says no is a
//     refusal people learn to route around.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/ai_chat_service.dart';
import '../theme/euphire_theme.dart';
import '../theme/markdown_quote_style.dart';

class AiChatTurnView extends StatelessWidget {
  const AiChatTurnView({
    super.key,
    required this.turn,
    required this.onAlternativeTap,
    required this.onUserFieldChanged,
    this.userFieldValues = const {},
  });

  final ChatTurnResult turn;

  /// Called with the prefill text when the therapist accepts an offered
  /// alternative after a refusal.
  final ValueChanged<String> onAlternativeTap;

  /// Called when a therapist-owned field is edited: (section title, text).
  final void Function(String, String) onUserFieldChanged;

  final Map<String, String> userFieldValues;

  @override
  Widget build(BuildContext context) {
    if (turn.isRefusal) {
      return _RefusalView(turn: turn, onAlternativeTap: onAlternativeTap);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (turn.wasDegraded) _DegradedBanner(reason: turn.degradeReason),
        for (final section in turn.sections)
          _SectionView(
            section: section,
            value: userFieldValues[section.title] ?? '',
            onChanged: (v) => onUserFieldChanged(section.title, v),
          ),
        if (turn.suggestedQuestions.isNotEmpty)
          _SuggestedQuestionsView(questions: turn.suggestedQuestions),
        // Jeden znacznik na CALA ture, na jej koncu — jak stopka.
        // Art. 50 AI Act wymaga oznaczenia tresci generowanej; wymaga
        // tego od TRESCI, nie od kazdego naglowka, a znacznik w wierszu
        // tytulu zgniatal dluzsze tytuly do kolumny pojedynczych slow.
        if (_turnCarriesAiContent)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Align(alignment: Alignment.centerRight, child: _AiMarker()),
          ),
      ],
    );
  }

  /// Czy tura niesie tresc wygenerowana (hipotezy lub sugerowane
  /// pytania), ktora art. 50 kaze oznaczyc.
  bool get _turnCarriesAiContent =>
      turn.suggestedQuestions.isNotEmpty ||
      turn.sections.any((s) => s.needsAiMarking);
}

// ── Degradation ────────────────────────────────────────────────────────

/// Says the answer was reduced and why.
///
/// Silence here would be worse than the reduction itself: a therapist who
/// asked for a conceptualization and got quotes without explanation would
/// reasonably conclude the feature does not work, rather than that it was
/// restricted for a reason they can act on.
class _DegradedBanner extends StatelessWidget {
  const _DegradedBanner({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    // TODO(i18n): move to .arb before release.
    final text = switch (reason) {
      'quota' =>
        'Miesięczny budżet rozmów został wyczerpany — pokazuję materiał źródłowy zamiast analizy.',
      'defined_ops' =>
        'Funkcje analityczne są tymczasowo ograniczone — pokazuję materiał źródłowy.',
      'verifier_block' =>
        'Pełna analiza nie przeszła kontroli jakości — pokazuję sam materiał źródłowy. Możesz zadać pytanie ponownie.',
      'low_conf' =>
        'Nie mam pewności, o co dokładnie pytasz — pokazuję to, co znalazłem. Doprecyzuj, jeśli chodziło o coś innego.',
      _ => 'Odpowiedź została ograniczona.',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EuphireColors.ember.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EuphireColors.ember.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: EuphireColors.ember,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: EuphireColors.mist,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sections ───────────────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.value,
    required this.onChanged,
  });

  final ChatSection section;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (section.kind == ChatSectionKind.userOnly) {
      return _UserOnlyField(
        title: section.title,
        value: value,
        onChanged: onChanged,
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tytul na pelna szerokosc. Znacznik 'hipoteza AI' stal tu w
          // wierszu obok i przy dluzszych tytulach zgniatal je do
          // kolumny pojedynczych slow; od 20.08 znacznik stoi RAZ, na
          // koncu tury (AiChatTurnView.build) — art. 50 wymaga
          // oznaczenia tresci, nie kazdego naglowka z osobna.
          Text(
            section.title,
            style: const TextStyle(
              color: EuphireColors.frostWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (section.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Markdown, nie Text. Model pisze etykiety statusu jako
            // **Obserwacja:** / **Hipoteza:** / **Alternatywa:** — to
            // wymog soczewek, nie ozdoba — a serwer sklada zastrzezenia
            // w liste "- ". Renderowane zwyklym Text-em pokazywaly sie
            // jako surowe gwiazdki i myslniki (zgloszenie 21.08).
            //
            // Sciezka zapasowa (rozmowa wczytana z notatki) uzywala
            // MarkdownBody od poczatku, wiec ta sama tura wygladala
            // inaczej przed i po ponownym otwarciu czatu. Zrodlem prawdy
            // jest wersja sformatowana.
            MarkdownBody(
              data: section.body,
              styleSheet: withQuoteStyle(
                MarkdownStyleSheet(
                  p: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.ember,
                  ),
                  em: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontStyle: FontStyle.italic,
                    color: EuphireColors.mist,
                  ),
                  listBullet: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist,
                    fontSize: 14,
                  ),
                  blockSpacing: 6,
                ),
              ),
            ),
          ],
          if (section.quotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _QuotesExpander(quotes: section.quotes),
          ],
        ],
      ),
    );
  }
}

/// The AI Act article 50 marker on generated clinical material.
class _AiMarker extends StatelessWidget {
  const _AiMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EuphireColors.aurora.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EuphireColors.aurora.withValues(alpha: 0.5)),
      ),
      // TODO(i18n): move to .arb before release.
      child: const Text(
        'hipoteza AI — do weryfikacji',
        style: TextStyle(
          color: EuphireColors.mist,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Expandable evidence.
///
/// Collapsed by default so the answer stays readable, but the count is
/// always visible: "3 cytaty" tells the therapist at a glance that the
/// claim is grounded, and one tap shows in what.
class _QuotesExpander extends StatefulWidget {
  const _QuotesExpander({required this.quotes});
  final List<ChatQuote> quotes;

  @override
  State<_QuotesExpander> createState() => _QuotesExpanderState();
}

class _QuotesExpanderState extends State<_QuotesExpander> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: EuphireColors.ember,
                ),
                const SizedBox(width: 4),
                Text(
                  // TODO(i18n): Polish plural forms belong in .arb.
                  '${widget.quotes.length} ${_plural(widget.quotes.length)}',
                  style: const TextStyle(
                    color: EuphireColors.ember,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          for (final q in widget.quotes) _QuoteCard(quote: q),
      ],
    );
  }

  static String _plural(int n) {
    if (n == 1) return 'cytat';
    final last = n % 10;
    final tens = n % 100;
    if (last >= 2 && last <= 4 && !(tens >= 12 && tens <= 14)) return 'cytaty';
    return 'cytatów';
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final ChatQuote quote;

  @override
  Widget build(BuildContext context) {
    final when = quote.sessionAt;
    final header = [
      if (quote.speaker.isNotEmpty) quote.speaker,
      if (when != null) '${when.day}.${when.month}.${when.year}',
      _timestamp(quote.tsStartMs),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EuphireColors.surfaceTeal.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: EuphireColors.ember.withValues(alpha: 0.6),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: TextStyle(
              color: EuphireColors.mist.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Shown verbatim, pseudonymization tokens included. Hiding them
          // would let the therapist believe they are reading the complete
          // utterance (open decision D2).
          Text(
            quote.text,
            style: const TextStyle(
              color: EuphireColors.frostWhite,
              fontSize: 13.5,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  static String _timestamp(int ms) {
    final total = ms ~/ 1000;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// A field that belongs to the therapist.
///
/// It arrives empty because the schema sent to the model had no such
/// field at all. The styling says so — a different surface, an explicit
/// label, and a cursor — so the boundary between what the system produced
/// and what the clinician concluded stays legible in the saved note.
class _UserOnlyField extends StatelessWidget {
  const _UserOnlyField({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EuphireColors.nocturne.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: EuphireColors.evergreen.withValues(alpha: 0.9),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 17,
                color: EuphireColors.mist,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: EuphireColors.frostWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            maxLines: null,
            minLines: 2,
            style: const TextStyle(
              color: EuphireColors.frostWhite,
              fontSize: 14,
              height: 1.45,
            ),
            decoration: InputDecoration(
              isDense: true,
              // TODO(i18n): move to .arb before release.
              hintText: 'To pole należy do Ciebie — model go nie wypełnia.',
              hintStyle: TextStyle(
                color: EuphireColors.mist.withValues(alpha: 0.55),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggested questions ────────────────────────────────────────────────

class _SuggestedQuestionsView extends StatelessWidget {
  const _SuggestedQuestionsView({required this.questions});
  final List<ChatSuggestedQuestion> questions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO(i18n): move to .arb before release.
          const Text(
            'Pytania do rozważenia',
            style: TextStyle(
              color: EuphireColors.frostWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final q in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${q.question}',
                    style: const TextStyle(
                      color: EuphireColors.mist,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (q.quotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _QuotesExpander(quotes: q.quotes),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Refusal ────────────────────────────────────────────────────────────

class _RefusalView extends StatelessWidget {
  const _RefusalView({required this.turn, required this.onAlternativeTap});

  final ChatTurnResult turn;
  final ValueChanged<String> onAlternativeTap;

  @override
  Widget build(BuildContext context) {
    final refusal = turn.refusal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _message(refusal?.messageKey ?? ''),
          style: const TextStyle(
            color: EuphireColors.mist,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        if (refusal != null && refusal.alternatives.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final alt in refusal.alternatives)
                if (_altLabel(alt.labelKey) != null)
                  ActionChip(
                    label: Text(
                      _altLabel(alt.labelKey)!,
                      style: const TextStyle(
                        color: EuphireColors.frostWhite,
                        fontSize: 12.5,
                      ),
                    ),
                    backgroundColor: EuphireColors.surfaceTeal,
                    side: BorderSide(
                      color: EuphireColors.glassBorder.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      final prefill = _altPrefill(alt.prefillKey);
                      if (prefill != null) onAlternativeTap(prefill);
                    },
                  ),
            ],
          ),
        ],
        if (refusal?.showCrisisInformation ?? false) ...[
          const SizedBox(height: 14),
          const _CrisisInformation(),
        ],
      ],
    );
  }

  // TODO(i18n): these maps are the .arb contract; keys come from the
  // server so the two must be kept in step. A key with no entry renders
  // the generic message rather than the raw key — a therapist must never
  // be shown "chat.refusal.diagnosis".
  static String _message(String key) {
    const map = {
      'chat.refusal.diagnosis':
          'Nie stawiam rozpoznań. Mogę natomiast zaproponować konceptualizację przypadku — czyli rozumienie tego, co się dzieje, oparte na cytatach z sesji.',
      'chat.refusal.medication':
          'Nie wypowiadam się o farmakoterapii. To decyzja lekarza prowadzącego.',
      'chat.refusal.risk':
          'Nie oceniam ryzyka. To wymaga Twojej bezpośredniej oceny klinicznej i, jeśli sytuacja tego wymaga, kontaktu ze służbami.',
      'chat.refusal.out_of_scope':
          'Wspieram Cię wyłącznie w pracy z klientem i przebiegiem sesji.',
      'chat.refusal.unclear':
          'Nie zrozumiałem pytania na tyle pewnie, żeby odpowiedzieć. Spróbuj sformułować je inaczej.',
      'chat.refusal.verifier_blocked':
          'Przygotowana odpowiedź nie przeszła kontroli jakości i nie została pokazana. To zadziałało zgodnie z założeniem.',
    };
    return map[key] ?? 'Nie mogę odpowiedzieć na to pytanie w tym trybie.';
  }

  static String? _altLabel(String key) => const {
    'chat.alt.conceptualization': 'Zamiast tego: konceptualizacja',
    'chat.alt.find_quotes': 'Pokaż cytaty na ten temat',
    'chat.alt.consult_physician': 'Skonsultuj z lekarzem',
    'chat.alt.consult_supervisor': 'Skonsultuj z superwizorem',
    'chat.alt.crisis_resources': 'Informacje kryzysowe',
    'chat.alt.scope_explainer': 'W czym mogę pomóc?',
  }[key];

  static String? _altPrefill(String key) => const {
    'chat.prefill.conceptualization':
        'Jak można rozumieć to, co dzieje się z klientem?',
    'chat.prefill.find_quotes': 'Pokaż fragmenty sesji na ten temat',
  }[key];
}

/// Crisis information.
///
/// Rendered from constants, never from the model, and reachable even when
/// the chat is switched off entirely (ADR section 11). This is the one
/// piece of the surface that must not depend on anything working.
class _CrisisInformation extends StatelessWidget {
  const _CrisisInformation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EuphireColors.magma.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EuphireColors.magma.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // TODO(i18n): move to .arb before release.
          Text(
            'W sytuacji kryzysowej',
            style: TextStyle(
              color: EuphireColors.frostWhite,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '112 — numer alarmowy\n'
            '800 70 2222 — Centrum Wsparcia dla osób w kryzysie psychicznym (całodobowo)\n'
            '116 111 — Telefon zaufania dla dzieci i młodzieży',
            style: TextStyle(
              color: EuphireColors.mist,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
