<!--
  Status: PLAN — nic z tego nie jest jeszcze zaimplementowane.
  Autor: sesja 2026-07-31.
  Poprzednik: docs/46 (Deepgram, wdrożony 2026-07-17, WYCOFANY 2026-07-31).
  Dowody: scripts/stt-benchmark (gałąź feat/stt-benchmark).
-->

# 59 — Migracja STT: Chirp 3 → ElevenLabs Scribe v2

## 0. Dlaczego drugie podejście i czego nauczyło nas pierwsze

Deepgram Nova-3 wszedł na produkcję 2026-07-17 i został wycofany
2026-07-31 (`STT_PROVIDER=chirp`, rewizja `stt-worker-00091-5x7`). Powód:
na polskim materiale nova-3 **przestawał emitować słowa w połowie
nagrania**, raportując przy tym poprawną długość pliku. Sesja testowa
62,07 s → 13 słów, ostatnie na 15,2 s. Wynik deterministyczny: ten sam
plik jako FLAC i jako m4a, z `diarize`/`smart_format` i bez nich — zawsze
identycznie.

Nie o samą awarię tu chodzi. Chodzi o to, że **przeszła przez całą
walidację Fazy 2 niezauważona**. Runbook docs/56 sprawdzał czas
odpowiedzi, liczbę mówców i mapowanie `{Terapeuta, Klient}` — wszystko
wychodziło zielono, bo fixture'y były krótkie. Żaden test nie pytał
_„czy transkrypcja sięga końca nagrania"_.

Stąd jedna zmiana, która odróżnia ten plan od docs/46 i jest w nim
najważniejsza: **pokrycie jest inwariantem produkcyjnym, sprawdzanym przy
każdej sesji** (§6.1), a nie metryką z raportu. Reszta planu jest
świadomie analogiczna do Deepgrama — te seamy się sprawdziły.

---

## 1. Zweryfikowane fakty o ElevenLabs API

Wszystko poniżej sprawdzone empirycznie 2026-07-31 przez
`scripts/stt-benchmark`, nie przepisane z dokumentacji.

### 1.1 Kontrakt

| | |
|---|---|
| Endpoint | `POST https://api.eu.residency.elevenlabs.io/v1/speech-to-text` |
| Auth | nagłówek `xi-api-key: <klucz>` |
| Model | `model_id=scribe_v2` (`scribe_v1` to poprzednia generacja) |
| Wejście | `multipart/form-data` z plikiem **albo** `source_url` (do 2 GB) |
| Limity | plik < 5 GB, minimum 100 ms audio; **brak limitu długości** |
| Tryb async | `webhook=true` + `webhook_id` — dostępny, ale nie używamy (D1) |

Parametry, które nas dotyczą: `language_code` (ISO-639-1 lub -3),
`diarize`, `num_speakers` (≤32), `timestamps_granularity` (`word`
domyślnie), `tag_audio_events` (domyślnie **true**).

### 1.2 Kształt odpowiedzi

```jsonc
{
  "language_code": "pol",
  "language_probability": 1.0,
  "text": "Bardzo proszę, państwo usiądą...",
  "transcription_id": "...",
  "audio_duration_secs": 1585.8,          // ← patrz §6.1
  "words": [
    {"text": "Bardzo", "start": 12.08, "end": 12.29,
     "type": "word", "speaker_id": "speaker_0", "logprob": -0.0021}
  ]
}
```

`words[]` miesza trzy typy: `word`, `spacing` (same odstępy — w
26-minutowym nagraniu 3252 sztuki obok 3256 słów) oraz `audio_event`
(np. śmiech, gdy `tag_audio_events=true`). **Parser musi filtrować po
`type`**, inaczej licznik słów jest zawyżony dwukrotnie, a `spacing`
trafia do transkryptu jako puste tokeny.

`audio_duration_secs` to długość policzona przez ElevenLabs — dostajemy
ją w tej samej odpowiedzi co słowa, więc pokrycie liczy się bez
dekodowania pliku po naszej stronie.

### 1.3 Wyniki benchmarku

Cztery nagrania, cztery silniki. Pokrycie = koniec ostatniego słowa ÷
długość audio.

