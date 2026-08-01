/// Usuwanie przerywników („yyy", „eee", „mhm") z tekstu transkrypcji.
///
/// Wyciągnięte z prywatnego gettera `_visibleSegments` w
/// transcript_screen.dart, żeby dało się to przetestować. Powodem był
/// błąd zgłoszony z produkcji: przełącznik „Ukryj przerywniki" wstawiał
/// w tekst dosłowne `$1` zamiast usuwać przerywnik
/// („Dzień dobry pani Agnieszko.$1 witam ponownie.").
///
/// Przyczyna: `String.replaceAll` w Darcie NIE rozwija odwołań do grup —
/// w odróżnieniu od JavaScriptu wstawia `$1` jako zwykły tekst. Do
/// podstawienia grupy służy `replaceAllMapped`. Ten sam błąd siedział
/// w pdf_exporter.dart i psuł treść eksportowanych raportów.
library;

/// Polskie litery — używane w lookaroundach, żeby nie wycinać przerywnika
/// ze środka prawdziwego słowa („mama" nie może stracić „ma").
const _plLetters = 'a-zA-ZęćłńóśźżĄĘĆŁŃÓŚŹŻ';

/// Dopasowuje typowe polskie przerywniki:
/// - wtrącenia: yhy, ehe, yhm, mhm, ehm, uhm, oho
/// - powtórzenia y/e/a/o o długości >= 2 (yyy, eee, aaa)
/// - pojedyncze y, e na granicy słowa
/// - formy z myślnikiem: e-e, y-y, „e myślnik e"
final RegExp fillerRegex = RegExp(
  '(?<![$_plLetters])(?:yhm|mhm|ehm|uhm|yhy|ehe|oho)(?![$_plLetters])|'
  '(?<![$_plLetters])(?:[yYeEaAoO]{2,})(?![$_plLetters])|'
  '(?<![$_plLetters])[yYeE](?:\\s*(?:-|myślnik|,?\\s*myślnik|,?\\s*-)\\s*[yYeE])+(?![$_plLetters])|'
  '(?<![$_plLetters])(?:[yYeE])(?![$_plLetters])',
  caseSensitive: false,
);

/// Zwraca [text] bez przerywników, z posprzątaną interpunkcją.
///
/// Samo wycięcie przerywnika zostawia śmieci — podwójne przecinki,
/// spację przed kropką, przecinek na początku zdania — więc porządki są
/// częścią kontraktu tej funkcji, nie dodatkiem.
String stripFillers(String text) {
  final withoutFillers = text.replaceAll(fillerRegex, '');
  return withoutFillers
      // ", ," → ","
      .replaceAll(RegExp(r',\s*,'), ',')
      // Spacja przed interpunkcją → sama interpunkcja. TU siedział błąd:
      // replaceAll wstawiał dosłowne "$1".
      .replaceAllMapped(RegExp(r'\s+([.,?!])'), (m) => m[1] ?? '')
      // Przerywnik stał między dwoma znakami interpunkcyjnymi, więc po
      // jego usunięciu sklejają się w bezsens: „Agnieszko., witam"
      // albo „Tak,. I co dalej". Znak kończący zdanie wygrywa
      // z przecinkiem, niezależnie od kolejności.
      .replaceAllMapped(RegExp(r'([.?!])\s*,'), (m) => m[1] ?? '')
      .replaceAllMapped(RegExp(r',\s*([.?!])'), (m) => m[1] ?? '')
      // Zdanie nie zaczyna się od interpunkcji zostawionej po przerywniku.
      .replaceAll(RegExp(r'^\s*[,.]\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
