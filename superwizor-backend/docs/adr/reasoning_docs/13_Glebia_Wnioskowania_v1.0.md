# 13. Głębia wnioskowania — integracja między-konstruktowa, dowody wzorcowe, kalibracja abstencji

| Pole | Wartość |
|---|---|
| Plik | `docs/13_Glebia_Wnioskowania.md` |
| Wersja | 1.0 |
| Data | 22 sierpnia 2026 r. |
| Status | Projekt — do zatwierdzenia decyzji D1–D3 (sekcja 13) |
| Impuls | Ocena architektury v1.1 pod kątem *depth & breadth of reasoning*: ryzyko raportów poprawnych, ale fragmentarycznych — trafne atomy bez warstwy integracyjnej, w której mieszka wartość superwizyjna |
| Dokumenty powiązane | `11_Architektura_Wnioskowania_Ontologia.md` v1.2 (potok bazowy — ten dokument go rozszerza); `12_Zarzadzanie_Wiedza_Domenowa.md`; ADR-0YY; ADR-0XX; feedback recenzenta (sierpień 2026) |
| Zakres | Raport główny (potok S1–S5) i — w ograniczonym zakresie — AI Chat; wszystkie modalności, pilot PPT |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-22 | Pierwsza wersja: diagnoza czterech mechanizmów spłycenia, S1.5 (dowody wzorcowe), S2b (integracja między-konstruktowa) + R8, rozwarstwienie R4 per status epistemiczny, metryki głębi, dwustronna kalibracja abstencji, tickety T13–T18. |

---

## 1. Streszczenie decyzyjne

Architektura v1.1 gwarantuje **podłogę**: brak konfabulacji, wierność taksonomii, pełną proweniencję. Nie gwarantuje **sufitu**: bez dodatkowych mechanizmów istnieje realne ryzyko raportów złożonych z trafnych, izolowanych twierdzeń o niskiej wartości superwizyjnej — bo głębia kliniczna rzadko mieszka w pojedynczym konstrukcie, a prawie zawsze w **relacjach** (konflikt X uruchamia się w obszarze Y; wzorzec Z powtarza się w trzech sesjach; obserwacja A przeczy hipotezie B) oraz we **wzorcach nad sekwencjami**, które nie są pojedynczym cytatem.