| Nagranie | Silnik | Pokrycie | Słów | Mówcy |
|---|---|---|---|---|
| liczenie 62,07 s, 1 mówca | **scribe_v2** | **99,9%** | 94 | 1 ✓ |
| | nova-3 | **24,5%** | 13 | 1 |
| | chirp_3 | 99,9% | 60 | brak |
| | speechmatics | **odrzucony** | — | — |
| dialog 72,98 s, 2 mówców | **scribe_v2** | 98,7% | 126 | **2 ✓** |
| | nova-3 | 98,5% | 99 | **1 ✗** |
| | chirp_3 | **błąd `code 13`** | — | brak |
| | speechmatics | 98,8% | 102 | 2 ✓ |
| sesja CBT 13:40, 2 mówców | **scribe_v2** | 99,0% | 2408 | 2 ✓ |
| | nova-3 | 99,0% | 2332 | 2 ✓ |
| | chirp_3 | 99,0% | 2387 | brak |
| | speechmatics | 99,0% | 2342 | 2 ✓ |
| konsultacja pary 26:26, 3 mówców | **scribe_v2** | 99,4% | 3256 | 3 ✓ |
| | nova-3 | 99,3% | 3171 | 3 ✓ |
| | chirp_3 | 99,3%¹ | 4066¹ | brak |
| | speechmatics | 99,3% | 3198 | 3 ✓ |

¹ Chirp wymagał pocięcia na kawałki (BatchRecognize odrzuca >20 min).
Liczba słów odbiega o ~25% od pozostałych trzech silników i **nie została
wyjaśniona** — podejrzenie nakładania się chunków. Do zbadania, zanim
ktokolwiek zacytuje tę komórkę.

**Scribe: 4/4 poprawnej diaryzacji, najwyższe pokrycie w każdym
przypadku.** Nova-3: 2/4. Chirp: 0/4, bo dla `pl-PL` nie diaryzuje wcale.

Trzy rzeczy z benchmarku, które mają konsekwencje projektowe:

- **Scribe przyjmuje nasz surowy FLAC z telefonu.** Speechmatics go
  odrzuca (`Job rejected due to invalid audio`) — zapis strumieniowy
  zostawia `total_samples=0` w STREAMINFO. Dla Scribe konwersja pozostaje
  optymalizacją, nie warunkiem działania.
- **Brak limitu 20 minut.** Chirp wymaga chunkowania sesji, Scribe wziął
  26-minutowy plik w całości. To usuwa całą klasę kodu.
- **Odporność na błędny `language_code`.** Nagranie CBT jest po
  angielsku; przy wymuszonym `pl` Scribe i Chirp przetranskrybowały je
  poprawnie, a nova-3 zwrócił **zero słów**, Speechmatics sieczkę. To
  argument za `language_code` jako podpowiedzią, nie twardym wymuszeniem
  (D7).

### 1.4 Czas odpowiedzi i koszt

| Długość audio | Czas odpowiedzi |
|---|---|
| 62 s | 3,0 s |
| 73 s | 3,3 s |
| 13:40 | 21,8 s |
| 26:26 | 28,2 s |

Ekstrapolacja na sesję 50-minutową: ~60 s. Timeout funkcji 540 s
(ustawiony pod Deepgrama) pokrywa to z ogromnym zapasem — tryb
synchroniczny zostaje bez dyskusji.

Cennik: **$0,22/h = $0,0037/min**. Przy 1000 sesji × 50 min = 50 000
min/mies daje **$183**, wobec $150 za Chirp w trybie dynamic batching
(bez SLA na czas) i $800 za Chirp w trybie z przewidywalnym czasem.
Deepgram kosztował $460. Scribe jest więc **4× tańszy od porównywalnego
latencyjnie Chirpa** i przy okazji jako jedyny diaryzuje polski.

---

## 2. Architektura docelowa

Seamy bez zmian: wejście `audio.uploaded`
(`{session_id, upload_id, object_path}`), wyjście `transcript.completed`
+ kanoniczny blob `transcripts.transcript_ciphertext` (ADR-IMPL-006).
Downstream od `persistTranscript` nie rusza się nic.

