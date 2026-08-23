# 14. Modalność CBT — analiza dopasowania architektury i rozszerzenia metaschematu

| Pole | Wartość |
|---|---|
| Plik | `docs/14_Modalnosc_CBT_Analiza_Dopasowania.md` |
| Wersja | 1.0 |
| Data | 22 sierpnia 2026 r. |
| Status | Projekt — do zatwierdzenia decyzji D1–D4 (sekcja 10); rozszerzenia metaschematu zintegrowane w dokumencie 11 v1.3 |
| Cel | Test tezy generyczności („nowa modalność = nowy plik ontologii + praca ekspercka, nie nowy kod") na CBT — modalności o najlepiej ustrukturyzowanej taksonomii i najbardziej złożonej strukturze jednostek pracy |
| Dokumenty powiązane | `11_Architektura_Wnioskowania_Ontologia.md` **v1.3** (metaschemat z rozszerzeniami z tego dokumentu); `12_Zarzadzanie_Wiedza_Domenowa.md`; `13_Glebia_Wnioskowania.md`; ADR-0XX (kategoria R_RISK); ADR-0YY; *Analiza wymagań regulacyjnych* rozdz. 3–4, 10 |
| Zakres | Ontologia CBT (rodzina Beck + wariant REBT), rozszerzenia metaschematu M1–M4, deterministyczna detekcja cykli (S2c), polityka treści ryzyka w potoku raportu (luka przekrojowa), wpływ na aplikację towarzyszącą |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-22 | Pierwsza wersja: inwentarz konstruktów CBT, rozszerzenia metaschematu M1–M4 (kompozyty, multi-label, kwantyfikacja, mediacja+S2c), polityka ryzyka w raporcie, wpływ na aplikację towarzyszącą, tickety, decyzje. |

---

## 1. Streszczenie decyzyjne

**Werdykt:** teza generyczności broni się w ~80 %. CBT przenosi się na architekturę **lepiej niż PPT** — drabina wnioskowania CBT (myśl automatyczna → przekonanie pośredniczące → przekonanie kluczowe) mapuje się jeden do jednego na drabinę statusów epistemicznych, pole `kind: behavioral` z S1 i reguła etiologiczna R5 trafiają w naturę modalności, a rozwarstwienie R4 z dokumentu 13 jest dla CBT **warunkiem wdrażalności** (bez niego walidator ścinałby systematycznie przekonania kluczowe, które są abdukcją z definicji).

Pozostałe ~20 % to cztery rozszerzenia metaschematu — wszystkie w duchu „więcej struktury, nie mniej szyn", zintegrowane w dokumencie 11 v1.3:

- **M1 — konstrukty kompozytowe** (`kind: composite`): epizod 5-elementowy i diagram konceptualizacji to krotki typowanych slotów, nie kategorie; `insufficient_data` per slot. Korzystne wstecznie dla PPT.
- **M2 — multi-label** (`multi_label: true`): jedna myśl ma zwykle 2–3 zniekształcenia poznawcze; benchmark kategorii przechodzi dla takich konstruktów na F1 per etykieta.
- **M3 — polityka kwantyfikacji** (`quantities: stated_only` + reguła R9): wartości liczbowe (natężenie emocji, siła przekonania, SUDS) wyłącznie ze spanu, w którym padły — fabrykowana precyzja to rodzaj konfabulacji, którego R1–R7 nie łapią.
- **M4 — relacja `mediacja` + S2c**: semantyka funkcjonalna („myśl pośredniczy między sytuacją a emocją") jako szósty typ relacji; **błędne koło nie jest generowane przez LLM** — jest deterministyczną detekcją cyklu w grafie zwalidowanych relacji (nowy krok S2c, Go, zero LLM). Najczystsze zastosowanie zasady „LLM proponuje, struktura rozporządza".

CBT ujawnia też **lukę przekrojową niezależną od modalności**: potok raportu nie ma polityki treści ryzyka (odpowiednika `R_RISK` z ADR czatu) — sekcja 7 definiuje bezpieczny środek do rozstrzygnięcia z doradcą regulacyjnym.

**Odkrycie strategiczne:** dzienniczek myśli i zadania behawioralne to natywna kultura CBT między sesjami — dane strukturalne autorstwa klienta z aplikacji towarzyszącej (strefa zielona, zero inferencji AI) zasilają potok jako gotowe epizody, z pominięciem najbardziej zawodnego etapu (ekstrakcji z mowy). CBT najmocniej uzasadnia istnienie aplikacji towarzyszącej i domyka pętlę danych — rekomendacja: **CBT jako modalność nr 2 w D3**, z projektowaniem formularzy aplikacji klienta od razu pod sloty kompozytów.

---

## 2. Inwentarz pojęciowy CBT → architektura

| Konstrukt CBT | Natura katalogu | Enum? | Charakterystyka dowodowa | Domyślny status | Dopasowanie |
|---|---|---|---|---|---|
| Myśl automatyczna | Otwarty (treść kliencka; typ jest konstruktem) | Nie (`values: null`) | **Najlepsza możliwa** — często wypowiadana niemal verbatim, jest spanem | `observation` | Doskonałe |
| Zniekształcenie poznawcze | Zamknięty ~10–15 (kanon: D1) | **Tak, multi-label** (M2) | Etykieta nad spanem myśli | `interpretation` | Dobre po M2 |
| Przekonanie pośredniczące (zasada / postawa / założenie „jeśli–to") | Typ zamknięty, treść otwarta | Typ tak | Czasem wprost, częściej z kilku myśli | `interpretation` | Dobre |
| Przekonanie kluczowe | Kategorie zamknięte (J. Beck: bezradność / niekochanie / bezwartościowość), treść otwarta | Kategoria tak | **Prawie nigdy verbatim** — konwergencja wielu myśli (strzałka w dół) | `theoretical_hypothesis` (wymuszony) | Dobre — sekcja 3 |
| Emocja + natężenie | Katalog podstawowy + skala | Emocja tak; natężenie = **dana ilościowa** (M3) | Natężenie tylko gdy podane | `observation` | Dobre po M3 |
| Epizod 5-elementowy (sytuacja–myśl–emocja–ciało–zachowanie) | **Krotka typowanych slotów** | Kompozyt (M1) | Sloty = spany + enum + liczba | mieszany per slot | Wymaga M1 |
| Błędne koło / cykl podtrzymujący | **Podgraf relacji** | Nie dotyczy | Wzorce `sequence`/`recurrence` (S1.5) + relacje | `theoretical_hypothesis` | S2c (sekcja 5) |
| Strategia kompensacyjna, zachowanie zabezpieczające | Półotwarty | Częściowo | Spany behawioralne (`kind: behavioral` z S1 — pole okazuje się przewidujące) | `interpretation` | Doskonałe |
| Dane z dzieciństwa (CCD) | Otwarty | Nie | **R5 pasuje wprost**: dane z dzieciństwa w konceptualizacji CBT pochodzą z relacji klienta — etiologia ze spanem jest standardem praktyki, nie naszym ograniczeniem | `observation`/`interpretation` | Doskonałe |
| Cel terapeutyczny / plan | Otwarty, autorstwa terapeuty | Nie | Wpis użytkownika (user-authored) | — | Poza inferencją (spójnie z A3/A7) |

---

## 3. Drabina wnioskowania CBT jako walidacja drabiny epistemicznej

Hierarchia myśl → przekonanie pośredniczące → przekonanie kluczowe to rosnąca abstrakcja i malejąca bezpośredniość dowodu — mapowanie 1:1 na `observation` → `interpretation` → `theoretical_hypothesis`. Technika strzałki w dół odwzorowana strukturalnie przez `requires` + `min_evidence`:

```yaml
# ontology/cbt/0.1.0.yaml — fragment ilustracyjny; treść i progi do autoryzacji eksperckiej
automatic_thought:
  label_pl: "Myśl automatyczna"
  values: null                      # treść otwarta — typ jest konstruktem
  min_evidence: {spans: 1}
  # domyślny status: observation (myśl jest spanem)

cognitive_distortion:
  label_pl: "Zniekształcenie poznawcze"
  multi_label: true                 # M2
  values: ["czytanie w myślach", "katastrofizacja", "myślenie czarno-białe",
           "nadmierna generalizacja", "filtr negatywny", "dyskwalifikowanie pozytywów",
           "wnioskowanie emocjonalne", "etykietowanie", "personalizacja",
           "imperatywy (muszę/powinienem)"]      # kanon do decyzji D1 (Beck vs Burns)
  requires: [automatic_thought]
  min_evidence: {spans: 1}
  aliases: {"myślenie dychotomiczne": "myślenie czarno-białe", ...}

intermediate_belief:
  label_pl: "Przekonanie pośredniczące"
  values: ["zasada", "postawa", "założenie warunkowe"]    # typ; treść otwarta
  requires: [automatic_thought]
  min_evidence: {spans: 2}

core_belief:
  label_pl: "Przekonanie kluczowe"
  values: ["bezradność", "niekochanie", "bezwartościowość"]   # kategorie J. Beck
  requires: [automatic_thought]
  min_evidence: {spans: 4, sessions: 2}   # konwergencja — decyzja ekspercka
  forced_status: theoretical_hypothesis    # nowe pole (M1-adjacent): status wymuszony
  # → test spójności R4 (dok. 13 §5) + obowiązkowy marker abdukcyjny

emotion:
  label_pl: "Emocja"
  values: ["lęk", "smutek", "złość", "wstyd", "poczucie winy", ...]  # kanon D1
  quantities: {policy: stated_only, scale: "0-100"}                   # M3

episode_5part:
  label_pl: "Epizod (model 5 elementów)"
  kind: composite                   # M1
  slots:
    situation: {type: span_ref, required: true}
    thought:   {type: construct_ref(automatic_thought), required: true}
    emotion:   {type: enum_ref(emotion) + quantity?, required: true}
    body:      {type: span_ref, required: false}
    behavior:  {type: span_ref, required: false, kind_hint: behavioral}
  min_complete_slots: 3
```

Rozwarstwienie R4 (dokument 13, sekcja 5) jest tu warunkiem wdrażalności: entailment ścisły dla myśli (są spanami), test spójności dla przekonań kluczowych (są abdukcją). W v1.1 CBT byłoby niewdrażalne albo płytkie — retrospektywne potwierdzenie, że poprawka głębi nie była opcjonalna.

---

## 4. Rozszerzenia metaschematu M1–M3 (zintegrowane w dokumencie 11 v1.3)

### M1 — Konstrukty kompozytowe (`kind: composite`)

- Kompozyt = krotka typowanych slotów (`span_ref` | `construct_ref` | `enum_ref` + opcjonalna kwantyfikacja), z `required` per slot i progiem `min_complete_slots`.
- S2 dla kompozytu wypełnia sloty z dowodami per slot; slot pusty = `insufficient_data` **per slot**, nie per kompozyt; kompozyt poniżej `min_complete_slots` = `insufficient_data` całości.
- Walidacja: typ slotu egzekwowany schematem (span_ref musi wskazywać istniejący span; construct_ref — zatwierdzone twierdzenie; enum_ref — wartość z katalogu); `kind_hint` sprawdzany przeciw `kind` spanu.
- **Wpływ wsteczny na PPT (korzystny):** konceptualizacja PPT jest de facto kompozytem (formularz z polami) — dotąd niewymuszonym formalnie; migracja szablonu A7/A3 na `kind: composite` ujednolica walidację i telemetrię `filled_by` per slot. Do wykonania przy najbliższej minor wersji ontologii PPT (bez blokowania pilota).
- Pole towarzyszące `forced_status`: konstrukt może wymuszać status epistemiczny (np. `core_belief` → zawsze `theoretical_hypothesis`), co deterministycznie kieruje go do właściwego testu R4 i markera abdukcyjnego.

### M2 — Multi-label (`multi_label: true`)

- Konstrukt z `multi_label: true` zwraca `categories: [values]` (≥ 1) zamiast pojedynczej `category`; schemat JSON egzekwuje niepustość i przynależność każdej etykiety do enumu.
- `min_evidence` liczone per etykieta (każde przypisane zniekształcenie musi mieć własne oparcie w spanie myśli).
- **Benchmark:** trafność kategorii dla konstruktów multi-label mierzona F1 per etykieta (micro/macro raportowane osobno), nie accuracy — wyniki PPT (single-label) i CBT nie są wprost porównywalne i nie wolno ich zestawiać w jednej liczbie.

### M3 — Polityka kwantyfikacji (`quantities` + reguła R9)

- Problem: CBT jest ilościowe (natężenie 0–100, siła przekonania %, SUDS), a transkrypty rzadko zawierają liczby, o ile terapeuta ich nie wywołał. Model bez polityki będzie **fabrykował precyzję** — rodzaj konfabulacji niełapany przez R1–R7 (liczba nie jest kategorią spoza enumu ani etiologią).
- Polityka `stated_only`: wartość liczbowa dopuszczalna wyłącznie ze spanem, w którym padła (weryfikacja mechaniczna: liczba lub jej słowny odpowiednik obecny w `quote_verbatim`); wzmianka jakościowa („bardzo silny lęk") pozostaje jakościowa — bez mapowania na liczbę.
- **Nowa reguła walidatora R9:** wartość ilościowa bez spanu źródłowego = twarde odrzucenie + metryka; benchmark: fabrykacja liczb = **0** (twarde, symetrycznie do konfabulacji etiologii).
- Dane z aplikacji towarzyszącej (sekcja 8) są natywnie ilościowe i spełniają `stated_only` z definicji (klient sam wpisał wartość).

### M4 — patrz sekcja 5 (relacja `mediacja` + S2c).

---

## 5. M4 — Relacja `mediacja` i deterministyczna detekcja cykli (S2c)

### 5.1. Typ `mediacja`

Sedno modelu poznawczego — „myśl **pośredniczy** między sytuacją a emocją/zachowaniem" — ma semantykę funkcjonalną, której nie niesie żaden z pięciu typów S2b (`sekwencja` jest czysto czasowa). Szósty typ:

```
relation{type: mediacja, roles: {trigger, mediator, outcome}, ...}
```

Wymóg dowodowy (R8c rozszerzone): wzorzec `sequence` obejmujący trigger→mediator→outcome **lub** epizod kompozytowy z wypełnionymi odpowiednimi slotami. Status: nigdy mocniejszy niż `interpretation` (mediacja jest wnioskiem funkccjonalnym, nie obserwacją); monotoniczność R8d obowiązuje.

### 5.2. S2c — cykle jako analiza grafowa (zero LLM)

Błędne koło / cykl podtrzymujący **nie jest generowany przez LLM**. Skoro S2b produkuje relacje parami (krawędzie), cykl jest domknięciem pętli w skierowanym grafie zwalidowanych relacji typu `sekwencja`/`mediacja`/`wzmocnienie`:

```
S3b: approved_relations ──► S2c DETEKCJA CYKLI (Go, deterministyczna)
     graf skierowany: wierzchołki = claims/patterns, krawędzie = relacje
     → cycles[]: {cycle_id, edges: [relation_id], nodes: [claim_id|pattern_id]}
     status cyklu: najsłabszy status krawędzi (monotoniczność dziedziczona)
     proweniencja: pełna — po wszystkich krawędziach do spanów
     rendering: „możliwe błędne koło" w sekcji Powiązania i wzorce,
     zawsze theoretical_hypothesis + marker abdukcyjny
```

Właściwości: deterministyczny (jak S1.5), testowalny grafowo, żadnej nowej treści — najbardziej „kliniczny" wniosek CBT (cykl podtrzymujący objaw) powstaje algorytmicznie z już zwalidowanych krawędzi. Limit: cykle proste, długość ≤ 6 krawędzi (parametr); przy wielu cyklach priorytet wg sumy confidence krawędzi.

---

## 6. Co CBT czyni łatwiejszym (niższe koszty niż PPT)

| Wymiar | PPT | CBT |
|---|---|---|
| Terminologia PL | Niestandaryzowana, kalki z niemieckiego — duża praca `aliases`/L1 | Ustandaryzowana (podręcznik Popiel & Pragłowskiej jako naturalne `source` dla L1) |
| Dostępność ekspertów | Wąska | Głęboka — dominująca certyfikowana modalność w Polsce; kontraktacja anotatorów łatwiejsza |
| Format anotacji złotego zestawu | Do zaprojektowania | **Gotowy** — eksperci CBT rutynowo produkują diagram konceptualizacji (CCD); protokół z dok. 13 §7.1 mapuje się na pola diagramu; oczekiwana wyższa zgodność międzyekspercka → czystsze progi |
| Prior parametryczny modelu | Szczątkowy (długi ogon) | Gęsty — niższy koszt kalibracji S2; zasada „L1+L2 jako źródło prawdy" obowiązuje bez zmian |
| Literatura źródłowa / licencje | Głównie DE, ograniczona | Bogata PL/EN; łatwiejsze decyzje manifestu korpusu (dok. 12) |

---

## 7. Luka przekrojowa: polityka treści ryzyka w potoku raportu

**Kontekst:** dobra praktyka CBT obejmuje rutynowe monitorowanie ryzyka suicydalnego — transkrypty CBT będą częściej niż PPT zawierały materiał ryzyka. Potok raportu nie ma dziś odpowiednika kategorii `R_RISK` z ADR czatu: S1 wyekstrahuje spany o treściach rezygnacyjnych, S2 coś z nimi zrobi, S4 coś wyrenderuje — bez żadnej reguły. Luka jest **niezależna od modalności** (dotyczy też PPT), CBT ją tylko uwidacznia.

**Pułapka dwustronna, nazwana wprost:**
- Automatyczna **detekcja/ocena/trend** ryzyka = funkcja alarmowa → Reguła 11 celuje w klasę **IIb** — głębiej w SaMD niż cokolwiek dotąd rozważanego.
- **Przemilczenie** materiału ryzyka w raporcie traktowanym przez terapeutę jako podsumowanie sesji = fałszywe poczucie kompletności — ryzyko kliniczne odwrotnego znaku.

**Zarys bezpiecznego środka (do rozstrzygnięcia z doradcą regulacyjnym — nowa pozycja na liście pytań; koordynacja z istniejącym serwisem Safety & Alerts):**

1. Spany ryzyka wydzielane **deterministycznie** (słownik + klasyfikator z progiem niskim — asymetria jak w R_RISK czatu: lepiej fałszywie wydzielić) do osobnej sekcji raportu „wypowiedzi wymagające uwagi klinicysty".
2. Zawartość sekcji: **wyłącznie verbatim + sygnatura + mówca** — zero kategoryzacji, zero oceny, zero natężenia, zero trendów między sesjami.
3. **Jawne wyłączenie** spanów ryzyka z S2/S2b/S2c i ze statystyk S1.5 (żadnych wniosków, wzorców ani relacji na ich bazie) — wyłączenie egzekwowane w kodzie, testowane negatywnie.
4. Intended use i onboarding: produkt **nie pełni funkcji monitorowania ani oceny ryzyka**; sekcja jest mechanicznym podświetleniem cytatów.
5. Rejestr zdarzeń (bez treści) do audytu; brak progów alarmowych, brak powiadomień push (powiadomienie = funkcja alarmowa = IIb).

Granica między „podświetleniem cytatu" a „alarmem" jest cienka i musi zostać narysowana świadomie, na piśmie, z podpisem doradcy — przed wdrożeniem CBT i najlepiej przed GA w ogóle. Do czasu rozstrzygnięcia: polityka tymczasowa = wariant 1–5 za flagą, domyślnie **wyłączony render sekcji**, spany ryzyka wyłączone z wnioskowania już teraz (punkt 3 jest bezpieczny niezależnie od decyzji o renderze).

---

## 8. Wpływ na aplikację towarzyszącą (strategiczny)

Dzienniczek myśli i zadania behawioralne to natywna kultura pracy CBT między sesjami:

- **Formularz dzienniczka = sloty kompozytu `episode_5part`** — projektować od razu pod metaschemat (sytuacja / myśl / emocja+natężenie / reakcja ciała / zachowanie), z katalogiem emocji z ontologii i skalą z `quantities`.
- Dane są **strukturalne, autorstwa klienta, bez inferencji AI** — strefa zielona (dokumentacja własna), spójna z pozycją regulacyjną aplikacji towarzyszącej z analizy wymagań (rozdz. 4.5).
- Wejście do potoku: epizody z aplikacji trafiają jako gotowe, zweryfikowane sloty (pomijają ekstrakcję z mowy — najbardziej zawodny etap); `stated_only` spełnione z definicji (klient sam wpisał wartość); proweniencja = rekord aplikacji zamiast spanu transkryptu (rozszerzenie typu referencji dowodowej: `entry_ref` obok `span_ref`/`pattern_id` — drobna zmiana w modelu danych, ujęta w T19).
- **Domknięcie pętli danych** (wartość strategiczna nr 1 platformy): terapeuta widzi w raporcie epizody z tygodnia zestawione z materiałem sesji — bez żadnej inferencji łączącej, samo zestawienie chronologiczne (strefa zielona).
- Konsekwencja dla D3 (kolejność modalności): **CBT jako nr 2**, z formularzami aplikacji projektowanymi równolegle do ontologii `cbt/` — jedna decyzja ekspercka (kanon emocji, skala) zasila oba artefakty.

---

## 9. Pogranicza rodziny CBT i kanon v1

- **Rdzeń v1:** terapia poznawcza J. Beck (drabina przekonań, CCD, epizod 5-elementowy).
- **REBT:** model ABC jako **wariant epizodu** w tym samym pliku ontologii (inna krotka slotów: A–B–C), nie osobna modalność — decyzja D1.
- **Terapia schematów:** 18 schematów + tryby — znakomicie enumowalna; naturalny kandydat na modalność nr 3 (osobny plik, po benchmarku CBT).
- **ACT:** procesualna (heksafleks) — ontologia „miękka" w sensie sekcji 9 dokumentu 11 (mniej enumów, więcej statusów hipotetycznych); niższa wartość walidatora, świadomie później.
- **Aktywizacja behawioralna:** pokrywana przez `kind: behavioral` + wzorce `distribution`/`trend` — nie wymaga osobnych konstruktów w v1.

---

## 10. Decyzje blokujące

| # | Decyzja | Opcje | Rekomendacja | Status |
|---|---|---|---|---|
| D1 | Kanon zniekształceń i emocji v1 | Beck (10) vs Burns (rozszerzony) vs hybryda; katalog emocji podstawowych | Decyzja ekspercka przy budowie `cbt/0.1.0.yaml`; jeden kanon, warianty w `aliases` | ☐ otwarta |
| D2 | REBT jako wariant epizodu czy osobna modalność | Wariant w `cbt/` vs `rebt/` osobno | **Wariant** — wspólna drabina przekonań, inna krotka slotów | ☐ otwarta |
| D3 | Polityka treści ryzyka w raporcie (sekcja 7) | A: pełne wdrożenie 1–5 po opinii doradcy · B: tylko punkt 3 (wyłączenie z wnioskowania), bez sekcji · C: nic | **A po opinii; punkt 3 natychmiast niezależnie od decyzji**; pytanie do doradcy dopisane do listy (rozdz. 9 analizy + 10.8) | ☐ otwarta |
| D4 | Formularze aplikacji towarzyszącej pod sloty kompozytów | Projektować równolegle z ontologią `cbt/` vs po niej | **Równolegle** — jedna sesja ekspercka zasila oba artefakty | ☐ otwarta |

---

## 11. Plan wdrożenia — tickety (delta)

Warunek wejścia: PPT przeszło benchmark (D3 z dokumentu 11 — sekwencyjność). Wyjątek: T19–T21 (metaschemat) wchodzą wcześniej, bo są zmianami silnika, nie treści.

| # | Ticket | Definition of Done |
|---|---|---|
| T19 | Metaschemat M1–M3 + `forced_status` + `entry_ref` | `kind: composite` (sloty, typy referencji, `min_complete_slots`), `multi_label`, `quantities: stated_only`, `forced_status`; walidacja CI; typ `entry_ref` w modelu dowodów; testy negatywne per rozszerzenie |
| T20 | Reguła R9 (kwantyfikacja) | Weryfikacja mechaniczna liczby w `quote_verbatim` (z odpowiednikami słownymi); twarde odrzucenie + metryka; benchmark: fabrykacja liczb = 0 |
| T21 | S2b typ `mediacja` + S2c detekcja cykli | Typ z rolami i wymogiem dowodowym w R8c; S2c deterministyczny (graf, cykle proste ≤ 6, priorytet wg confidence); status dziedziczony; testy grafowe; rendering „możliwe błędne koło" z markerem |
| T22 | Wyłączenie spanów ryzyka z wnioskowania (pkt 3 sekcji 7) | Deterministyczne wydzielenie (słownik+klasyfikator, próg niski); wyłączenie z S2/S2b/S2c/S1.5 egzekwowane w kodzie; test negatywny; rejestr zdarzeń bez treści; **wdrażane natychmiast, niezależnie od D3** |
| T23 | Sekcja „wypowiedzi wymagające uwagi" za flagą (pkt 1–2, 4–5) | Render verbatim+sygnatura, zero oceny; flaga domyślnie OFF do opinii doradcy; teksty `.arb`; zapis intended use |
| T24 | Ontologia `cbt/0.1.0` + L1 + manifest korpusu CBT | Po D1–D2; sesja ekspercka; `approved_by` niepuste przed prod; spójność krzyżowa CI (jak T2/K2–K3) |
| T25 | Migracja szablonu PPT na `kind: composite` | Przy najbliższej minor ontologii PPT; telemetria `filled_by` per slot; bez blokowania pilota |
| T26 | Benchmark CBT | Złoty zestaw wg protokołu dok. 13 §7.1 zmapowanego na CCD; metryki multi-label (F1 per etykieta, micro/macro osobno); recall cykli vs anotacje eksperckie |
| T27 | Formularze aplikacji towarzyszącej (po D4) | Sloty `episode_5part`; katalog emocji i skala z ontologii; `entry_ref` w potoku; zestawienie chronologiczne w raporcie bez inferencji łączącej |

---

*Dokument wewnętrzny. Nie stanowi opinii prawnej. Treści kliniczne (katalogi, progi, kanony) są placeholderami do autoryzacji eksperckiej; polityka ryzyka (sekcja 7) wymaga opinii doradcy regulacyjnego przed włączeniem renderu.*
