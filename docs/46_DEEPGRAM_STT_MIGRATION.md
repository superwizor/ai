---
type: System Documentation
title: "46 — Migracja STT: Chirp 3  Deepgram Nova-3"
description: "1. Brak natywnej diaryzacji dla polskiego (ADR-IMPL-007) — diaryzację robi"
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/docs/46_DEEPGRAM_STT_MIGRATION.md
tags: [ai, analytics, billing, database, frontend, identity, infrastructure, ingestion, security, testing]
timestamp: 2026-07-17T13:34:21.794441
---

# 46 — Migracja STT: Chirp 3 → Deepgram Nova-3

**Status:** design (2026-07-16). Brak kodu. Branch implementacyjny:
`feat/stt-deepgram`.

**Motywacja.** Dwa problemy z obecnym pipeline'em Chirp 3:

1. **Brak natywnej diaryzacji dla polskiego** (ADR-IMPL-007) — diaryzację robi
   llm-worker call-1 (klastrowanie chunków przez Gemini), co jest udokumentowanym
   źródłem incydentów jakościowych (`diarisation_issues/2026-05-28_cross_group_
   chunk_collision.md`, incydent "Agnieszka" 2026-05-18, sparse labels ADR-IMPL-007a).
2. **Wolne przetwarzanie** — Chirp BatchRecognize potrafi zająć 1–30+ min
   (ogon do godzin przy awariach, patrz outage 2026-05-22), co wymusiło całą
   maszynerię submit/finalize/watchdog z docs/13.

Rozważany wcześniej Speechmatics odpada z powodu słabej jakości diaryzacji.
Wybór: **Deepgram Nova-3** (`model=nova-3`, `language=pl`, `diarize=true`,
`mip_opt_out=true`, endpoint EU).

**Założenia przyjęte w tym designie:**

- Brak chunkingu plików — jedna sesja = jeden plik (limit Deepgrama 2 GB;
  nasz 60-min FLAC 16 kHz mono ≈ 50–60 MB).
- Diaryzację robi Deepgram (per słowo, bez sparse labels).
- Po naszej stronie zostaje: upload do bucketu + konwersja formatu
  (ingestion-svc bez zmian).
- Flaga wyboru pipeline'u (Chirp vs Deepgram) + automatyczny fallback,
  żeby awaria zewnętrznego API nie kosztowała nagrań.

---

## 1. Zweryfikowane fakty o Deepgram API