```
audio.uploaded ──► stt-worker (ProcessAudio)
                     │ provider = resolveSTTProvider(session)
        ┌────────────┼────────────────────┐
        ▼ chirp      ▼ deepgram           ▼ elevenlabs (NOWY)
   (bez zmian)   (bez zmian, do          1. idempotencja: SELECT stt_operations
                  usunięcia w Fazie 4)      świeży wpis w toku → NACK
                                         2. INSERT stt_operations(
                                              provider='elevenlabs',
                                              finalized_at=NULL) — PRZED wywołaniem
                                         3. mint V4 signed GET URL (TTL 15 min)
                                         4. POST /v1/speech-to-text
                                              model_id=scribe_v2
                                              language_code=pol
                                              diarize=true
                                              timestamps_granularity=word
                                              source_url=<signed>
                                            — SYNCHRONICZNIE
                                         5. STRAŻNIK POKRYCIA (§6.1)
                                         6. parse → []chunker.Word
                                            (speaker_0 → tag 1, …)
                                         7. wspólny finalize:
                                            ChunkByPauses → persistTranscript →
                                            ANALYZING → transcript.completed →
                                            kasowanie audio → finalized_at=now()
                                         8. ack (~5–60 s łącznie)
```

### Kluczowe decyzje projektowe

**D1 — synchronicznie, nie webhook.** ElevenLabs oferuje `webhook=true`,
ale przyjmowanie transkryptu PHI jako niezaufanego inbound POST oznacza
nowy publiczny endpoint, weryfikację podpisu i obsługę zgubionego
callbacku. Argument z docs/46 §D1 obowiązuje bez zmian, a zmierzone 28 s
na 26 minutach audio odbiera ostatni powód, żeby to rozważać.

**D2 — statusy `TRANSCRIBING → ANALYZING`.** Jak przy Deepgramie —
`MERGING` był artefaktem multi-chunk merge, którego tu nie ma.

**D3 — idempotencja przez `stt_operations`.** Wpis **przed** wywołaniem
API; redelivery widzi świeży wpis (`finalized_at IS NULL`, < 15 min) →
NACK; starszy → przejęcie i ponowny submit. UNIQUE na
`transcripts(session_id)` jako druga linia obrony. Bez zmian wobec docs/46
§D3 — ten mechanizm przetrwał wycofanie Deepgrama nietknięty i nie ma
powodu go ruszać. `transcription_id` z odpowiedzi ląduje w
`stt_operations.request_id` (kolumna istnieje od migracji 000075).

**D4 — zero chunkingu.** Scribe nie ma limitu długości, więc submit bierze
oryginalny obiekt z `object_path`. Chunking w ingestion-svc (>1140 s)
zostaje na razie, bo potrzebuje go fallback Chirp; wycofanie w Fazie 4.

**D5 — downstream bez zmian.** Słowa mają etykiety mówców →
`hasNativeSpeakers=true` → llm-worker idzie istniejącą gałęzią role-only.
Zostaje nasz `ChunkByPauses` (progi 600/300/60000 ms zestrojone pod polską
mowę terapeutyczną).

**D6 — mapowanie parsera.** Z `words[]` bierzemy **wyłącznie
`type == "word"`**. `start`/`end` w sekundach float → ms. `text` jako
treść. `speaker_id` `"speaker_0"` → `SpeakerLabel` `"1"`, `"speaker_1"` →
`"2"` itd. (parsowanie sufiksu po `speaker_`, +1); brak `speaker_id` →
tag 0. `logprob` → pewność per słowo, agregowana do średniej w `Result`.
Semantyka wyjścia identyczna z `ParseChirp3Results` i z parserem
Deepgrama, więc `persistTranscript` bez zmian.

**D7 — `language_code` jako podpowiedź.** Wysyłamy `pol` gdy znamy język
sesji (`sessions.language_code`), ale **nie traktujemy niezgodności jako
błędu**. Benchmark pokazał, że Scribe poprawnie transkrybuje materiał
w innym języku niż zadeklarowany, a nasze dane produkcyjne mają sesje
z pustym `language_code` (rekordy sprzed `feat/llm-optimisation`). Przy
pustym — parametr pomijamy i pozwalamy na autodetekcję;
`language_probability` z odpowiedzi logujemy.

