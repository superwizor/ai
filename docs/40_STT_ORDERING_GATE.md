---
type: System Documentation
title: "40 — Ordering gate: serializacja sesji per kartoteka (wariant serwerowy)"
description: "Flaga `STT_ORDER_GATE` domyślnie off."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/docs/40_STT_ORDERING_GATE.md
tags: [ai, analytics, database, identity, infrastructure, ingestion, testing]
timestamp: 2026-07-18T23:26:24.735379
---

# 40 — Ordering gate: serializacja sesji per kartoteka (wariant serwerowy)

**Status:** implemented (2026-07-17), branch `feat/stt-ordering-gate`.
Flaga `STT_ORDER_GATE` domyślnie **off**.

## 1. Problem

Dwie krótkie sesje tej samej kartoteki (`patient_file`) mogły być
analizowane w złej kolejności chronologicznej — zmienna latencja STT
(historycznie Chirp: 1–30+ min bez SLA) sprawiała, że sesja 2 kończyła
się przed sesją 1. Skutek trwały: `persistRAGMemoryV2` zapisuje pamięć
pacjenta w kolejności *ukończenia*, a `loadRAGContextV2` wybiera anchor
jako „summary najświeższej poprzedniej sesji" — raport sesji 2 powstaje
bez kontekstu sesji 1, a łańcuch wątków klinicznych pacjenta jest
permanentnie odwrócony. Deepgram (STT ~1 s) zawęża okno wyścigu, ale go
nie zamyka (retry, fallback na Chirpa, latencja LLM).

**Inwariant:** dla danej kartoteki w pipeline (`CREATED → … →
ANALYZING`) jest naraz co najwyżej JEDNA sesja; następcy czekają na
wejściu STT, zanim dostaną status `TRANSCRIBING`.

Wariant kliencki (pauzowanie PUT w aplikacji) został odrzucony:
zostawiał jedyną kopię nagrania na telefonie na czas czekania, nie
domykał multi-device/web/importu i wymagał wydania aplikacji.

## 2. Mechanizm — celowe NACK-as-wait

`ProcessAudio` (stt-worker), przed flipem na `TRANSCRIBING`:

```
applyOrderingGate(session):
  1. SELECT patient_file_id, session_number, created_at sesji.
  2. Bypass: wiek sesji ≥ STT_ORDER_GATE_MAX_WAIT_H (12 h) → przepuść
     (Warn `ordering_gate_bypass` + analytics) — kolejność ustępuje
     żywotności.
  3. SELECT aktywnego poprzednika:
       patient_file_id = ten sam
       AND deleted_at IS NULL
       AND status IN ('CREATED','TRANSCRIBING','MERGING','ANALYZING')
       AND (session_number, created_at, id) < (moje wartości)
  4. Jest → log `ordering_gate_waiting` + **return błąd (NACK)**.
     Nie ma → przepuść.
```

**NACK-i są celowe.** Handler CloudEvent nie ma innego sposobu na
„dostarcz później" niż zwrócenie błędu. Pętlą odpytującą jest polityka
retry subskrypcji Eventarc (`audio.uploaded`, backoff 10–600 s,
`max_delivery_attempts=100` z `infra/scripts/wire_dlq.sh`). Framework
Cloud Functions zaloguje te zwroty jako ERROR — **to nie jest awaria**;
filtrować po komunikacie `ordering gate: waiting for predecessor`.

Porządek totalny `(session_number, created_at, id)` — `session_number`
nadawany transakcyjnie w `CreateAudioUpload` — łamie symetrię: dwie
równoczesne sesje nigdy nie zablokują się nawzajem.

## 3. Twardy inwariant bezpieczeństwa DLQ

Budżet redelivery subskrypcji ≈ **15–16 h** (100 prób × ≤600 s).
`STT_ORDER_GATE_MAX_WAIT_H` (default 12 h) **musi być ostro mniejszy**
— inaczej czekający następca wyczerpie próby, spadnie do
`audio.uploaded.dlq`, a reaper DLQ oznaczy zdrową sesję jako FAILED.
Pilnowane w trzech miejscach naraz (zmieniać RAZEM):

1. `ordering_gate.go` — nagłówek + `defaultOrderGateMaxWaitHours`,
2. `infra/scripts/wire_dlq.sh` — sekcja „ORDERING GATE DEPENDS ON…",
3. test `TestOrderGateMaxWait_DLQSafetyInvariant` (failuje przy
   default ≥ 15 h).

## 4. Edge case'y (decyzje)

| Przypadek | Zachowanie |
|---|---|
| Poprzednik COMPLETED / FAILED / CANCELLED_BY_USER | terminal → przepuść przy najbliższym redelivery |
| Poprzednik utknięty (transient retry) | następca czeka do 12 h (bypass), backstop `reapStuckSessions` ~26 h FAIL-uje poprzednika |
| Poprzednik `PENDING_UPLOAD` | **nie blokuje** — audio nigdy nie dotarło (porzucony upload, inne urządzenie); blokada zamroziłaby kartotekę do orphan-cleanupu |
| Poprzednik usunięty w trakcie | `deleted_at IS NULL` wyklucza → przepuść |
| 3+ sesji naraz | kaskada: każda widzi wszystkich wcześniejszych aktywnych |
| Dwie sesje w tej samej sekundzie | porządek totalny z tie-breakerem `(created_at, id)` |
| Multi-device / web / import pliku | działa w 100% — brama patrzy na bazę, nie na lokalną kolejkę klienta |
| Redelivery po zwolnieniu | start do ~600 s (bieżący backoff) po ukończeniu poprzednika |
| Błąd DB w bramie | NACK (retry) — reszta ProcessAudio i tak wymaga DB |
| Import historycznego nagrania po nowszej sesji | poza zakresem — brama pilnuje kolejności *napływu*, nie retro-chronologii (problem istniał przed bramą) |

## 5. Flagi i rollout

| Env (stt-worker) | Default | Znaczenie |
|---|---|---|
| `STT_ORDER_GATE` | `off` | `on` włącza bramę; rollback = flip env (wzorzec `STT_PROVIDER`) |
| `STT_ORDER_GATE_MAX_WAIT_H` | `12` | okno bypass; patrz inwariant §3 |

Rollout: deploy z `off` → włączenie na stagingu → e2e (dwie krótkie
sesje jednej kartoteki: sesja 2 bez `TRANSCRIBING` przed `COMPLETED`
sesji 1; `rag.retrieved` sesji 2 z `anchor_used=true`) → zostaje `on`.
Zero migracji; zero zmian klienta, ingestion, llm-workera.

## 6. Observability

- log/analytics `stt.ordering_gate_wait` (predecessor_id, status, wiek
  następcy) — wolumen = ile sesji czeka;
- `stt.ordering_gate_bypass` — **alert przy każdym wystąpieniu**
  (oznacza patologicznego poprzednika > 12 h);
- filtr logów pod alerting błędów stt-workera musi wykluczać komunikat
  `ordering gate: waiting for predecessor` (celowy NACK).

Dokumenty powiązane: `docs/agents/05_ai-pipeline-svc.md` (flagi,
pipeline), `docs/agents/08_infrastructure-terraform.md` +
`infra/scripts/wire_dlq.sh` (budżet retry), `docs/30_RAG_THEME_CONTEXT_
REFACTOR.md` (dlaczego kolejność ma znaczenie), docs/21 (semantyka
NACK/transient).