| Wymaganie | Status | Szczegóły |
|---|---|---|
| Nova-3 + polski | ✅ | Nova-3 dodał polski w fali rozszerzeń językowych ("11 new languages across Europe and Asia"); parametry: `model=nova-3&language=pl` |
| Diaryzacja | ✅ | `diarize=true` — każde słowo dostaje `speaker` (int, 0-based) + `speaker_confidence`; diaryzacja niezależna od języka, **każde słowo ma etykietę** (koniec problemu sparse labels z ADR-IMPL-007a) |
| `mip_opt_out=true` | ✅ | Parametr query na dowolnym żądaniu. Efekt: dane nie trafiają do Model Improvement Program, retencja tylko na czas przetwarzania requestu. Koszt: rezygnacja z 50% zniżki MIP (stawki cennikowe zakładają opt-in → cena ~2× cennikowej). Weryfikowalne w Console → Usage → Logs (feature `mip_opt_out: true`). Uwaga: część SDK nie eksponowała parametru (deepgram-python-sdk issue #474) — nas nie dotyczy, wołamy surowy REST z Go |
| Rezydencja EU (P3) | ✅ | `api.eu.deepgram.com` — GA, hosting AWS EU, przetwarzanie w całości w UE, te same klucze API, parytet funkcji poza Whisperem. **Do weryfikacji kontraktowej:** DPA + potwierdzenie `nova-3`+`pl`+`diarize` na endpointcie EU |
| Limity | ✅ | Max 2 GB pliku, max 10 min czasu przetwarzania po stronie serwera (potem 504 — przy szybkości Nova-3 to wiele godzin audio, nie dotyczy sesji 60-min), 100 równoległych żądań/projekt |
| Wejście przez URL | ✅ | `POST /v1/listen` z body `{"url": "<signed GCS GET URL>"}` — nie streamujemy pliku przez funkcję |
| Tryb pracy | ⚠️ kluczowe | Pre-recorded API jest **synchroniczne** (odpowiedź w sekundach). Deepgram **nie przechowuje wyników** — nie ma `GET /jobs/{id}/transcript`. Tryb `callback` istnieje, ale oznacza przyjmowanie transkryptu jako niezaufanego inbound POST bez możliwości pull-weryfikacji; zgubiony callback = utrata wyniku |

Źródła: sekcja "Źródła" na końcu dokumentu.

### 1.1 Cennik (zweryfikowany 2026-07-16)

Stawki z oficjalnego cennika; przypis na stronie: *"Rates listed above opt
in to the Model Improvement Program"*. Opt-out = rezygnacja z 50% zniżki
MIP, w praktyce **2× stawki cennikowej**. **Uwaga: diaryzacja jest osobno
płatnym dodatkiem** (nie jest wliczona w stawkę bazową).

| Składnik ($/min, pre-recorded) | Pay-As-You-Go | Growth |
|---|---|---|
| Nova-3 monolingual (`language=pl`) | $0.0077 | $0.0065 |
| Diaryzacja (dodatek) | $0.0020 | $0.0017 |
| **Razem, MIP opt-in** (dane do treningu — nie dla nas) | $0.0097 | $0.0082 |
| **Razem, `mip_opt_out=true` (2×)** | **$0.0194** | **$0.0164** |

**Za 1 h transkrypcji (nasz wariant, `mip_opt_out=true`): $1.16 (PAYG) /
$0.98 (Growth).** Dla porównania Chirp 3: $0.024/min = **$1.44/h** — bez
diaryzacji dla polskiego (diaryzację dopłacamy tokenami Gemini w call-1).
Nawet najdroższy wariant Deepgrama jest ~20% tańszy, z diaryzacją w cenie.
`language=multi` (code-switching): baza $0.0092/min → ~$1.34/h przy
opt-out na PAYG.

Zastrzeżenia (Faza 0): Deepgram nie publikuje oficjalnej tabeli stawek po
opt-oucie — "2×" wynika z zapisu o utracie 50% zniżki, potwierdzić w
umowie/DPA; nie jest jasne, czy dodatek za diaryzację też podlega
podwojeniu (założono konserwatywnie, że tak); brak informacji, czy
endpoint EU ma tę samą cenę co US.

---

## 2. Architektura docelowa

Seamy pozostają te same co dziś: wejście = topic `audio.uploaded`
(`{session_id, upload_id, object_path}`), wyjście = topic
`transcript.completed` + kanoniczny blob `transcripts.transcript_ciphertext`
(ADR-IMPL-006). Nic downstream od `persistTranscript` się nie zmienia.

```
audio.uploaded ──► stt-worker (ProcessAudio)
                     │ provider = resolveSTTProvider(session)
        ┌────────────┴──────────────┐
        ▼ chirp (istniejący, frozen) ▼ deepgram (NOWY)
   BatchRecognize → GCS →        1. idempotencja: SELECT stt_operations;
   Eventarc → stt-finalize          świeży wpis w toku → NACK, sfinalizowany → ack
   (bez zmian)                   2. INSERT stt_operations(provider='deepgram',
                                    finalized_at=NULL) — PRZED wywołaniem
                                 3. mint V4 signed GET URL (TTL 15 min)
                                 4. POST https://api.eu.deepgram.com/v1/listen
                                      ?model=nova-3&language=pl&diarize=true
                                      &punctuate=true&smart_format=true
                                      &mip_opt_out=true
                                    body: {"url": signedURL}
                                    — SYNCHRONICZNIE, odpowiedź w sekundach
                                 5. parse → []chunker.Word (speaker 0→tag 1, …)
                                 6. wspólny finalize (internal/sttfinalize):
                                    ChunkByPauses → persistTranscript →
                                    status ANALYZING → transcript.completed →
                                    delete audio źródłowego → finalized_at=now()
                                 7. ack (~10–60 s łącznie)
```

### Kluczowe decyzje projektowe

**D1 — tryb synchroniczny, nie callback.** Deepgram nie przechowuje wyników,
więc callback oznaczałby: (a) transkrypt PHI przyjmowany jako niezaufany
inbound HTTP POST, (b) brak pull-weryfikacji, (c) zgubiony callback = ponowny
pełny submit i billing. Sync eliminuje te problemy **i cały publiczny
endpoint** (lepsza postawa P2 Zero Trust — zero nowych funkcji, bucketów,
topiców). Obawa, która zabiła sync przy Chirpie (docs/13: funkcja wisząca
30+ min), tu nie występuje — worst case to serwerowy cap 10 min; timeout
funkcji 540 s pokrywa go z zapasem przy timeoutcie klienta HTTP ~330 s
i jednym wewnętrznym retry.

**D2 — statusy: `TRANSCRIBING → ANALYZING` bezpośrednio.** `MERGING` był
artefaktem multi-chunk merge; ścieżka Deepgram go pomija (enum pozwala,
monotonic rank guard w Firestore nieczuły — `transcribing`=2, `analyzing`=3).

**D3 — idempotencja.** Wpis `stt_operations` **przed** wywołaniem Deepgrama:
redelivery widzi świeży wpis w toku (< 15 min, `finalized_at IS NULL`) →
NACK z opóźnieniem; wpis starszy → przejęcie i ponowny submit. Istniejący
UNIQUE na `transcripts(session_id)` (migracja 000021) jako druga linia
obrony przy wyścigu na persist — identycznie jak dziś w stt-finalize.

**D4 — chunking i `audio_chunks` ignorowane na ścieżce Deepgram.** Submit
zawsze bierze oryginalny obiekt z `audio.uploaded.object_path` (1 plik).
Chunking w ingestion-svc (>1140 s) zostaje bez zmian, bo fallback Chirp go
potrzebuje. Wycofanie chunkingu dopiero w Fazie 4.

**D5 — downstream zero zmian.** Słowa mają etykiety mówców →
`hasNativeSpeakers=true` → llm-worker idzie **istniejącą** gałęzią role-only
(Format B, gramatyka `Speaker N — role`). Gramatyka klastrująca i doom-loop
z `diarisation_issues/` przechodzą do lamusa. Zostawiamy nasz
`ChunkByPauses` (progi 600/300/60000 ms zestrojone pod polską mowę
terapeutyczną, downstream na nich polega) — `utterances` Deepgrama nie
włączamy do przepływu, najwyżej do shadow-eval.

**D6 — mapowanie parsera.** `results.channels[0].alternatives[0].words[]`:
`start`/`end` w sekundach float → ms; `punctuated_word` gdy dostępne
(smart_format/punctuate włączone), inaczej `word`; `speaker` 0-based →
`SpeakerLabel` "1"/"2"…; brak pola `speaker` → tag 0. Semantyka zgodna
z dzisiejszym `ParseChirp3Results`, więc `persistTranscript` bez zmian.

---

## 3. Plan prac

### Faza 0 — formalności (najdłuższa ścieżka, zacząć od razu)

1. Konto Deepgram (Growth/Enterprise), **DPA pod dane szczególnej kategorii**
   (audio terapii = dane zdrowotne, GDPR art. 9 + art. 28). Pisemne
   potwierdzenia: rezydencja EU dla `api.eu.deepgram.com`, semantyka retencji
   przy `mip_opt_out=true` (brak trwałej kopii), dostępność
   `nova-3`+`pl`+`diarize` na endpointcie EU, ewentualna allow-lista IP
   (mało prawdopodobna; gdyby była — Cloud NAT + `ALL_TRAFFIC` na tej funkcji),
   cennik przy naszym wolumenie (2× stawki cennikowej vs Chirp $0.024/min).
2. Secret Manager: sekret `deepgram-api-key`,
   `roles/secretmanager.secretAccessor` **tylko** dla SA stt-workera,
   wstrzyknięcie `--set-secrets="DEEPGRAM_API_KEY=deepgram-api-key:latest"`
   (wzorzec jak `postgres-database-url`). Endpoint w env `DEEPGRAM_API_URL`
   przypięty w terraformie do `https://api.eu.deepgram.com` — kod nie może
   mieć fallbacku na endpoint US.
3. Aktualizacja zgód pacjenta / polityki prywatności o nowego podprocesora —
   luka zgoda-vs-implementacja (docs/37) musi być zamknięta **przed**
   pierwszym produkcyjnym audio.

### Faza 1 — kod (branch `feat/stt-deepgram`)

4. **Migracja** `0000XX_stt_operations_provider.up.sql`:

   ```sql
   ALTER TABLE stt_operations
       ADD COLUMN provider      TEXT NOT NULL DEFAULT 'chirp',
       ADD COLUMN request_id    TEXT,
       ADD COLUMN fallback_from UUID REFERENCES stt_operations(id);
   ```

   UNIQUE `(session_id, chunk_index)` zostaje — dedup redelivery bez zmian;
   fallback **nadpisuje** wiersz (provider + request_id) zamiast wstawiać
   drugi chunk-0, żeby zachować inwariant.

5. **Nowy pakiet** `services/ai-pipeline-svc/internal/deepgram/`:
   - `client.go` — `Transcribe(ctx, signedURL, params)`:
     `http.Client{Timeout: 330 * time.Second}`, nagłówek
     `Authorization: Token <key>`, jeden retry z backoffem na 429/5xx,
     typowany błąd z kodem HTTP. Parametry zapytania budowane centralnie —
     **`mip_opt_out=true` na sztywno, nie konfigurowalnie** (flaga env nie
     może go przypadkiem wyłączyć na danych PHI); test jednostkowy failuje,
     jeśli parametr zniknie z query stringa.
   - `parse.go` — mapowanie D6 → `[]chunker.Word` + `TranscriptResult`
     (word count, speaker count, avg confidence, language). Czysta funkcja,
     testy na fixture'ach z prawdziwych polskich odpowiedzi (nagrać 2–3 na
     stagingu jako testdata).
   - `classify.go` — mapowanie na semantykę docs/21:

     | Odpowiedź Deepgrama | Klasyfikacja | Zachowanie |
     |---|---|---|
     | 400 / 415 / 422 (zła konfiguracja, nieobsługiwany format) | **terminal** | session FAILED, `finalize_error`, ack |
     | 401 / 403 (klucz) | **specjalna** | NACK + alert (rotacja klucza, nie wina sesji — **nigdy** FAILED) |
     | 429 / 5xx / 504 / timeout / błąd sieci | **transient** | NACK → retry ≤24 h (audio żyje 48 h; inwariant docs/21: nigdy FAILED na gałęzi transient) |