**D8 — `tag_audio_events` wyłączone w v1.** Domyślnie `true`, co wstrzykuje
do `words[]` wpisy typu `audio_event` (śmiech, płacz). Klinicznie to
potencjalnie cenne, ale zmienia kontrakt transkryptu i wymaga decyzji
downstream (czy `[śmiech]` ma trafiać do raportu LLM i do widoku
terapeuty). Na starcie `tag_audio_events=false` — jedna zmienna mniej
przy migracji. Włączenie to osobny ticket z decyzją produktową.

**D9 — `num_speakers` nieustawiane.** Kuszące byłoby podać 2 dla sesji
indywidualnej, ale nie wiemy z góry, ile osób jest w gabinecie (sesje par,
rodzinne, superwizja). Benchmark pokazał poprawne 1/2/3 bez tej
podpowiedzi. Ustawianie jej na sztywno wprowadziłoby błąd systematyczny
dokładnie w przypadkach, na których nam zależy.

---

## 3. Plan prac

### Faza 0 — formalności

1. **Potwierdzenie EU data residency na piśmie** — uzyskane 2026-07-31,
   dopiąć do rejestru podprocesorów. Do potwierdzenia dodatkowo:
   retencja audio i transkryptu po stronie ElevenLabs (czy i jak długo
   przechowują), użycie danych do trenowania (musi być wyłączone —
   odpowiednik `mip_opt_out` Deepgrama), dostępność `scribe_v2` +
   diaryzacji na endpointcie EU, cennik przy naszym wolumenie.
2. **DPA pod dane szczególnej kategorii** (audio terapii = dane
   zdrowotne, GDPR art. 9 + art. 28).
3. **Secret Manager**: sekret `elevenlabs-api-key`,
   `roles/secretmanager.secretAccessor` wyłącznie dla SA stt-workera.
   Endpoint w env `ELEVENLABS_API_URL` przypięty w terraformie do hosta
   rezydencji EU — **kod nie może mieć fallbacku na host globalny**
   (odpowiednik `IsEUEndpoint` z pakietu deepgram; ten sam test
   jednostkowy, nowa stała).
4. **Aktualizacja zgód pacjenta i polityki prywatności** o nowego
   podprocesora — przed pierwszym produkcyjnym audio. Deepgram wypada
   z listy, ElevenLabs wchodzi.
5. **Rotacja kluczy testowych.** Klucze użyte w benchmarku (ElevenLabs
   i Speechmatics) przeszły przez czat — traktować jako spalone.

### Faza 1 — kod (branch `feat/stt-elevenlabs`)

6. **Nowy pakiet** `services/ai-pipeline-svc/internal/elevenlabs/`,
   symetryczny do `internal/deepgram/`:
   - `client.go` — `Transcribe(ctx, audioURL, Params) (*Result, error)`,
     `http.Client{Timeout: 330s}`, nagłówek `xi-api-key`, jeden retry
     z backoffem na 429/5xx, `IsEUEndpoint` pilnujący hosta rezydencji.
   - `parse.go` — mapowanie D6. **Test jednostkowy failuje, jeśli parser
     przestanie filtrować `type != "word"`** — to najłatwiejszy do
     przeoczenia szczegół kontraktu.
   - `classify.go` — ta sama tabela klasyfikacji co docs/46 §5:

     | Odpowiedź | Klasyfikacja | Zachowanie |
     |---|---|---|
     | 400 / 415 / 422 | terminal | session FAILED, `finalize_error`, ack |
     | 401 / 403 | specjalna | NACK + alert, **nigdy** FAILED |
     | 429 / 5xx / timeout / sieć | transient | NACK → retry ≤24 h |
   - `coverage.go` — strażnik z §6.1, osobno, bo używa go też watchdog.
7. **`resolveSTTProvider`**: dołożyć `case "elevenlabs"`. Uwaga — dziś
   funkcja przy nieznanej wartości loguje warning i wraca na `chirp`
   ([`deepgram_path.go:75`](../superwizor-backend/services/ai-pipeline-svc/cmd/stt-worker/deepgram_path.go));
   dopisanie nowej wartości to jedna linia, ale **allowlista canary jest
   dziś zaszyta pod Deepgrama** (`return "deepgram"` w gałęzi listed) —
   trzeba ją uogólnić na „provider z env", inaczej canary ElevenLabs
   wysyła ruch do Deepgrama.
