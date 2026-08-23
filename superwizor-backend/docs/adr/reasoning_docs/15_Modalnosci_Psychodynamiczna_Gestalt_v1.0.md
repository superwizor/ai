# 15. Modalności: terapia psychodynamiczna i Gestalt — analiza dopasowania i synteza czterech modalności

| Pole | Wartość |
|---|---|
| Plik | `docs/15_Modalnosci_Psychodynamiczna_Gestalt.md` |
| Wersja | 1.0 |
| Data | 22 sierpnia 2026 r. |
| Status | Projekt — do zatwierdzenia decyzji D1–D5 (sekcja 8); rozszerzenia przekrojowe zintegrowane w dokumencie 11 v1.4 |
| Cel | Domknięcie testu generyczności na modalnościach atakujących architekturę z przeciwnych stron: psychodynamiczna kwestionuje drabinę dowodową (prawie nic nie jest obserwacją), Gestalt — pokrycie danych (znaczna część materiału jest niewerbalna); synteza wniosków z czterech modalności |
| Dokumenty powiązane | `11_Architektura_Wnioskowania_Ontologia.md` **v1.4**; `12_Zarzadzanie_Wiedza_Domenowa.md`; `13_Glebia_Wnioskowania.md`; `14_Modalnosc_CBT_Analiza_Dopasowania.md`; ADR-0YY; *Analiza wymagań regulacyjnych* rozdz. 3–4 |
| Zakres | Ontologie psychodynamiczna i Gestalt (inwentarze, szkice YAML), rozszerzenia silnika: relacja `paralela`, reguła **R10** (granica terapeuty), wzorzec `latency`, pola spanu `interaction_frame` i `observed_by`, profil raportu **M5**; protokół osiągalności w benchmarku; macierz syntezy czterech modalności i rekomendacja kolejności |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-22 | Pierwsza wersja. |

---

## 1. Streszczenie decyzyjne

**Werdykt:** psychodynamiczna pasuje w ~75 % — wymaga jednego nowego typu relacji (`paralela`), jednej twardej reguły przekrojowej (**R10**: zakaz inferencji o stanach wewnętrznych terapeuty), jednego typu wzorca (`latency` — za darmo z istniejącego chunkera 600 ms) i jednej metadanej spanu (`interaction_frame`). Gestalt enumeruje się ontologicznie zaskakująco dobrze (~70 % — przerwania kontaktu, cykl kontaktu, strefy świadomości to katalogi zamknięte), ale jego ograniczeniem wiążącym nie jest taksonomia, tylko **sufit pokrycia danych z transkryptu audio** — znaczna część materiału modalności jest niewerbalna i nazwać to trzeba uczciwie (protokół osiągalności w benchmarku, komunikacja sufitu w onboardingu), a nie maskować.

