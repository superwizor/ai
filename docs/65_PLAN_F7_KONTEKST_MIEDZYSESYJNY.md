---
type: Implementation Plan
title: "65 — F7: kontekst międzysesyjny potoku ontologicznego (F7a okno deterministyczne + F7b indeks semantyczny)"
description: "Plan wprowadzenia wnioskowania podłużnego do potoku S1–S5: deterministyczne okno ustaleń per konstrukt (F7a) oraz semantyczny indeks twierdzeń i hipotez z pełną proweniencją (F7b). Status: ZATWIERDZONY KIERUNKOWO 2026-08-25, przed implementacją."
tags: [ontologia, pipeline, rag, pgvector, proweniencja, F7]
timestamp: 2026-08-25T09:30:00+02:00
---

# 65 — F7: kontekst międzysesyjny potoku ontologicznego

**Status:** F7a WDROŻONE I ZWERYFIKOWANE NA PRODUKCJI, F7b-1/F7b-2
wdrożone (2026-08-25). Pozostaje F7b-3 (kanał ciągłości hipotez + V8)
i F7b-4 (benchmark powtarzalności). Sekcje 1–5 opisują ZAMIAR; sekcja 9
— co faktycznie powstało i czym różni się od zamiaru.
**Zależności:** potok S1–S5 w trybie eksperymentalnym (plan 16 / dok. 11),
migracja 000093 (report_spans / report_claims / report_patterns),
FIFO per kartoteka w kolejce mobilnej (2026-08-24).

---

## 1. Problem

Potok eksperymentalny widzi dokładnie **jedną sesję**. Trzy konsekwencje:

1. **Martwy zapis w metaschemacie.** `min_evidence: {sessions: N}` jest dziś
   niespełnialne — np. `unfinished_business` (Gestalt) wymaga 3 spanów z 2
   sesji, więc przy jednosesyjnym przebiegu ZAWSZE ląduje w
   `insufficient_data`. Część ontologii jest nieaktywowalna z definicji.
2. **Brak wnioskowania podłużnego.** Hipoteza z sesji 3 nie ma jak odnaleźć
   się w sesji 19; konceptualizacja nie ewoluuje, tylko powstaje od zera
   przy każdym przebiegu. Terapia jest procesem długohoryzontowym — raport,
   który tego nie widzi, jest ślepy na główny wymiar pracy.
3. **V5 słusznie ubija prawdziwe wzorce.** Model pisze „temat wraca trzeci
   raz" o rekurencji MIĘDZY sesjami, a S1.5 liczy wyłącznie w obrębie
   jednej — wzmianka jest prawdziwa klinicznie i niepoliczalna technicznie,
   więc weryfikator ją kasuje (kanarek 149156fb, 2026-08-24).

Legacy-RAG (`rag_summary_chunk` + `rag_themes`) **nie jest** rozwiązaniem dla
tego potoku: to stratne streszczenia prozy modelu, nieweryfikowalne wstecz.
Wpuszczenie ich do S2/S4 otworzyłoby tylne drzwi, które cała architektura
zamyka — twierdzenie „oparte" na parafrazie parafrazy. Legacy-RAG zostaje
tam, gdzie jest (raport legacy, czat); F7 go nie dotyka.

## 2. Fundament: proweniencja przeżywa retrieval

Od migracji 000093 składujemy pełną zweryfikowaną strukturę każdej sesji:

- `report_spans` — dosłowne cytaty (szyfrowane), z metadanymi dowodowymi
  (`kind`, `observed_by`, `about_past`, wykluczenia ryzyka T22, cisze);
  każdy przeszedł weryfikację mechaniczną S1 w swoim czasie,
- `report_claims` — twierdzenia po walidacji S3, z odnośnikami do spanów,
- `report_patterns` — wzorce policzone przez S1.5.

Twierdzenia i hipotezy są więc **obiektami niosącymi proweniencję**:
wyszukiwanie (deterministyczne czy semantyczne) jest tylko ADRESOWANIEM —
to, co wyciągniemy, przynosi ze sobą swoje kotwice dowodowe. To odróżnia F7
od klasycznego RAG po fragmentach tekstu i jest warunkiem zgodności z
architekturą.