8. **`cmd/stt-worker`**: gałąź `processAudioElevenLabs` — kroki 1–8
   z diagramu, wzorowana na `processAudioDeepgram`. Signed URL: SA ma już
   `storage.objectViewer` i `signBlob`, nic nowego w IAM.
9. **`cmd/stt-watchdog`**: wiersze `provider='elevenlabs'` bez
   `finalized_at` starsze niż 15 min → resubmit (max 2), potem
   jednorazowy fallback na Chirp (`fallback_from`, metryka
   `stt_provider_fallback`). Kod fallbacku istnieje —
   `fallbackToChirp` jest generyczny.
10. **Terraform**: sekret + IAM, env `ELEVENLABS_API_URL`,
    `STT_PROVIDER`, `STT_PROVIDER_ALLOWLIST` na stt-worker i watchdogu.
    `timeout_seconds = 540` zostaje. Żadnej nowej funkcji, bucketu ani
    topicu.

### Faza 2 — walidacja (staging)

11. **Benchmark jako bramka akceptacyjna**, nie raport. `scripts/stt-benchmark`
    z manifestem czterech nagrań musi przejść: pokrycie ≥ 95% dla
    wszystkich, diaryzacja zgodna z `expected_speakers` dla wszystkich,
    zero `bogus_timestamps`. To jest test, którego zabrakło przy
    Deepgramie.
12. Testy jednostkowe + e2e: krótka sesja PL i **pełna 50-minutowa**
    do `COMPLETED`. Weryfikacja: dwóch mówców w `speaker_label_mapping`,
    llm-worker na gałęzi role-only, czas end-to-end.
13. Chaos-testy pod semantykę docs/21: 500 z API (NACK, sesja zostaje
    `TRANSCRIBING`, brak FAILED); timeout w połowie odpowiedzi
    (redelivery → przejęcie wpisu → drugi submit → UNIQUE chroni
    persist); unieważniony klucz (alert, fallback ratuje); redelivery
    w trakcie przetwarzania (NACK na świeżym wpisie).
14. **Test strażnika pokrycia**: podać nagranie, na którym wiadomo, że
    silnik urwie transkrypcję (plik z sesji 7 przez nova-3), i sprawdzić,
    że strażnik zapala alarm zamiast zapisać obcięty transkrypt.

### Faza 3 — produkcja

15. Canary przez `STT_PROVIDER_ALLOWLIST` (po uogólnieniu z kroku 7),
    potem shadow mode na ~50 sesjach: porównanie pokrycia, liczby mówców
    i czasu wobec Chirpa. Dopiero potem flip defaultu.

### Faza 4 — sprzątanie

16. Default → `elevenlabs`. Potem, osobnymi PR-ami: usunięcie ścieżki
    Deepgram (`internal/deepgram`, `deepgram_path.go`, sekret, env),
    chunking w ingestion-svc (>1140 s), `stt-finalize` + Eventarc +
    bucket `transcripts-raw`, `fillSpeakerLabels`, gramatyka klastrująca
    w llm-worker i mapa `Chirp3DiarizationLanguages`. **Najpierw ADR
    unieważniający IMPL-001/007/007a.**

Uwaga do kolejności: Chirp zostaje jako fallback do końca Fazy 4. To
oznacza, że przez cały ten czas utrzymujemy trzy ścieżki STT. Świadomy
koszt — po wycofaniu Deepgrama nie chcemy zostać bez siatki.

---

## 4. Flaga i kill-switch

`STT_PROVIDER=chirp|deepgram|elevenlabs` — env na stt-workerze, default
`chirp` do końca Fazy 3. Rollback = flip env + `terragrunt apply`, zero
zmian w bazie.

Źródłem prawdy jest default w
`infra/environments/staging/variables.tf` (ten katalog celuje w projekt
produkcyjny `superwizor-ai-25ecd` — osobnego `prod/` nie ma). Zmiana
tylko przez `gcloud run services update` zostanie cofnięta przy
najbliższym apply.

---

## 5. Bezpieczeństwo

