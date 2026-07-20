---
type: Technical Design
title: "HiTOP — Plan implementacji (NA PÓŹNIEJ)"
description: "W audycie pipeline LLM (2026-05-11) ustaliliśmy, że obecna implementacja HiTOP jest pseudonaukowa — LLM dostaje 1 linijkę \"Wskaż wymiary HiTOP\" i wymyśla sco..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/HiTOP_plan.md
tags: [ai, analytics, database, frontend, identity, ingestion, security, testing]
timestamp: 2026-05-11T04:31:05+02:00
---

# HiTOP — Plan implementacji (NA PÓŹNIEJ)

> **Status**: ZAPARKOWANY — wrócimy po wdrożeniu refaktoru pipeline LLM
> **Źródło naukowe**: HiTOP-DAT Manual (Jonas et al., Stony Brook University)
> **Pełny plan techniczny**: patrz `llm_pipeline_audit.md.resolved` Część 9

## Kontekst decyzji

W audycie pipeline LLM (2026-05-11) ustaliliśmy, że obecna implementacja HiTOP jest **pseudonaukowa** — LLM dostaje 1 linijkę "Wskaż wymiary HiTOP" i wymyśla score 0-100 bez kalibracji psychometrycznej. Decyzja: **usunąć z pipeline LLM, zaprojektować porządnie**.

## Docelowa architektura (w skrócie)

```
LLM czyta transkrypt
  → wydobywa granularne objawy + cytaty (symptom_observations)
  → mapuje na HiTOP: spectrum > subfactor > symptom component

Terapeuta w Flutter
  → widzi listę objawów z cytatami
  → potwierdza / odrzuca / zmienia severity (subthreshold/mild/moderate/severe)

Backend
  → zapisuje potwierdzone obserwacje do hitop_observations
  → agreguje: avg_severity per subfaktor per sesja

Flutter wykres (fl_chart)
  → Oś X: daty sesji, Oś Y: avg_severity (0-3)
  → "Dystres spadł z 2.5 do 1.0 w ciągu 5 sesji"
```

## Hierarchia HiTOP (z manuala)

```
p-factor
├── INTERNALIZING
│   ├── distress — smutek, zmartwienia, bezsenność, trauma
│   ├── fear — fobie, panika, OCD
│   ├── eating_pathology
│   ├── sexual_pathology
│   └── mania (prowizoryczny)
├── THOUGHT_DISORDER — halucynacje, urojenia, dezorganizacja
├── DISINHIBITED_EXTERNALIZING
│   ├── substance_use
│   └── antisocial_disinhibited
├── ANTAGONISTIC_EXTERNALIZING
│   └── antisocial_antagonistic
├── DETACHMENT — anhedonia, wycofanie społeczne
└── SOMATOFORM — lęk o zdrowie, objawy somatyczne
```

## Fazy wdrożenia

1. **Faza A**: Dodać `symptom_observations` do schema + prompt LLM (dane w encrypted report blob)
2. **Faza B**: Flutter ekran potwierdzania + endpoint + migracja `hitop_observations`
3. **Faza C**: Ekran wykresów per pacjent

## Powiązane pliki

- SQL schema: `migrations/000007_phase2_ingestion.up.sql` (tabele `hitop_dimensions`, `hitop_measurements`)
- LLM worker: `services/ai-pipeline-svc/cmd/llm-worker/main.go` (linia 700-728 — do usunięcia)
- Pełna specyfikacja techniczna: `llm_pipeline_audit.md.resolved` Część 9