## 3. Niezbywalne niezmienniki (obowiązują F7a i F7b)

**N1 — przeszła hipoteza nigdy nie jest dowodem.** Dowodem może być
wyłącznie span (zweryfikowany cytat — dzisiejszy albo historyczny).
Wyciągnięta hipoteza wchodzi wyłącznie do dedykowanego kanału ciągłości,
z sufitem statusu nie wyższym niż źródłowy (V4 rozciągnięte na czas).
Pewność wolno podnieść tylko NOWYM materiałem z bieżącej sesji; samo
odnalezienie wątku bez nowego dowodu produkuje co najwyżej pytanie otwarte.
Egzekwuje nowa reguła weryfikatora **V8**: proza cytująca przeszłą hipotezę
jako uzasadnienie = naruszenie (V7 zajęty w F7a-4 — patrz §5.4). Bez N1 system automatyzuje konfirmację —
wyciąga własną wczorajszą interpretację, powtarza ją, jutro wyciąga
„pewniejszą" (pętla samowzmacniania).

**N2 — retrieval jest częścią proweniencji przebiegu.** Tabela
`report_run_context` zapisuje, KTÓRE historyczne twierdzenia/hipotezy/spany
przebieg zobaczył (i z jakiego kanału: okno/semantyka). Audyt może odtworzyć
wejście; strojenie widzi, czego zabrakło. Bez N2 nie wdrażamy F7b w ogóle.

**N3 — konfiguracja selekcji jest wersjonowana.** Model embeddingów, wymiar,
k, progi podobieństwa, głębokość okna — wchodzą do `pipeline_version` jak
wersje promptów. Zmiana selekcji = zmiana wersji potoku, widoczna w
benchmarku.

**N4 — kolejność.** Przebieg sesji N czyta wyłącznie sesje < N tej samej
kartoteki. Kolejka mobilna ma już FIFO per kartoteka (2026-08-24); po
stronie workera dochodzi bariera analogiczna: dual-run dla sesji N czeka,
aż starsze sesje kartoteki zakończą przetwarzanie (albo jawnie je pomija
z wpisem w run_context, nigdy po cichu).

**N5 — prywatność bez nowych powierzchni.** Embeddingi treści klinicznej są
treścią kliniczną: pgvector w TEJ SAMEJ instancji Cloud SQL (szyfrowanie,
EEA), żadnego zewnętrznego vector-store. Teksty twierdzeń przechodzą przez
istniejącą pseudonimizację (docs/41) ZANIM powstanie embedding. Spany ryzyka
(T22) nie są indeksowane nigdy.

## 4. F7a — deterministyczne okno ustaleń (fundament)

Cel: ożywić `min_evidence.sessions`, dać S4 ciągłość ustaleń, policzyć
rekurencję międzysesyjną. Zero nowych mechanizmów rozmytych.

### 4.1 Ładowanie kontekstu (S0, czysty kod w workerze)

Dla kartoteki sesji N: ostatnie **W sesji** (decyzja produktowa, propozycja
startowa W=3) → z bazy: zatwierdzone twierdzenia + ich spany-dowody +
wzorce. Deszyfrowanie w workerze (ma KMS). Budżet twardy: max **K twierdzeń**
(propozycja: 60) i **S spanów** (propozycja: 120), najnowsze najpierw;
przycięcie logowane do run_context (N2 — „czego nie pokazaliśmy" też jest
częścią proweniencji).

### 4.2 Adresacja historyczna

Globalny adres spanu: `s{MMDD}:{span_ref}` (np. `s0821:s07`); jednoznaczny
w obrębie kartoteki dzięki UNIQUE(transcript_id, span_ref) + dacie sesji.
Kolizje dat (dwie sesje jednego dnia) rozstrzyga sufiks porządkowy.

### 4.3 Zmiany per etap

