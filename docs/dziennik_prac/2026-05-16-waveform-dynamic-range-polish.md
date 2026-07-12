---
type: Developer Worklog
title: "Sesja: Waveform Indicator — Dynamic Range + Smooth Pause Transitions"
description: "Data: 2026-05-16 Cel sesji: Przebudowa wizualizacji audio (waveform) w ekranie nagrywania — poprawa czułości na mowę, eliminacja \"kwadratowego\" efektu, płynn..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/dziennik_prac/2026-05-16-waveform-dynamic-range-polish.md
tags: [dziennik-prac]
timestamp: 2026-05-16T12:13:02+02:00
---

# Sesja: Waveform Indicator — Dynamic Range + Smooth Pause Transitions

**Data:** 2026-05-16
**Cel sesji:** Przebudowa wizualizacji audio (waveform) w ekranie nagrywania — poprawa czułości na mowę, eliminacja "kwadratowego" efektu, płynne przejścia pauza/wznowienie.

---

## 🛠 Zmiany w kodzie i plikach

### Pipeline amplitudy (`recording_service.dart`)

- **Noise gate -42 dB** — sweet spot między -45 (lodówka widoczna) a -35 (mowa niewidoczna). macOS AGC podnosi szum do ~-35 dBFS; gate -42 tłumi większość szumu zachowując cichą mowę.
- **Post-gate boost `pow(x, 0.7)`** — bezpieczny bo noise jest gated do 0. Podnosi czułość na mowę o ~30%: spokojna mowa 0.43→0.54, normalna 0.68→0.75, głośna 0.93→0.95.
- Dodany import `dart:math`.

### Waveform Indicator (`euphire_waveform_indicator.dart`)

- **Per-bar jitter ±12%** — rozbija efekt "kwadratu". Amplitude pollowane co 200ms, słupki co 50ms → 4 identyczne słupki z rzędu tworzyły blok. Random variation nadaje organiczny kształt.
- **Scroll-off na pauzie** — stare słupki jadą w lewo i znikają za krawędzią (~1s = 20 słupków × 50ms) zamiast znikać w jednej klatce.
- **Fade controller (1.2s)** — nowy `AnimationController` steruje płynnością przejść:
  - Pauza: ring opacity × fade (1.0→0.0), istniejące ringi dochodzą do końca arcu
  - Wznowienie: fade 0.0→1.0, płynne pojawienie się ringów
- **Usunięta linia pozioma** — painter zawsze rysuje oddzielne słupki (na zero = 2px kreski z przerwami). Brak przełączania trybów wizualnych.
- **`TickerProviderStateMixin`** zamiast `SingleTickerProviderStateMixin` — potrzebne dla dwóch `AnimationController`.
- **Smoothing α=0.55** — szybsza reakcja na transjenty mowy (było 0.35).
- **minBarHeight 2px** (było 4px) — cieńsze kreski ciszy.
- **Zaokrąglone słupki** (RRect r=2.5) — bardziej organiczny wygląd.
- **Glow od progu 0.2** (było 0.4) z progresywnym blurem — mowa "świeci".

---

## 🏗 Architektura i Decyzje

### Ewolucja pipeline'u amplitudy

| Wersja | Gate | Krzywa | Mowa normalna (-15 dB) | Szum lodówki (-35 dB) |
|--------|------|--------|------------------------|-----------------------|
| v0 (oryginał) | brak | linear [-60..0] + pow(0.7) | 0.88 | 0.62 ← kwadrat |
| v1 | -45 dB | x² | 0.25 | 0.0 ← za słabo |
| v2 | -35 dB | x^1.5 | 0.66 | 0.0 ← za słabo |
| v3 | -40 dB | x^1.2 | 0.60 | 0.0 ← za słabo |
| v4 | -42 dB | linear | 0.68 | 0.18 ← OK ale cicha mowa ledwo |
| **v5 (finalna)** | **-42 dB** | **pow(0.7)** | **0.75** | **0.28** ← ✅ |

Kluczowy insight: pow(0.7) jest bezpieczny PO gate, ale destruktywny PRZED gate (inflacja szumu).

### Scroll-off vs Decay

Rozważane podejścia na pauzę:
1. ~~Instant clear~~ — agresywne, skok wizualny
2. ~~Exponential decay (×0.85)~~ — słupki kurczą się w miejscu, nienaturalne
3. **Scroll-off** ✅ — `_smoothedAmplitude = 0.0` natychmiast, tick controller kontynuuje, nowe puste słupki wypychają stare z prawej → naturalny efekt "odjeżdżania"

---

## 🚨 Znane problemy i Dług Technologiczny

- [ ] `isRecording` prop w painterze jest teraz unused (ale zostawiony bo może przydać się do future features jak kolor/styl zależny od stanu)
- [ ] Jitter ±12% jest statyczny — w przyszłości można go skorelować z delta amplitudy dla bardziej realistycznego efektu
- [ ] Na iPhone'ie noise gate -42 dB może być za agresywny (inny AGC niż macOS) — wymaga testów na urządzeniu

---

## 🎯 Następne kroki

- [ ] Test na iPhone — zweryfikować czy gate -42 dB działa dobrze z iOS AGC
- [ ] Nagrać demo video waveformu dla portfolio/prezentacji
- [ ] Przetestować pełny cykl nagranie→upload→raport po fixach z 2026-05-15
