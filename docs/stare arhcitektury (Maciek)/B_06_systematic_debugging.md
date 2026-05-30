# 06_SYSTEMATIC_DEBUGGING.md

**WERSJA:** 1.0_Superwizor
**STATUS:** DOKUMENT PROCESOWY (DEBUGOWANIE)

Losowe strzelanie poprawkami i szybkie łatki maskują prawdziwe problemy. Poniższy proces to podstawa rozwiązywania problemów w architekturze Superwizor AI (Flutter + Firebase).

## 🚨 Żelazna Reguła
**ŻADNYCH FIXÓW BEZ ZNALEZIENIA PRZYCZYNY (ROOT CAUSE).**

## Faza 1: Śledztwo (Root Cause Investigation)
Zanim napiszesz linijkę kodu naprawiającego błąd:
1. **Przeczytaj błędy do końca** - Przejrzyj logi Crashlytics, stack trace Fluttera lub Firebase Functions od góry do dołu. Zignorowanie linijek typu `Unhandled Exception` mści się podwójnie.
2. **Reprodukcja** - Spróbuj to powtórzyć. Jakie były dokładne kroki?
3. **Izolacja Systemu** - Mamy aplikację mobilną `Flutter`, warstwę chmurową `Cloud Functions` i bazę `Firestore`. Gdzie pękło? Zaloguj wejście/wyjście w Cloud Functions, sprawdź czy JSON z transkryptu dotarł poprawnie z telefonu.
4. **Złota Reguła Firebase** - Zweryfikuj reguły bezpieczeństwa (Security Rules). 90% błędów połączenia `PERMISSION_DENIED` wynika z izolacji RLS (Profil Pacjenta vs Profil B2B).

## Faza 2: Analiza Wzorców
- Znajdź działający komponent w kodzie (`src/features/...`).
- Zobacz, jak wywoływany jest poprawny serwis w innej części aplikacji. Co je różni?

## Faza 3: Hipoteza i Test
1. **Jedna Hipoteza Jednocześnie** - Np. "Wektor nie przechodzi do RAG, ponieważ zapomnieliśmy zdeserializować datę w modelu pacjenta".
2. **Minimalny Test** - Dodaj jednostkowy test (`mocktail` w Dart), albo print upewniający o typie zmiennej w funkcji. Nie przebudowuj całego repozytorium.

## Faza 4: Implementacja Fixa
- Napraw przyczynę. Jeden fix na commit. Żadnego dorzucania "przy okazji zrefaktoryzowałem to obok".
- Przepuść Flutter widget tests.
- Jeśli Twoje łatki "odsłaniają kolejne bugi gdzie indziej" (efekt domina) - zatrzymaj się. Architektura pęka. Skonsultuj zmianę układu `Providerów` lub całych powiązań bazy danych.