- **S1** — bez zmian (bieżąca sesja).
- **S1.5** — rekurencja na sumie topics bieżących i historycznych; wymaga
  dopisania surowych `topics` do składowania (dziś mamy tylko wynikowe
  wzorce) — kolumna `topics TEXT[]` w `report_spans` (migracja), zasilana
  od wdrożenia; historia sprzed migracji ma puste topics i uczciwie nie
  liczy się do rekurencji.
- **S2** — prompt dostaje blok „USTALENIA Z POPRZEDNICH SESJI" (twierdzenia
  WŁASNEGO konstruktu + ich cytaty z datami); enum `evidence` rozszerzony
  o adresy historyczne. R2 liczy odrębne sesje w dowodach →
  `min_evidence.sessions` egzekwowalne.
- **S3** — R2 jak wyżej; R5 (etiologia) honoruje `about_past` spanów
  historycznych tak samo jak bieżących.
- **S4** — wejście `PastClaims` (ustalenia, bez transkrypcji — sygnatura
  dalej jej nie przyjmuje); reguła promptu: ciągłość wolno stwierdzić
  wyłącznie przez odnośnik do konkretnego ustalenia.
- **V1** — dozwolone odnośniki obejmują adresy historyczne pokazane w tym
  przebiegu (dokładnie te z run_context, żadne inne).
- **Renderer** — cytat historyczny z datą: `> (21 sie) „…"`.

### 4.4 Decyzja projektowa: kto dostaje kontekst