Połowa funkcji wskazanych przez recenzenta jako sedno wartości narzędzia („trzeci raz powtarza się wzorzec", „ten fragment przeczy Twojej pierwszej hipotezie", „tego mogłaś nie zauważyć") to wnioski **relacyjne** — a w v1.1 żaden etap nie ma prawa ich wygenerować: S2 mapuje konstrukty w izolowanych wywołaniach, S4 celowo tylko pisze z zatwierdzonych twierdzeń.

Rozwiązanie — zasada przewodnia: **głębia wewnątrz szyn, nie zamiast szyn**. Nie luzujemy żadnego ograniczenia antykonfabulacyjnego; dajemy głębi legalne miejsce i legalne dowody:

1. **S1.5 — dowody wzorcowe (pattern evidence):** deterministyczne obliczenia nad spanami (rekurencja, współwystępowanie, sekwencja, rozkład, trend) produkują cytowalne obiekty z pełną proweniencją. „Wzorzec" staje się dowodem, nie dopowiedzeniem.
2. **S2b — etap integracji między-konstruktowej:** po walidacji S3 osobny etap generuje wyłącznie **twierdzenia relacyjne** nad zatwierdzonymi twierdzeniami i wzorcami. S2b nie może wprowadzić żadnego nowego bytu klinicznego — tylko połączenia między istniejącymi; relacje przechodzą własną walidację deterministyczną (R8), w tym **monotoniczność statusu** (relacja nigdy nie jest epistemicznie mocniejsza niż najsłabszy z jej elementów).
3. **Rozwarstwienie R4 per status epistemiczny:** obserwacje — entailment ścisły; hipotezy teoretyczne — test spójności (zgodność + niesprzeczność) zamiast wynikania, z obowiązkowym markerem abdukcyjnym w renderowaniu. Rygor przesuwa się z cenzury na etykietowanie.
4. **Metryki głębi w benchmarku:** recall ustaleń eksperckich (anty-lobotomijna miara symetryczna do miar konfabulacji — system, który nic nie zmyśla, ale połowy nie widzi, obleje), nietrywialność hipotez, pokrycie integracyjne, precyzja relacji.
5. **Dwustronna kalibracja abstencji:** przeoczenie jest błędem symetrycznym do zmyślenia — w promptach, w benchmarku (próg `insufficient_data` na zestawach z danymi kompletnymi) i w telemetrii.

Granica nazwana świadomie: część głębi **celowo** zostaje po stronie terapeuty. System nie konkuruje z superwizorem w budowaniu jednej pogłębionej narracji; dowozi nieoczywiste, ugruntowane obserwacje i połączenia plus uczciwą mapę niepewności. Miarą sukcesu jest „czy terapeuta regularnie znajduje w raporcie coś, czego sam nie widział" — mierzalne w telemetrii (sekcja 9).

---

## 2. Diagnoza: cztery mechanizmy spłycenia

### 2.1. Korekta punktu odniesienia

„Głębia" raportu sprzed zmiany była w znacznej mierze **głębią pozorną**: elegancka, psychologicznie prawdopodobna narracja, która przesuwała teorię i dopisywała etiologię (feedback, sekcja 5: *local coherence* zamiast *theoretical fidelity*). Płynna proza symuluje głębię, bo spójność narracyjna jest tym, co LLM optymalizuje natywnie. Trzy elementy v1.1 głębię realnie podnoszą i pozostają bez zmian: pole `counter_evidence` wymusza myślenie dialektyczne (jednoprzebiegowy LLM prawie nigdy sam nie szuka danych przeciw); pełne L1 w kontekście S2 daje więcej ugruntowania niż szczątkowy prior parametryczny; osobne wywołanie per konstrukt to skupiona uwaga na wszystkich spanach naraz.

### 2.2. Mechanizmy spłycenia w v1.1

| # | Mechanizm | Dlaczego występuje | Objaw w raportach | Adres |
|---|---|---|---|---|
| A | **Brak etapu integracji między-konstruktowej** (luka największa) | S2 mapuje konstrukty w izolowanych wywołaniach; S4 tylko pisze z zatwierdzonych twierdzeń — integracja nie ma domu | Lista trafnych, rozłącznych twierdzeń; brak powiązań, napięć, sekwencji, sprzeczności | S2b + R8 (sekcja 4) |
| B | **Dowody wyłącznie spanowe** gubią wzorce | `min_evidence` liczone w cytatach verbatim premiuje to, co powiedziane wprost; meta-obserwacja nad sekwencją spanów („klient zmienia temat przy każdej wzmiance o ojcu") nie jest spanem — walidator ją zabije albo model jej nie zgłosi | Ślepota na rekurencję, współwystępowanie, sekwencje; utrata materiału implicytnego | S1.5 (sekcja 3) |
| C | **R4 jednolity dusi abdukcję** | Wnioskowanie kliniczne jest abdukcyjne — hipoteza *wyjaśnia* dane, nie *wynika* z nich; test „czy fragment wspiera twierdzenie" ścina hipotezy teoretyczne albo spycha je w asekuracyjną papkę | Hipotezy banalne, przeformułowujące obserwacje; brak odważnych, oznaczonych hipotez wyjaśniających | Rozwarstwienie R4 (sekcja 5) |
| D | **Dwa wektory Goodharta** | (i) prompt premiujący `insufficient_data` bez lustrzanej kary za przeoczenie wychowuje system leniwy poznawczo; (ii) metrykę „≥ 2 hipotezy" zaspokajają dwie parafrazy tej samej myśli | Ciche przeoczenia (niemierzalne w v1.1 — benchmark mierzy tylko, czy system nie zmyśla); pseudo-alternatywy | Kalibracja dwustronna (sekcja 6) + metryki głębi (sekcja 7) |

---

## 3. S1.5 — Dowody wzorcowe (pattern evidence)

### 3.1. Definicja i zasady

Dowód wzorcowy to obiekt pierwszej klasy obliczony **deterministycznie** (kod, nie LLM) nad spanami S1, z pełną proweniencją do spanów bazowych. Wzorce są **dowodami, nie twierdzeniami** — nie niosą interpretacji; interpretację nadaje im dopiero S2/S2b, cytując je jako evidence.

Zasady twarde:

- P1: etap w całości deterministyczny — ten sam zestaw spanów zawsze daje ten sam zestaw wzorców; metody zarejestrowane w kodzie z wersją (`method_registry`), wersja w metadanych każdego wzorca.
- P2: każdy wzorzec referencuje ≥ 2 spany (wyjątek: `distribution` — agregat sesyjny).
- P3: wzorce nie wprowadzają treści — pola tekstowe ograniczone do etykiet tematów już obecnych w `topics[]` spanów.
- P4: brak wzorców „nieobecności" w v1 (sekcja 3.4).

### 3.2. Typy wzorców (v1) i schemat

```
pattern{
  pattern_id, type ∈ {recurrence, co_occurrence, sequence, distribution, trend},
  spans: [span_id],            # proweniencja — zawsze
  sessions: [session_id],
  method: string, method_version: semver,
  params: {...},               # np. okno czasowe, próg
  computed_stats: {...}        # np. liczność, rozpiętość sesji
}
```

| Typ | Definicja operacyjna | Przykład użycia w raporcie |
|---|---|---|
| `recurrence` | Temat/kategoria z `topics[]` występuje ≥ N razy w ≥ M sesjach | „Trzeci raz w materiale powtarza się wzorzec X (s07, s19, s31)" |
| `co_occurrence` | Dwa tematy współwystępują w oknie K tur częściej niż próg | Podstawa dowodowa relacji `wspolwystepowanie` w S2b |
| `sequence` | Po temacie A następuje zmiana tematu w ≤ K tur w ≥ N przypadkach | „Po wzmiance o ojcu klient zmienia temat (s04→s05, s12→s13, s27→s28)" |
| `distribution` | Rozkład tematu/kategorii per sesja (agregat) | Materiał do modelu równowagi: proporcje obszarów w wypowiedziach |
| `trend` | Istotna zmiana częstości tematu między sesjami wczesnymi a późnymi | „Temat pracy narasta od sesji 4" |

Progi (N, M, K) są parametrami metody w `method_registry`, kalibrowanymi na benchmarku — nie decyzjami promptu.

### 3.3. Implementacja

- Miejsce: rozszerzenie S1 w `llm-worker`/`clinical-svc` (obliczenia po ekstrakcji i mechanicznej weryfikacji spanów; wynik cache'owany razem ze spanami per zestaw sesji).
- Model danych: tabela `patterns` obok `spans` (sqlc), FK do spanów; `pattern_id` cytowalne w `evidence` twierdzeń i relacji na równi ze `span_id`.
- Walidator S3: akceptuje `pattern_id` w evidence; reguła zliczania do `min_evidence` — wzorzec liczy się jako liczba swoich spanów bazowych z `kind` odziedziczonym (decyzja implementacyjna w T13).
- UI: wzorce renderowane jako `pattern_notices` z klikalnymi spanami (istniejący mechanizm z dokumentu 11, teraz z realnym źródłem danych).

### 3.4. Nieobecności — świadomie odroczone do v2

Systematyczne *niepodejmowanie* tematu („klient nigdy nie mówi o…") jest klinicznie cenne, ale wymaga **bazy oczekiwań** (skąd wiadomo, że temat „powinien" się pojawić?). Bez ostrożnej definicji „brak wzmianki" staje się nową furtką do dopowiadania — dokładnie tego, co zamknęliśmy w S4. Warunki podjęcia w v2: (a) baza oczekiwań wyłącznie z jawnych źródeł (tematy zadeklarowane przez terapeutę jako obszary pracy; kategorie modelu równowagi z ontologii), nigdy z priorytetu modelu; (b) status epistemiczny zawsze `open_question`, renderowany jako pytanie, nie teza; (c) osobny podzbiór benchmarku.

---

## 4. S2b — Etap integracji między-konstruktowej

### 4.1. Pozycja w potoku i reguła wejścia

S2b działa **po S3** — na twierdzeniach już zatwierdzonych, nie na kandydatach z S2. Konsekwencja: integracja buduje wyłącznie na zwalidowanych atomach; twierdzenie graniczne odrzucone w S3 nie może zostać „uratowane" przez relację. Wejściem są: `approved_claims[]` (z osadzonymi cytatami — zwalidowane fragmenty), `patterns[]`, oraz L1/L2 dla konstruktów występujących w twierdzeniach. **S2b nie widzi surowego transkryptu** — inwersja antykonfabulacyjna z S4 obowiązuje.

```
[S3: approved_claims] ──┐
[S1.5: patterns]  ──────┼──► S2b INTEGRACJA (Gemini Pro, T=0, structured output)
[L1+L2 dla konstruktów] ┘        │  relations[] — kandydaci
                                 ▼
                          S3b WALIDACJA RELACJI (R8, deterministyczna + celowany entailment)
                                 │  approved_relations[]
                                 ▼
                          S4 (rozszerzone wejście: claims + relations + patterns)
```

### 4.2. Schemat wyjścia

```
relation{
  relation_id,
  relation_type ∈ {wspolwystepowanie, napiecie, sekwencja, sprzecznosc, wzmocnienie},
  involves: [claim_id | pattern_id],      # ≥ 2 elementy
  evidence: [span_id | pattern_id],       # dowody własne relacji
  hypothesis_text: string,                 # sformułowanie powiązania
  epistemic_status ∈ statuses,             # z monotonicznością (R8d)
  confidence: 0..1
}
```

Semantyka typów: `wspolwystepowanie` (elementy pojawiają się razem — wymaga wzorca `co_occurrence` lub wspólnych spanów), `napiecie` (elementy pozostają w konflikcie dynamicznym — np. konflikt aktualny × obszar modelu równowagi), `sekwencja` (następstwo czasowe — wymaga wzorca `sequence`), `sprzecznosc` (element przeczy elementowi — w tym: obserwacja przeczy hipotezie; wymaga celowanego testu z R8c), `wzmocnienie` (element wspiera/nasila element).

### 4.3. R8 — walidacja relacji (S3b)

| Reguła | Treść | Charakter |
|---|---|---|
| R8a | Każdy element `involves` i `evidence` istnieje w zbiorze zatwierdzonym (claims po S3, patterns z S1.5) | Deterministyczna |
| R8b | **Zakaz nowych bytów:** `hypothesis_text` nie zawiera kategorii ontologii spoza kategorii elementów `involves`; nie zawiera treści etiologicznych bez spanu (R5 stosuje się do relacji tak samo jak do twierdzeń) | Deterministyczna (słownik kategorii) + LLM-check przy wątpliwości |
| R8c | Wymogi dowodowe per typ: `sekwencja` → ≥ 1 wzorzec `sequence`; `wspolwystepowanie` → wzorzec `co_occurrence` lub ≥ 2 wspólne spany; `sprzecznosc` → celowany test entailmentu „czy treść A jest niezgodna z treścią B: tak/nie" (Flash, T=0) = tak | Mieszana |
| R8d | **Monotoniczność statusu:** status relacji nie może być mocniejszy niż najsłabszy status elementu `involves` (relacja nad hipotezami nie może być obserwacją); porządek: observation > interpretation > theoretical_hypothesis > open_question | Deterministyczna |
| R8e | Limit liczby relacji per raport (D1); nadwyżka ucinana wg `confidence` × waga typu | Deterministyczna |

Relacje odrzucone trafiają do rejestru z powodami (telemetria + benchmark), symetrycznie do R1–R7.

### 4.4. Zasada promptu S2b

„Zidentyfikuj powiązania, napięcia, sekwencje, sprzeczności i wzmocnienia **między przekazanymi ustaleniami**. Nie wprowadzaj żadnego nowego zjawiska, kategorii ani przyczyny — wolno Ci wyłącznie łączyć to, co już ustalone, i cytować przekazane dowody. Sprzeczność między ustaleniami jest wartościowym wynikiem, nie błędem do ukrycia. Jeżeli żadne nietrywialne powiązanie nie istnieje, zwróć pustą listę — to pełnoprawna odpowiedź."

### 4.5. S4 po zmianie

Wejście S4 rozszerza się o `approved_relations[]` i `patterns[]`. Renderowanie: sekcja raportu **„Powiązania i wzorce"** (relacje z linkowanymi elementami i dowodami) oraz `pattern_notices` przy konstruktach. Format przestrzeni hipotez (dokument 11, sekcja 5) bez zmian — relacje typu `sprzecznosc` zasilają pole `contradicting` hipotez, co domyka funkcję „ten fragment przeczy Twojej pierwszej hipotezie".

---

## 5. Rozwarstwienie R4 per status epistemiczny

Wnioskowanie kliniczne jest abdukcyjne: hipoteza *wyjaśnia* dane, nie *wynika* z nich logicznie. Jednolity test entailmentu stosowany do hipotez teoretycznych systematycznie je ścina albo wymusza asekuracyjne przeformułowania obserwacji. Rygor przesuwamy z **cenzury** na **etykietowanie**:

| Status | Test R4 | Kryterium | Marker w renderowaniu |
|---|---|---|---|
| `observation` | Entailment ścisły (jak w v1.1) | Każdy span z evidence: „wspiera" = tak | — |
| `interpretation` | Entailment złagodzony | ≥ 2 spany z wynikiem „tak" lub „częściowo"; żaden „nie" | „interpretacja" |
| `theoretical_hypothesis` | **Test spójności** (dwuczęściowy): (1) *zgodność* — dane w evidence są zgodne z hipotezą (pytanie: „czy ta hipoteza jest spójna z tym fragmentem: tak/nie"); (2) *niesprzeczność* — żaden span z evidence ∪ counter_evidence nie jest jawnie niezgodny z hipotezą | (1) ≥ próg zgodności; (2) zero jawnych niezgodności niezaadresowanych w `contradicting` | **Obowiązkowy marker abdukcyjny:** „hipoteza wyjaśniająca — nie wniosek z danych" |
| `open_question` | Brak testu treściowego | Wyłącznie forma pytania (walidacja składniowa) | „pytanie do sprawdzenia" |

Spany niezgodne z hipotezą nie kasują jej automatycznie — trafiają do `contradicting` i są **widoczne** w formacie przestrzeni hipotez. Hipoteza z danymi przeciw jest wartościowsza superwizyjnie niż hipoteza wygładzona; ukrywanie niezgodności byłoby powrotem pozornej głębi.

---

## 6. Dwustronna kalibracja abstencji

Problem: v1.1 nagradza `insufficient_data` jednostronnie — bez lustrzanej kary za przeoczenie system optymalizuje się w stronę asekuracji, a przeoczenia są **ciche** (benchmark v1.1 mierzy wyłącznie, czy system nie zmyśla).

Trzy poziomy korekty:

1. **Prompt (S2, S2b):** jawne nazwanie dwóch klas błędu jako symetrycznych — *zmyślenie* (twierdzenie bez oparcia) i *przeoczenie* (nieraportowanie zjawiska obecnego w danych). Instrukcja: „raportuj wszystko, co znajdujesz, z uczciwym statusem epistemicznym — obniżenie statusu jest właściwą reakcją na niepewność; pominięcie nie jest".
2. **Benchmark:** próg dwustronny — na zestawie z danymi celowo niepełnymi `insufficient_data` > 0 (jak w v1.1), **oraz** na zestawie z danymi kompletnymi `insufficient_data` ≤ 10 % (nowe). Plus metryka recall ustaleń eksperckich (sekcja 7), która czyni przeoczenia mierzalnymi wprost.
3. **Ewaluacja per konstrukt:** macierz pomyłek rozszerzona o komórkę „ekspert znalazł / system abstynował" — raportowana osobno od „ekspert znalazł / system zmapował błędnie", bo to różne defekty wymagające różnych korekt (leniwy prompt vs zła definicja L1).

---

## 7. Metryki głębi — rozszerzenie benchmarku (8.2 w dokumencie 11)

### 7.1. Rozszerzenie protokołu anotacji złotego zestawu

Konceptualizacje eksperckie w złotym zestawie zostają rozszerzone o: (a) **wagę ustalenia** per twierdzenie: `krytyczne / istotne / marginalne`; (b) **jawne relacje** między ustaleniami (typ + elementy — słownik typów wspólny z S2b); (c) przy hipotezach alternatywnych — wskazanie, czy różnią się **mechanizmem** czy sformułowaniem. To jest dodatkowa praca ekspercka nad istniejącym zestawem (koszt nazwany w D3).

### 7.2. Metryki i progi startowe

| Metryka | Definicja | Próg startowy | Charakter |
|---|---|---|---|
| **Recall ustaleń eksperckich** (miara anty-lobotomijna) | Odsetek ustaleń z konceptualizacji eksperckich, które system wydobył z poprawnym lub słabszym statusem epistemicznym | ≥ 0,70 ogółem; **≥ 0,85 dla ustaleń `krytyczne`** | Kluczowa — czyni przeoczenia mierzalnymi; symetryczna do miar konfabulacji |
| Nietrywialność hipotez | Ocena ekspercka 1–4: „czy doświadczony superwizor uznałby to za wnoszące"; para hipotez różniąca się tylko sformułowaniem (ocena ekspercka „parafraza") = fail dla pozycji | Średnia ≥ 2,5; parafrazy ≤ 10 % par | Tnie pseudo-alternatywy (Goodhart D-ii) |
| Pokrycie integracyjne | Odsetek relacji z anotacji eksperckich odnalezionych przez S2b (dopasowanie: typ + elementy) | ≥ 0,60 (kalibrować) | Mierzy mechanizm A |
| Precyzja relacji | Odsetek relacji S2b ocenionych przez eksperta jako zasadne | ≥ 0,80 | Chroni przed spamem relacyjnym |
| Recall wzorców | Odsetek wzorców wskazanych przez ekspertów (rekurencje, sekwencje) wykrytych przez S1.5 | ≥ 0,80 | Kalibruje progi metod |
| Abstencja dwustronna | `insufficient_data` na zestawie kompletnym | ≤ 10 % | Sekcja 6 |

Reguła regresji z 8.2 (spadek > 2 p.p. blokuje release) obejmuje nowe metryki. Uwaga metodologiczna, nazwana uczciwie: metryki głębi są tak dobre, jak anotacje — mierzą zgodność z ekspertem, nie głębię absolutną; rozbieżność między ekspertami w anotacji relacji jest daną (konstrukty/relacje o niskiej zgodności → wyższe progi lub status „zawsze hipoteza", spójnie z 8.1).

---

## 8. Telemetria produkcyjna głębi (rozszerzenie 8.3)

Zdarzenia (bez PII): `report_relation_generated {type, status}`, `report_relation_rejected {rule: R8a..R8e}`, `report_relation_clicked {type}`, `report_pattern_notice_shown / _clicked {pattern_type}`, `report_hypothesis_selected {id, rank}` (istniejące — teraz z rangą).

Wskaźnik nadrzędny „czy terapeuta znajduje coś, czego sam nie widział" — proxy złożone: odsetek raportów z ≥ 1 interakcją z relacją lub wzorcem; odsetek wyborów hipotezy o randze > 1. Progi przeglądu: interakcje z relacjami bliskie zeru przez kwartał → S2b nie dowozi wartości → przegląd promptu/typów/UI przed skalowaniem na kolejne modalności; `report_relation_rejected(R8b) > 10 %` → S2b próbuje przemycać nowe byty → audyt promptu.

---

## 9. Wpływ na UI

- Nowa sekcja raportu **„Powiązania i wzorce"**: relacje z typem, elementami (klikalne linki do twierdzeń/hipotez) i dowodami (klikalne spany/wzorce); kolejność wg `confidence` × waga typu.
- **Marker abdukcyjny** przy hipotezach teoretycznych (sekcja 5) — wizualnie odrębny od statusów, tekst w `.arb`.
- `pattern_notices` przy konstruktach z listą spanów bazowych.
- Relacje `sprzecznosc` renderowane w polu `contradicting` hipotez (spójnie z formatem przestrzeni hipotez).
- Zasada niezmieniona: „brak powiązań" nie jest renderowany jako pusta sekcja-błąd — sekcja znika, gdy `approved_relations` puste.

---

## 10. Wpływ regulacyjny (uczciwie)

- Relacje są wnioskowaniem o konkretnym kliencie — **kwalifikacja MDR bez zmian** (P2/strefa czerwona; dokument 11, sekcja 10, obowiązuje w całości). S2b nie zmienia kwalifikacji; zmienia wartość, przejrzystość i dowodliwość.
- Monotoniczność statusu (R8d), markery abdukcyjne i widoczność danych przeciw **wzmacniają** obronę „klinicysta jako autor decyzji" oraz spójność z AUP dostawcy (nadzór profesjonalisty): system jawnie odróżnia to, co widzi, od tego, co proponuje jako wyjaśnienie.
- Relacja `sprzecznosc` wobec hipotezy **terapeuty** (funkcja „ten fragment przeczy Twojej hipotezie") wymaga, by hipoteza terapeuty była zarejestrowana jako jego wpis (`report_hypothesis_selected` / pole user-authored) — wejście autorskie użytkownika, nie inferencja systemu o intencjach terapeuty. Ta kolejność (najpierw wybór terapeuty, potem test sprzeczności) jest warunkiem, nie szczegółem.

---

## 11. Czego v1.2 nadal nie rozwiązuje (nazwane wprost)

- **Nieobecności** — odroczone do v2 z warunkami z sekcji 3.4.
- **Jedna zintegrowana narracja kliniczna** — celowo poza zakresem: teza produktowa (drugi system myślenia), teza recenzenta i pozycja regulacyjna jednocześnie. S2b dowozi połączenia, nie opowieść.
- **Automation bias** — bez zmian względem v1.1 (adresowany miękko); relacje mogą go wręcz pogłębić, jeśli będą renderowane zbyt autorytatywnie — stąd markery i statusy w UI jako warunek T18.
- **Sufit anotacyjny** — metryki głębi mierzą zgodność z ekspertami; głębsze niż złoty zestaw nie zmierzymy. Rozbudowa zestawu jest procesem ciągłym (stress-testy recenzenta z Ewą).

---

## 12. Plan wdrożenia — tickety (delta względem T1–T12)

Fazowanie: T13–T16 po F2 (potok bazowy działa); T17 rozszerza T9 (wymaga **dodatkowej pracy eksperckiej** nad istniejącym złotym zestawem — koszt w D3); T18 po T14–T15. Rekomendowana kolejność wdrożenia produkcyjnego: S2b za flagą (`REPORT_RELATIONS_ENABLED`), włączenie domyślne po przejściu progów 7.2 (D2).

| # | Ticket | Definition of Done |
|---|---|---|
| T13 | S1.5 — silnik wzorców | 5 typów v1 z `method_registry` (wersjonowanie metod i parametrów); test determinizmu (ten sam input → identyczny output); proweniencja wzorzec→spany; tabela `patterns` (sqlc); cache spójny z cache spanów; reguła zliczania wzorców do `min_evidence` rozstrzygnięta i przetestowana |
| T14 | S2b — integracja | Prompt wg zasady 4.4 (wersjonowany); structured output wg schematu 4.2; pusta lista jako ścieżka testowana jawnie; S2b bez dostępu do transkryptu (wymuszone sygnaturą, test negatywny) |
| T15 | S3b — walidacja R8 | R8a–R8e zaimplementowane; R8d z porządkiem statusów; celowany entailment R8c (Flash, T=0); rejestr odrzuceń; testy jednostkowe per reguła |
| T16 | Rozwarstwienie R4 | Testy per status wg tabeli 5; marker abdukcyjny w danych wyjściowych S4; spany niezgodne → `contradicting`, nie kasacja; testy na zestawie hipotez abdukcyjnych |
| T17 | Benchmark głębi | Protokół anotacji 7.1 (wagi, relacje, mechanizm-vs-parafraza); ponowna anotacja złotego zestawu przez ekspertów; metryki 7.2 liczone automatycznie; progi w bramce CI; macierz „ekspert znalazł / system abstynował" |
| T18 | UI powiązań i wzorców | Sekcja „Powiązania i wzorce"; markery abdukcyjne; `pattern_notices`; `sprzecznosc` w polu `contradicting`; sekcja znika przy pustych relacjach; `.arb`; telemetria sekcji 8 |

---

## 13. Decyzje blokujące

| # | Decyzja | Opcje | Rekomendacja | Status |
|---|---|---|---|---|
| D1 | Limit relacji per raport (R8e) i funkcja priorytetu | Stała (np. 7) vs zależna od liczby sesji vs bez limitu z progiem confidence | Startowo stała ≈ 7, kalibracja po benchmarku precyzji relacji | ☐ otwarta |
| D2 | Tryb wdrożenia S2b | A: w pierwszym release raportu v1.2 · B: za flagą, domyślnie po przejściu progów 7.2 | **B** — relacje niskiej precyzji zniszczyłyby zaufanie do całego raportu szybciej niż ich brak | ☐ otwarta |
| D3 | Budżet ekspercki na rozszerzoną anotację (7.1) | Realne godziny: ponowna anotacja ≥ 15 transkryptów × wagi + relacje + ocena parafraz; do wyceny z Ewą i recenzentem | Zakontraktować łącznie z pracą nad ontologią (T2/K2–K3) — te same osoby, spójny kontekst | ☐ otwarta |

---

*Dokument wewnętrzny. Nie stanowi opinii prawnej. Progi liczbowe (7.2, parametry metod 3.2, limit D1) są wartościami startowymi do kalibracji na benchmarku.*
