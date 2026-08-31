# 11. Architektura wnioskowania — ontologia modalności jako warstwa egzekwująca wierność teorii

| Pole | Wartość |
|---|---|
| Plik | `docs/11_Architektura_Wnioskowania_Ontologia.md` |
| Wersja | 1.4 |
| Data | 20 sierpnia 2026 r. |
| Status | Projekt architektury — do zatwierdzenia decyzji D1–D3 (sekcja 12) |
| Impuls | Feedback zewnętrznego recenzenta (test Supervisor AI z Ewą, sierpień 2026): 7 klas błędów wnioskowania w raporcie konceptualizacyjnym PPT |
| Dokumenty powiązane | ADR-0XX *AI Chat z klasyfikatorem* (18.08.2026); ADR-0YY *Ontologia modalności* (20.08.2026); `12_Zarzadzanie_Wiedza_Domenowa.md` (warstwy L0–L3, manifest korpusu, licencje); `13_Glebia_Wnioskowania.md` (S1.5, S2b, R8, metryki głębi); `14_Modalnosc_CBT_Analiza_Dopasowania.md` (M1–M4, S2c, R9, polityka ryzyka); `15_Modalnosci_Psychodynamiczna_Gestalt.md` (R10, `paralela`, `latency`, `interaction_frame`, osiągalność, M5); *Analiza wymagań regulacyjnych* rozdz. 4, 7, 8, 10; `02_ARCHITEKTURA_TECHNICZNA.md`; `06_Architektura_Mikroserwisow.md` |
| Zakres | Raport główny (konceptualizacja po sesji) **i** AI Chat — wspólne komponenty; wszystkie modalności (pilot: PPT) |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-20 | Pierwsza wersja: diagnoza, potok S1–S5, metaschemat ontologii, walidator, benchmark, integracja z czatem, tickety. |
| 1.1 | 2026-08-21 | (a) Nowa sekcja 2a: mechanizm przechowywania wiedzy przez LLM i wnioski (wiedza parametryczna jako prior, nie źródło prawdy); (b) status `no_fit` w S2/S3/benchmarku (ryzyko wymuszonego wyboru przy enumach); (c) `aliases` i `source` w metaschemacie ontologii; (d) rationale doboru modeli Flash/Pro per etap; (e) reguła „S2 nigdy nie konsumuje RAG" + odesłanie do dokumentu 12 (warstwy L0–L3, manifest korpusu, licencje); (f) motto „LLM proponuje, struktura rozporządza" w streszczeniu; tickety T6/T7/T9 rozszerzone o `no_fit`. |
| 1.2 | 2026-08-22 | Głębia wnioskowania (specyfikacja pełna: `13_Glebia_Wnioskowania.md`): (a) S1.5 — dowody wzorcowe (deterministyczne, cytowalne obiekty `pattern`); (b) S2b — etap integracji między-konstruktowej nad zatwierdzonymi twierdzeniami + walidacja R8 (w tym monotoniczność statusu R8d); (c) rozwarstwienie R4 per status epistemiczny (obserwacje: entailment; hipotezy: test spójności + marker abdukcyjny); (d) dwustronna kalibracja abstencji (przeoczenie symetryczne do zmyślenia); (e) metryki głębi w benchmarku (recall ustaleń eksperckich, nietrywialność, pokrycie integracyjne); (f) tickety T13–T18; sekcja raportu „Powiązania i wzorce". |
| 1.3 | 2026-08-22 | Rozszerzenia metaschematu z analizy CBT (specyfikacja pełna: `14_Modalnosc_CBT_Analiza_Dopasowania.md`): (a) **M1** — konstrukty kompozytowe `kind: composite` (typowane sloty, `min_complete_slots`, `insufficient_data` per slot) + pole `forced_status`; (b) **M2** — `multi_label: true` (benchmark: F1 per etykieta zamiast accuracy); (c) **M3** — polityka kwantyfikacji `quantities: stated_only` + nowa reguła walidatora **R9** (wartość liczbowa bez spanu = twarde odrzucenie; fabrykacja liczb = 0 w benchmarku); (d) **M4** — szósty typ relacji `mediacja` (role trigger/mediator/outcome) + **S2c**: deterministyczna detekcja cykli w grafie zwalidowanych relacji (zero LLM); (e) typ referencji dowodowej `entry_ref` (dane strukturalne z aplikacji towarzyszącej); (f) polityka treści ryzyka w potoku raportu — spany ryzyka wyłączone z wnioskowania (S2/S2b/S2c/S1.5), render sekcji za flagą do opinii doradcy (dokument 14, sekcja 7); tickety T19–T27. |
| 1.4 | 2026-08-22 | Rozszerzenia przekrojowe z analizy modalności psychodynamicznej i Gestalt (specyfikacja pełna: `15_Modalnosci_Psychodynamiczna_Gestalt.md`): (a) **R10** — twarda granica terapeuty: zakaz inferencji o stanach wewnętrznych użytkownika; treści o doświadczeniu terapeuty wyłącznie jako `entry_ref` jego autorstwa (wdrażane natychmiast — luka istnieje w PPT); (b) pola spanu **`interaction_frame`** (rama/adresat wypowiedzi — materiał przeniesieniowy, eksperymenty Gestalt) i **`observed_by`** (obserwacja terapeuty o kliencie vs samoopis); (c) siódmy typ relacji **`paralela`** (analogia strukturalna) z obostrzeniami: twardy `theoretical_hypothesis`, próg precyzji ≥ 0,85, flaga wyłączenia per modalność; (d) deterministyczny wzorzec **`latency`** w S1.5 (znaczniki ciszy z chunkera 600 ms — zero nowej infrastruktury); (e) **protokół osiągalności** w benchmarku: recall liczony względem ustaleń wyprowadzalnych z transkryptu, „sufit pokrycia" raportowany per modalność; (f) **M5** — opcjonalny `report_profile` per modalność (wagi sekcji, ton S4); deklaracja `therapist_boundary` w metaschemacie; tickety T28–T36. |
| 1.5 | 2026-08-25 | Zmiana doboru modelu: **S2 i S4 przechodzą z Pro na Flash** (S1 był na Flash od początku), po spełnieniu warunku benchmarku z sekcji 2a. Motywacja kosztowa: $0,45 wobec $0,028 za raport legacy, przy czym rachunek robi S2 wołane raz na konstrukt. Uzasadnienie merytoryczne: budżet myślenia był już zerowy/minimalny na wszystkich etapach, więc jakość niosą schemat i kod (enumy, weryfikacja cytatów, R1–R10, V1–V7), a nie klasa modelu. Przy okazji naprawione dwie rzeczy, które ta zmiana ujawniła: (a) etap potoku był rozpoznawany po nazwie modelu — `LLMRequest` niesie teraz jawne pole `Stage`; (b) koszt przebiegu ontologicznego był liczony po stawce modelu potoku legacy, zaniżając każdy raport eksperymentalny ok. 3,7× przez pięć tygodni — wycena idzie teraz za potokiem. Wiersze historyczne nietknięte. |
| 1.6 | 2026-08-26 | Pole `value_glosses` w metaschemacie (plan `Plan_Implementacji_value_glosses_v1.0`): objaśnienia 1-liniowe per wartość enumu, renderowane do promptu S2 (separator „ — ”, nagłówek warunkowy, automatyczny dopisek „NIE mylić z” dla par podłańcuchowych) i — docelowo — pickera A7 (T11, jeszcze nie istnieje; dziś glosy edytuje Ontology Studio). Identyfikatory enumu bez zmian; test kontraktowy pilnuje bajtowej identyczności JSON Schema wyjścia S2 z glosami i bez. Reguły lintera G1–G6, przy czym G6 (wymuszenie glos dla par podłańcuchowych) jest błędem dla konstruktu używającego glos, a ostrzeżeniem dla konstruktu bez glos — bezwarunkowy ERROR przeczyłby wymogowi, żeby `ppt/0.1.0` przechodził bez zmian. Prompt S2 podbity do s2/1.3.0. Metaschemat w `ontology/_meta/schema.yaml` doniesiony przy okazji do stanu kodu (label_en, report_profile.layout — dryf dokument↔kod). |
| 1.7 | 2026-08-31 | Faza addytywna Noty Zmian Silnika (`docs/plany/Nota_Zmian_Silnika_v1.5.md` — pisana jako delta „v1.4→v1.5” przed wejściem v1.5/v1.6 do tego pliku; wchodzi jako v1.7): **E5** unie typów slotów (`construct_ref(a|b)`, `span_ref|entry_ref`) + `multiple`/`min_items` (gramatyka: `pkg/ontology/slots.go`, jedyny interpreter); **E7** reguła G7 — homonim międzykonstruktowy bez glos obu stron = WARNING, renderer S2 dopisuje „(tu: <label>)” (prompt s2/1.4.0); **E9** `min_evidence.speaker` — R2 liczy progi wyłącznie na spanach wskazanej roli (z `observed_by`); **E10** WARNING lintera dla layoutu bez sekcji `patterns`/`out_of_taxonomy`. Zintegrowany seed `cbt/0.1.1` (17 konstruktów, pełny layout 12 sekcji, glosy; propozycje silnika wyłącznie w komentarzach). Pozostałe zmiany noty (E1–E4, E6, E8) czekają: E1 na decyzję D1 i benchmark z kolumną tierów, E2/E3/E4/E6 to zmiany potoku S1–S5 (tickety T42–T46), E8 na T39. |
| 1.8 | 2026-08-31 | **T42a — fakty sesyjne** (E4 wg projektu scalenia `docs/67`; D1–D4 zatwierdzone): S1 nadaje spanom `fact_kind` (6 wartości, prompt s1/1.1.0, weryfikacja mechaniczna bez zmian, kolumna `report_spans.fact_kind` z CHECK — migracja 000103); konstrukt z `fact_kind_map` jest pomijany w S2 i mapowany deterministycznie na twierdzenie-obserwację (confidence 1.0, dowód = span), walidowane w S3 tą samą ścieżką i w tej samej pozycji pętli (stabilna kolejność twierdzeń dla indeksu wnioskowania). Lint F1–F5 (m.in. jeden konstrukt na fact_kind, wymagane forced_status: observation). Seed `cbt/0.1.2` aktywuje mapę na `session_agreement` i `mood_rating`. Kluczowe rozstrzygnięcie z docs/67: `prior_report_context` z noty NIE powstaje — tym wejściem jest PastContext (F7a/F7b); numeracja: V8 = zakaz procentów (E1), V9 = lustro R11 (E2). |

