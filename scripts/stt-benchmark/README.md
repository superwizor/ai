# Harness porównawczy dostawców STT

Powstał 2026-07-31, po wycofaniu Deepgrama z produkcji. Ma odpowiedzieć na
jedno pytanie: **który dostawca spełnia oba twarde wymagania — diaryzację
dla polskiego i hosting danych w UE — nie gubiąc przy tym końcówki
nagrania.**

## Dlaczego istnieje

nova-3 deterministycznie przestawał emitować słowa w połowie nagrania,
mimo że w metadanych raportował pełną długość pliku. Sesja 7: 13 słów,
koniec na 15,2 s przy 62,08 s audio. Żaden nasz test tego nie złapał, bo
mierzyliśmy jakość na krótkich fixture'ach — a awaria dotyczyła
**pokrycia** długiego nagrania.

Stąd metryka pierwszej kategorii:

| Metryka | Co mierzy | Dlaczego |
|---|---|---|
| `coverage_pct` | koniec ostatniego słowa ÷ długość audio | Jedyna metryka, która złapałaby nova-3 (24% na sesji 7) |
| `speaker_count` | liczba wykrytych mówców vs faktyczna | Diaryzacja jest twardym wymaganiem — Chirp 3 nie ma jej dla `pl-PL` |
| `latency_s` | czas od wysłania do wyniku | Chirp w trybie dynamic batching potrafi wisieć godzinami |

**WER nie jest liczony** — nie mamy transkrypcji referencyjnych. Harness
mierzy to, co da się zmierzyć bez ground truth, i zapisuje pełne surowe
odpowiedzi do `results/raw/` do ręcznej oceny jakości tekstu.

Długość audio liczona jest przez pełne zdekodowanie (`ffmpeg -f null -`),
nie z nagłówka: FLAC-i z telefonu mają `total_samples=0` w STREAMINFO, bo
zapis strumieniowy nie zna długości z góry. Nagłówek skłamałby w
mianowniku `coverage_pct`.

## Materiał testowy

| Sesja | Mówcy | Rola w teście |
|---|---|---|
| 7 | 1 | Pokrycie. 62 s ciągłego liczenia. nova-3: 24%, chirp_3: 100% |
| 9 | 2 | Diaryzacja — **nova-3 błędnie**. Pokrycie było dobre, więc sesja izoluje samą diaryzację |
| 10 | 3 | Diaryzacja — **nova-3 poprawnie**. Kontrola negatywna |

Sesje 9 i 10 wymagają uzupełnienia `session_id` i `gcs_generation`
w `manifest.json` — patrz „Pobranie audio".

## Dostawcy i status EU

| Dostawca | Diaryzacja pl | Rezydencja EU |
|---|---|---|
| `chirp3` | **nie** — recognizer `eu/_` zwraca 400 `Recognizer does not support feature: speaker_diarization`; mówców rozdziela klasteryzacja LLM w dół pipeline'u | `locations/eu` |
| `speechmatics` | tak (`diarization: speaker`) | `asr.api.speechmatics.com` stoi w UE; hosty per-jurysdykcja na życzenie |
| `elevenlabs` | tak (`diarize=true`) | **tylko w planie z EU data residency** (`api.eu.residency.elevenlabs.io`) |
| `whisper` | **nie ma jej wcale** — to model transkrypcyjny; potrzebny osobny diaryzator (pyannote 3.1) | self-hosted, więc nasza |
| `deepgram` | tak | `api.eu.deepgram.com` — punkt odniesienia, to z czego wychodzimy |

Dwie rzeczy warto mieć na uwadze przy czytaniu wyników:

**ElevenLabs na zwykłym koncie zwróci 401/404** z hosta rezydencji EU.
To nie jest błąd harnessu — brak działającego hosta EU oznacza, że
dostawca nie spełnia twardego wymagania, i tak ma zostać zaraportowany.
Do testu jakości bez rezydencji: `ELEVENLABS_HOST=https://api.elevenlabs.io`.

**Whisper to nie jest jedno pudełko.** Sam large-v3 zwróci
`speaker_count: brak`. Realna alternatywa to „Whisper + pyannote", czyli
dwa modele, własny hosting i utrzymanie — i tak należy go porównywać z
managed API, a nie jako równorzędny wiersz w tabeli.

## Uruchomienie

Klucze: z `ENV` albo z Secret Managera (`speechmatics-api-key`,
`elevenlabs-api-key`). Żadnego z nich jeszcze nie ma w SM.

```bash
python3 scripts/stt-benchmark/benchmark.py --providers chirp3,speechmatics,elevenlabs
```

Dostawcy API nie mają zależności poza stdlib. Chirp wymaga bucketa
roboczego, bo BatchRecognize nie przyjmuje plików lokalnych, a Recognize
inline ma limit 60 s — nasze nagrania są dłuższe:

```bash
BENCH_GCS_PREFIX=gs://<bucket-roboczy>/stt-bench python3 scripts/stt-benchmark/benchmark.py --providers chirp3
```

Whisper wymaga doinstalowania (~3 GB modelu). Na M1 Pro działa na CPU
w `int8`; diaryzacja dodatkowo wymaga tokenu HuggingFace i zaakceptowania
licencji `pyannote/speaker-diarization-3.1` na ich stronie:

```bash
pip install faster-whisper pyannote.audio
```

## Pobranie audio

Nagrania są kasowane z `*-audio-uploads` po transkrypcji, ale bucket ma
soft-delete 7 dni. Generacje:

```bash
gcloud storage ls -l --recursive --soft-deleted "gs://superwizor-ai-25ecd-audio-uploads/**" --project=superwizor-ai-25ecd
```

Przywrócenie jest bezpieczne — bucket audio **nie ma** triggera eventarc
(jedyny GCS-trigger to `stt-finalize` na `*-transcripts-raw`), więc
restore nie odpala pipeline'u:

```bash
gcloud storage restore "gs://<bucket>/<sciezka>#<generacja>" --project=superwizor-ai-25ecd
```

Po skopiowaniu pliku do `audio/` **usuń przywrócony obiekt z bucketa** —
to nagrania sesji terapeutycznych i nie mają tam leżeć jako żywe.

`audio/` i `results/` są w `.gitignore`: nagrania i transkrypcje nie
trafiają do repozytorium.
