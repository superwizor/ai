---
type: System Documentation
title: "31 — Admin Prompt Studio (edit modality prompts to fine-tune reports)"
description: "Status: DESIGNED (2026-06-10) — not implemented Surfaces: marketing-site /admin/prompts (new screen) + clinical-svc (3 new admin RPCs + 1 migration) Pipeline..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/31_ADMIN_PROMPT_STUDIO.md
tags: [ai, analytics, crm, database, frontend, identity, infrastructure, security, testing]
timestamp: 2026-06-10T20:40:20+02:00
---

# 31 — Admin Prompt Studio (edit modality prompts to fine-tune reports)

**Status:** DESIGNED (2026-06-10) — not implemented
**Surfaces:** marketing-site `/admin/prompts` (new screen) + clinical-svc (3 new
admin RPCs + 1 migration)
**Pipeline impact:** none — llm-worker is untouched (see §2, the load-bearing fact)

## 1. Goal

Let a SUPERWIZOR_ADMIN edit the per-modality report prompts from the admin
panel and iterate on report quality without an engineer: change → next
report uses it → compare → adjust or roll back. Every change is versioned,
attributed, reasoned, and reversible.

## 2. The load-bearing fact: prompts are already DB-driven

`modalities.therapist_ai_general_prompt` (JSONB, shape `{"system": "<text>"}`)
is read **fresh from Postgres on every report** by llm-worker's
`loadModalityPrompt` (cmd/llm-worker/main.go) and injected as the FIRST block
of the call-2 prompt — it is the report template (sections, tone, lens of the
modality). There is no cache and no env coupling.

**Consequence:** an UPDATE to that column changes the very next report,
zero redeploys, zero llm-worker changes. The entire feature is therefore
"a safe, audited editor for one JSONB column" — the pipeline never changes.

### What is editable vs deliberately NOT

| Prompt piece | Where | Editable here? |
|---|---|---|
| Modality system prompt (report template per modality: UNIV, CBT, …) | `modalities.therapist_ai_general_prompt["system"]` | **YES — this screen** |
| Call-2 fixed scaffold (language rules, ZASADY ZWIĘZŁOŚCI, CZEGO NIE PISZ, RAG block, transcript) | hardcoded, llm-worker | No — shown read-only for context |
| Call-1 grammars (diarization + Metadata/RAG_Theme) | hardcoded, llm-worker | No — the strict Markdown **parser is coupled to them**; a prompt edit could break every report (2026-05-18 incident class) |
| Therapist report preferences (length/emphasis) | `users.report_preferences` | No — per-therapist, already self-serve (docs/10) |

This boundary is the design's main safety property: admins can tune *what a
report says*, not *whether the pipeline parses*.

## 3. Data model — versioning without touching the pipeline

The active prompt **stays** in `modalities.therapist_ai_general_prompt`
(llm-worker keeps reading it, unchanged). Versioning is a sidecar history
table; every save is one transaction: bump the live column + append history.

```sql
-- migration 000052_modality_prompt_versions.up.sql
CREATE TABLE modality_prompt_versions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    modality_id   UUID NOT NULL REFERENCES modalities(id) ON DELETE CASCADE,
    version       INTEGER NOT NULL,              -- 1, 2, 3… per modality
    prompt        JSONB NOT NULL,                -- full {"system": …} snapshot
    change_note   TEXT NOT NULL,                 -- the ActionDialog reason
    created_by    UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (modality_id, version)
);

-- Backfill: snapshot the current live prompt of every modality as version 1
INSERT INTO modality_prompt_versions (modality_id, version, prompt, change_note, created_by)
SELECT id, 1, therapist_ai_general_prompt, 'seed snapshot (migration 000052)',
       (SELECT id FROM users WHERE role='SUPERWIZOR_ADMIN' ORDER BY created_at LIMIT 1)
FROM modalities;
```

Rollback model: "restore version N" re-applies that snapshot as a **new**
version (history is append-only; the live column always equals the highest
version). No `is_active` flag — the invariant "live = latest" keeps the two
sources from drifting.

## 4. API — clinical-svc (owns `modalities`), 3 admin RPCs

Same conventions as `admin_sessions.go`: `requireSuperwizorAdmin` ctx-role
gate (no extra DB hop), audit_log row per mutation, reason required.