**Rekomendacja: wyłącznie konstrukty z zadeklarowanym progiem
`sessions` w ontologii** (ekspert jawnie mówi „ten konstrukt jest
międzysesyjny"). Alternatywa (wszystkie konstrukty) zwiększa szum i koszt
bez deklaracji eksperckiej. Do potwierdzenia przy wdrożeniu.

## 5. F7b — indeks semantyczny twierdzeń i hipotez (rozszerzacz)

Cel: długi horyzont (poza okno W), łączenie w poprzek konstruktów, cykl
życia hipotezy. Semantyka jest ROZSZERZACZEM recall nad F7a, nigdy jedynym
kanałem.

### 5.1 Składowanie

Nowa tabela `report_inference_index`:

```sql
CREATE TABLE report_inference_index (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    -- 'claim' | 'hypothesis' — poziomy NIGDY się nie mieszają (N1).
    kind            VARCHAR(16) NOT NULL,
    source_claim_id UUID REFERENCES report_claims(id) ON DELETE CASCADE,
    construct_id    TEXT NOT NULL,
    epistemic_status TEXT NOT NULL,
    confidence      REAL,
    -- Snapshot tekstu PO pseudonimizacji, szyfrowany jak reszta treści.
    text_ciphertext    BYTEA NOT NULL,
    text_encrypted_dek BYTEA NOT NULL,
    -- Embedding wielojęzyczny (kartoteki PL i EN); model+wymiar w
    -- pipeline_version (N3).
    embedding       vector(768) NOT NULL,
    session_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_inference_ann ON report_inference_index
    USING hnsw (embedding vector_cosine_ops);
CREATE INDEX idx_inference_pf ON report_inference_index(patient_file_id, kind);
```

Zasilanie: na końcu udanego przebiegu (po S5) worker indeksuje zatwierdzone
twierdzenia i opublikowane hipotezy. Spany ryzyka i treść odrzucona — nigdy.
Zapytania ZAWSZE zawężone do `patient_file_id` (izolacja kartotek jest
warunkiem twardym, nie optymalizacją).

### 5.2 Retrieval (w S0, obok okna)

Zapytanie: embedding bieżących twierdzeń S2 pierwszego przejścia? NIE —
zapętlałoby etapy. Kwerendą są **topics + tekst spanów bieżącej sesji**
(dostępne przed S2): top-k (propozycja k=8) sąsiadów typu `claim` do bloku
ustaleń S2 (poza oknem W), top-k typu `hypothesis` do kanału ciągłości S4.
Deterministyczne tie-breaki (data malejąco, id), próg podobieństwa
odcinający szum (kalibracja na benchmarku). Wynik w całości do run_context
(N2).

### 5.3 Kanał ciągłości w raporcie

Nowy rodzaj sekcji układu `kind: continuity` („Wątki między sesjami"):
hipoteza z historią pewności („stawiana 3×: 0.5 → 0.6 → 0.7"), data przy
każdym przywołaniu, jawna adnotacja „bez nowego dowodu w tej sesji" tam,
gdzie N1 zablokował podniesienie. Układ bez tej sekcji → kanał ciągłości
wyłączony (guidance przez ontologię, jak suggestions/interventions).

### 5.4 V8 (nowa reguła weryfikatora)

**Numeracja:** V7 został zajęty w F7a-4 (`V7_ciaglosc_bez_zakotwiczenia`
— zdanie o powrocie wątku bez cytatu z tamtego spotkania). Reguła F7b
dostaje numer V8.

Proza, która: (a) cytuje przeszłą hipotezę jako dowód, (b) podnosi pewność
wątku bez nowego spanu z bieżącej sesji, (c) odwołuje się do wątku
niepokazanego w run_context — naruszenie. Ścieżka reakcji jak V1–V6
(regeneracja → przycięcie → tryb ekstraktywny), z tym że przycięcie tnie
per wątek, jak dziś per wzmianka.

## 6. Kolejność wdrożenia

| Krok | Zakres | Stan |
|---|---|---|
| F7a-1 | migracja topics w report_spans + zapis od wdrożenia | **ZROBIONE** (000097) |
| F7a-2 | S0 loader okna + run_context (N2) + bariera kolejności (N4) | **ZROBIONE** (000098) |
| F7a-3 | S2/R2/R5 + adresy historyczne + V1 | **ZROBIONE** (s2/1.2.0) |
| F7a-4 | S4 PriorFindings + renderer dat + V7 | **ZROBIONE** (s4/1.6.0) |
| F7a-5 | kanarek końca do końca | **ZROBIONE** — raport 5b703f65, dwa datowane cytaty |
| F7b-1 | indeks + zasilanie po przebiegu | **ZROBIONE** (000099) |
| F7b-2 | retrieval w S0 + progi + run_context | **ZROBIONE** (000100) |
| F7b-3 | kanał ciągłości S4 + `kind: continuity` + V8 | otwarte |
| F7b-4 | benchmark powtarzalności retrieval | otwarte — bramka przed produkcją |

Każdy krok osobno deployowalny i kanarkowalny.

## 7. Punkty decyzyjne — ROZSTRZYGNIĘTE

1. **W (głębokość okna)** — **3 sesje**, budżety K=60 twierdzeń /
   S=120 spanów. Przycięcia liczone i zapisywane.
2. **Zasięg kontekstu S2** — historia zawężona do spanów, które
   uziemiały **ten sam konstrukt**. Ostrzejsze niż rekomendacja
   („konstrukty z progiem sessions"): S2 jest wołane osobno na konstrukt
   właśnie po to, by nie mieszać poziomów pojęciowych, a pokazanie
   każdemu konstruktowi całej historii cofnęłoby ten rozdział i
   pomnożyło koszt przez liczbę konstruktów ontologii.
3. **Model embeddingów** — **text-embedding-005** (768, wielojęzyczny),
   ten sam, którego od dawna używa legacy-RAG. pgvector 0.8.1 był już
   zainstalowany. Reużycie znanego modelu zamiast nowej zależności:
   ta sama przestrzeń wektorowa, koszt zmierzony w produkcji
   (~$0.0001/wywołanie).
4. **k i próg** — k=8, próg podobieństwa 0.55, max 6 sesji źródłowych.
   **Wartości startowe**, jawnie oznaczone jako do kalibracji: każdy
   odrzucony sąsiad jest liczony (`semantic_below_threshold`), każdy
   przyjęty zapisuje swoje `similarity`.
5. **Sekcja ciągłości w układach** — odłożone do F7b-3, razem z V8.

### 7a. Decyzja dodana w trakcie: kto dostaje semantykę

Wyszukiwanie semantyczne jest **domyślnie włączone na powierzchni
eksperymentalnej** — organizacja z raportami eksperymentalnymi ma je
w tych raportach bez osobnego wpisu w konfiguracji. Raport
**produkcyjny** wymaga jawnej flagi `SEMANTIC_CONTEXT_ENABLED`.

Uzasadnienie: raport eksperymentalny z definicji nie służy do pracy
klinicznej — powstaje na ontologii bez autoryzacji ekspertów właśnie po
to, żeby było co kalibrować. Organizacja, która go włączyła, zgodziła
się już oglądać wyniki niezautoryzowanego wnioskowania; dołożenie tam
niedeterministycznej selekcji nie zmienia charakteru tej zgody. Materiał
kliniczny zostaje przy decyzji człowieka.

Odwrotne rozwiązanie (osobny wpis dla każdej organizacji) byłoby
sprzeczne z intencją: zapomniany wpis wyglądałby jak „semantyka nic nie
znajduje", czyli jak ubogi wynik, a nie jak brak konfiguracji.

## 8. Ryzyka i mitygacje (podsumowanie)

| Ryzyko | Mitygacja |
|---|---|
| Pętla samowzmacniania interpretacji | N1 + V8 (hipoteza ≠ dowód; pewność tylko za nowy span) |
| Niedeterministyczny selektor psuje audyt i benchmark | N2 (run_context) + N3 (wersjonowana konfiguracja) + deterministyczne tie-breaki |
| Wyciek treści przez wektory | N5: pgvector w tej samej instancji, pseudonimizacja przed embeddingiem, zero indeksowania T22 |
| Przetwarzanie poza kolejnością psuje ciągłość | N4: bariera per kartoteka w workerze + FIFO mobilne (już jest) |
| Koszt kontekstu rozsadza prompt S2/S4 | twarde budżety K/S + przycięcia logowane do run_context |
| Historia sprzed migracji bez topics | uczciwe zero (nie liczy się do rekurencji), bez dorabiania wstecz |

---

## 9. Co faktycznie powstało (2026-08-25)

Sekcje 1–8 opisują zamiar. Ta opisuje implementację — łącznie z tym,
czym różni się od planu i czego plan nie przewidział.

### 9.1 Ścieżka danych, krok po kroku

**Zapis (każdy przebieg ontologiczny):**

1. `Persist` zapisuje spany **razem z hasłami tematycznymi** (000097) —
   bez nich rekurencja międzysesyjna nie miałaby z czego się policzyć.
2. `Persist` zwraca `PersistResult.ClaimIDs` — identyfikatory powstają
   dopiero przy zapisie, a indeks musi mieć na co wskazać.
3. `indexInference` liczy wektory dla zatwierdzonych twierdzeń i
   opublikowanych hipotez, zapisuje je do `report_inference_index`
   (000099) z klasą potoku, modelem embeddingów i adresem wpisu.

**Odczyt (przed S2):**

4. `loadPastContext` — okno W=3 sesji wstecz, klasa potoku zgodna
   z bieżącym przebiegiem, spany ryzyka wykluczone w zapytaniu (T22),
   sesje w toku pominięte i policzone (N4).
5. `dolaczSemantyczne` — jeśli włączone: wektor ze streszczenia
   i tematów call-1 (już spseudonimizowanych), top-k sąsiadów spoza
   okna, próg 0.55, limit sesji źródłowych, deduplikacja wobec okna.
6. Wynik trafia do `PastContext`; każdy element niesie swój kanał
   (`window` / `semantic`) i — dla semantyki — podobieństwo.

**Konsumpcja:**

7. **S2** dostaje blok „USTALENIA Z POPRZEDNICH SESJI" tego konstruktu
   i oddzielony blok fragmentów historycznych (adres `sMMDD:sNN`).
8. **S3** — jedna mapa spanów dla całego przebiegu, więc R2 liczy
   odrębne sesje (`min_evidence.sessions` żyje), R5 honoruje
   `about_past` spanu historycznego, a nowa reguła
   `R2_no_current_span` wymaga co najmniej jednego dowodu z bieżącej
   sesji.
9. **S4** dostaje ustalenia konstruktów w grze i oznaczenie
   „· SPOTKANIE DD.MM" przy cytatach historycznych; enum dozwolonych
   spanów obejmuje adresy historyczne.
10. **S5** — `V7_ciaglosc_bez_zakotwiczenia`: zdanie o powrocie wątku
    bez cytatu z tamtego spotkania jest naruszeniem; przycięcie tnie
    to zdanie, nie cały raport.
11. **Renderer** — cytat historyczny z datą w języku raportu
    („(21.08)" / „(Aug 21)"), identyfikatory spanów usuwane z prozy.
12. **Proweniencja** — `report_run_context` (co przebieg zobaczył,
    z kanałem i podobieństwem) + `report_run_context_stats` (czego nie
    pokazaliśmy: budżety, pominięte sesje, odrzucenia progiem).

### 9.2 Czego plan nie przewidział — pięć wad znalezionych kanarkami

Wszystkie przeszły przez komplet zielonych testów jednostkowych.
Wspólny mianownik: **awaria wyglądająca jak ubogi, ale poprawny wynik**.

1. **Persist nie umiał dowiązać cytatu z wcześniejszej sesji.**
   Pub/Sub ponawiał cały przebieg co 6 minut, zostawiając duplikat
   raportu za każdym razem. Naprawa: adres `sMMDD:sNN` rozwiązuje się
   przez `(session_id, span_ref)` do ORYGINALNEGO wiersza spanu.
2. **Enum S4 nie zawierał adresów historycznych.** Reguła V7 była
   NIE DO SPEŁNIENIA: prosiliśmy model o zdanie o ciągłości i
   zabranialiśmy jedynego sposobu jego uzasadnienia. Osiem naruszeń na
   przebieg → jedno po naprawie.
3. **Identyfikatory spanów wyciekały do prozy** („Klient dystansuje
   się (s04)"): 33 na raport z kontekstem, 0 bez. Model odwzorowywał
   adresy widziane w wejściu. Naprawa: reguła 12 w prompcie + scrubber
   w rendererze (wzorzec wąski, nawiasy z treścią przechodzą).
4. **`source_claim_id` puste we wszystkich wierszach indeksu.**
   Zapytanie F7b-2 tego wymaga, więc wyszukiwanie nie znalazłoby nigdy
   niczego, a liczniki pokazałyby „0 znalezionych, 0 poniżej progu" —
   nieodróżnialne od braku historii.
5. **Klasa potoku brana z `pipeline.Pipeline`** dawała „ontology" także
   dla eksperymentu (stempel eksperymentalny dokłada się osobno), więc
   filtr klasy nie trafiałby w nic.

Wniosek operacyjny: **każdy mechanizm kontekstu ma licznik odróżniający
„nic nie było" od „coś nie zadziałało"**. To nie jest metryka poboczna,
tylko jedyna obrona przed awarią, która wygląda jak poprawność.

### 9.3 Wersje i migracje

| Element | Wersja / numer |
|---|---|
| topics w report_spans | migracja 000097 |
| report_run_context + stats | migracja 000098 |
| report_inference_index | migracja 000099 |
| similarity + liczniki semantyczne | migracja 000100 |
| prompt S2 (blok ustaleń) | s2/1.2.0 |
| prompt S4 (ciągłość, zakaz odnośników) | s4/1.7.0 |
| nowe reguły walidatora | R2_no_current_span, V7_ciaglosc_bez_zakotwiczenia |
| model embeddingów | text-embedding-005 (768) |
| parametry selekcji | W=3, K=60, S=120, k=8, próg 0.55, max 6 sesji |

### 9.4 Co zostało

- **F7b-3**: kanał ciągłości dla hipotez (`kind: continuity` w układzie,
  historia pewności, V8 pilnujące, że przeszła hipoteza nie staje się
  dowodem). Indeks już zbiera hipotezy — czeka na konsumenta.
- **F7b-4**: benchmark powtarzalności retrievalu. **Bramka przed
  włączeniem semantyki dla raportów produkcyjnych**: dopóki dwa
  przebiegi na tym samym materiale nie dadzą tej samej selekcji,
  niedeterministyczna bramka nie ma wstępu do materiału klinicznego.
- **Kalibracja progu** na danych z `similarity` i
  `semantic_below_threshold`.