6. **`cmd/stt-worker/main.go`**: `resolveSTTProvider(session)` (sekcja 4)
   + gałąź deepgram (kroki 1–7 z diagramu). Signed URL: SA ma już
   `storage.objectViewer`; dodać `iam.serviceAccounts.signBlob` na sobie
   (IAM Credentials API) do podpisu V4. TTL 15 min, URL nigdy nie trafia
   do logów.
7. **Refaktor wspólnego finalize** do `internal/sttfinalize`
   (chunker → persistTranscript → status → publish → kasowanie audio
   źródłowego) — używany przez obie ścieżki; kasowanie audio przenosi się
   tam z dotychczasowego miejsca.
8. **`cmd/stt-watchdog`**: dla wierszy `provider='deepgram'` bez
   `finalized_at` starszych niż 15 min — jeśli audio wciąż w buckecie:
   resubmit (max 2 próby), potem **jednorazowy automatyczny fallback na
   Chirp** (`fallback_from`, metryka `stt_provider_fallback`); backstop
   ~26 h `reapStuckSessions` bez zmian. Odpada polling Operations API —
   przy sync nie ma czego pollować.
9. **Terraform**: sekret + IAM, env na stt-worker/watchdog
   (`DEEPGRAM_API_URL`, `STT_PROVIDER`, `STT_PROVIDER_ALLOWLIST`,
   `STT_SHADOW`), `timeout_seconds = 540` na stt-workerze (świadomy wybór
   pod sync, nie band-aid). Egress: `PRIVATE_RANGES_ONLY` przepuszcza
   publiczny HTTPS bez zmian. **Żadnej nowej funkcji, bucketu ani topicu.**

