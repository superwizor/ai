import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/utils/action_plan_extractor.dart';

void main() {
  group('extractActionPlan — ATX headings', () {
    test('PL "## Plan działania klienta" captures body until next ##', () {
      const md = '''
## Podsumowanie sesji
Klient zgłasza bóle głowy.

## Plan działania klienta
- **Zadanie 1:** Dziennik myśli.
- **Zadanie 2:** Spacer 10 minut dziennie.

## Propozycje interwencji
Praca z pustym krzesłem.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('Zadanie 1'));
      expect(d.text, contains('Spacer 10 minut'));
      expect(d.text, isNot(contains('pustym krzesłem')));
      expect(d.text, isNot(contains('bóle głowy')));
    });

    test('EN "## Client Action Plan" works', () {
      const md = '''
## Session Summary
Headaches reported.

## Client Action Plan
- Task 1: Thought diary.
- Task 2: 10-minute walk.

## Proposed Interventions
Empty chair work.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('Thought diary'));
      expect(d.text, contains('10-minute walk'));
      expect(d.text, isNot(contains('Empty chair')));
    });
  });

  group('extractActionPlan — bold-as-heading (LLM often emits these)', () {
    test('PL "**Plan działania klienta**" bold heading captures body', () {
      const md = '''
**Podsumowanie sesji**
Klient zgłasza bóle głowy.

**Plan działania klienta**
- **Zadanie 1:** Dziennik myśli.
- **Zadanie 2:** Spacer 10 minut dziennie.

**Propozycje interwencji**
Praca z pustym krzesłem.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('Zadanie 1'));
      expect(d.text, contains('Spacer 10 minut'));
      // The next bold "section" must end the capture.
      expect(d.text, isNot(contains('pustym krzesłem')));
      // Per-task bold sub-labels must NOT truncate the body.
      expect(d.text, contains('Dziennik myśli'));
    });

    test('bold heading with trailing colon "**Action plan:**"', () {
      const md = '''
**Summary**
Some text.

**Action plan:**
- Do the breathing exercise.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('breathing exercise'));
    });
  });

  group('extractActionPlan — alternate modality section names', () {
    test('PL "## Inspiracje Między Sesjami" is recognized', () {
      const md = '''
## Bilans Sesji
Coś tam.

## Inspiracje Między Sesjami
- Mikro-praktyka wdzięczności.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('wdzięczności'));
    });

    test('EN "## Between-Session Inspirations" is recognized', () {
      const md = '''
## Session Balance
Stuff.

## Between-Session Inspirations
- Gratitude micro-practice.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('Gratitude micro-practice'));
    });
  });

  group('extractActionPlan — priority + edge cases', () {
    test('specific "Plan działania klienta" beats broad "Zadania"', () {
      const md = '''
## Zadania
Broad section.

## Plan działania klienta
The real plan.
''';
      final d = extractActionPlan(md);
      expect(d.text, contains('The real plan'));
      expect(d.text, isNot(contains('Broad section')));
    });

    test('no matching heading → empty text', () {
      const md = '''
## Podsumowanie sesji
Tylko podsumowanie, brak planu.
''';
      final d = extractActionPlan(md);
      expect(d.text, isEmpty);
    });

    test('title uses prefix + session date', () {
      final d = extractActionPlan('## Plan działania klienta\nFoo',
          sessionDate: DateTime(2026, 6, 1), titlePrefix: 'Plan działania');
      expect(d.title, 'Plan działania — 01.06.2026');
    });
  });
}
