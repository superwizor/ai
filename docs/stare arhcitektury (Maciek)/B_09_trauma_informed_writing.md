# 09_TRAUMA_INFORMED_WRITING.md

**WERSJA:** 1.0_Superwizor
**STATUS:** DOKUMENT KONTROLI TREŚCI I ARB (UX WRITING)

Połączenie starych reguł unikania "AI voice" i brutalnego korporacyjnego pisania z absolutnymi wymogami **Trauma-Informed Care** z Design Systemu Superwizor AI.

## 1. Zdejmujemy brzemię presji z układu nerwowego
Główny cel przy projektowaniu etykiet (Label), dialogów błędu (Error State) czy pustych stanów (Empty State) aplikacji: Maszyna ma rozumieć, odciążać, nigdy oceniać ani straszyć.

### Zamiast wywoływać winę, zaoferuj rozwiązanie
- ❌ **Error / AI Form:** "Dane podsłuchanej sesji są niepoprawne." (Brzmi jak strach, oskarża).
- ✅ **Opisowy UX:** "Nie mogliśmy zapisać fragmentu dźwięku. Spróbuj mówić bliżej telefonu, a resztą zajmiemy się my."

## 2. Anty-słownik (Zakazane Konstrukcje z generowania AI)
Sztuczna Inteligencja ma tendencję do tworzenia korporacyjnego bełkotu bez emocji, który uderza w dysonans psychologiczny w aplikacji medycznej.

- ❌ "W dzisiejszym dynamicznym świecie..." / "Kompleksowo, kluczowo".
- ❌ Hedging: "Potencjalnie mogłoby to pomóc w terapii...".
- ✅ Pisz wprost, stawiaj twarde kropki. "Ten fragment sesji zapiszemy do RAG.".
- ❌ Zasada trójek AI: AI kocha pisać "Oszczędza Twój czas, nerwy i optymalizuje pracę". Oducz to siebie. Zostaw jedno, wybitne stwierdzenie.

## 3. Żelazny Kodeks UX Superwizor AI
- **Zakaz Toksycznej Pozytywności**: Zero pompowania balonu "Zaraz poczujesz się niesamowicie!". Aplikacja mówi: "To zrozumiałe, że po 8 pacjentach potrzebujesz odpocząć".
- **Bez strony biernej (Zombie Nouns)**: "Dokonano zapisu" ➔ "Zapisaliśmy sesję na bezpiecznym serwerze.".
- **Kapitalizacja Zaimków**: **Ty, Twój, Ciebie**. Zaś apka mówi o sobie z małej: **my, nasze, od nas**. Jesteśmy służebni.

## 4. Krok Wstecz PRZED wypchnięciem tekstu 
*(Spędź nad tym 10 sekund)*
1. Czy w błędzie jest cudzysłów błędu?
2. Czy kazałeś pacjentowi "poczekać cierpliwie"? (Błąd! Bądź rzeczowy).
3. Czy komunikaty są zdefiniowane i podpięte do plików L10n i mapowane w `.arb`? We Flutterze nic nie wklejamy na twardo bez kluczy!