### Faza 2 — walidacja (staging)

10. Testy jednostkowe + e2e: krótka sesja PL i 60-min sesja do `COMPLETED`;
    weryfikacja: dwóch mówców w `speaker_label_mapping`, llm-worker na
    gałęzi role-only, jakość diaryzacji vs znane problematyczne nagrania
    (sesja `26ecf316`, cross-group collision — jeśli odtwarzalne), latency
    end-to-end.
11. Chaos-testy pod semantykę docs/21: 500 z Deepgrama (NACK, sesja zostaje
    `TRANSCRIBING`, brak FAILED); timeout w połowie odpowiedzi (redelivery →
    przejęcie wpisu → drugi submit → UNIQUE na transcripts chroni persist);
    unieważniony klucz (alert, sesje czekają, fallback ratuje); redelivery
    podczas przetwarzania (NACK na świeżym wpisie).
12. Weryfikacja w Deepgram Console, że każdy request loguje się z
    `mip_opt_out: true` — audytowalny dowód zgodności; wpisać do runbooka
    jako okresowa kontrola.

### Faza 3 — produkcja

13. Rollout flagami (sekcja 4); **shadow mode na ~50 sesjach** przed
    przełączeniem defaultu (podwójny koszt STT pomijalny; porównanie:
    liczba mówców, pokrycie etykiet, WER wyrywkowo, latency) — dowód
    jakości diaryzacji zamiast intuicji.