---

## 1. Streszczenie decyzyjne

Feedback recenzenta opisuje **jeden błąd architektoniczny z siedmioma objawami**: wierność teorii (theoretical fidelity) jest egzekwowana wyłącznie siłą promptu i RAG — czyli wcale. Model językowy rozpoznaje bliskość semantyczną pojęć („sumienność" ~ „perfekcjonizm" ~ „odpowiedzialność"), ale nie utrzymuje formalnych relacji taksonomii szkoły terapeutycznej (*collapse of domain ontology*).

Rozwiązanie: przenieść ontologię, dopuszczalność twierdzeń i proweniencję **z warstwy językowej do warstwy danych i kodu**:

1. **Ontologia modalności jako dane** — wersjonowane pliki YAML, treść autoryzowana przez ekspertów klinicznych; zamknięte katalogi kategorii jako enumy w schematach wyjścia (model fizycznie nie może zwrócić kategorii spoza taksonomii).
2. **Potok pięcioetapowy zamiast pojedynczego przebiegu** — ekstrakcja dowodów → mapowanie per konstrukt → deterministyczny walidator dziedzinowy → synteza **bez dostępu do transkryptu** → weryfikator wyjścia.
3. **Proweniencja jako warunek istnienia twierdzenia** — każde twierdzenie wskazuje spany źródłowe; twierdzenia etiologiczne bez spanu są twardo odrzucane; koszt konfabulacji przestaje być zerowy, bo generator syntezy nie widzi materiału, z którego mógłby konfabulować.
4. **„Brak wystarczających danych" i „poza ontologią" jako wartości pierwszej klasy** — `insufficient_data` (za mało danych) oraz `no_fit` (danych dość, ale zjawisko nie mieści się w żadnej kategorii taksonomii); schematy i UI projektowane tak, że niewypełnione pole jest cechą, nie błędem; raport wypełniony w 100 % to sygnał alarmowy.
5. **Format przestrzeni hipotez** zamiast pojedynczej „ostatecznej konceptualizacji" (hipoteza A/B, dane za, dane przeciw, czego nie wiemy, pytanie na kolejną sesję) — rekomendowany domyślny format raportu (decyzja D1).
6. **Benchmark ekspercki z bramką CI** — złoty zestaw konceptualizacji, 7 klas błędów z feedbacku jako taksonomia metryk; prompty i ontologie wersjonowane i podlegające temu samemu procesowi release co kod.
7. **Głębia wewnątrz szyn, nie zamiast szyn** (v1.2, specyfikacja: dokument 13) — wnioski relacyjne i wzorcowe dostają legalne miejsce i legalne dowody bez luzowania ograniczeń antykonfabulacyjnych: deterministyczne dowody wzorcowe (S1.5), etap integracji między-konstruktowej nad zatwierdzonymi twierdzeniami (S2b + R8), testy R4 rozwarstwione per status epistemiczny, a benchmark mierzy także przeoczenia (recall ustaleń eksperckich), nie tylko zmyślenia.

Zasada podziału pracy, spinająca całość: **LLM proponuje, struktura rozporządza.** Wiedza parametryczna modelu i definicje w kontekście generują kandydatów; enum, `is_not`, `min_evidence` i deterministyczny walidator decydują, co przeżyje. Uzasadnienie w mechanizmie przechowywania wiedzy przez LLM — sekcja 2a. Zarządzanie samą wiedzą domenową (biblioteka źródeł, wyciągi kanoniczne, indeksy RAG, licencje) jest wydzielone do `12_Zarzadzanie_Wiedza_Domenowa.md`.

Silnik jest generyczny, treść jest danymi: nowa modalność = nowy plik ontologii + reguły, nie nowy kod. Pilot: PPT (jest feedback i ekspert); pozostałe modalności po przejściu PPT przez benchmark (decyzja D3).

**Sprzężenie regulacyjne (uczciwie):** ta architektura nie zmienia kwalifikacji MDR funkcji konceptualizacyjnych — mapowanie klienta na model pozostaje wnioskowaniem o konkretnej osobie (P2 w taksonomii ADR czatu, strefa czerwona). Zmienia natomiast profil ryzyka, dowodliwość kontroli i realność obrony „klinicysta jako autor decyzji", i wprost wzmacnia pozycję pod dyrektywą 2024/2853. Status modułu raportu wymaga domknięcia w ADR (D1).

---

## 2. Diagnoza: objaw → przyczyna architektoniczna

| # | Objaw (feedback) | Przyczyna architektoniczna | Adres w architekturze |
|---|---|---|---|
| 1 | Błędy kategorialne („spokój", „troska o siebie" jako potencjalności) | Kategorie są otwartym tekstem; model osadza pojęcia w przestrzeni semantycznej, nie w taksonomii | Enumy z ontologii w schemacie wyjścia (S2) + walidator (S3) |
| 2 | Mieszanie poziomów (potrzeba = zasób = potencjalność = funkcja objawu = Positum) | Schemat wyjścia nie rozróżnia typów konstruktów | Osobne wywołanie S2 per typ konstruktu z definicją i `is_not` |
| 3 | Fałszywy key conflict | Brak warunków minimalnych danych i zależności między konstruktami | `requires` + `min_evidence` w ontologii; degradacja do `fallback_rendering` (S3) |
| 4 | Nadmierne domykanie pól | „Brak danych" nie jest legalną wartością schematu | `insufficient_data` jako status pierwszej klasy (S2, S4, UI) |
| 5 | Konfabulacja etiologii („mikrotrauma", „supermatka") | Zerowy koszt dopowiedzenia: twierdzenie nie musi wskazać źródła | Proweniencja obowiązkowa; etiologia bez spanu = twarde odrzucenie (S3); S4 bez dostępu do transkryptu |
| 6 | Zlanie obserwacji z interpretacją | Status epistemiczny jest stylem prozy, nie polem danych | `epistemic_status` jako pole wymagane każdego twierdzenia (S2→S5) |
| 7 | RAG nie gwarantuje ontologii | RAG dostarcza *tekst o teorii*, nie *strukturę teorii* | RAG pozostaje dla warstwy edukacyjnej (A4_EDU); struktura teorii = rejestr ontologii |

Wniosek przewodni (za recenzentem): *local coherence* nie może zastępować *theoretical fidelity* i *provenance*. Iteracja promptów bez benchmarku daje złudzenie postępu — stąd sekcja 8.

---

## 2a. Dlaczego LLM nie może być źródłem prawdy o teorii — mechanizm przechowywania wiedzy

Diagnoza z sekcji 2 nie jest usterką konkretnego wdrożenia, lecz właściwością mechanizmu, którym generyczny LLM przechowuje wiedzę. Model nie ma bazy wiedzy ani „kopii książek" — wiedza jest **parametryczna**: rozproszona w wagach jako statystyczne regularności wyuczone z korpusu przez przewidywanie kolejnego tokenu. To kompresja stratna; pojęcia istnieją jako kierunki w przestrzeni aktywacji, splecione ze sobą, bez granic między źródłami, wydaniami i autorami. Cztery konsekwencje wprost tłumaczą feedback:

1. **Efekt częstości.** Jakość zapamiętania zależy od reprezentacji tematu w korpusie treningowym. CBT i kryteria diagnostyczne mają gęsty, stabilny prior; PPT — literatura źródłowa w znacznej części niemieckojęzyczna, śladowy korpus polski — jest wiedzą długiego ogona, zmieszaną z parafrazami z prac wtórnych, bez rozróżnienia kanonu od popularyzacji.
2. **Bliskość semantyczna zamiast relacji formalnych.** Trening osadza „sumienność", „odpowiedzialność", „perfekcjonizm" blisko siebie, bo współwystępują w tekstach — nie koduje faktu, że w taksonomii PPT jedno jest potencjalnością wtórną, a drugie nią nie jest. To jest dosłownie *collapse of domain ontology*.
3. **Brak wierności katalogom zamkniętym.** Generacja jest próbkowaniem z rozkładu, nie odczytem z rejestru: lista potencjalności wygenerowana z pamięci parametrycznej będzie w większości trafna, z 1–3 pozycjami podmienionymi i inna przy każdym uruchomieniu.
4. **Modele mniejsze (Flash) kompresują agresywniej** — wiedza długiego ogona cierpi pierwsza.

Wnioski architektoniczne (wiążące dla przyszłych zmian):

- Wiedza parametryczna jest traktowana jako **prior** (kompetencja językowa, generowanie kandydatów) — nigdy jako źródło prawdy o taksonomii.
- **Rationale doboru modeli per etap (zmienione 2026-08-25 — patrz niżej):** zadania niewymagające wiedzy domenowej idą na model mniejszy — S1 (ekstrakcja cytatów: operacja czysto językowa) i R4 (entailment: pytanie logiczno-językowe) na Flash. Etap dotykający teorii (S2) dostaje **całą wiedzę domenową w kontekście** (wyciągi kanoniczne L1 + ontologia L2 w całości, bez selekcji retrievalem) — i to, a nie klasa modelu, jest właściwym zabezpieczeniem. Warunek pozostaje w mocy: optymalizacja kosztowa nie może wprowadzić selekcji kontekstu S2 ani przenieść S2 na model mniejszy **bez przejścia benchmarku** (sekcja 8).
- **S2 i S4 na Flash od 2026-08-25.** Warunek z poprzedniego akapitu został spełniony, nie obejściony: benchmark A/B na tej samej sesji jest częścią zmiany. Powód: S2 jest wołane raz na konstrukt (14 wywołań dla PPT), za każdym razem z pełną listą spanów, i to tam szedł cały rachunek — raport eksperymentalny na Pro kosztował ok. **$0,45** wobec $0,028 za raport legacy, szesnastokrotnie więcej. Dlaczego zmiana jest do obrony: budżet myślenia był już wyłączony na każdym etapie (Flash 0, Pro 128 = minimum, które Pro w ogóle przyjmuje), więc potok nigdy nie opierał się na długim wnioskowaniu modelu — jakości pilnują enumy w schemacie, mechaniczna weryfikacja cytatów, walidator R1–R10 i weryfikator V1–V7. Kryteria odrzucenia zmiany (sekcja 8): spadek liczby zatwierdzonych twierdzeń, przesunięcie rozkładu odrzuceń R1–R10, wzrost naruszeń V1–V7 albo wpadnięcie raportu w tryb ekstraktywny. Raport, któremu terapeuta nie ufa, nie jest tańszy — jest bezużyteczny.
- **S2 nigdy nie konsumuje wyników RAG.** RAG dostarcza tekst o teorii, nie strukturę teorii (sekcja 2, wiersz 7); obsługuje wyłącznie warstwę edukacyjną `A4_EDU` i warsztat ekspertów. Warstwy wiedzy (L0 biblioteka źródeł → L1 wyciągi kanoniczne → L2 ontologia → L3 indeksy pochodne), manifest korpusu, licencje i pipeline ingestu — `12_Zarzadzanie_Wiedza_Domenowa.md`.
- Fine-tuning per modalność pozostaje odrzucony (ADR-0YY, opcja B): przesuwa rozkład prawdopodobieństwa, ale nie daje gwarancji katalogu zamkniętego, a wiedza jako *dane w kontekście + ograniczenia strukturalne* jest audytowalna i wymienialna bez retrainingu.

---

## 3. Rejestr ontologii modalności

### 3.1. Zasady

- **Treść ontologii piszą i autoryzują eksperci kliniczni** (pilot: Ewa + zewnętrzny recenzent). AI może wspierać redakcję; autoryzacja jest kliniczna. W przeciwnym razie collapse ontologii przenosi się o warstwę wyżej.
- Ontologia jest **danymi w repo**: `ontology/<modality>/<semver>.yaml`, wersjonowanie semantyczne, zmiany przez PR z uzasadnieniem klinicznym, approvers z CODEOWNERS (D2).
- Tam, gdzie teoria ma katalog zamknięty (np. potencjalności wtórne/pierwotne w PPT), lista jest **enumem** ładowanym do JSON Schema wyjścia — niezgodna odpowiedź modelu jest odrzucana walidacją, zanim cokolwiek zobaczy walidator dziedzinowy.
- Każdy konstrukt definiuje (format postulowany wprost przez recenzenta): definicję, dozwolone wartości, czym **nie** jest (`is_not`), relacje/zależności (`requires`), minimalne dane (`min_evidence`), typowe pomyłki (`common_confusions`), przykłady i kontrprzykłady.

### 3.2. Metaschemat (wspólny dla wszystkich modalności)

```yaml
# ontology/_meta/schema.yaml — walidowany w CI
modality: string                # ppt | cbt | psychodynamic | systemic | ...
version: semver
approved_by: [string]           # imiona/identyfikatory ekspertów
constructs:
  <construct_id>:
    label_pl: string
    aliases: [string]           # synonimy i warianty tłumaczeń PL (np. „zdolności aktualne");
                                # terminologia PL niestandaryzowana — rozstrzygana w wyciągach L1
                                # (dokument 12, D3) i lustrzanie wpisywana tutaj; S2 i UI mówią jednym językiem
    definition: string
    source:                     # audytowalność definicji do literatury — ontologia jest źródłem
      work_id: string           # prawdy zamiast modelu, więc sama musi być audytowalna
      edition: string           # (work_id z manifestu korpusu — dokument 12, sekcja 3)
      pages: string
    kind: category | composite  # M1 (v1.3): composite = krotka typowanych slotów
                                # (np. epizod 5-elementowy CBT, formularz konceptualizacji);
                                # domyślnie category
    slots:                      # tylko dla kind: composite
      <slot_id>:
        type: span_ref | construct_ref(<id>) | enum_ref(<id>) | entry_ref
        # entry_ref = rekord strukturalny z aplikacji towarzyszącej (dokument 14, sekcja 8)
        required: bool
        kind_hint: behavioral | declarative | null   # sprawdzane przeciw kind spanu
        quantity: bool          # slot dopuszcza wartość liczbową (podlega quantities.policy)
    min_complete_slots: int | null      # kompozyt poniżej progu = insufficient_data całości;
                                        # slot pusty = insufficient_data PER SLOT
    values: [string] | null     # null = konstrukt bez katalogu zamkniętego
    multi_label: bool           # M2 (v1.3): true = wyjście `categories: [values]` (≥1)
                                # zamiast pojedynczej category; min_evidence liczone PER etykieta;
                                # benchmark: F1 per etykieta (micro/macro), NIE accuracy —
                                # wyników multi-label nie zestawiać wprost z single-label
    quantities:                 # M3 (v1.3): polityka wartości liczbowych (natężenie, siła, SUDS)
      policy: stated_only       # liczba dopuszczalna WYŁĄCZNIE ze spanem, w którym padła
                                # (weryfikacja mechaniczna w quote_verbatim); wzmianka jakościowa
                                # pozostaje jakościowa; egzekwuje reguła R9 walidatora
      scale: string | null      # np. "0-100"
    forced_status: epistemic_status | null   # M1-adjacent (v1.3): status wymuszony konstruktu
                                # (np. core_belief CBT → zawsze theoretical_hypothesis →
                                # deterministycznie test spójności R4 + marker abdukcyjny)
    is_not: [construct_id]
    requires: [construct_id]    # zależności twarde (S3)
    min_evidence:
      spans: int                # min. liczba niezależnych spanów
      sessions: int | null      # min. liczba sesji, w których występuje
      behavioral: int | null    # min. liczba spanów behawioralnych (nie deklaratywnych)
    common_confusions:
      - {input: string, correct: string, note: string}
    examples: [string]
    counter_examples: [string]
    fallback_rendering: string | null   # jak renderować przy niespełnionym `requires`
epistemic_statuses: [observation, interpretation, theoretical_hypothesis, open_question,
                     insufficient_data, no_fit]
# insufficient_data = za mało danych, by rozstrzygnąć
# no_fit            = danych dość, ale zjawisko nie mieści się w żadnej kategorii taksonomii
#                     (bez tego statusu enum wymusza wybór najbliższej kategorii — forced-choice bias;
#                      wysoki odsetek no_fit w produkcji = luka ontologii, sygnał dla ekspertów)
etiology_policy: strict         # strict = twierdzenia genetyczne tylko ze spanem źródłowym
therapist_boundary: strict      # R10 (v1.4): twierdzenia S2/S2b/S2c wyłącznie o materiale
                                # klienta; treści o stanach wewnętrznych TERAPEUTY tylko jako
                                # entry_ref jego autorstwa (render z atrybucją „notatka
                                # terapeuty"), nigdy jako inferencja systemu
relation_types: [wspolwystepowanie, napiecie, sekwencja, sprzecznosc, wzmocnienie,
                 mediacja,      # M4 (v1.3): role {trigger, mediator, outcome};
                                # wymóg dowodowy: wzorzec sequence lub kompozyt (R8c);
                                # status nigdy mocniejszy niż interpretation;
                                # cykle w grafie relacji wykrywa DETERMINISTYCZNIE S2c
                                # (dokument 14, sekcja 5.2) — nigdy LLM
                 paralela]      # v1.4 (dokument 15 §2.2-c): analogia strukturalna —
                                # instances: [claim|composite] ≥ 2 z zbioru zatwierdzonego;
                                # najsłabiej gwarantowalny typ (sąd LLM o izomorfizmie):
                                # status TWARDO theoretical_hypothesis + marker abdukcyjny;
                                # shared_pattern_description podlega R8b i R10;
                                # benchmark: precyzja ≥ 0,85 (wyżej niż inne typy);
                                # flaga wyłączenia per modalność
report_profile:                 # M5 (v1.4, opcjonalne): wagi sekcji raportu i ton szablonów
  sections: {<section>: {weight: high|default|low}}   # S4; walidacja i statusy BEZ zmian
  default_tone: string | null   # np. phenomenological (Gestalt — dokument 15 §3.3)
```

Uwagi do rozszerzeń v1.3 (specyfikacja pełna i uzasadnienia: dokument 14, sekcje 4–5): rozszerzenia są addytywne — istniejące ontologie `kind: category`, single-label, bez kwantyfikacji pozostają ważne bez zmian; migracja szablonu konceptualizacji PPT na `kind: composite` jest korzystna i zaplanowana jako T25 (bez blokowania pilota). Reguła **R9** (wartość liczbowa bez spanu źródłowego = twarde odrzucenie) dołącza do walidatora S3; benchmark: fabrykacja liczb = 0 (twarde). Polityka treści ryzyka w potoku raportu — spany ryzyka wyłączone z S2/S2b/S2c/S1.5 (T22, wdrażane natychmiast), render sekcji za flagą do opinii doradcy — dokument 14, sekcja 7.

Uwagi do rozszerzeń v1.4 (specyfikacja pełna: dokument 15): **R10** wdrażane natychmiast, niezależnie od kolejności modalności — luka istnieje już w PPT (T28); pola spanu `interaction_frame` i `observed_by` — sekcja 4 (S1); protokół **osiągalności** w benchmarku (recall względem ustaleń wyprowadzalnych z transkryptu; „sufit pokrycia" raportowany per modalność i komunikowany w onboardingu) — sekcja 8.1; wzorzec `latency` — S1.5. Wszystkie rozszerzenia addytywne.

### 3.3. Przykład — PPT (fragment ilustracyjny; treść do autoryzacji eksperckiej)

```yaml
# ontology/ppt/0.1.0.yaml
modality: ppt
version: 0.1.0
approved_by: []                 # PUSTE do czasu autoryzacji — blokuje użycie w prod (CI)
constructs:
  actual_capacity_secondary:
    label_pl: "Potencjalność wtórna"
    definition: "..."
    values: ["punktualność", "czystość", "porządek", "posłuszeństwo", "uprzejmość",
             "szczerość", "wierność", "sprawiedliwość", "pilność/osiągnięcia",
             "oszczędność", "niezawodność", "dokładność", "sumienność"]   # katalog zamknięty wg Peseschkiana — ZWERYFIKOWAĆ z ekspertem
    is_not: [actual_capacity_primary, need, resource, symptom_function, positum]
    min_evidence: {spans: 2, behavioral: 1}
    common_confusions:
      - {input: "spokój", correct: "nie jest potencjalnością wtórną", note: "kandydat: potrzeba / obszar pierwotny — do weryfikacji"}
      - {input: "troska o siebie", correct: "nie jest potencjalnością", note: "częsty błąd modelu"}
      - {input: "samoświadomość", correct: "nie jest potencjalnością", note: "j.w."}
  actual_capacity_primary:
    label_pl: "Potencjalność pierwotna"
    values: ["miłość", "wzór", "cierpliwość", "czas", "kontakt", "zaufanie",
             "nadzieja", "wiara", "wątpienie", "pewność", "jedność"]      # ZWERYFIKOWAĆ
    is_not: [actual_capacity_secondary, need, resource]
    min_evidence: {spans: 2}
  current_conflict:
    label_pl: "Konflikt aktualny"
    min_evidence: {spans: 2}
  inner_conflict:
    label_pl: "Konflikt wewnętrzny"
    requires: [current_conflict]
    min_evidence: {spans: 2}
  basic_conflict:
    label_pl: "Konflikt podstawowy"
    min_evidence: {spans: 2, sessions: 2}
  key_conflict:
    label_pl: "Konflikt kluczowy"
    requires: [current_conflict, inner_conflict, basic_conflict]
    min_evidence: {spans: 3, sessions: 3}      # przykładowo — DECYZJA EKSPERCKA
    fallback_rendering: "hipoteza robocza napięcia aktualnego (nie key conflict w sensie PPT)"
  positum:
    label_pl: "Positum"
    definition: "..."
    is_not: [symptom_function]                 # funkcja adaptacyjna ≠ Positum
    min_evidence: {spans: 2}
    common_confusions:
      - {input: "bezsenność jako mądry sygnał ciała", correct: "hipoteza funkcjonalna (symptom_function), nie Positum", note: "z feedbacku"}
  symptom_function:
    label_pl: "Hipoteza funkcjonalna objawu"
    is_not: [positum]
    min_evidence: {spans: 2}
  balance_model_area:
    label_pl: "Obszar modelu równowagi"
    values: ["ciało/zmysły", "praca/osiągnięcia", "kontakty", "fantazja/przyszłość/sens"]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis, open_question, insufficient_data]
etiology_policy: strict
```

Uwagi: (a) wszystkie `values` i progi `min_evidence` w przykładzie są **placeholderami do autoryzacji** — CI blokuje ontologię z pustym `approved_by`; (b) `common_confusions` zasilamy bezpośrednio z feedbacku i z przyszłych błędów benchmarku — to żywy rejestr antywzorców.

---

## 4. Potok raportu głównego (S1–S5, z rozszerzeniami S1.5 i S2b z dokumentu 13)

Raport generuje się asynchronicznie po sesji (Pub/Sub → worker), więc latencja wieloetapowości jest akceptowalna. Wszystkie wywołania LLM: T=0, structured output, wersjonowane prompty w repo.

```
[transkrypt + notatki terapeuty]
   │
   ▼
S1  EKSTRAKCJA JEDNOSTEK DOWODOWYCH            (Gemini Flash, T=0)
   → spans[]: {span_id, session_id, ts_start, ts_end, speaker,
               quote_verbatim, kind: declarative|behavioral, topics[],
               interaction_frame: {about_therapy_relation: bool,          # v1.4
                                   addressee: therapist|part|other},
               observed_by: therapist|self}                               # v1.4
   # interaction_frame — materiał przeniesieniowy (psychodynamiczna) i segmenty
   # eksperymentów (Gestalt: addressee=part); observed_by — obserwacja
   # terapeuty o kliencie („widzę, że zaciskasz pięści") vs samoopis;
   # obserwacja terapeuty o KLIENCIE nie narusza R10
   → WERYFIKACJA MECHANICZNA (Go): quote_verbatim musi być podłańcuchem
     transkryptu (fuzzy match, próg podobieństwa ≥ 0.95 po normalizacji);
     brak dopasowania = odrzucenie spanu i licznik metryki s1_reject
   │
   ▼
S1.5 DOWODY WZORCOWE                           (Go — deterministyczne, nie LLM;
   specyfikacja: dokument 13, sekcja 3; latency: dokument 15, sekcja 2.2-d)
   → patterns[]: {pattern_id, type ∈ {recurrence, co_occurrence, sequence,
                  distribution, trend, latency}, spans[], method, method_version, ...}
   latency (v1.4): pauzy > progu przed/po temacie, w N przypadkach — ze
   znaczników ciszy istniejącego chunkera 600 ms (zero nowej infrastruktury);
   progi konserwatywne; NIGDY nie renderowany samodzielnie jako teza —
   wyłącznie jako dowód interpretacji (np. „opór")
   wzorce są DOWODAMI, nie twierdzeniami — cytowalne w evidence na równi
   ze spanami; pełna proweniencja do spanów bazowych; nieobecności — v2
   │
   ▼
S2  MAPOWANIE PER KONSTRUKT                    (Gemini Flash, T=0; osobne wywołanie
   na typ konstruktu — nigdy „cała konceptualizacja naraz";
   rationale doboru modelu: sekcja 2a — jedyny etap dotykający teorii)
   wejście:  spans[] + CAŁOŚĆ wiedzy kanonicznej dla konstruktu:
             wyciąg L1 (dokument 12) + definicja + values(enum) + is_not + aliases
             + common_confusions + przykłady/kontrprzykłady
             — L1+L2 w całości, bez selekcji retrievalem;
             S2 NIE KONSUMUJE WYNIKÓW RAG (reguła z sekcji 2a, wymuszona
             brakiem zależności serwisowej, nie konwencją)
   wyjście (walidacja JSON Schema z enumem z ontologii):
     {construct_id, category ∈ values | null,
      evidence: [span_id], counter_evidence: [span_id],
      confidence: 0..1, epistemic_status ∈ statuses,
      insufficient_data: bool, no_fit: bool, missing: string}
   „insufficient_data" (za mało danych) i „no_fit" (danych dość, zjawisko
   poza taksonomią) są odpowiedziami pierwszej klasy — prompt jawnie
   premiuje je nad wybór najbliższej kategorii z listy (forced-choice bias);
   KALIBRACJA DWUSTRONNA (dokument 13, sekcja 6): przeoczenie jest błędem
   symetrycznym do zmyślenia — prompt nazywa obie klasy; właściwą reakcją
   na niepewność jest obniżenie statusu, nie pominięcie
   │
   ▼
S3  WALIDATOR DZIEDZINOWY                      (Go — deterministyczny, nie LLM)
   R1 enum: category ∈ values (drugi bezpiecznik po schemacie)
   R2 coverage: |evidence| ≥ min_evidence.spans; kind=behavioral jeśli wymagane;
      rozpiętość sesji ≥ min_evidence.sessions
   R3 requires: konstrukt bez spełnionych zależności → degradacja do
      fallback_rendering; NIGDY podniesienie rangi
   R4 entailment ROZWARSTWIONY PER STATUS EPISTEMICZNY (dokument 13, sekcja 5):
      observation — entailment ścisły (Flash, „czy fragment wspiera
      twierdzenie: tak/nie/częściowo"); interpretation — złagodzony
      (≥ 2 spany tak/częściowo, zero „nie"); theoretical_hypothesis —
      TEST SPÓJNOŚCI zamiast wynikania (zgodność + niesprzeczność)
      z obowiązkowym markerem abdukcyjnym w renderowaniu; spany niezgodne
      z hipotezą → contradicting, NIE kasacja; spadek poniżej min_evidence
      → insufficient_data
   R5 etiologia: twierdzenia genetyczne (dzieciństwo, rodzina pochodzenia,
      „mikrotrauma", wzorce międzypokoleniowe) dopuszczone WYŁĄCZNIE ze spanem
      źródłowym wprost o przeszłości; inaczej twarde odrzucenie + metryka
   R6 is_not: kategoria z common_confusions → odrzucenie + zapis do rejestru
   R7 no_fit: przechodzi do S4 jako obserwacja bez kategorii (spany + opis
      zjawiska, bez przypisania taksonomicznego); NIGDY nie jest mapowane
      wstecznie na najbliższą kategorię; licznik per konstrukt → rejestr
      luk ontologii (sygnał dla ekspertów)
   R9 kwantyfikacja (v1.3, dokument 14 §4/M3): wartość liczbowa (natężenie,
      siła przekonania, SUDS) dopuszczalna WYŁĄCZNIE ze spanem, w którym
      padła (weryfikacja mechaniczna w quote_verbatim, z odpowiednikami
      słownymi); liczba bez spanu = twarde odrzucenie + metryka —
      fabrykowana precyzja jest konfabulacją; wyjątek: entry_ref
      (klient sam wpisał wartość w aplikacji — stated_only z definicji)
   R10 GRANICA TERAPEUTY (v1.4, przekrojowa — dokument 15 §2.2-a; T28,
      wdrażana natychmiast): twierdzenia wyłącznie o materiale KLIENTA;
      podmiot=terapeuta + predykat mentalny w twierdzeniu = twarde odrzucenie
      + metryka; treści o doświadczeniu terapeuty (np. przeciwprzeniesienie)
      wyłącznie jako entry_ref jego autorstwa, render z atrybucją
      „notatka terapeuty"; wypowiedzi terapeuty w transkrypcie pozostają
      legalnymi dowodami (observed_by: therapist — o kliencie)
   wynik: approved_claims[] + rejected[] (z powodami — do telemetrii i benchmarku)
   │
   ▼
S2b INTEGRACJA MIĘDZY-KONSTRUKTOWA             (niewdrożone; przy wdrożeniu
                                                dobór modelu jak S2, T=0;
   specyfikacja: dokument 13, sekcja 4; za flagą REPORT_RELATIONS_ENABLED — D2/13)
   wejście: approved_claims[] + patterns[] + L1/L2 dla występujących konstruktów
   — S2b NIE WIDZI TRANSKRYPTU (inwersja antykonfabulacyjna jak w S4)
   wyjście: relations[] {relation_type ∈ {wspolwystepowanie, napiecie,
            sekwencja, sprzecznosc, wzmocnienie, mediacja, paralela},
            involves: [claim|pattern]≥2 (paralela: instances z zatwierdzonych
            twierdzeń/kompozytów), roles? {trigger, mediator, outcome} dla
            mediacji, shared_pattern_description? dla paraleli,
            evidence, hypothesis_text, epistemic_status, confidence}
   pusta lista = pełnoprawna odpowiedź; zakaz wprowadzania nowych bytów
   │
   ▼
S3b WALIDACJA RELACJI (R8)                     (Go + celowany entailment;
   dokument 13, sekcja 4.3; mediacja: dokument 14 §5.1; paralela: dokument 15 §2.2-c)
   R8a elementy involves/evidence istnieją w zbiorze zatwierdzonym
   R8b zakaz nowych bytów (kategorie tylko z involves; R5 i R10 stosują się —
       w tym do shared_pattern_description)
   R8c wymogi dowodowe per typ (sekwencja→pattern sequence; sprzecznosc→
       celowany test niezgodności; mediacja→pattern sequence obejmujący
       trigger→mediator→outcome LUB kompozyt z wypełnionymi slotami)
   R8d MONOTONICZNOŚĆ STATUSU: relacja nigdy mocniejsza epistemicznie
       niż najsłabszy element involves; mediacja dodatkowo nigdy mocniejsza
       niż interpretation; paralela TWARDO theoretical_hypothesis
       (sąd LLM o izomorfizmie strukturalnym — najsłabiej gwarantowalny typ)
       + marker abdukcyjny zawsze; flaga wyłączenia paraleli per modalność
   R8e limit relacji per raport (D1/13); nadwyżka wg confidence × waga typu
   │
   ▼
S2c DETEKCJA CYKLI                             (Go — deterministyczna, ZERO LLM;
   dokument 14, sekcja 5.2)
   graf skierowany: wierzchołki = claims/patterns, krawędzie = zatwierdzone
   relacje sekwencja/mediacja/wzmocnienie
   → cycles[]: {cycle_id, edges: [relation_id], nodes}; cykle proste ≤ 6 krawędzi
   status cyklu = najsłabszy status krawędzi; proweniencja pełna po krawędziach
   rendering: „możliwe błędne koło" — zawsze theoretical_hypothesis + marker
   abdukcyjny; najbardziej kliniczny wniosek (cykl podtrzymujący) powstaje
   algorytmicznie z już zwalidowanych krawędzi
   │
   ▼
S4  SYNTEZA RAPORTU                            (Gemini Flash)
   wejście: WYŁĄCZNIE approved_claims[] + approved_relations[] + patterns[]
   + cycles[] — S4 NIE MA DOSTĘPU DO TRANSKRYPTU; generator pisze język,
   nie decyduje o treści
   pola bez zatwierdzonych twierdzeń → rendering „na obecnym etapie brak
   wystarczających danych" + wygenerowane pytanie na kolejną sesję
   sekcja „Powiązania i wzorce" z approved_relations i cycles (znika przy
   pustych); relacje sprzecznosc zasilają pole contradicting hipotez;
   markery abdukcyjne przy theoretical_hypothesis i przy cyklach
   format: przestrzeń hipotez (sekcja 5) — zależnie od D1
   │
   ▼
S5  WERYFIKATOR WYJŚCIA                        (guardrail-svc, rozszerzony)
   V1 każde zdanie wnioskujące ma odnośnik [span|pattern|entry] i epistemic_status
   V2 brak terminów kategorii spoza ontologii w trybie oznajmującym
   V3 brak zdań etiologicznych bez proweniencji
   V4 zgodność liczby/hierarchii hipotez z approved_claims
   V5 każda relacja/cykl w prozie ma odpowiednik w approved_relations/cycles;
      markery abdukcyjne obecne przy hipotezach i cyklach
   V6 (v1.3) żadna wartość liczbowa w prozie bez pokrycia w zatwierdzonym
      twierdzeniu z ważnym spanem/entry (lustro R9 na wyjściu)
   naruszenie → regeneracja S4 (max 2) → przy dalszym naruszeniu raport
   w trybie ekstraktywnym (cytaty + kategorie bez prozy) + alert
```

**Kluczowa inwersja (odpowiedź na objaw 5):** koszt dopowiedzenia przestaje być zerowy, ponieważ S4 (i analogicznie S2b) fizycznie nie widzi materiału źródłowego — wszystko, czym dysponuje, zostało już policzone, skategoryzowane i podparte w S1–S3. **Zasada głębi (v1.2):** głębia wewnątrz szyn, nie zamiast szyn — S2b może wyłącznie łączyć zatwierdzone byty, nigdy tworzyć nowych; wzorce S1.5 czynią meta-obserwacje („trzeci raz powtarza się…") legalnymi dowodami zamiast dopowiedzeń; S2c (v1.3) wykrywa cykle algorytmicznie z zatwierdzonych krawędzi — najbardziej kliniczny wniosek bez udziału LLM.

**Polityka treści ryzyka (v1.3, przekrojowa — dokument 14, sekcja 7):** spany o treściach ryzyka (suicydalne, autoagresja, przemoc, dekompensacja) są wydzielane deterministycznie po S1 (próg niski — asymetria jak w R_RISK czatu) i **wyłączane z S2/S2b/S2c oraz ze statystyk S1.5** — żadnych wniosków, wzorców ani relacji na ich bazie (egzekwowane w kodzie, test negatywny; T22, wdrażane natychmiast). Render osobnej sekcji „wypowiedzi wymagające uwagi klinicysty" (wyłącznie verbatim + sygnatura, zero oceny/natężeń/trendów) — za flagą, domyślnie wyłączony do opinii doradcy regulacyjnego; automatyczna ocena/alarm ryzyka = klasa IIb i pozostaje poza zakresem produktu.

---

## 5. Format przestrzeni hipotez (rekomendowany domyślny — D1)

Zamiast pojedynczej „ostatecznej konceptualizacji" raport prezentuje dla konstruktów interpretacyjnych:

```json
{
  "construct_id": "inner_conflict",
  "hypotheses": [
    {"id": "A", "claim": "...",
     "supporting": ["s12", "s31"], "contradicting": ["s44"],
     "theory_fit": {"modality": "ppt", "fit": "zgodna", "notes": "..."},
     "epistemic_status": "theoretical_hypothesis", "confidence": 0.62},
    {"id": "B", "claim": "...",
     "supporting": ["s31"], "contradicting": [],
     "epistemic_status": "interpretation", "confidence": 0.41}
  ],
  "unknown_yet": ["..."],
  "next_session_questions": ["..."],
  "pattern_notices": ["trzeci raz w materiale powtarza się wzorzec X (s07, s19, s31)"]
}
```

Funkcje docelowe (za recenzentem): „tego mogłaś nie zauważyć", „są co najmniej dwie możliwe interpretacje", „ten fragment przeczy pierwszej hipotezie", „tu nie mamy jeszcze danych", „powtarza się wzorzec", „warto sprawdzić Z na kolejnej sesji zamiast przyjmować jako fakt".

Uzasadnienie potrójne: (a) klinicznie — superwizja poszerza przestrzeń dobrze ugruntowanych hipotez terapeuty zamiast zamykać ją jedną narracją; (b) bezpieczeństwo — pojedynczy błąd modelu jest widoczny na tle danych przeciw, nie ukryty w płynnej prozie; (c) regulacyjnie — obrona „klinicysta jako autor decyzji" staje się realna, nie deklaratywna. **Uczciwie:** format nie wyprowadza funkcji poza wnioskowanie o konkretnym kliencie — kwalifikacja MDR bez zmian (sekcja 10).

**UI:** statusy epistemiczne rozróżnione wizualnie (obserwacja / interpretacja / hipoteza teoretyczna / pytanie otwarte / brak danych); każde twierdzenie klikalne → span w transkrypcie z sygnaturą; pola „brak danych" renderowane jako zaproszenie („co warto sprawdzić"), nie jako pusty błąd. Teksty w `.arb`.

---

## 6. Integracja z AI Chat

Ta sama maszyneria, inne punkty zaczepienia; potok płytszy ze względu na budżet latencji z ADR czatu (p95 ≤ 1,5 s dla guardrail; odpowiedzi mogą streamować).

| Element czatu | Zmiana |
|---|---|
| `A7_TEMPLATE_MAP` | Kategorie szablonu pochodzą **z enumów ontologii** — terapeuta wybiera kategorię z listy zamkniętej (UI: picker, nie wolny tekst), system podpina spany. Znika wektor „wpisz spokój jako potencjalność", bo kategorie nie są generowane |
| `A4_EDU` | Odpowiada z ontologii (definicje, `is_not`, przykłady) + RAG po literaturze — tu RAG jest właściwym narzędziem (tekst teorii, nie klasyfikacja) |
| `A1_SEARCH` / `A5_SUPERVISION_PACK` | Korzystają ze spanów S1 (cache per sesja po wygenerowaniu raportu) — spójna proweniencja między raportem a czatem |
| Weryfikator wyjścia czatu | + reguły ontologiczne: zakaz terminów kategorii spoza enumu w trybie oznajmującym; zakaz etiologii bez spanu |
| Test entailmentu | Współdzielony komponent `guardrail-svc` (S3-R4 i weryfikator czatu) |
| S1 | Uruchamiany raz per sesja (przy transkrypcji), wynik cache'owany — czat nie płaci latencji ekstrakcji |

---

## 7. Zmiany w serwisach

| Serwis | Zmiana | Uwagi |
|---|---|---|
| `ontology-registry` (nowy, lekki) lub moduł w `guardrail-svc` | Ładowanie/walidacja ontologii z repo, serwowanie enumów i reguł do S2/S3/czatu; cache; endpoint wersji | Ontologia jest read-only w runtime; zmiana = release |
| `llm-worker` | Rozbicie generacji raportu na S1/S2/S4 z osobnymi promptami; structured output per konstrukt | Prompty wersjonowane; ID promptu i wersji ontologii w metadanych raportu |
| `guardrail-svc` | S3 (walidator dziedzinowy), S5 (rozszerzony weryfikator), komponent entailment | Wspólny dla raportu i czatu |
| `clinical-svc` | Model danych: spans, claims (z proweniencją), raport jako graf twierdzeń, wersje ontologii/promptów per raport | Migracja: dotychczasowe raporty oznaczone `pipeline_version=legacy` |
| UI web/Flutter | Rendering statusów epistemicznych, klikalne spany, picker kategorii w A7, rendering „brak danych" | `.arb` z opisami |
| CI | Walidacja ontologii metaschematem; blokada pustego `approved_by`; benchmark gate (sekcja 8) | |

Każdy raport zapisuje: `ontology_version`, `prompt_versions{s1,s2,s4}`, `validator_version` — pełna odtwarzalność do audytu i benchmarku.

---

## 8. Benchmark i pętla ewaluacji

### 8.1. Złoty zestaw

- Transkrypty: rzeczywiste za zgodą lub kontrolowane/syntetyczne pisane pod klasy błędów; min. 15–20 na modalność na start.
- Niezależne konceptualizacje ≥ 2 ekspertów per transkrypt; rozstrzyganie rozbieżności udokumentowane (rozbieżność ekspertów to też dana — konstrukty o niskiej zgodności międzyeksperckiej dostają wyższe progi `min_evidence` albo status „zawsze hipoteza").
- **Protokół osiągalności (v1.4, wszystkie modalności):** ekspert oznacza per ustalenie `osiągalność: transcript | in_person_only`; recall liczony względem osiągalnych; odsetek `in_person_only` raportowany osobno jako **sufit pokrycia modalności** i komunikowany użytkownikom w onboardingu (dla PPT/CBT bliski zeru — to też informacja; dla Gestalt istotny — dokument 15 §3.2).
- Taksonomia błędów = 7 klas z feedbacku + klasy z produkcji.
- Proces zasilania: stress-testy recenzenta z Ewą sformalizowane jako rola (ekspert walidujący ontologię + anotator benchmarku); każdy znaleziony błąd → przykład w zestawie + wpis w `common_confusions`.

### 8.2. Metryki i bramka CI (release promptu lub ontologii = przebieg pełnego benchmarku)

| Metryka | Definicja | Próg startowy |
|---|---|---|
| Trafność kategorii | Zgodność S2 z ekspertem per konstrukt; dla konstruktów `multi_label` — **F1 per etykieta (micro/macro osobno)**, nieporównywalna wprost z accuracy single-label | ≥ 0,85 (kalibrować) |
| Pokrycie dowodowe | Odsetek twierdzeń z ≥ 1 ważnym (po R4) spanem | **100 %** (twarde) |
| Wskaźnik konfabulacji etiologii | Twierdzenia genetyczne bez spanu przechodzące do S4 | **0** (twarde) |
| Fabrykacja wartości liczbowych (v1.3) | Wartości ilościowe bez spanu/entry źródłowego przechodzące R9 | **0** (twarde) |
| Wskaźnik konfabulacji ogólny | Twierdzenia bez oparcia (ocena ekspercka) | ≤ 2 % |
| Odsetek `insufficient_data` | Na zestawie z celowo niepełnymi danymi | > 0 — **raport wypełniony w 100 % na takim zestawie = fail** |
| Recall `no_fit` | Na zestawie z celowo pozataksonomicznymi zjawiskami (danych dość, kategoria nie istnieje) — czy S2 zwraca `no_fit` zamiast najbliższej kategorii | ≥ 0,80 (kalibrować); wybór kategorii z listy na tym zestawie = błąd forced-choice |
| Kalibracja pewności | ECE na deklarowanym `confidence` | ≤ 0,10 |
| Zgodność hipotez alternatywnych | Czy przy danych wieloznacznych generowane ≥ 2 hipotezy | ≥ 0,80 |
| **Recall ustaleń eksperckich** (miara anty-lobotomijna; dokument 13, sekcja 7) | Odsetek ustaleń z konceptualizacji eksperckich wydobytych przez system z poprawnym lub słabszym statusem; **liczony względem ustaleń `osiągalność: transcript`** (v1.4) | ≥ 0,70 ogółem; **≥ 0,85 dla `krytyczne`** |
| Nietrywialność hipotez | Ocena ekspercka 1–4 „czy wnoszące"; parafrazy w parach A/B = fail pozycji | Średnia ≥ 2,5; parafrazy ≤ 10 % |
| Pokrycie integracyjne | Odsetek relacji z anotacji eksperckich odnalezionych przez S2b | ≥ 0,60 (kalibrować) |
| Precyzja relacji | Odsetek relacji S2b ocenionych przez eksperta jako zasadne | ≥ 0,80 |
| Precyzja `paralela` (v1.4) | Osobno od innych typów — sąd o izomorfizmie jest najsłabiej gwarantowalny | ≥ 0,85; poniżej → typ wyłączany flagą per modalność |
| Naruszenia R10 (v1.4) | Twierdzenia o stanach wewnętrznych terapeuty przechodzące walidację (zestaw adversarialny) | **0** (twarde) |
| Recall cykli (v1.3) | Odsetek błędnych kół z anotacji eksperckich odnalezionych przez S2c (dopasowanie węzłów) | ≥ 0,60 (kalibrować) |
| Abstencja dwustronna | `insufficient_data` na zestawie z danymi kompletnymi | ≤ 10 % |
| Regresja | Dowolna metryka poniżej wyniku poprzedniej wersji o > 2 p.p. | blokada release |

### 8.3. Telemetria produkcyjna (bez PII, spójna z ADR czatu)

`report_claim_generated {construct, category|categories, epistemic_status, n_evidence}`, `report_claim_rejected {rule: R1..R7, R9, R10}`, `report_relation_generated {type, status}`, `report_relation_rejected {rule: R8a..R8e}`, `report_relation_clicked {type}`, `report_cycle_detected {n_edges}` / `report_cycle_clicked` (v1.3), `report_risk_span_excluded` (licznik bez treści — v1.3, T22), `report_pattern_notice_shown / _clicked {pattern_type}`, `report_field_insufficient_data {construct}`, `report_construct_no_fit {construct}` (rejestr luk ontologii), `report_span_clicked` (czy terapeuci weryfikują proweniencję — wskaźnik UX i nadzoru), `s1_reject_rate`, `s4_regeneration_rate`, `report_hypothesis_selected {id, rank}` (którą hipotezę terapeuta oznacza jako roboczą — pętla uczenia i dowód autorstwa klinicysty).

Progi przeglądu: `report_claim_rejected(R5) > 5 %` miesięcznie → audyt promptu S2; `report_construct_no_fit` > 10 % dla konstruktu w kwartale → przegląd ekspercki ontologii (luka taksonomii albo błędna definicja L1); `report_relation_rejected(R8b) > 10 %` → S2b próbuje przemycać nowe byty → audyt promptu; interakcje z relacjami/wzorcami bliskie zeru przez kwartał → S2b nie dowozi wartości → przegląd przed skalowaniem na kolejne modalności; `report_span_clicked` bliskie zeru → terapeuci nie weryfikują → przegląd UX (ryzyko automation bias); rozkład `report_hypothesis_selected` zdominowany przez hipotezę A → sprawdzić, czy kolejność nie sugeruje „poprawnej" odpowiedzi (randomizacja kolejności hipotez o zbliżonym confidence).

---

## 9. Czego ta architektura NIE rozwiązuje (nazwane wprost)

- **Jakości treści ontologii** — gwarantuje egzekwowanie taksonomii, nie jej poprawność; ta zależy od pracy eksperckiej (D2). Błędna ontologia = spójnie egzekwowany błąd.
- **Kwalifikacji MDR** — konceptualizacja pozostaje wnioskowaniem o konkretnym kliencie (sekcja 10); dotyczy to również relacji S2b.
- **Trafności pojedynczej hipotezy** — obniża wagę tego problemu (dane przeciw są widoczne), nie eliminuje go.
- **Automation bias** — terapeuta nadal może przyjmować hipotezę A bezrefleksyjnie; adresowane miękko (UX, telemetria `report_span_clicked`, randomizacja kolejności), nie twardo; relacje S2b mogą go pogłębić przy zbyt autorytatywnym renderowaniu — stąd markery i statusy w UI jako warunek T18.
- **Nieobecności** (systematyczne niepodejmowanie tematu) — odroczone do v2 z warunkami z dokumentu 13, sekcja 3.4 (baza oczekiwań wyłącznie z jawnych źródeł; status zawsze `open_question`).
- **Jednej zintegrowanej narracji klinicznej** — celowo poza zakresem (teza produktowa „drugi system myślenia", teza recenzenta, pozycja regulacyjna); S2b dowozi połączenia, nie opowieść.
- **Sufitu anotacyjnego** — metryki głębi mierzą zgodność z ekspertami; głębsze niż złoty zestaw nie zmierzymy.
- **Modalności bez stabilnej taksonomii** — szkoły o luźnej strukturze pojęciowej dostaną ontologię „miękką" (mniej enumów, więcej statusów hipotetycznych); metaschemat to dopuszcza, ale wartość walidatora będzie tam niższa.

---

## 10. Sprzężenie regulacyjne

- Raport konceptualizacyjny (key conflict, Positum, geneza, model równowagi zastosowany do klienta) = **P2/strefa czerwona** w taksonomii ADR czatu — tworzenie nowej informacji klinicznej o konkretnym pacjencie (Reguła 11 MDR). Architektura S1–S5 tego nie zmienia.
- Co architektura zmienia: (a) dowodliwość kontroli przeznaczenia (rejestr odrzuceń R1–R7, proweniencja, statusy epistemiczne — pakiet na etap art. 94); (b) profil ryzyka pojedynczego błędu (format hipotez + dane przeciw); (c) realność obrony „klinicysta autorem decyzji" (`report_hypothesis_selected`, pola wnioskowe user-only w szablonach); (d) pozycję pod dyrektywą 2024/2853 (udokumentowany, testowany benchmarkiem proces jakości).
- **Wymagane domknięcie w ADR (D1):** raport konceptualizacyjny jako jawny moduł czerwony za flagą (podejście modułowe MDCG 2019-11, rozdz. 10.5 analizy) — albo w formacie przestrzeni hipotez jako domyślnym, z nazwanym ryzykiem rezydualnym, że format nie zmienia kwalifikacji.
- Spójność z AUP dostawcy modelu (Google/Vertex: nadzór wykwalifikowanego profesjonalisty + ujawnienie AI): statusy epistemiczne, proweniencja i wybór hipotezy przez terapeutę są implementacją tych wymogów, nie tylko MDR.

---

## 11. Plan wdrożenia — tickety

Fazowanie: F1 fundament (T1–T4) → F2 potok raportu (T5–T8) → F3 benchmark + gate (T9–T10) → F4 integracja czatu (T11–T12) → **F4b głębia (T13–T18, dokument 13; S2b za flagą do przejścia progów)** → F5 pozostałe modalności (po D3; CBT jako nr 2 — dokument 14; dalej psychodynamiczna → schematy → Gestalt — dokument 15/D5; tickety silnika T19–T22, T28–T33 mogą wejść wcześniej, bo są zmianami metaschematu/walidatora, nie treści; **T22, T28 i T32 — wdrażane natychmiast, niezależnie od kolejności modalności**).

| # | Ticket | Definition of Done |
|---|---|---|
| T1 | Metaschemat ontologii + walidacja CI | `ontology/_meta/schema.yaml`; CI odrzuca plik niezgodny lub z pustym `approved_by`; test negatywny |
| T2 | Ontologia PPT 0.1.0 — szkielet do autoryzacji | Plik z pełną strukturą i placeholderami (w tym `aliases`, `source`); sesja robocza z ekspertami zaplanowana **wspólnie z K2–K3 z dokumentu 12** (te same osoby, jedna sesja); changelog decyzji eksperckich |
| T3 | `ontology-registry` (lub moduł w `guardrail-svc`) | Endpointy: enums, rules, aliases, wersja; cache; testy; OTel |
| T4 | Model danych spans/claims w `clinical-svc` | Migracje SQL (sqlc); proweniencja span→claim; `pipeline_version` na raportach; test odtwarzalności (raport → wersje ontologii/promptów) |
| T5 | S1 ekstrakcja + weryfikacja mechaniczna cytatów | Fuzzy match ≥ 0,95; metryka `s1_reject_rate`; cache per sesja; testy na transkryptach z chunkera 600 ms |
| T6 | S2 mapowanie per konstrukt | Prompt per typ konstruktu; JSON Schema z enumem z registry; kontekst = pełne L1+L2 (bez retrievalu — brak zależności S2→L3 wymuszony architektonicznie, test negatywny); `insufficient_data` i `no_fit` ścieżkami testowanymi jawnie; T=0 |
| T7 | S3 walidator R1–R7 | Reguły deterministyczne + entailment R4; obsługa `no_fit` (R7: obserwacja bez kategorii, rejestr luk, zakaz mapowania wstecznego); rejestr odrzuceń z powodami; testy jednostkowe per reguła; **R5: 0 fałszywych przepuszczeń na zestawie adversarialnym etiologii** |
| T8 | S4 synteza bez transkryptu + S5 weryfikator | S4 przyjmuje wyłącznie zatwierdzone byty (claims; po T14–T15 także relations i patterns) — wymuszone sygnaturą funkcji, nie konwencją; V1–V4 (V5 dochodzi w T18); regeneracja max 2 → tryb ekstraktywny + alert |
| T9 | Benchmark harness + złoty zestaw PPT | ≥ 15 transkryptów, ≥ 2 konceptualizacje eksperckie każdy; podzbiór z celowo pozataksonomicznymi zjawiskami (test `no_fit`) i z niepełnymi danymi (test `insufficient_data`); metryki 8.2 liczone automatycznie; raport porównawczy wersji |
| T10 | Bramka CI benchmarku | Release promptu/ontologii blokowany progami 8.2; wynik w PR |
| T11 | Czat: A7 z pickerem kategorii z ontologii; A4 z ontologii+RAG | UI picker (web+Flutter) z `aliases` w wyszukiwaniu kategorii; A4 wg dokumentu 12 sekcja 6 (próg odmowy, odesłania bibliograficzne); weryfikator czatu z regułami ontologicznymi; latencja p95 ≤ 1,5 s utrzymana |
| T12 | UI raportu: statusy, klikalne spany, „brak danych" jako zaproszenie, wybór hipotezy roboczej | `.arb`; telemetria 8.3; test dostępności |
| T13–T18 | **Głębia wnioskowania** — S1.5 silnik wzorców, S2b integracja, S3b/R8, rozwarstwienie R4, benchmark głębi (ponowna anotacja ekspercka!), UI powiązań | Pełne DoD: dokument 13, sekcja 12; S2b za flagą `REPORT_RELATIONS_ENABLED` do przejścia progów 8.2 |
| T19–T27 | **Rozszerzenia CBT/metaschemat** — M1–M3 + `forced_status` + `entry_ref` (T19), R9 (T20), `mediacja` + S2c (T21), wyłączenie spanów ryzyka (T22 — **natychmiast**), sekcja ryzyka za flagą (T23), ontologia `cbt/` + L1 + korpus (T24), migracja PPT na composite (T25), benchmark CBT (T26), formularze aplikacji towarzyszącej (T27) | Pełne DoD: dokument 14, sekcja 11; T24–T27 po przejściu PPT przez benchmark (D3) i decyzjach D1–D4/14 |
| T28–T36 | **Rozszerzenia psychodynamiczna/Gestalt** — R10 granica terapeuty (T28 — **natychmiast**), `interaction_frame`+`observed_by` (T29), wzorzec `latency` (T30), relacja `paralela` (T31), protokół osiągalności (T32 — **przekrojowy, z najbliższą falą**), M5 `report_profile` (T33), ontologie `psychodynamic/` i `gestalt/` + L1 + korpusy (T34–T35), benchmarki obu modalności (T36) | Pełne DoD: dokument 15, sekcja 6; T34–T36 po benchmarku CBT, zgodnie z kolejnością D5/15 |

---

## 12. Decyzje blokujące

Decyzje D1–D3 tego dokumentu — poniżej. Decyzje warstwy wiedzy (model treści produktowych, licencje, terminologia PL) — dokument 12, sekcja 11. Decyzje głębi (limit relacji, tryb wdrożenia S2b, budżet anotacji) — dokument 13, sekcja 13. Decyzje CBT (kanon zniekształceń/emocji, REBT jako wariant, polityka ryzyka, formularze aplikacji) — dokument 14, sekcja 10. Decyzje psychodynamiczna/Gestalt (kanony, poziomy organizacji poza v1, budżet anotacji hypothesis-heavy, kolejność 3–5) — dokument 15, sekcja 8. D3 z dokumentu 13 (budżet ekspercki) łączy się z D2 poniżej w jedną pulę pracy do zakontraktowania; rozstrzygnięcia D3/14 (polityka ryzyka) i D2/15 (poziomy organizacji) wymagają doradcy regulacyjnego i są niezależne od kolejności modalności.

| # | Decyzja | Opcje | Rekomendacja | Status |
|---|---|---|---|---|
| D1 | Format raportu głównego | A: pojedyncza konceptualizacja (moduł jawnie czerwony za flagą) · B: przestrzeń hipotez jako domyślna · C: B domyślnie + A za osobną flagą jako świadome rozszerzenie | **B** (rekomendacja recenzenta i autora dokumentu); C akceptowalna, jeśli A ma realny popyt | ☐ otwarta |
| D2 | Właścicielstwo ontologii | Proces: Ewa + recenzent jako approvers (CODEOWNERS `ontology/`), PR z uzasadnieniem klinicznym, semver; nakład: dni pracy eksperckiej na modalność | Zatwierdzić proces i zakontraktować pracę ekspercką **przed** T2 | ☑ rozstrzygnięta 22.08.2026 — MECHANIZM ZMIENIONY względem opcji z tego wiersza (adnotacja pod tabelą); nakład ekspercki do zakontraktowania bez zmian |
| D3 | Kolejność modalności | Sekwencyjnie (PPT → benchmark → kolejne) vs równolegle | **Sekwencyjnie** — metaschemat wykuje się na PPT i zmieni się co najmniej raz; po benchmarku PPT: **CBT (nr 2)** → **psychodynamiczna (nr 3)** → **terapia schematów (nr 4)** → **Gestalt (nr 5)** — uzasadnienia: dokumenty 14 i 15 §4 | ☐ otwarta |

### Adnotacja do D2 (22.08.2026 — decyzja produktowa, plan wykonawczy: dokument 16 v1.2)

Mechanizm własnościowy ontologii został rozstrzygnięty INACZEJ, niż
zakładał ten dokument: zamiast plików w repo (PR + CODEOWNERS,
read-only w runtime) ontologia żyje w bazie i jest edytowana w
**Ontology Studio**, z cyklem życia `draft → ready_for_review →
approved`, rolą `ONTOLOGY_EDITOR` dla ekspertów klinicznych i
**aktywacją produkcyjną wyłącznie przez SUPERWIZOR_ADMIN** (osobna
operacja od zatwierdzenia; wymaga statusu `approved` i zielonego
benchmarku z sekcji 8).

Intencja D2 pozostaje w mocy w całości — zmienił się nośnik, nie
zasady. Własności, które ten dokument uzasadniał mechanizmem
PR/CODEOWNERS, są odtworzone środkami Studia i traktowane jako
nienegocjowalne (dokument 16 §1): (a) wersja `approved` jest
niemutowalna — edycja to nowa wersja `draft`; (b) autor wersji nie
może jej sam zatwierdzić (four-eyes egzekwowane serwerowo);
(c) walidacja metaschematem z sekcji 3.2 jest twarda przy zapisie,
zatwierdzeniu i aktywacji; (d) pełny audyt każdego przejścia z
wymaganą notatką. Treść ontologii nadal piszą i autoryzują eksperci
kliniczni (sekcja 3.1, zdanie pierwsze — bez zmian); zdanie „ontologia
jest danymi w repo" z sekcji 3.1 oraz uwaga „read-only w runtime" z
sekcji 7 należy czytać przez pryzmat tej adnotacji: pliki
`ontology/<modality>/<semver>.yaml` pozostają w repo jako SEEDY i
dokumentacja formatu, nie jako źródło prawdy runtime.

Ryzyko rezydualne nazwane wprost: przeniesienie autoryzacji z PR do
aplikacji obniża próg wprowadzenia zmiany (brak review kodu po drodze).
Kompensacja: four-eyes + niemutowalność + rozdzielenie „zatwierdzone"
od „aktywne" + benchmark jako bramka aktywacji. Rejestr zmian
merytorycznych ontologii przenosi się z historii gita do
`ontology_versions` + audytu Studia.

---

*Dokument wewnętrzny. Nie stanowi opinii prawnej. Wszystkie treści kliniczne ontologii (katalogi wartości, progi min_evidence) są placeholderami do autoryzacji eksperckiej.*