```proto
// clinical.proto — AdminPromptStudio (docs/31)
rpc AdminListModalityPrompts(google.protobuf.Empty) returns (AdminListModalityPromptsResponse);
rpc AdminGetModalityPromptHistory(AdminGetModalityPromptHistoryRequest) returns (AdminGetModalityPromptHistoryResponse);
rpc AdminUpdateModalityPrompt(AdminUpdateModalityPromptRequest) returns (AdminUpdateModalityPromptResponse);

message AdminModalityPrompt {
  string modality_id = 1;
  string system_code = 2;        // "CBT"
  string display_name = 3;
  string modality_type = 4;      // therapy | coaching
  bool   is_supported = 5;
  string system_prompt = 6;      // therapist_ai_general_prompt["system"]
  int32  version = 7;            // latest version number
  string updated_by_email = 8;   // join users for display
  google.protobuf.Timestamp updated_at = 9;
}

message AdminUpdateModalityPromptRequest {
  string modality_id = 1;
  string system_prompt = 2;      // full replacement text
  string change_note = 3;        // >= 10 chars (ActionDialog reason)
  int32  expected_version = 4;   // optimistic lock — reject if stale
}
```

Server-side rules in `AdminUpdateModalityPrompt`:
- `requireSuperwizorAdmin(ctx)`.
- Validation: trimmed non-empty; ≤ 20 000 chars (the whole call-2 prompt must
  stay well under the model's input budget — today's largest seed is ~2 k);
  `change_note` ≥ 10 chars; UTF-8 valid.