### Faza 4 — sprzątanie (po tygodniach stabilności)

14. Default → `deepgram`. Potem wycofanie (osobne PR-y, w tej kolejności):
    chunking w ingestion-svc (>1140 s) + bucket `audio-chunks-staging`,
    `stt-finalize` + Eventarc + bucket `transcripts-raw`, `stt_operations`
    kolumny chirp-owe, `fillSpeakerLabels` (ADR-IMPL-007a),
    gramatyka klastrująca w llm-worker + mapa `chirp3DiarizationLanguages`.
    **Najpierw ADR unieważniający IMPL-001/007/007a.**

---

## 4. Flaga wyboru pipeline'u i eliminacja ryzyka zewnętrznego API

- **`STT_PROVIDER=chirp|deepgram`** (env na stt-worker; default `chirp` do
  końca Fazy 3) — globalny kill-switch; rollback = flip env, zero zmian
  w DB (wzorzec jak `STT_NATIVE_DIARIZATION` / `LLM_DIARIZATION_MODE`).
- **`STT_PROVIDER_ALLOWLIST`** (CSV UUID terapeutów/organizacji) — kanarek
  przy defaultcie `chirp`.
- **`STT_SHADOW=deepgram`** — Chirp jako źródło prawdy + równoległy submit
  do Deepgrama wyłącznie do logów porównawczych (bez persistu).
- **Automatyczny failover** (Faza 1, pkt 8): awaria Deepgrama degraduje
  sesję do dzisiejszej ścieżki Chirp zamiast do straty nagrania. To jest
  właściwe "wyeliminowanie ryzyka zewnętrznego API" — sama flaga wymaga
  człowieka przy konsoli.

Kolejność rollbacku przy incydencie: flip `STT_PROVIDER=chirp` (natychmiast,
nowe sesje) → watchdog dociąga wiszące sesje deepgram fallbackiem (audio
żyje 48 h) → post-mortem.

---

## 5. Bezpieczeństwo

- **Mniejsza powierzchnia ataku niż dziś**: brak publicznego webhooka;
  jedyny nowy wektor to wychodzące HTTPS do `api.eu.deepgram.com` + signed
  URL o TTL 15 min.
- **`mip_opt_out=true` jako inwariant kodu**, nie konfiguracja (pkt 5 planu).
  Brak trwałej kopii po stronie Deepgrama → nie ma odpowiednika
  `DELETE /jobs`, bo nie ma czego kasować; potwierdzić zapisem w DPA.
