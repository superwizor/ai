# Runbook: Deepgram STT — Faza 2 (deploy + walidacja na stagingu)

Wykonanie ręczne kroków z `docs/39_DEEPGRAM_STT_MIGRATION.md` §Faza 2
dla brancha `feat/stt-deepgram`. Wszystkie komendy z katalogu
`superwizor-backend/` na tym branchu. Stan wyjściowy: sekret
`deepgram-api-key` istnieje w Secret Managerze (wersja 1, replikacja
`europe-central2`, accessor dla SA stt-workera — utworzone 2026-07-17).

Uwaga na gcloud na tej maszynie: `export CLOUDSDK_PYTHON=/usr/local/bin/python3.14`
(domyślny Python 3.9 wywala `gcloud builds`/część poleceń).

## Krok 1 — migracja 000075 (PRZED deployem workerów)

Nowy kod workerów SELECT-uje kolumnę `provider` — bez migracji watchdog
zacznie sypać błędami. Kolejność jest twarda: najpierw baza.

```bash
# proxy (osobny terminal)
./cloud-sql-proxy --port 5433 superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de

# hasło z Secret Managera (nie loguj!)
DBURL=$(gcloud secrets versions access latest --secret=postgres-database-url --project=superwizor-ai-25ecd)
PW=$(python3 -c "import urllib.parse,os;print(urllib.parse.urlsplit(os.environ['DBURL']).password)" DBURL="$DBURL")
# UWAGA: hasło w URL jest już percent-encoded — migrate przyjmuje je wprost:
migrate -path migrations \
  -database "postgres://superwizor_app:${PW}@127.0.0.1:5433/superwizor?sslmode=disable" up

# weryfikacja
psql "host=127.0.0.1 port=5433 dbname=superwizor user=superwizor_app sslmode=disable" -c \
  "SELECT version, dirty FROM schema_migrations;
   SELECT column_name FROM information_schema.columns
   WHERE table_name='stt_operations' AND column_name IN ('provider','request_id','fallback_attempted');"
# oczekiwane: version=75, dirty=f, 3 wiersze kolumn
```

Rollback migracji: `migrate ... down 1` (czysty DROP COLUMN).

## Krok 2 — deploy workerów (terragrunt, flaga domyślnie chirp)

Default `STT_PROVIDER=chirp` ⇒ apply NIE zmienia zachowania pipeline'u;
dostarcza tylko nowy kod + env/sekret/IAM/timeout.

```bash
cd infra/environments/staging
terragrunt plan -target=module.cloud_functions | tee /tmp/dg-plan.txt
# Oczekiwane zmiany (i TYLKO takie):
#  ~ google_cloudfunctions2_function.stt_worker    (env +3, secret DEEPGRAM_API_KEY,
#                                                   timeout 120→540, nowy zip)
#  ~ stt_finalize / stt_watchdog                   (nowy zip — wspólne źródło)
#  + google_service_account_iam_member.stt_worker_self_signer
#  + google_secret_manager_secret_iam_member.stt_worker_deepgram_key[0]
#    (binding już istnieje po ręcznym gcloud — apply będzie no-opem/przejęciem)
terragrunt apply -target=module.cloud_functions
```

Weryfikacja startu:
```bash
gcloud functions describe stt-worker --region=europe-central2 --gen2 \
  --format="value(serviceConfig.environmentVariables.STT_PROVIDER, serviceConfig.timeoutSeconds)"
gcloud logging read 'resource.labels.service_name="stt-worker" AND jsonPayload.msg:"deepgram client wired"' \
  --project=superwizor-ai-25ecd --limit=1 --freshness=15m
```

## Krok 3 — okno walidacyjne (deepgram ON) + e2e

```bash
TF_VAR_stt_provider=deepgram terragrunt apply -target=module.cloud_functions

cd ../../..  # superwizor-backend
cd tests && go test -tags=e2e -timeout=15m -v ./e2e/... -run 'TestFullSession_HappyPath$'
```

Kryteria zaliczenia (docs/39 §Faza 2 pkt 10):
- log stt-workera: `deepgram attempt claimed` → `deepgram transcription complete`
  (z `dg_request_id`, `word_count`, `speaker_count>=2`, `transcribe_ms`);
- `transcripts.stt_model = 'deepgram-nova-3'` dla sesji e2e;
- `sessions.speaker_label_mapping` z DWOMA rolami (Terapeuta/Pacjent) —
  llm-worker na gałęzi role-only (log: brak "cluster" w call-1);
- sesja `COMPLETED`; latency STT « Chirpa (sekundy, nie minuty).

Sesja 60-min (opcjonalnie, ~1,2 USD): zsyntetyzuj długą fixture i przepuść
tym samym testem:
```bash
for i in $(seq 90); do printf "file '%s'\n" "$PWD/tests/e2e/testdata/sample.flac"; done > /tmp/list.txt
ffmpeg -f concat -safe 0 -i /tmp/list.txt -c copy /tmp/long60.flac
AUDIO_FILE=/tmp/long60.flac go test -tags=e2e -timeout=25m -v ./e2e/... -run 'TestFullSession_HappyPath$'
# sprawdź w logach, że NIE było chunkingu po stronie STT (1 plik, deepgram)
```

Weryfikacja `mip_opt_out` (docs/39 pkt 12 — audytowalny dowód):
Deepgram Console → Usage → Logs → request z `dg_request_id` musi mieć
feature `mip_opt_out: true`. Alternatywnie API:
```bash
curl -s -H "Authorization: Token $DG_KEY" \
  "https://api.eu.deepgram.com/v1/projects" | jq .
# potem /v1/projects/{id}/requests/{dg_request_id}
```

Chaos-lite (pkt 11, bez psucia klucza produkcyjnego):
- redelivery/idempotencja: pokryte unit-testami claim/takeover + UNIQUE
  na transcripts(session_id);
- fallback na chirp: przetestuj wymuszając błąd — najprościej tymczasowo
  podmień `DEEPGRAM_API_URL` na `https://x.eu.deepgram.com` (przechodzi
  pin EU, ale nie istnieje) → transient → po 3 próbach/30 min watchdog
  robi failover; sesja ma skończyć jako COMPLETED przez chirpa z
  `stt.provider_fallback` w logach. Przywróć URL po teście.

## Krok 4 — powrót na chirp (do czasu canary z Fazy 3)

```bash
cd infra/environments/staging
terragrunt apply -target=module.cloud_functions   # bez TF_VAR → default chirp
```

Canary (Faza 3): `TF_VAR_stt_provider_allowlist=<uuid-terapeuty>` przy
defaulcie chirp.

## Rollback całości

1. Flaga: apply z defaultem (chirp) — natychmiastowy.
2. Kod: terragrunt apply z main (poprzedni zip).
3. Migracja: `migrate ... down 1` (dopiero po cofnięciu kodu!).

## Po walidacji — obowiązkowo

**Rotacja klucza Deepgram** (przeszedł przez czat 2026-07-17):
konsola Deepgram → nowy klucz → `printf '<NOWY>' | gcloud secrets versions add deepgram-api-key --data-file=- --project=superwizor-ai-25ecd`
→ dezaktywuj stary klucz. Workery czytają `latest` — bez redeployu
(wymaga restartu instancji funkcji: nowa rewizja lub odczekać scale-to-zero).