**Synteza czterech modalności:** teza generyczności („nowa modalność = nowy plik ontologii + praca ekspercka, nie nowy kod") broni się **z korektą sformułowania** — jest prawdziwa dla treści, ale pierwsze cztery modalności ujawniły po kilka rozszerzeń silnika każda. Kluczowa obserwacja: lista rozszerzeń **konwerguje** (psychodynamiczna i Gestalt współdzielą `interaction_frame` i `entry_ref`; Gestalt reużywa `napiecie`, `sequence` i detektor imperatywów z CBT; `paralela` przydaje się trzem modalnościom). Silnik zbliża się do kompletności — piąta modalność prawdopodobnie zmieści się w istniejącym metaschemacie.

**Elementy przekrojowe do wdrożenia niezależnie od kolejności modalności** (analogicznie do T22):
- **R10** — luka istnieje już dziś w PPT: nic nie broni S2 przed twierdzeniem o stanie psychicznym terapeuty.
- Pole **osiągalności** w protokole anotacji — uczciwość metryk recall dla każdej modalności.

**Rekomendacja kolejności po CBT** (do decyzji z danymi rynkowymi, D5): psychodynamiczna jako nr 3 mimo wyższego kosztu (obok CBT największa modalność w Polsce — argument rynkowy bije argument kosztowy), terapia schematów jako nr 4 (najtańsza ontologicznie), Gestalt jako nr 5 — po zbudowaniu adnotacji terapeuty (`entry_ref` z T27) i z jawnie zakomunikowanym sufitem pokrycia.

---

## 2. Terapia psychodynamiczna

### 2.1. Inwentarz pojęciowy → architektura

| Konstrukt | Katalog | Enum? | Charakterystyka dowodowa | Status domyślny | Dopasowanie |
|---|---|---|---|---|---|
| Mechanizmy obronne | **Zamknięty** ~20–30 (kanon D1: hierarchia Vaillanta vs McWilliams; dla PL naturalna McWilliams — *Diagnoza psychoanalityczna* jako `source` L1) | **Tak** | Obrona jest z definicji nieświadoma — klient nigdy nie wypowiada jej wprost; identyfikacja jest zawsze interpretacją z wzorca wypowiedzi | `interpretation`/`theoretical_hypothesis` — **`forced_status` obowiązkowy** | Dobre: enum + wymuszona pokora epistemiczna |
| Przeniesienie | Półzamknięty (idealizujące, negatywne, erotyczne, lustrzane…) | Typ tak | **Dowód relacyjny**: materiał kierowany do terapeuty / o relacji terapeutycznej — spany istnieją, liczy się adresat | `interpretation` | Wymaga `interaction_frame` (2.2-b) |
| **Przeciwprzeniesienie** | — | — | **Nie istnieje w transkrypcie** — wewnętrzne doświadczenie terapeuty | — | **R10** (2.2-a); wyłącznie `entry_ref` autorstwa terapeuty |
| Trójkąt konfliktu (impuls–lęk–obrona) | Struktura 3-elementowa | Kompozyt (M1) | Sloty = zatwierdzone twierdzenia z trzech domen | `theoretical_hypothesis` | M1 pasuje wprost |
| Trójkąt wglądu (przeszłość–teraźniejszość–przeniesienie) | Struktura 3-elementowa | Kompozyt + **`paralela`** | Analogia strukturalna między instancjami wzorca | `theoretical_hypothesis` | 2.2-c |
| Relacje z obiektem, wewnętrzne modele operacyjne | Otwarty | Nie | Konwergencja wielu spanów (jak core belief CBT) | `theoretical_hypothesis` | OK — `requires`+`min_evidence` |
| Materiał senny | Otwarty | Nie | Relacja klienta = span (`observation`); interpretacja = hipoteza | rozwarstwiony | R4 rozwarstwione pasuje idealnie |
| Opór, przebieg wolnych skojarzeń | Procesowe | Nie | Pauzy, zmiany tematu, milczenia | wzorzec → interpretacja | `latency` (2.2-d) + `sequence` |
| Poziomy organizacji osobowości (McWilliams) | Zamknięty | Technicznie tak | — | — | **Świadomie poza v1 — D2** (2.3) |

### 2.2. Cztery ustalenia

**(a) R10 — twarda reguła przekrojowa: zakaz twierdzeń o stanach wewnętrznych terapeuty.** Przeciwprzeniesienie jest kluczowym narzędziem modalności, ale jego jedynym legalnym źródłem jest sam terapeuta (notatka, wpis `entry_ref` user-authored). Model wnioskujący „terapeutka reaguje irytacją na materiał klienta" to nowa kategoria problemu, której R1–R9 nie łapią: nie konfabulacja o kliencie, lecz o **użytkowniku** — klinicznie inwazyjna, produktowo zabójcza dla zaufania, regulacyjnie otwierająca pytanie o „ocenę profesjonalisty".

Specyfikacja R10:
- Twierdzenia S2/S2b/S2c mogą dotyczyć wyłącznie materiału klienta; wypowiedzi terapeuty w transkrypcie są dowodami (kontekst, obserwacje typu `observed_by: therapist` — sekcja 3.2), nigdy przedmiotem inferencji o jego stanach psychicznych.
- Treści o doświadczeniu terapeuty (przeciwprzeniesienie, reakcje) wchodzą do raportu wyłącznie jako `entry_ref` autorstwa terapeuty, renderowane z atrybucją „notatka terapeuty".
- Egzekwowanie: walidacja słownikowo-klasyfikatorowa nad `hypothesis_text`/treścią twierdzeń (podmiot = terapeuta + predykat mentalny → odrzucenie + metryka `report_claim_rejected(R10)`); test negatywny w CI; zestaw adversarialny w benchmarku (0 przepuszczeń, twarde).
- **Wdrożenie natychmiast, niezależnie od kolejności modalności** — luka istnieje już dziś w PPT (T28).

**(b) `interaction_frame` — adresat/rama wypowiedzi jako metadana spanu.** Materiał przeniesieniowy to wypowiedzi o relacji terapeutycznej lub kierowane do terapeuty; S1 ma mówcę, nie ma ramy interakcyjnej. Rozszerzenie spanu: `interaction_frame: {about_therapy_relation: bool, addressee: therapist|part|other}` (wartość `part` obsługuje też eksperymenty Gestalt — sekcja 3.1). Nadawane w S1 (tanie — jedna etykieta więcej w istniejącej ekstrakcji); bez tego `min_evidence` dla przeniesienia nie ma czego liczyć.

**(c) Typ relacji `paralela` — analogia strukturalna.** Rdzeń wnioskowania psychodynamicznego: ten sam wzorzec relacyjny u ojca ≈ u szefa ≈ wobec terapeuty. Żaden z sześciu typów S2b tego nie niesie (`wspolwystepowanie` to koincydencja, nie izomorfizm).

```
relation{type: paralela,
         instances: [claim_id | composite_id] (≥ 2),
         shared_pattern_description: string,
         evidence, epistemic_status, confidence}
```

Uczciwie: to **najsłabiej gwarantowalny typ relacji** — ocena podobieństwa strukturalnego jest sądem LLM, nie algorytmem. Obostrzenia:
- Status twardo ograniczony do `theoretical_hypothesis` (zaostrzenie R8d dla tego typu) + marker abdukcyjny zawsze.
- `instances` wyłącznie z zatwierdzonych twierdzeń/kompozytów — konfabulacja ograniczona do samego sądu o podobieństwie, nie do treści instancji.
- `shared_pattern_description` podlega R8b (zakaz nowych bytów) i R10.
- Benchmark: osobna metryka precyzji z progiem **wyższym** niż dla innych typów (≥ 0,85); niska precyzja `paralela` → typ wyłączany per modalność flagą, bez wyłączania S2b w całości.
- Reużywalność: psychodynamiczna (trójkąt wglądu), Gestalt (wzorzec przez konteksty), PPT (przeniesienie koncepcji między sferami modelu równowagi).

**(d) `latency` — wzorce ciszy za darmo z istniejącego stacku.** Pipeline STT tnie na pauzach z progiem 600 ms — **znaczniki czasowe ciszy już istnieją w danych**. Nowy deterministyczny typ wzorca S1.5:

```
pattern{type: latency, spans: [span_id poprzedzający i następujący],
        params: {threshold_ms, topic}, computed_stats: {n_occurrences, mean_ms}}
# semantyka: przed podjęciem/po podjęciu tematu X pauza > T, w N przypadkach
```

Struktura dwuwarstwowa idealnie zgodna z architekturą: pauza jest obserwacją (deterministyczną, z sygnaturą), „opór" jest interpretacją **cytującą** wzorzec. Zero nowej infrastruktury; jeden wpis w `method_registry`. Zastrzeżenie kalibracyjne: pauzy mają przyczyny trywialne (namysł, przerwa fizyczna) — próg i minimalna liczność konserwatywne, wzorzec nigdy nie renderowany samodzielnie jako teza, wyłącznie jako dowód interpretacji.

### 2.3. Poziomy organizacji osobowości — jawna decyzja wyłączenia z v1 (D2)

Poziomy organizacji (neurotyczny/borderline/psychotyczny wg McWilliams) są technicznie enumowalne, ale to **najbliższy formalnej diagnozie konstrukt w całym portfolio czterech modalności**. Wpisanie go do ontologii przesuwa produkt semantycznie w stronę P1 (hipotezy diagnostyczne), nawet jeśli MDR-owo cała konceptualizacja i tak jest P2 — pogarsza pozycję w rejestrze claimów, w rozmowie z doradcą i w odbiorze środowiska. Rekomendacja: poza v1, decyzją jawną wpisaną do ADR-0YY przy aktualizacji (nie domyślnym pominięciem); ewentualny powrót wyłącznie łącznie z decyzją o module czerwonym (D1 dokumentu 11).

### 2.4. Szkic ontologii (fragment ilustracyjny; treść do autoryzacji eksperckiej)

```yaml
# ontology/psychodynamic/0.1.0.yaml
modality: psychodynamic
version: 0.1.0
approved_by: []                 # blokada prod do autoryzacji (CI)
constructs:
  defense_mechanism:
    label_pl: "Mechanizm obronny"
    values: ["wyparcie", "zaprzeczenie", "projekcja", "introjekcja", "racjonalizacja",
             "intelektualizacja", "przemieszczenie", "formacja reaktywna", "regresja",
             "sublimacja", "acting out", "dysocjacja", "idealizacja", "dewaluacja",
             "identyfikacja projekcyjna", ...]      # kanon McWilliams — DECYZJA D1
    forced_status: interpretation                    # obrona nigdy nie jest obserwacją
    min_evidence: {spans: 3, sessions: 2}            # wzorzec, nie pojedynczy przykład
    common_confusions:
      - {input: "klient zaprzecza faktowi", correct: "zaprzeczenie jako obrona wymaga wzorca, nie pojedynczej niezgody", note: "częsty błąd"}
  transference:
    label_pl: "Przeniesienie"
    values: ["idealizujące", "negatywne", "erotyczne", "lustrzane", "bliźniacze", ...]  # D1
    forced_status: interpretation
    min_evidence: {spans: 2, interaction_frame: about_therapy_relation}   # nowe kryterium
  conflict_triangle:
    label_pl: "Trójkąt konfliktu"
    kind: composite
    slots:
      impulse: {type: construct_ref | span_ref, required: true}
      anxiety: {type: construct_ref | span_ref, required: true}
      defense: {type: construct_ref(defense_mechanism), required: true}
    min_complete_slots: 3
    forced_status: theoretical_hypothesis
  insight_triangle:
    label_pl: "Trójkąt wglądu"
    kind: composite
    slots:
      past_figure:   {type: claim_ref, required: true}
      current_figure: {type: claim_ref, required: true}
      transference:  {type: construct_ref(transference), required: false}
    min_complete_slots: 2
    forced_status: theoretical_hypothesis
    # domknięcie trójkąta = relacja paralela między slotami
  dream_material:
    label_pl: "Materiał senny"
    values: null
    min_evidence: {spans: 1}   # relacja snu = span; interpretacja rozwarstwiona przez R4
therapist_boundary: strict      # R10 — deklaracja polityki w ontologii (spójność CI)
```

---

## 3. Gestalt

### 3.1. Inwentarz — zaskoczenie ontologiczne

Gestalt enumeruje się lepiej, niż sugeruje jego reputacja modalności „procesowej":

| Konstrukt | Katalog | Enum? | Uwaga |
|---|---|---|---|
| Przerwania kontaktu | **Zamknięty** ~5–7 (konfluencja, introjekcja, projekcja, retrofleksja, defleksja, egotyzm) | **Tak** | Część ma **markery językowe wykrywalne deterministycznie**: introjekcje = imperatywy „muszę/powinienem" — **ten sam detektor leksykalny co zniekształcenie „imperatywy" w CBT (współdzielony komponent)**; defleksja = zmiana tematu = wzorzec `sequence` z S1.5 |
| Cykl kontaktu (doznanie→świadomość→mobilizacja→działanie→kontakt→wycofanie) | Zamknięty (fazy) | Tak | Fazy jako enum; przerwanie cyklu = relacja `sekwencja` z brakującą fazą |
| Strefy świadomości (wewnętrzna / zewnętrzna / pośrednia) | Zamknięty (3) | Tak | Czysta etykieta klasyfikacyjna nad spanem |
| Polaryzacje (topdog/underdog) | Struktura dwubiegunowa | Kompozyt + istniejąca relacja **`napiecie`** | Architektura miała to od v1.2 — zero nowego kodu |
| Figura/tło | Procesowe, moment-po-momencie | Nie | Częściowo: przesunięcia salience tematów = `trend`/`distribution`; dynamika chwilowa poza zasięgiem |
| Niedokończone sprawy | Otwarty | Nie | `recurrence` tematu + brak fazy domknięcia cyklu |
| Eksperymenty (puste krzesło, dialog części) | Zdarzenia sesyjne | — | **Widoczne w transkrypcie**: jeden mówca, zmiana ramy adresata — `interaction_frame.addressee: part` (2.2-b) oznacza segmenty eksperymentu |
| **Proces cielesny** (postawa, gest, oddech, ton) | — | — | **Sufit pokrycia — 3.2** |

Zbieżność filozoficzna warta nazwania: fenomenologiczny etos Gestalt („obserwacja przed interpretacją, opis przed oceną") jest **tożsamy z dyscypliną epistemiczną architektury**. Modalność uchodząca za najmniej strukturalną jest najbliższa duchowi statusów epistemicznych — raport Gestalt będzie naturalnie observation-heavy, z pytaniami o świadomość zamiast tez; format przestrzeni hipotez z `next_session_questions` pasuje do dialogicznego stylu pracy lepiej niż w jakiejkolwiek innej modalności.

### 3.2. Ograniczenie wiążące: sufit pokrycia danych, nie ontologia

Znacząca część materiału Gestalt jest **niewerbalna**, a dane źródłowe to transkrypt audio. Konsekwencje, nazwane uczciwie:

1. **Materiał cielesny wchodzi tylko zwerbalizowany.** „Widzę, że zaciskasz pięści" terapeuty jest spanem — i to dobrym (`kind: behavioral`). Wymaga rozróżnienia w metadanych: `observed_by: therapist | self` — obserwacja terapeuty o kliencie vs samoopis klienta; różny status dowodowy, obie wartości legalne (obserwacja terapeuty w transkrypcie NIE narusza R10 — jest wypowiedzią terapeuty o **kliencie**, cytowaną verbatim, nie inferencją systemu o terapeucie).
2. **Prozodia z audio — poza v1, świadomie.** Ton, tempo, drżenie głosu są technicznie w zasięgu (surowe audio istnieje), ale to osobny projekt badawczy z własnymi problemami walidacyjnymi i regulacyjnymi — analiza afektu z głosu ociera się o systemy rozpoznawania emocji w rozumieniu AI Act. Nie obiecywać; wpis do rejestru pomysłów z warunkami wejścia.
3. **Protokół osiągalności w benchmarku (przekrojowy).** Recall ustaleń eksperckich dla Gestalt będzie strukturalnie niższy nie z winy systemu, lecz kanału danych — benchmark musi to odróżniać, inaczej Gestalt „obleje" niesłusznie. Rozszerzenie protokołu anotacji (dokument 13 §7.1): ekspert oznacza per ustalenie pole **`osiągalność: transcript | in_person_only`** — czy ustalenie jest wyprowadzalne z transkryptu, czy wymagało obecności w pokoju. Metryka recall liczona **względem osiągalnych**; odsetek `in_person_only` publikowany osobno jako **sufit pokrycia modalności** — liczba komunikowana także użytkownikom w onboardingu (zarządzanie oczekiwaniami). Pole wdrażane dla **wszystkich** modalności (w PPT i CBT będzie bliskie zeru — to też jest informacja).
4. **Mitygacja produktowa: szybkie adnotacje terapeuty.** Przycisk/notatka głosowa w trakcie lub tuż po sesji („klient wstrzymał oddech przy temacie matki") jako `entry_ref` autorstwa terapeuty — spójne z R10 i istniejącym wejściem notatek; funkcja, o którą terapeuci Gestalt prawdopodobnie sami poproszą. Fundament techniczny: T27 (`entry_ref`).

### 3.3. M5 — profil raportu per modalność (opcjonalne rozszerzenie metaschematu)

Uwaga kulturowa przed wejściem w segment: część środowiska Gestalt jest **filozoficznie niechętna konceptualizacji przypadku jako takiej** — produkt „raport konceptualizacyjny" może być odbierany jako obcy gatunkowo; produkt „lustro procesu" (cytaty, wzorce, przerwania cyklu, pytania o świadomość) — nie. Rozszerzenie M5:

```yaml
report_profile:                 # opcjonalne; brak = profil domyślny
  sections:
    patterns_and_relations: {weight: high}
    open_questions: {weight: high}
    interpretive_constructs: {weight: low}    # Gestalt: konstrukty interpretacyjne w dół
  default_tone: phenomenological              # wpływa na szablony S4, nie na treść twierdzeń
```

Silnik ten sam, kompozycja inna. M5 nie zmienia walidacji ani statusów — wyłącznie wagi sekcji i szablony językowe S4 (podlegające S5 bez zmian).

### 3.4. Szkic ontologii (fragment ilustracyjny)

```yaml
# ontology/gestalt/0.1.0.yaml
modality: gestalt
version: 0.1.0
approved_by: []
constructs:
  contact_interruption:
    label_pl: "Przerwanie kontaktu"
    values: ["konfluencja", "introjekcja", "projekcja", "retrofleksja", "defleksja", "egotyzm"]  # kanon D3
    forced_status: interpretation
    min_evidence: {spans: 2}
    detectors:                              # markery deterministyczne wspierające (nie zastępujące) S2
      introjekcja: {lexical: imperatives}   # współdzielony z CBT (imperatywy)
      defleksja:   {pattern: sequence}      # zmiana tematu z S1.5
  contact_cycle_phase:
    label_pl: "Faza cyklu kontaktu"
    values: ["doznanie", "świadomość", "mobilizacja", "działanie", "kontakt", "wycofanie"]
    min_evidence: {spans: 1}
  awareness_zone:
    label_pl: "Strefa świadomości"
    values: ["wewnętrzna", "zewnętrzna", "pośrednia"]
    min_evidence: {spans: 1}
  polarity:
    label_pl: "Polaryzacja"
    kind: composite
    slots:
      pole_a: {type: claim_ref | span_ref, required: true}
      pole_b: {type: claim_ref | span_ref, required: true}
    min_complete_slots: 2
    # napięcie między biegunami = istniejąca relacja `napiecie`
  unfinished_business:
    label_pl: "Niedokończona sprawa"
    values: null
    min_evidence: {spans: 3, sessions: 2}   # rekurencja bez domknięcia
    forced_status: interpretation
report_profile: {sections: {patterns_and_relations: high, open_questions: high,
                 interpretive_constructs: low}, default_tone: phenomenological}
therapist_boundary: strict
```

---

## 4. Synteza czterech modalności

| | PPT | CBT | Psychodynamiczna | Gestalt |
|---|---|---|---|---|
| Twardość ontologii | Średnia | Wysoka | **Hybrydowa** (obrony: enum; reszta miękka) | Średnio-wysoka (zaskoczenie) |
| Rozkład statusów | Mieszany | Observation-heavy (myśli = spany) | **Hypothesis-heavy** (prawie nic nie jest wprost) | Observation-heavy (fenomenologia) |
| Ograniczenie wiążące | Praca ekspercka / terminologia PL | Struktura (kompozyty, liczby) → rozwiązane M1–M4 | Dowód relacyjny + granica terapeuty | **Pokrycie danych z audio** |
| Nowe wymagania silnika | — (baza) | M1–M4, S2c, R9 | `paralela`, **R10**, `latency`, `interaction_frame` | `observed_by`, protokół osiągalności, M5 (opcjonalnie) |
| Reużycie z wcześniejszych | — | `kind: behavioral`, R5 | M1 (trójkąty), R4 rozwarstwione, `entry_ref` | `napiecie`, `sequence`, detektor imperatywów (CBT), `interaction_frame`, `entry_ref` |
| Koszt ekspercki (relatywnie) | Wysoki (terminologia) | Niski (kanon gotowy, rynek głęboki) | Wysoki (kanon sporny, hypothesis-heavy anotacja) | Średni (kanon krótki, ale osiągalność podnosi koszt anotacji) |

**Wniosek o generyczności:** teza „nowy plik ontologii, nie nowy kod" jest prawdziwa dla treści; silnik wymagał rozszerzeń przy każdej z pierwszych czterech modalności, ale lista **konwerguje** — rozszerzenia z modalności N są reużywane przez N+1. Zdrowy sygnał: piąta modalność (systemowa, terapia schematów) prawdopodobnie mieści się w metaschemacie v1.4 bez zmian silnika.

**Rekomendacja kolejności (D5):** PPT (pilot, w toku) → CBT (nr 2 — dokument 14) → **psychodynamiczna (nr 3)** mimo wyższego kosztu: obok CBT największa modalność w Polsce, argument rynkowy bije argument kosztowy → **terapia schematów (nr 4)**: najtańsza ontologicznie (18 schematów + tryby = czyste enumy), „odpoczynek" po psychodynamicznej → **Gestalt (nr 5)**: po zbudowaniu adnotacji terapeuty (T27) i z jawnie zakomunikowanym sufitem pokrycia.

---

## 5. Wpływ regulacyjny (uczciwie)

- Kwalifikacja MDR bez zmian: konstrukty obu modalności to wnioskowanie o konkretnym kliencie (P2). `Paralela` i trójkąty nie zmieniają kwalifikacji — zmieniają przejrzystość.
- **R10 wzmacnia pozycję**: jawna, egzekwowana w kodzie granica „system nie ocenia profesjonalisty" jest argumentem w intended use, w rozmowie z doradcą i w AUP-owym wymogu nadzoru profesjonalisty (system wspiera terapeutę, nie analizuje go).
- Wyłączenie poziomów organizacji osobowości (D2) utrzymuje dystans od P1 (hipotezy diagnostyczne) w warstwie semantycznej claimów.
- Prozodia/afekt z głosu: przed jakimkolwiek podjęciem — analiza pod kątem przepisów o systemach rozpoznawania emocji (AI Act) i aktualizacja DPIA; do rejestru pomysłów z warunkami, nie do roadmapy.

---

## 6. Plan wdrożenia — tickety (delta)

| # | Ticket | Definition of Done |
|---|---|---|
| T28 | **R10 — granica terapeuty (przekrojowe, natychmiast)** | Walidacja podmiotowo-predykatowa nad twierdzeniami i `hypothesis_text`; `entry_ref` jako jedyna ścieżka treści o doświadczeniu terapeuty, render z atrybucją; metryka odrzuceń; zestaw adversarialny (0 przepuszczeń, twarde); test negatywny CI; deklaracja `therapist_boundary` w metaschemacie |
| T29 | `interaction_frame` + `observed_by` w spanach S1 | Pola w schemacie spanu i modelu danych; nadawanie w S1 (rozszerzenie promptu ekstrakcji); `addressee: part` dla eksperymentów; kryterium `interaction_frame` w `min_evidence`; testy |
| T30 | Wzorzec `latency` w S1.5 | Typ w `method_registry` na znacznikach ciszy chunkera 600 ms; progi konserwatywne (parametry); nigdy nie renderowany samodzielnie jako teza; testy determinizmu |
| T31 | Typ relacji `paralela` w S2b/S3b | Schemat z `instances`; obostrzenia R8d (twardy `theoretical_hypothesis`) i R8b/R10 na `shared_pattern_description`; flaga wyłączenia per modalność; benchmark: precyzja ≥ 0,85 |
| T32 | Protokół osiągalności w benchmarku (przekrojowe) | Pole `osiągalność` w anotacji wszystkich modalności; recall liczony względem osiągalnych; „sufit pokrycia" raportowany per modalność; tekst onboardingowy per modalność (`.arb`) |
| T33 | M5 — `report_profile` w metaschemacie i S4 | Wagi sekcji + szablony tonu; S5 bez zmian; profil domyślny przy braku pola; testy renderowania |
| T34 | Ontologia `psychodynamic/0.1.0` + L1 + korpus | Po D1–D2; sesja ekspercka (kanon obron, typów przeniesienia); `approved_by` niepuste; spójność CI |
| T35 | Ontologia `gestalt/0.1.0` + L1 + korpus | Po D3; kanon przerwań i faz; detektory współdzielone z CBT podpięte; `report_profile` ustawiony |
| T36 | Benchmark psychodynamiczny i Gestalt | Złote zestawy wg protokołu z osiągalnością; dla psychodynamicznej: zestaw adversarialny R10; dla Gestalt: raport sufitu pokrycia |

Fazowanie: T28 i T32 — przekrojowe, wchodzą z najbliższą falą silnika (obok T19–T22); T29–T31, T33 — zmiany silnika, mogą wejść przed treścią; T34–T36 — po benchmarku CBT, zgodnie z kolejnością D5.

---

## 7. Czego ta analiza NIE rozstrzyga (nazwane wprost)

- Kanonów treściowych (lista obron, typy przeniesienia, katalog przerwań) — decyzje eksperckie D1/D3.
- Jakości `paralela` w praktyce — typ jest eksperymentem z flagą wyłączenia; benchmark rozstrzygnie.
- Prozodii — poza zakresem z warunkami wejścia (5).
- Ekonomiki anotacji hypothesis-heavy (psychodynamiczna) — zgodność międzyekspercka może być niska; protokół z dokumentu 13 §7.1 (rozbieżność jako dana) będzie tam testowany najmocniej; realny koszt do wyceny w D4.

---

## 8. Decyzje blokujące

| # | Decyzja | Opcje | Rekomendacja | Status |
|---|---|---|---|---|
| D1 | Kanon psychodynamiczny v1 (obrony, typy przeniesienia) | Vaillant vs McWilliams vs hybryda | **McWilliams** (standard PL, naturalne `source` L1); warianty w `aliases` | ☐ otwarta |
| D2 | Poziomy organizacji osobowości | W ontologii v1 vs poza | **Poza v1, decyzją jawną w ADR-0YY** — najbliższy diagnozie konstrukt portfolio; powrót tylko łącznie z decyzją o module czerwonym | ☐ otwarta |
| D3 | Kanon Gestalt v1 (przerwania, fazy cyklu) | Wersje kanonu różnią się liczbą przerwań (5–7) | Decyzja ekspercka przy `gestalt/0.1.0` | ☐ otwarta |
| D4 | Budżet anotacji psychodynamicznej | Hypothesis-heavy = droższa anotacja, potencjalnie niska zgodność | Wycena z ekspertami przed T34; próg zgodności międzyeksperckiej jako kryterium go/no-go dla konstruktów | ☐ otwarta |
| D5 | Kolejność modalności 3–5 | Psychodynamiczna → schematy → Gestalt (rekomendacja) vs warianty | **Jak w sekcji 4** — argument rynkowy dla psychodynamicznej; Gestalt po T27 i T32 | ☐ otwarta |

---

*Dokument wewnętrzny. Nie stanowi opinii prawnej. Treści kliniczne (katalogi, progi) są placeholderami do autoryzacji eksperckiej.*