- **Endpoint EU wymuszony**: konfiguracja terraform + walidacja w `init()`
  workera — odmowa startu, jeśli `DEEPGRAM_API_URL` nie kończy się na
  `eu.deepgram.com` (analogia do przypiętego `europe-west4` z ADR-IMPL-003).
  Świadomy, udokumentowany wyjątek od P3 (dane wychodzą poza
  `europe-central2`, ale zostają w UE) — wymaga akceptacji przed Fazą 3.
- **Klucz API**: tylko Secret Manager, runbook rotacji, alert na 401/403
  jako osobny sygnał (nigdy nie faluje sesji).
- **Higiena logów**: bez tekstu transkryptu, bez signed URL, bez klucza —
  tylko session_id / request_id (zgodnie z obecną dyscypliną slog).
- **Szyfrowanie at rest bez zmian**: transkrypt ląduje wyłącznie
  w `transcripts.transcript_ciphertext` przez `pkg/cryptobox`.
- **Kasowanie audio**: bez zmian — explicit delete po udanej transkrypcji
  (we wspólnym finalize) + OLM 48 h jako dead-man-switch.

---

## 6. Observability

| Sygnał | Typ | Alert |
|---|---|---|
| `stt_provider` | label na istniejących metrykach pipeline'u | — |
| `dg_transcribe_seconds` | histogram czasu odpowiedzi `/v1/listen` | p95 > 120 s |
| `stt_provider_fallback_count` | licznik fallbacków na Chirp | > 3/h = "Deepgram leży" |
| odsetek słów bez etykiety mówcy per sesja | kanarek jakości diaryzacji | > 5% rolling 24 h (analogia do monitoringu sparse-labels) |
| licznik 429 | zbliżanie się do limitu 100 równoległych żądań | jakiekolwiek wystąpienie |
| DLQ `audio.uploaded.dlq` | bez zmian | bez zmian |

---

## 7. Otwarte punkty (wszystkie w Fazie 0)

1. Cennik: potwierdzić w umowie stawki po opt-oucie (sekcja 1.1 —
   szacunek $1.16/h PAYG / $0.98/h Growth), w tym czy dodatek za
   diaryzację też podlega podwojeniu i czy endpoint EU kosztuje tyle
   samo co US.
2. Pisemne potwierdzenie `nova-3`+`pl`+`diarize` na endpointcie EU.
3. DPA + lista podprocesorów Deepgrama (AWS EU).
4. Ewentualna allow-lista IP (→ Cloud NAT).
5. `language=pl` vs `language=multi` przy wtrąceniach angielskich
   (przetestować w shadow; `multi` włącza code-switching).
6. Zachowanie `speaker_sensitivity`-odpowiedników — Deepgram nie eksponuje
   tuningu diaryzacji; zweryfikować w shadow, czy default wystarcza dla
   cichych wtrąceń ("mhm") z incydentu cross-group collision.

**Szacunek:** Fazy 1–2 ≈ 1,5 tygodnia inżynierii. Ścieżka krytyczna =
Faza 0 (DPA + zgody).

---

## Źródła

- [Nova-3 expansion — 11 new languages across Europe and Asia](https://deepgram.com/learn/deepgram-expands-nova-3-with-11-new-languages-across-europe-and-asia)
- [Models & languages overview](https://developers.deepgram.com/docs/models-languages-overview)
- [Model Improvement Partnership Program (mip_opt_out)](https://developers.deepgram.com/docs/the-deepgram-model-improvement-partnership-program)
- [Deepgram EU endpoint GA](https://deepgram.com/learn/deepgram-eu-endpoint-now-generally-available)
- [Data privacy compliance](https://developers.deepgram.com/trust-security/data-privacy-compliance)
- [Pre-recorded audio docs](https://developers.deepgram.com/docs/pre-recorded-audio)
- [mip_opt_out SDK issue #474](https://github.com/deepgram/deepgram-python-sdk/issues/474)

Dokumenty powiązane: `docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md` (obecna
architektura Chirp), `docs/22_SESSION_STATUS_PROPAGATION_AND_FAILURE_SEMANTICS.md`
(semantyka terminal/transient), `docs/agents/05_ai-pipeline-svc.md` (stan
workerów), `docs/42_KOREKTY_ZGODNOSC_ZGODA_VS_IMPLEMENTACJA.md` (zgody).
