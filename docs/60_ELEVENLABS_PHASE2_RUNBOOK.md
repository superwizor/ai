<!--
  Status: RUNBOOK — do wykonania po Fazie 0 (docs/59 §3).
  Kod Fazy 1: galaz feat/stt-elevenlabs.
  Poprzednik: docs/56 (Deepgram, Faza 2). Ten runbook celowo dokłada
  krok, ktorego tam zabraklo — bramke pokrycia.
-->

# 60. Runbook: ElevenLabs Scribe v2 — Faza 2 (deploy + walidacja)

## Czego zabrakło poprzednim razem

Runbook docs/56 przeprowadził Deepgrama przez walidację i **wszystko
wyszło zielono**: czas odpowiedzi 705–935 ms, dwóch mówców w
`speaker_label_mapping`, mapowanie `{Terapeuta, Klient}`, full happy path.
Dwa tygodnie później okazało się, że nova-3 ucina transkrypcje w połowie
nagrania.

Powód, dla którego walidacja tego nie złapała, jest banalny: fixture
`sample.flac` trwa kilkanaście sekund. Na takim materiale urwanie
transkrypcji jest niewidoczne, bo nie ma czego urwać.

Stąd **krok 3 tego runbooka jest nieusuwalny**: bramka pokrycia na
materiale wielominutowym. Nie „sprawdź, czy działa" — sprawdź, czy
transkrypcja sięga końca nagrania.

---

## Warunki wstępne

Faza 0 z docs/59 musi być zamknięta, w szczególności:

- sekret `elevenlabs-api-key` istnieje w Secret Managerze,
- pisemne potwierdzenie EU data residency (mamy, 2026-07-31),
- **odpowiedź o retencję i trenowanie** (docs/59 §7.1) — bez niej można
  wykonać kroki 1–4 na materiale testowym, ale **nie wolno przepuścić
  ani jednej prawdziwej sesji pacjenta**.

Klucze użyte w benchmarku przeszły przez czat i są spalone — do
Secret Managera trafia **nowy**.

## Krok 1 — utworzenie sekretu

```bash
printf '%s' 'NOWY_KLUCZ' | gcloud secrets create elevenlabs-api-key --data-file=- --project=superwizor-ai-25ecd
```

Weryfikacja, że wersja istnieje (bez wypisywania wartości):

```bash
gcloud secrets versions list elevenlabs-api-key --project=superwizor-ai-25ecd --format="table(name,state,createTime)"
```

## Krok 2 — deploy (flaga domyślnie chirp)

W `infra/environments/staging/variables.tf` ustawić
`elevenlabs_api_key_secret_id` na `"elevenlabs-api-key"`. `stt_provider`
zostaje `chirp` — ten deploy tylko **wpina** providera, nie włącza go.

```bash
cd superwizor-backend/infra/environments/staging && terragrunt plan -target=module.cloud_functions
```

Oczekiwane zmiany i **tylko takie**:

```
~ google_cloudfunctions2_function.stt_worker   (env +2: ELEVENLABS_API_URL,
                                                STT_PROVIDER_CANARY;
                                                secret ELEVENLABS_API_KEY; nowy zip)
~ stt_finalize / stt_watchdog                  (nowy zip — wspólne źródło)
+ google_secret_manager_secret_iam_member.stt_worker_elevenlabs_key
```

Jeśli plan chce zmienić `STT_PROVIDER` — **przerwać**. To znaczy, że ktoś
zmienił default i deploy włączyłby nowy silnik bez walidacji.

Po `apply` sprawdzić, że worker wstał i wpiął klienta:

```bash
gcloud functions logs read stt-worker --project=superwizor-ai-25ecd --region=europe-central2 --limit=50 | grep -i "elevenlabs client wired"
```

Brak tej linii przy ustawionym sekrecie oznacza, że klucz nie dojechał —
`elClient` jest `nil` i flaga i tak wróciłaby na chirpa.

**Kontrola bramki EU:** worker odmawia startu, gdy `ELEVENLABS_API_URL`
nie jest hostem rezydencji. Warto to raz sprawdzić celowo na stagingu
(ustawić globalny host, zobaczyć `refusing to start`, cofnąć) — bramka
nietestowana to bramka, o której się tylko zakłada, że działa.

## Krok 3 — bramka pokrycia (NIE POMIJAĆ)

To jest krok, którego zabrakło przy Deepgramie.

```bash
python3 scripts/stt-benchmark/benchmark.py --providers elevenlabs
```

Warunki przejścia — **wszystkie**, dla **każdego** nagrania z manifestu:

| Warunek | Próg |
|---|---|
| pokrycie | ≥ 95% |
| liczba mówców | dokładnie `expected_speakers` |
| `bogus_timestamps` | 0 |
| słów na sekundę | ≥ 1,5 dla nagrań konwersacyjnych |

