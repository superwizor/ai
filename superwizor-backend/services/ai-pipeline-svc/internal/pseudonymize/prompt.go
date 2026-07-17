package pseudonymize

// PIIPromptRules — kanoniczne instrukcje ekstrakcji PII (docs/41),
// współdzielone przez: sekcję # PII w prompcie call-1 (llm-worker),
// mini-call extractPIIFallback oraz bramkę cmd/pii-eval. Jedno źródło
// prawdy: każda poprawka jakości ląduje wszędzie naraz i przechodzi
// przez eval przed wdrożeniem.
//
// Sformułowania kalibrowane evalem 2026-07-17: jawna lista przypadków
// gramatycznych (model pomijał celownik), jawne "także duże miasta"
// (model zostawiał Poznań) i jawny zakaz zdrobnień imion (model
// wpisywał "Marysia"/"Piotruś" jako encje).
const PIIPromptRules = `- WYŁĄCZNIE linie w formacie [TOKEN]: forma1 | forma2 | ... — nic więcej.
- Kategorie tokenów: [NAZWISKO-n] (nazwiska), [PRACODAWCA(-n)] (firmy i instytucje-pracodawcy — TAKŻE byłe miejsca pracy, wspomniane mimochodem i znane sieci/marki jak Ikea czy Biedronka, gdy padają jako miejsce pracy), [SZKOŁA(-n)], [MIEJSCOWOŚĆ-x], [ADRES] (ulice z numerami), [DATA-URODZENIA].
- Dla każdej encji przejdź transkrypt zdanie po zdaniu i wypisz WSZYSTKIE występujące formy gramatyczne — każdy przypadek (mianownik, dopełniacz, CELOWNIK, biernik, narzędnik, miejscownik), liczbę mnogą i formy przekręcone/błędnie zapisane — dokładnie tak, jak zapisane w tekście.
- [MIEJSCOWOŚĆ-x]: KAŻDA nazwa miejscowości i dzielnicy — TAKŻE duże miasta (Warszawa, Kraków, Poznań, Wrocław itd.).
- IMIONA I ZDROBNIENIA IMION (np. Anna, Karol, Kasia, Marysia, Piotruś, Staś) POMIŃ CAŁKOWICIE — nie umieszczaj ich w żadnym tokenie ani w formach.
- Nazwy leków, terminy medyczne i zawody to NIE są dane identyfikujące — pomiń.
- NIE zgaduj form nieobecnych w tekście.
- Brak PII → pomiń sekcję / zwróć pustą odpowiedź.`
