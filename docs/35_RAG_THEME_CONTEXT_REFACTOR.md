---
type: System Documentation
title: "35 — RAG Theme-Level Session Context (refactor plan)"
description: "Status: DONE (deployed + verified in prod 2026-06-10 — llm-worker-00092-cop; two-session e2e TestFullSessionRAGTwoSessions green: session 2 retrieved poolsiz..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/35_RAG_THEME_CONTEXT_REFACTOR.md
tags: [ai, analytics, database, frontend, identity, infrastructure, security, testing]
timestamp: 2026-06-10T20:20:14+02:00
---

# 35 — RAG Theme-Level Session Context (refactor plan)

**Status:** DONE (deployed + verified in prod 2026-06-10 — llm-worker-00092-cop;
two-session e2e `TestFullSession_RAGTwoSessions` green: session 2 retrieved
`pool_size=3 themes_count=2 hits=2 anchor_used=true`)
**Owner:** llm-worker (`services/ai-pipeline-svc/cmd/llm-worker/main.go`)
**Supersedes:** the read-side described in `docs/agents/05_ai-pipeline-svc.md`
§"Long-term memory (RAG) — wired 2026-05-19" (write-side concepts carry over).

## 1. Goal

When the current session talks about *an intimidating mother* and *work
stress*, the report prompt should receive the **prior threads about those
specific topics** — not whichever whole-session summaries happen to land
nearest to a blended query vector. Scope of memory: the patient's **last 36
sessions** (a hard, session-based lookback).

Operator decisions (2026-06-10):

| Question | Decision |
|---|---|
| Memory granularity | **Theme-chunks per session** (2–5 rows) in addition to the whole-session summary row |
| Query representation | **Reorder pipeline**: call-1 → RAG retrieve → call-2 |
| Ranking | **Anchor (always previous session) + recency-weighted cosine + MMR diversity** |
| Existing data | **Coexist, no backfill** — old summary rows stay retrievable, age out naturally |
| Context budget / lookback | **~8 000 chars**; lookback becomes **36 sessions** (not 36 rows) |

## 2. Current state (what we're refactoring)

```
ProcessTranscript
  ├─ loadSession / loadTranscriptBlob / loadModalityPrompt
  ├─ loadRAGContext(patientFileID, legacyChunkFormat(chunks))   ← ① query = RAW TRANSCRIPT
  │     WITH recent AS (last 36 ROWS by created_at)             ← ② row-based lookback
  │     ORDER BY embedding <=> $query LIMIT 3                   ← ③ pure cosine, top-3
  ├─ generateReport(ragContext)
  │     ├─ call-1: metadata + diarization + RAG_Summary  (no RAG input — by design, keep)
  │     └─ call-2: clinical report  ← ragContext at "KONTEKST POPRZEDNICH SESJI:"
  ├─ persistReport
  ├─ generateEmbedding(report.RAGSummaryChunk)                  ← ④ ONE vector per session
  └─ persistRAGMemory  (1 row: chunk_type='summary', importance_score=0.7)
```

Concrete defects, in order of impact:

1. **Query truncation (correctness bug).** `text-embedding-005` accepts
   ~2 048 tokens and **silently truncates**. A 2-hour session transcript is
   15–20 k tokens, so the query vector represents roughly the first 10
   minutes of the session — usually small talk, not the clinical themes.
2. **Theme dilution.** One vector per session averages "mother" + "work
   stress" + everything else. Cross-session thread matching is approximate
   at best; a strongly-matching single theme in an old session loses to a
   blandly-similar full summary in a recent one.
3. **No diversity.** Top-3 cosine hits are frequently 3 near-duplicates of
   the same dominant thread (consecutive sessions about the same crisis),
   leaving the second current theme unrepresented.
4. **No recency signal in ranking.** Inside the pool, an 8-month-old hit
   ties a last-week hit at equal cosine. Clinically, recency matters.