- Klucz wyłącznie w Secret Managerze, dostęp tylko dla SA stt-workera.
- Signed URL V4, TTL 15 min, **nigdy w logach**.
- Host rezydencji EU przypięty w terraformie; `IsEUEndpoint` odrzuca
  wszystko inne przy starcie klienta. Bez tego jedna literówka w env
  wysyła dane zdrowotne poza UE.
- Wyłączenie użycia danych do trenowania — do potwierdzenia w Fazie 0
  i, jeśli istnieje odpowiedni parametr, wysyłane na sztywno z testem
  jednostkowym pilnującym, że nie zniknęło z żądania (wzorzec
  `mip_opt_out` z docs/46).
- `transcription_id` logujemy (audyt), treści transkryptu nie.

---

## 6. Observability

### 6.1 Strażnik pokrycia — najważniejszy element tego planu

Odpowiedź zawiera `audio_duration_secs`, a ostatnie słowo ma `end`.
Pokrycie liczy się więc z samej odpowiedzi, bez dekodowania pliku:

```
coverage = max(end dla type=="word") / audio_duration_secs
```

Zachowanie przy niskim pokryciu — **nie** cicha akceptacja:

| Pokrycie | Zachowanie |
|---|---|
| ≥ 0,95 | normalna ścieżka |
| 0,50–0,95 | zapis transkryptu + metryka `stt_low_coverage` + alert; sesja przechodzi dalej, bo częściowy transkrypt jest lepszy niż żaden |
| < 0,50 | **traktowane jak awaria transient**: NACK, retry, po wyczerpaniu prób fallback na Chirp; sesja nigdy nie kończy się `COMPLETED` z transkryptem pokrywającym ćwierć nagrania |

Progi są arbitralne i mają takie zostać do czasu, aż zobaczymy rozkład na
produkcji — ale każdy z nich jest lepszy od dzisiejszego braku sprawdzenia.
Sesja 7 przez nova-3 dała 0,245 i trafiłaby w trzeci wiersz.

Dodatkowo do metryk per sesja: `stt_words_per_second` (Speechmatics na
źle otagowanym językowo nagraniu miał pokrycie 99% przy 0,81 słowa/s
zamiast 2,9 — pokrycie patrzy tylko na ostatnie słowo i nie widzi dziury
w środku) oraz `stt_max_word_gap`.

### 6.2 Pozostałe

- `stt_provider_fallback` — licznik fallbacków na Chirpa.
- `stt_latency_seconds` per provider.
- `language_probability` z odpowiedzi — niska wartość sygnalizuje
  niezgodność języka sesji z rzeczywistością.
- Alert na 401/403 (rotacja klucza) — osobny od alertów jakościowych.

---

## 7. Otwarte punkty

1. **Retencja i trenowanie po stronie ElevenLabs** — czy istnieje
   odpowiednik `mip_opt_out`? Bez pisemnej odpowiedzi Faza 1 może ruszyć,
   ale Faza 3 nie.
2. **Cena przy rezydencji EU.** Benchmark opierał się na koncie bez EU
   residency; $0,22/h to stawka standardowa. Jeśli rezydencja podnosi
   cenę powyżej Deepgrama ($0,0092/min), rachunek z §1.4 trzeba
   przeliczyć od nowa.
3. **Anomalia Chirpa 4066 słów** (§1.3, przypis) — do zbadania, zanim
   ktoś użyje tej liczby jako punktu odniesienia.
4. **`tag_audio_events`** — decyzja produktowa, czy śmiech i płacz mają
   trafiać do transkryptu i raportu (D8).
5. **Kolejność wycofywania Chirpa.** Po tej migracji Chirp jest jedynym
   fallbackiem, ale nie diaryzuje polskiego — więc fallback oznacza
   degradację jakości, nie tylko opóźnienie. Czy to akceptowalne, czy
   fallbackiem powinien zostać Speechmatics (wymaga konwersji FLAC,
   §1.3)?

---

## Źródła

- Benchmark: `scripts/stt-benchmark` (gałąź `feat/stt-benchmark`),
  surowe odpowiedzi w `results*/raw/`.
- Poprzednia migracja: docs/46, runbook docs/56.
- Semantyka błędów pipeline'u: docs/21.
- Wycofanie Deepgrama: commit `fd04ecb1` (gałąź `infra/stt-provider-chirp`).
