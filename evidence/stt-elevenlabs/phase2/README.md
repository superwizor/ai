# Faza 2 — dowody (docs/60)

Data: 2026-07-31. Gałąź: `feat/stt-elevenlabs`.

## Krok 2 — deploy (ZALICZONY)

`terragrunt apply -target=module.cloud_functions` → 4 added, 6 changed,
4 destroyed (trzy zipy + null_resource zastępowane; każde liczy się
podwójnie). Rewizja `stt-worker-00092-yod`, 100% ruchu.

Stan na żywo po deployu:

    STT_PROVIDER        = chirp          ← NIETKNIĘTY, provider wpięty ale wyłączony
    ELEVENLABS_API_URL  = https://api.eu.residency.elevenlabs.io
    STT_PROVIDER_CANARY = (pusty)
    ELEVENLABS_API_KEY  = (brak — sekret nie istnieje, elClient = nil)

**Wyłapane przy `plan`:** pierwsza wersja planu chciała przestawić
`STT_PROVIDER` z `chirp` na `deepgram`. Przyczyna: gałąź wychodziła z
`main`, a poprawka defaulta siedziała na `infra/stt-provider-chirp`.
Terraform widział rozjazd wobec produkcji przestawionej przez `gcloud`
i „naprawiłby" ją z powrotem na wycofany silnik. Cherry-pick `fd04ecb1`
przed `apply`; po nim plan nie rusza `STT_PROVIDER`.

To jest dokładnie przypadek, na który runbook każe przerwać — i dowód,
że ręczna zmiana przez `gcloud` bez utrwalenia w terraformie jest
tymczasowa.

## Krok 3 — bramka pokrycia (ZALICZONA)

Pełne wyniki: `coverage-gate.log`.

| Kryterium | Próg | Wynik |
|---|---|---|
| pokrycie | ≥ 95% | 98,7–99,9% |
| liczba mówców | = oczekiwana | 5/5 |
| uszkodzone znaczniki | 0 | 0 |
| słów/s | ≥ 1,5 | 1,51–2,93 |

Dla porównania na tym samym materiale nova-3 dawał 24,5% pokrycia
(s7-liczenie) i 1 mówcę zamiast 2 (lilith).

## Kroki 4–5 — ZABLOKOWANE

Rezydencja EU **nie jest udostępniona na koncie**. Ten sam klucz:

    https://api.elevenlabs.io                  -> HTTP 200
    https://api.eu.residency.elevenlabs.io     -> invalid_api_key

Bramkę kroku 3 wykonano więc przez host globalny — to jest ważne dla
oceny wyniku: mierzy jakość modelu, nie zgodność rezydencji.

Dopóki to nie zostanie rozwiązane, worker i tak **nie wystartuje** z
kluczem ElevenLabs (guard `IsEUEndpoint` przy starcie odmawia innego
hosta niż rezydencyjny), więc konfiguracja jest fail-safe — ale kroków
4 i 5 nie da się wykonać.