5. **Previous session not guaranteed.** Continuity ("co ustaliliśmy
   ostatnio") is the single most common therapist expectation, yet the
   immediately-prior session often isn't in the top-3.
6. **Dead knobs.** `importance_score` and `chunk_type` are written but never
   read; legacy zero-vector rows still pollute ranking order (skipped only
   after decrypt).

What we deliberately **keep**: call-1 gets no RAG (the 2026-05-19 rationale
table in docs/agents/05 stands — titles/summaries/RAG entries must stay
self-contained); KMS envelope encryption of all stored plaintext;
`patient_file_id` scoping as the privacy boundary; every RAG failure
non-fatal to the report.

## 3. Target design

### 3.1 Pipeline shape (after)

```
ProcessTranscript
  ├─ loadSession / loadTranscriptBlob / loadModalityPrompt
  ├─ CALL-1  (generateMetadata — split out of generateReport; unchanged prompts
  │           except the new RAG_Themes block; still no RAG input)
  │     emits: …existing fields…, RAG_Summary, RAG_Themes (2–5 entries)
  ├─ loadRAGContextV2(patientFileID, currentSessionID, themes, ragSummary)
  │     pool   = all rag_memories rows from the patient's LAST 36 SESSIONS
  │     query  = one embedding PER current theme (fallback: RAG_Summary)
  │     rank   = cosine × recency-decay, MMR dedup, anchor = previous session
  │     output = grouped, dated context block ≤ 8 000 chars
  ├─ CALL-2  (generateReportBody — gets the new context block)
  ├─ persistReport
  └─ persistRAGMemoryV2  (1 summary row + N theme rows, embeddings in parallel)
```

The reorder costs nothing: call-1 never used RAG, so moving retrieval after
it changes no model input except call-2's (which is the point). Wall-clock
impact ≈ +0 — the retrieval that used to overlap nothing now runs between
the two Vertex calls; embedding calls are ~100–200 ms and parallelized.

### 3.2 Write side — theme chunks

**Call-1 prompt additions** (both markdown + JSON modes, after the existing
`RAG_Summary` instruction):

```
RAG_Themes: 2–5 odrębnych wątków klinicznych TEJ sesji, każdy w osobnej
linii "- <wątek>: <2–3 zdania gęstego opisu>". Wątek = temat, który może
powrócić w przyszłych sesjach (np. "lęk przed matką", "stres w pracy",
"wzorzec unikania"). BEZ danych identyfikujących. Nie dziel jednego tematu
na kilka wpisów; nie twórz wątku z small-talku.
```

- Markdown mode: new `RAG_Themes:` list block in `# Metadata`; parser change
  in `markdownResultToPayload` (tolerant: absent block → empty slice — old
  behavior, never a parse failure).
- JSON mode: new optional `rag_themes: []string` in the call-1 inline schema.
- `ReportPayload` gains `RAGThemes []string` with the same fall-through
  spirit as `RAGSummaryChunk` (absent → empty).

**`persistRAGMemoryV2`** (replaces `persistRAGMemory`):

- Row 1: the whole-session summary — exactly today's row
  (`chunk_type='summary'`, `importance_score=0.7`). This row powers the
  **anchor** and remains the fallback for theme-less sessions.
- Rows 2..N: one per theme — `chunk_type='theme'`,
  `importance_score=0.5`, plaintext = the theme line ("lęk przed matką: …"),
  its own embedding.
- All embeddings generated concurrently (`errgroup`, ≤6 calls); single
  transaction for the inserts. Whole step stays **non-fatal** (Warn + skip),
  exactly like today.
- **No schema migration.** `chunk_type VARCHAR(50)` and the partial index
  `idx_rag_memories_patient_file (patient_file_id, created_at DESC) WHERE
  NOT is_compacted` already support everything below.

### 3.3 Read side — `loadRAGContextV2`

**Step 1 — pool fetch (SQL stays dumb, ranking moves to Go).**

```sql
WITH recent_sessions AS (
    SELECT DISTINCT source_session_id, max(created_at) AS session_at
    FROM rag_memories
    WHERE patient_file_id = $1 AND NOT is_compacted
      AND source_session_id IS NOT NULL
      AND source_session_id <> $2          -- exclude the session being processed
    GROUP BY source_session_id
    ORDER BY session_at DESC
    LIMIT 36                               -- ragLookbackSessions
)
SELECT m.id, m.source_session_id, m.chunk_type, m.created_at, m.embedding
FROM rag_memories m
JOIN recent_sessions rs ON rs.source_session_id = m.source_session_id
WHERE m.patient_file_id = $1 AND NOT is_compacted;
```

Pool ceiling: 36 sessions × ≤6 rows = ≤216 rows × 768 floats ≈ 650 KB.
Trivial to score in memory; **no ciphertext is fetched and nothing is
decrypted at this stage** (decryption = 1 KMS round-trip per row — we only
pay it for final winners). The pgvector HNSW index becomes irrelevant for
this path; the partial B-tree index covers the CTE.

`$2` (current session exclusion) also fixes a latent retry bug: today, a
Pub/Sub redelivery after a partial run could retrieve the *current*
session's own freshly-written memory.

**Step 2 — query embeddings.** One per call-1 theme (≤5, parallel).
Fallbacks, in order: themes empty → embed `RAG_Summary`; that empty (the
<2-chunk fast-path skips call-1) → embed first+last 1 000 transcript chars.
Embedding failure → return `""` (non-fatal, as today).

**Step 3 — score (pure Go, unit-testable).** For each candidate row, against
each theme vector:

```
sim(c,t)   = 1 - cosineDistance(c.embedding, t.vec)
recency(c) = exp(-ageDays(c) * ln2 / ragRecencyHalfLifeDays)   // 90d half-life
score(c)   = max over themes [ sim(c,t) ] * (0.7 + 0.3*recency(c))
```

Zero-vector legacy rows score ~0 and never surface — fixing defect 6
without touching the data.

**Step 4 — select with MMR + anchor.**

```
anchor   = the 'summary' row of the most recent session in the pool (always included)
selected = [anchor]
repeat until len == ragMaxHits(6) or candidates exhausted:
    best = argmax score(c) among candidates where
             c.source_session_id ∉ {already 2 rows selected from}   // per-session cap
             and max cosine-sim(c, any selected) < 0.92             // near-dup gate
    selected += best
```

The per-theme `max` in scoring plus the dup-gate is what guarantees *both*
"mother" *and* "work stress" threads surface instead of three copies of the
stronger one.

**Step 5 — decrypt winners only, assemble.** Group by session, newest first,
with explicit dates so the model can reason about time:

```
KONTEKST POPRZEDNICH SESJI:

[Poprzednia sesja — 2026-06-03]
1. <summary anchor>

[Sesja z 2026-05-12 — powiązane wątki]
2. lęk przed matką: …
3. wzorzec unikania: …

[Sesja z 2026-03-30 — powiązany wątek]
4. stres w pracy: …
```

Cap `ragContextMaxCharsV2 = 8000`, trimming lowest-score-first (anchor is
never trimmed). Keep the `last_accessed_at` background bump and the
`rag.retrieved` analytics event, adding `themes_count`, `anchor_used`,
`sessions_represented`.

### 3.4 Knobs (all package-level consts, same style as today)

| Knob | Value | Note |
|---|---|---|
| `ragLookbackSessions` | 36 | replaces `ragLookbackMemories` (rows→sessions) |
| `ragMaxHits` | 6 | anchor + ≤5 semantic hits |
| `ragPerSessionCap` | 2 | diversity across sessions |
| `ragDupSimThreshold` | 0.92 | MMR near-duplicate gate |
| `ragRecencyHalfLifeDays` | 90 | decay half-life |
| `ragRecencyFloor` | 0.7 | `0.7+0.3*recency` — recency tunes, never dominates |
| `ragContextMaxCharsV2` | 8000 | ≈4 k tokens, <10 % call-2 input |
| `ragMaxThemes` | 5 | write-side cap, prompt + parser enforced |

### 3.5 No legacy fallback (dev-stage decision, 2026-06-10)

We are pre-GA, so there is **no rollback flag** — the v2 reader fully
replaces the old one (`loadRAGContext` and the `LLM_RAG_MODE` switch were
removed). The v2 reader handles pre-refactor summary-only rows natively
(they're just `chunk_type='summary'` candidates with no themes), so the
write-side change can land first and old history stays retrievable with
zero data surgery. If a rollback path is ever needed post-GA, reintroduce
the flag then.

## 4. Implementation phases

**Phase 1 — extraction + scoring core (no behavior change).**
Split `generateReport` into `generateMetadata` (call-1 + <2-chunk fast-path)
and `generateReportBody` (call-2); `ProcessTranscript` orchestrates, RAG
still called before call-1 with legacy logic. New file `rag.go` in
`cmd/llm-worker/` (the shared-zip glob in `package.sh` already picks up
`*.go`): move both RAG functions there; add pure functions `cosineSim`,
`recencyWeight`, `selectWithMMR` + table-driven unit tests (mother/work-stress
fixture proving two themes beat three duplicates; zero-vector exclusion;
anchor-always; per-session cap; budget trim order).
*Gate: `go build && go vet && go test` green; staging report byte-equivalent.*

**Phase 2 — write side.**
Call-1 prompts (markdown + JSON) emit `RAG_Themes`; parser + `ReportPayload.
RAGThemes`; `persistRAGMemoryV2` with parallel embeddings + transactional
multi-row insert. Reader untouched.
*Gate: staging session writes 1 summary + N theme rows; markdown parser
regression tests incl. absent-block tolerance.*

**Phase 3 — read side + reorder.**
`loadRAGContextV2` (pool SQL, per-theme embeddings, score/MMR/anchor,
grouped block); `ProcessTranscript` reorders to call-1 → retrieve → call-2.
The old reader + `LLM_RAG_MODE` flag were removed outright (§3.5, dev-stage).
*Gate: two-session e2e on staging — session A about distinct topics X+Y,
session B mixing both; assert `rag.retrieved` shows ≥2 sessions represented,
anchor present, context ≤8 000 chars; flip flag to `legacy` and re-verify
old path still works.*

**Phase 4 — deploy + docs.**
Deploy llm-worker (terragrunt `module.cloud_functions`, or `gcloud` from the
packaged zip per the 2026-06-09 precedent if the unrelated cloud_sql PITR
drift is still unresolved). Rewrite docs/agents/05 RAG section; update this
doc's status; add `rag.retrieved` fields to the analytics doc (26).
*Gate: first real prod session logs `rag.retrieved` with v2 fields; spot-check
one report's context block on staging with `LLM_DEBUG_LOG_PROMPTS` (staging
only — PHI).*

## 5. Cost, privacy, failure modes

- **Cost/report:** embeddings 1→~10 calls (write ≤6 + read ≤5, parallel)
  ≈ +$0.001; call-2 input +~3 k tokens ≈ +$0.004; call-1 output +~300 tokens.
  Total well under $0.01/report.
- **Privacy:** unchanged guarantees — `patient_file_id` scoping, KMS envelope
  on every stored plaintext (theme rows included), no-PII instruction now on
  both `RAG_Summary` and `RAG_Themes`, `ON DELETE CASCADE` still wipes a
  patient's whole memory (theme rows live in the same table). Pool fetch
  reads embeddings only; plaintext decrypted solely for the ≤6 winners.
- **Failure modes:** every new step inherits the non-fatal contract —
  theme-parse failure → empty themes → summary-query fallback; embedding
  failure → context `""`; persist failure → Warn, report unaffected. The
  only hard failures remain the existing call-1/call-2 terminal classes.

## 6. Explicit non-goals (this iteration)

- No backfill of historical rows (decision Q4) — old whole-session summaries
  compete as-is and age out of the 36-session window.
- No compaction job (`is_compacted` stays write-only), no cross-patient or
  cross-therapist retrieval, no external vector store (ADR-002 stands), no
  embedding-model bump (text-embedding-005 stays; a swap would invalidate
  stored vectors and is a separate migration with its own plan).