Ostatni wiersz jest osobno od pokrycia celowo: pokrycie patrzy tylko na
ostatnie słowo i nie widzi dziury w środku. Speechmatics na źle
otagowanym językowo nagraniu miał 99% pokrycia przy 0,81 słowa/s.

Manifest zawiera cztery nagrania, w tym 26-minutową konsultację pary
(3 mówców) i 62-sekundowe liczenie, na którym nova-3 dawał 24,5%.
Nagrania nie są w repo — pobrać wg `scripts/stt-benchmark/README.md`.

## Krok 4 — e2e na pełnej sesji

Okno walidacyjne z providerem włączonym:

```bash
cd superwizor-backend/infra/environments/staging && TF_VAR_stt_provider=elevenlabs terragrunt apply -target=module.cloud_functions
```

Przepuścić **pełną 50-minutową sesję** do `COMPLETED`. Krótka sesja PL
też, ale to ta długa jest testem — na krótkiej nie widać niczego, co nas
tu interesuje.

W logach sprawdzić linię `elevenlabs transcription complete` i w niej:

- `coverage` ≥ 0,95 i `coverage_verdict=accept`,
- `speaker_count` = 2,
- `bogus_timestamps` = 0,
- `language_probability` blisko 1,0,
- `transcribe_ms` — spodziewane ~60 s dla 50 minut audio.

W bazie: `transcripts.stt_model = 'elevenlabs-scribe-v2'`,
`stt_operations.provider = 'elevenlabs'`, `request_id` niepuste,
`finalized_at` ustawione. W raporcie: llm-worker na gałęzi role-only
(`hasNativeSpeakers=true`), mapowanie `{Terapeuta, Klient}`.

## Krok 5 — chaos-testy (semantyka docs/21)

Każdy scenariusz kończy się tym samym pytaniem: **czy sesja została
oznaczona FAILED?** Poza gałęzią terminalną odpowiedź musi brzmieć nie.

| Scenariusz | Jak wywołać | Oczekiwane |
|---|---|---|
| 5xx od API | podmienić `ELEVENLABS_API_URL` na endpoint zwracający 500 | NACK, sesja zostaje `TRANSCRIBING`, brak FAILED |
| unieważniony klucz | wpisać zły klucz do nowej wersji sekretu | log `elevenlabs_auth_error`, sesja czeka, **nigdy** FAILED |
| wygasły signed URL | opóźnić dostarczenie ponad 15 min | 400 „Failed to download" sklasyfikowane jako **transient**, nie terminal |
| redelivery w trakcie | ręcznie republikować `audio.uploaded` | NACK na świeżym wpisie (`another elevenlabs attempt in flight`) |
| wyczerpanie prób | 3× wymusić błąd | jednorazowy fallback na chirpa, log `provider_fallback=elevenlabs→chirp` |
| **niskie pokrycie** | podać nagranie, na którym silnik urywa | log `stt_low_coverage`, **transkrypt NIE zapisany**, NACK, po próbach fallback |

Ostatni wiersz jest sednem całej migracji. Jeśli sesja z uciętą
transkrypcją kończy się jako `COMPLETED`, straż nie działa i nie wolno
iść do Fazy 3.

## Krok 6 — powrót na chirpa

Do czasu canary Fazy 3:

```bash
cd superwizor-backend/infra/environments/staging && terragrunt apply -target=module.cloud_functions
```

(default w `variables.tf` to `chirp`, więc apply bez `TF_VAR` cofa flagę).

Potwierdzić:

```bash
gcloud run services describe stt-worker --project=superwizor-ai-25ecd --region=europe-central2 --format="value(spec.template.spec.containers[0].env)" | tr ';' '\n' | grep STT_PROVIDER
```

## Rollback całości

Flaga: `STT_PROVIDER=chirp` + apply — bez zmian w bazie, bez migracji do
cofania (Faza 1 nie dodaje żadnej).

Pełne wypięcie providera: `elevenlabs_api_key_secret_id = ""` → sekret
przestaje być montowany, `elClient` zostaje `nil`, a nawet omyłkowe
`STT_PROVIDER=elevenlabs` wraca na chirpa zamiast wywracać sesje.

## Czego ten runbook NIE sprawdza

Uczciwie, żeby następna osoba nie założyła inaczej:

- **jakości transkrypcji** — nie mamy transkryptów referencyjnych, więc
  WER nie jest liczony nigdzie w tym procesie. Benchmark mierzy pokrycie
  i diaryzację; tekst trzeba przeczytać samemu z `results/raw/`;
- **zachowania na materiale niepolskim** — manifest ma jedno nagranie
  angielskie, co nie jest pokryciem wielojęzyczności;
- **retencji po stronie ElevenLabs** — to kwestia umowna (docs/59 §7.1),
  nie do zweryfikowania z naszej strony;
- **kosztu przy rezydencji EU** — benchmark szedł przez konto bez niej.