- **Optimistic lock:** `expected_version` must equal the current max version
  for the modality, else `FailedPrecondition` ("prompt changed by someone
  else — reload"). Two admins can't silently clobber each other.
- One transaction: `UPDATE modalities SET therapist_ai_general_prompt =
  jsonb_build_object('system', $2) WHERE id=$1` + `INSERT
  modality_prompt_versions (…, version = max+1, …)` + audit_log row
  (`action='ADMIN_UPDATE_MODALITY_PROMPT'`, metadata: modality code, old/new
  version, note, chars delta).
- Restore = the same RPC; the frontend sends the historical text (no separate
  rollback endpoint to maintain).

`AdminGetModalityPromptHistory` returns versions newest-first (id, version,
prompt text, note, author email, created_at), paged (page_size ≤ 50).

## 5. The screen — `/admin/prompts`

Follows the established stack exactly: page under
`src/app/[locale]/admin/prompts/page.tsx`, gated by the existing
`AdminGuardAndShell` layout, `clinicalClient` Connect-RPC (typed — NOT the
CRM fetch-proxy pattern, which the CRM doc itself flags as a legacy choice),
`Field.tsx` form controls, `ActionDialog` for the save-with-reason flow,
`translateError` for errors, keys under `admin.prompts.*` in
`messages/{pl,en}.json` (Polish primary). New sidebar item in `AdminShell`:
"Prompty" / "Prompts".

### Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│ Prompty raportów                                  [admin.prompts.title]│
│ Zmiany działają od NASTĘPNEGO raportu. Wersjonowane, z audytem.       │
├───────────────┬──────────────────────────────────────────────────────┤
│ MODALITIES    │  CBT — Cognitive Behavioral Therapy        therapy   │
│               │  wersja 4 · zmienił d.piotrak@… · 2026-06-08 14:12   │
│ ▸ UNIV   v2   │ ┌──────────────────────────────────────────────────┐ │
│ ▸ CBT    v4 ● │ │ [monospace editor, auto-grow, ~70vh]             │ │
│ ▸ PSYCHO v1   │ │ You are a CBT-trained clinical supervision       │ │
│ ▸ COACH  v3   │ │ assistant. Analyze session transcripts through…  │ │
│   (＋ filter)  │ │                                                  │ │
│               │ └──────────────────────────────────────────────────┘ │
│               │  3 412 / 20 000 znaków        [Pokaż zmiany (diff)]  │
│               │                                                      │
│               │  ▸ Gdzie ten prompt trafia? (kontekst call-2)        │
│               │    [read-only accordion: the fixed scaffold with a   │
│               │     highlighted «TWÓJ PROMPT» slot + RAG/transcript  │
│               │     placeholders — so admins see what surrounds it]  │
│               │                                                      │
│               │  [Anuluj zmiany]                [Zapisz nową wersję] │
│               ├──────────────────────────────────────────────────────┤
│               │  HISTORIA                                            │
│               │  v4  2026-06-08  d.piotrak  „mocniejszy nacisk na…"  │
│               │      [Pokaż] [Porównaj z bieżącą] [Przywróć]         │
│               │  v3  2026-06-01  …                                   │
└───────────────┴──────────────────────────────────────────────────────┘
```

### Behaviors

- **List (left):** all modalities from `AdminListModalityPrompts`; badge for
  `is_supported=false`; dot marks unsaved local edits. Switching modalities
  with a dirty editor prompts to discard.
- **Editor:** plain `<textarea>` (monospace, `Field.tsx` `TextArea` styling).
  Live char counter; save disabled when unchanged/empty/over-limit.
- **Diff before save:** "Pokaż zmiany" renders a line-diff (small dep-free
  LCS util, ~80 lines — no new npm dependency) between the loaded version
  and the draft. The same component powers history "Porównaj".
- **Save:** opens `ActionDialog` (existing component — mandatory reason
  ≥ 10 chars). On confirm → `AdminUpdateModalityPrompt` with
  `expected_version`; on `FailedPrecondition` show "ktoś właśnie zmienił ten
  prompt — odśwież" and offer reload-with-diff. On success → reload + toastless
  inline confirmation (panel convention).
- **History:** `AdminGetModalityPromptHistory`; each row: view (read-only
  modal), compare-to-current (diff), restore (pre-fills the editor with that
  version's text and opens the save dialog with note pre-set to
  `przywrócenie wersji N` — restore IS a save, one code path).
- **Context accordion:** static, read-only rendering of the call-2 scaffold
  (copied at build time into an i18n-exempt constant with a sync-note
  comment pointing at llm-worker main.go) with the editable slot highlighted.
  Sets correct expectations about what admins do/don't control.
- **Banner:** "Zmiany obowiązują od następnego wygenerowanego raportu i
  dotyczą wszystkich terapeutów tej modalności." — the one fact an admin
  must internalize.

## 6. Safety & audit

- SUPERWIZOR_ADMIN only, both ends (AdminGuardAndShell + requireSuperwizorAdmin).
- Append-only history; live column always reproducible from it. Worst case
  (bad prompt ships) the rollback path is the same one-click restore.
- audit_log row per change (who/when/why/what-version) — consistent with the
  panel's existing reason-based mutations.
- Validation keeps the JSONB shape server-side (`jsonb_build_object`), so a
  malformed value can never reach `loadModalityPrompt`.
- Optimistic lock prevents concurrent-admin clobber.
- PHI: prompts contain no patient data; no new PHI surface.

## 7. Known coupling to flag (not blockers)

1. **llm-eval drift** — `cmd/llm-eval/main.go` hardcodes copies of the
   modality prompts for offline eval and already carries a "sync manually"
   note. Once prompts are DB-edited, those copies go stale silently.
   Follow-up (separate, small): make llm-eval load prompts from the DB or a
   dumped JSON instead of constants.
2. **Seed migration 000006** stops being the source of truth after the first
   admin edit — already true of any seeded-then-mutated row; history table
   now records the lineage.
3. **`migrations/add_modality.py` + `modality_prompts/*.json`** — new
   modalities are authored as structured JSON (general_instructions +
   category_prompts sections + footer) and concatenated into the seed's
   `system` string by the script. After an admin edits a prompt in the
   panel, the JSON source file diverges the same way the seed does. The
   history table preserves lineage; if section-structured editing ever
   matters, a v2 editor could adopt that JSON shape (general + per-section
   fields) instead of one textarea — the DB column wouldn't change.

## 8. Implementation plan (when approved)

| Phase | Work | Gate |
|---|---|---|
| 1 — backend | migration 000052 + sqlc queries; 3 RPCs in clinical-svc behind `requireSuperwizorAdmin`; audit wiring; unit tests (validation, optimistic lock, restore-as-save) | `go build/vet/test`; e2e: update → ListModalities sees new text → history has v2 → FailedPrecondition on stale version |
| 2 — frontend | `/admin/prompts` page + sidebar item; list/editor/diff/history components; i18n pl+en; ActionDialog save flow | `pnpm build`; Playwright screenshot of editor + diff + history per repo evidence convention |
| 3 — verify live | edit CBT prompt on staging (add a marker sentence), run one e2e full-session with a CBT patient, confirm the marker appears in the report; restore v1; confirm next report reverts | marker visible in report → restore works end-to-end |

Estimated size: ~1 migration + ~350 lines Go + ~600 lines TSX + messages.

## 9. Deliberate non-goals (v1)

- **No draft/test-run against a real transcript from the panel.** The
  fine-tune loop v1 is: edit → next real/staging session shows the effect →
  iterate or roll back. A "Preview on a past session" button (re-running
  call-2 with a draft prompt against a chosen COMPLETED session's stored
  transcript) is the natural v2 — it needs a new ai-pipeline endpoint with
  PHI-decrypt + Vertex cost per click, so it earns its own design.
- No editing of call-1 grammars or the call-2 scaffold (parser/safety
  coupling, §2).
- No per-therapist prompt overrides (that's `report_preferences`, docs/10).
- No prompt A/B testing or eval-matrix integration (pairs with the llm-eval
  follow-up in §7).
