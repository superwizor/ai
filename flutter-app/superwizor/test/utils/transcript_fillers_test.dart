// Regresja zgłoszona z produkcji (2026-08-01): przełącznik „Ukryj
// przerywniki" wstawiał w transkrypcję dosłowne `$1` zamiast usuwać
// przerywnik — „Dzień dobry pani Agnieszko.$1 witam ponownie.".
//
// Przyczyna: String.replaceAll w Darcie nie rozwija odwołań do grup
// (inaczej niż w JavaScripcie) i wstawia `$1` jako tekst. Do
// podstawienia grupy służy replaceAllMapped.

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/utils/transcript_fillers.dart';

void main() {
  group('stripFillers', () {
    // Ten test jest sednem zgłoszenia. Gdyby ktoś wrócił do replaceAll,
    // wynik znów zawierałby "$1".
    test('nigdy nie wstawia dosłownego \$1', () {
      const inputs = [
        'Dzień dobry pani Agnieszko. Yyy, witam ponownie.',
        'Okej, dobrze. Eee ja myślę',
        'Tak , eee . I co dalej ?',
      ];
      for (final input in inputs) {
        final out = stripFillers(input);
        expect(out, isNot(contains(r'$1')),
            reason: 'replaceAll nie podstawia grup — użyj replaceAllMapped');
        expect(out, isNot(contains(r'$')));
      }
    });

    test('usuwa przerywnik i sprząta interpunkcję po nim', () {
      expect(
        stripFillers('Dzień dobry pani Agnieszko. Yyy, witam ponownie.'),
        'Dzień dobry pani Agnieszko. witam ponownie.',
      );
    });

    // Przerywnik między dwoma znakami interpunkcyjnymi zostawiał po
    // sobie sklejkę „., " albo „,." — bez tej reguły transkrypcja
    // wyglądała na uszkodzoną, choć \$1 już nie było.
    test('sklejona interpunkcja redukuje sie do znaku konczacego zdanie', () {
      expect(stripFillers('Tak , eee . I co dalej ?'), 'Tak. I co dalej?');
    });

    test('spacja przed interpunkcją znika razem z przerywnikiem', () {
      expect(stripFillers('Tak eee , dobrze'), 'Tak, dobrze');
    });

    test('zdanie nie zaczyna się od osieroconej interpunkcji', () {
      final out = stripFillers('Yyy, a jak z emocjami?');
      expect(out.startsWith(','), isFalse);
      expect(out.startsWith('.'), isFalse);
      expect(out, 'a jak z emocjami?');
    });

    test('podwójne przecinki po usunięciu scalają się w jeden', () {
      expect(stripFillers('No, yyy, dobrze'), 'No, dobrze');
    });

    test('typowe polskie przerywniki', () {
      for (final f in ['yyy', 'eee', 'mhm', 'ehm', 'yhy', 'aaa']) {
        expect(stripFillers('Tak $f dobrze'), 'Tak dobrze',
            reason: 'przerywnik "$f" powinien zniknąć');
      }
    });

    // Najważniejsze zabezpieczenie w drugą stronę: nie wolno okaleczać
    // prawdziwych słów zawierających te litery.
    test('nie tyka prawdziwych słów', () {
      const untouched = [
        'Mama ma ale',
        'Ewa jest wesoła',
        'To jest bardzo dobre',
        'Aleja Yorku',
      ];
      for (final s in untouched) {
        expect(stripFillers(s), s, reason: 'słowo okaleczone: "$s"');
      }
    });

    test('tekst bez przerywników zostaje bez zmian', () {
      const s = 'Fantastycznie.';
      expect(stripFillers(s), s);
    });

    test('pusty tekst nie wybucha', () {
      expect(stripFillers(''), '');
      expect(stripFillers('   '), '');
    });
  });
}
