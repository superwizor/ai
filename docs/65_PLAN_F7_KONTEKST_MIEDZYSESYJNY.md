---
type: Implementation Plan
title: "65 — F7: kontekst międzysesyjny potoku ontologicznego (F7a okno deterministyczne + F7b indeks semantyczny)"
description: "Plan wprowadzenia wnioskowania podłużnego do potoku S1–S5: deterministyczne okno ustaleń per konstrukt (F7a) oraz semantyczny indeks twierdzeń i hipotez z pełną proweniencją (F7b). Status: ZATWIERDZONY KIERUNKOWO 2026-08-25, przed implementacją."
tags: [ontologia, pipeline, rag, pgvector, proweniencja, F7]
timestamp: 2026-08-25T09:30:00+02:00
---

# 65 — F7: kontekst międzysesyjny potoku ontologicznego

**Status:** zatwierdzony kierunkowo (2026-08-25). Implementacja nie rozpoczęta.
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
Egzekwuje nowa reguła weryfikatora **V7**: proza cytująca przeszłą hipotezę
jako uzasadnienie = naruszenie. Bez N1 system automatyzuje konfirmację —
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

### 5.4 V7 (nowa reguła weryfikatora)

Proza, która: (a) cytuje przeszłą hipotezę jako dowód, (b) podnosi pewność
wątku bez nowego spanu z bieżącej sesji, (c) odwołuje się do wątku
niepokazanego w run_context — naruszenie. Ścieżka reakcji jak V1–V6
(regeneracja → przycięcie → tryb ekstraktywny), z tym że przycięcie tnie
per wątek, jak dziś per wzmianka.

## 6. Kolejność wdrożenia

| Krok | Zakres | Uwagi |
|---|---|---|
| F7a-1 | migracja topics w report_spans + zapis od wdrożenia | mała, bez ryzyka |
| F7a-2 | S0 loader okna + run_context (N2) + bariera kolejności (N4) | rdzeń |
| F7a-3 | S2/R2/R5 + enum adresów historycznych + V1 | ożywia min_evidence.sessions |
| F7a-4 | S4 PastClaims + renderer dat | ciągłość ustaleń |
| F7a-5 | kanarki: Gestalt `unfinished_business` na ≥2 sesjach jednej kartoteki | dowód życia |
| F7b-1 | migracja pgvector + indeksowanie po przebiegu | zasilanie bez konsumpcji |
| F7b-2 | retrieval w S0 + progi + run_context | za flagą organizacji |
| F7b-3 | kanał ciągłości S4 + `kind: continuity` + V7 | pełny cykl życia hipotezy |
| F7b-4 | benchmark: powtarzalność retrieval (dwa przebiegi, ta sama selekcja) | bramka przed szerszym włączeniem |

Każdy krok osobno deployowalny i kanarkowalny; F7b w całości za flagą.

## 7. Punkty decyzyjne (przed startem odpowiednich kroków)

1. **W (głębokość okna F7a)** — propozycja 3; alternatywa: pełna historia
   z twardym budżetem K/S.
2. **Zasięg kontekstu S2** — tylko konstrukty z progiem `sessions`
   (rekomendacja) vs wszystkie.
3. **Model embeddingów** — Vertex multilingual, wymiar 768; potwierdzić
   dostępność w europe-central2 i koszt.
4. **k i próg podobieństwa F7b** — startowo k=8 / próg z kalibracji;
   wchodzi do pipeline_version.
5. **Sekcja ciągłości w układach** — czy PPT/CBT dostają ją w szkicach od
   razu, czy po pierwszych kanarkach F7b.

## 8. Ryzyka i mitygacje (podsumowanie)

| Ryzyko | Mitygacja |
|---|---|
| Pętla samowzmacniania interpretacji | N1 + V7 (hipoteza ≠ dowód; pewność tylko za nowy span) |
| Niedeterministyczny selektor psuje audyt i benchmark | N2 (run_context) + N3 (wersjonowana konfiguracja) + deterministyczne tie-breaki |
| Wyciek treści przez wektory | N5: pgvector w tej samej instancji, pseudonimizacja przed embeddingiem, zero indeksowania T22 |
| Przetwarzanie poza kolejnością psuje ciągłość | N4: bariera per kartoteka w workerze + FIFO mobilne (już jest) |
| Koszt kontekstu rozsadza prompt S2/S4 | twarde budżety K/S + przycięcia logowane do run_context |
| Historia sprzed migracji bez topics | uczciwe zero (nie liczy się do rekurencji), bez dorabiania wstecz |
