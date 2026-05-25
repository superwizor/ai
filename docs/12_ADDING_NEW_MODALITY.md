# 12 — Adding a new psychotherapy modality

**Audience:** anyone (engineer or prompt-engineer) who wants to add a new
therapy modality — its system prompt, the database row that the
llm-worker reads at runtime, and the Flutter picker entry.

**Tool:** [`superwizor-backend/migrations/add_modality.py`](../superwizor-backend/migrations/add_modality.py)
generates the SQL migration from a per-modality JSON file at
[`superwizor-backend/migrations/modality_prompts/<name>.json`](../superwizor-backend/migrations/modality_prompts/).

**Status:** generalised from `build_gestalt_migration.py` on 2026-05-22.
First modality shipped under the new flow: GESTALT (`000019_seed_gestalt_modality.up.sql`).

---

## When to use this

You're adding a 10th, 11th, Nth therapy modality (CBT / Psychodynamic /
Gestalt / etc.) to the supported set. Concretely you want:

- The modality to appear in the Flutter "Wybierz nurt" sheet at create-
  patient-file time.
- The modality_code (e.g. `IFS`, `DBT`, `ACT`) to be writable to
  `patient_files.modality_code` via gRPC `CreatePatientFile`.
- The llm-worker to load the modality's system prompt from
  `modalities.therapist_ai_general_prompt` when generating reports for
  any session whose patient_file uses that code.

Not in scope: changing a modality's **code** after it's been used in
production (modality_code is immutable per the ADR — see
`docs/agents/06_flutter-therapist-app.md` guardrails). Edit the prompt
text via the same JSON-and-regenerate flow; that's safe.

---

## The four-step workflow

```
1. Drop a JSON spec into migrations/modality_prompts/
2. Run add_modality.py → emits .up.sql + .down.sql
3. Wire the Flutter UI (3 small files)
4. Commit + push → CI migrator picks it up on next backend deploy
```

### Step 1 — Write the JSON spec

Copy an existing spec as a template:

```bash
cd superwizor-backend/migrations/modality_prompts
cp gestalt.json ifs.json
```

Edit `ifs.json` (Internal Family Systems used as the example below):

```json
{
  "system_code":   "IFS",
  "display_name":  "Internal Family Systems",
  "modality_type": "therapy",
  "general_instructions": "Jesteś Superwizorem AI ...",
  "category_prompts": {
    "<section name 1>": "Cel: ...",
    "<section name 2>": "Cel: ...",
    "<section name 3>": "Cel: ..."
  }
}
```

**`modality_type`** must be `"therapy"` or `"coaching"`. Drives the
localized speaker-label vocabulary in transcripts:

- `therapy` → therapist label is "Terapeuta" (PL) / "Therapist" (EN),
  patient label is "Pacjent" (PL) / "Patient" (EN).
- `coaching` → "Trener" / "Coach" + "Klient" / "Client".

Almost every modality is therapy. Use `coaching` only for explicitly
non-clinical engagements (ICF-style coaching frameworks). See
`pkg/i18n/rolelabels` for the full localization table and migration
000026 for the underlying enum + backfill.

**Section names are per-modality** — there is no globally-fixed set.
UNIV/CBT/PSYCHO/Gestalt use "Podsumowanie sesji", "Wnikliwe obserwacje",
"Plan działania klienta", "Propozycje interwencji", "Wątki do pogłębienia",
"Wskazówki superwizyjne", "Wstępne hipotezy diagnostyczne". PPT uses
"Bilans Sesji", "Analiza w Modelu Równowagi", "Inspiracje Między Sesjami",
"Konflikty i Ukryte Potencjalności", "Pozytywna Konceptualizacja", etc.
Each modality picks the framing that fits its theoretical model. Names
surface verbatim as `## Section` headers in `report_markdown`.

**Do NOT add a `footer` field.** The script auto-builds the prompt
without one. Migration `000016` explicitly stripped three legacy bullets
(`Speaker Role Inference`, `HiTOP Dimensions`, `RAG Summary Chunk`) from
every existing modality because the LLM was emitting them as section
headers in `report_markdown` — a pre-call-1/call-2-split residue. Those
three values are now produced by call 1 as structured columns
(`speaker_role_inference`, `hitop_dimensions`, `rag_summary_chunk`); the
modality prompt's job is the prose report only. The validator rejects
the three bullets if they appear in `general_instructions` or any
`category_prompts` body — no accidental copy-paste from an old prompt.

Avoid:
- `(TL;DR)` and other English internet shorthand — write Polish prose
  matching the register of UNIV/CBT/PSYCHO/PPT.
- Section names longer than 100 chars (UI header truncation).
- Newlines inside section name keys.

### Step 2 — Generate the SQL migration

```bash
python3 migrations/add_modality.py migrations/modality_prompts/ifs.json
```

Output:

```
wrote migrations/000020_seed_ifs_modality.up.sql  (10003 bytes)
wrote migrations/000020_seed_ifs_modality.down.sql (493 bytes)

Next: wire 'IFS' into the Flutter UI ...
```

The generator:
- Auto-picks the next free 6-digit prefix (override with `--number 000023` if
  you want a stable filename in a batch with several modalities).
- Validates the JSON (see "Validation rules" below).
- Refuses to overwrite a `.up.sql` it didn't generate (clobber-guard).
- Prints a Flutter checklist you can copy-paste.

For a sanity preview without writing files: `--dry-run`.

### Step 3 — Wire the Flutter UI

The script prints exact line snippets. Five files:

**`flutter-app/superwizor/lib/constants/modalities.dart`** — add to `kModalities`:

```dart
Modality(code: 'IFS', displayKey: 'modality_ifs',
         icon: Icons.diversity_2_outlined),
```

Pick an `Icons.*_outlined` that resonates with the modality's central
metaphor. Gestalt uses `center_focus_strong_outlined` for figure/ground;
IFS could use `diversity_2_outlined` for parts/self; pick something that
won't collide visually with neighbouring modalities.

**`flutter-app/superwizor/lib/widgets/modality_sheet.dart`** — add to the
display-name switch:

```dart
case 'IFS': return t.modality_ifs;
```

**`flutter-app/superwizor/lib/l10n/app_pl.arb`** + **`app_en.arb`** — full
name + abbreviation:

```json
"modality_ifs":      "Internal Family Systems (IFS)",
"modality_abbr_ifs": "IFS",
```

**`docs/03_DATA_MODEL.md`** — refresh the `system_code` enum comment in the
modalities table block.

Then regenerate l10n and verify:

```bash
cd flutter-app/superwizor
flutter gen-l10n
flutter analyze
flutter test --timeout 30s
```

### Step 4 — Commit + push

```bash
git add superwizor-backend/migrations/modality_prompts/ifs.json \
        superwizor-backend/migrations/000020_seed_ifs_modality.{up,down}.sql \
        flutter-app/superwizor/lib/constants/modalities.dart \
        flutter-app/superwizor/lib/widgets/modality_sheet.dart \
        flutter-app/superwizor/lib/l10n/ \
        docs/03_DATA_MODEL.md
git commit -m "feat(modalities): add IFS modality"
git push origin main
```

The migrator service picks up the new `*.up.sql` on next CI deploy of
superwizor-backend and applies it automatically.

---

## Where things end up at runtime

```
modality_prompts/ifs.json   (source of truth, tracked in git)
        │
        ▼  python3 add_modality.py
000020_seed_ifs_modality.up.sql
        │
        ▼  CI migrator (next backend deploy)
PostgreSQL: modalities row (id, system_code='IFS', display_name='...',
                            therapist_ai_general_prompt=JSONB{'system': '...'},
                            is_supported=TRUE)
        │
        ▼
        ├──► clinical-svc.ListModalities → Flutter modality picker
        │    (also: hard-coded in lib/constants/modalities.dart; pickers
        │    today render from the local list, but the gRPC call is wired
        │    so the future "remote-toggle of is_supported" works without
        │    a client release)
        │
        └──► llm-worker reads `therapist_ai_general_prompt.system` at
             session-process time via models.GetModalityPrompt(modalityID)
             (services/ai-pipeline-svc/internal/models/db.go).
             That string becomes the system message for every report
             section's LLM call.
```

The system prompt itself is assembled from the JSON like this:

```
<general_instructions>

Wytyczne do poszczególnych sekcji raportu:
- Podsumowanie sesji: <category_prompts["Podsumowanie sesji"]>
- Wnikliwe obserwacje: <category_prompts["Wnikliwe obserwacje"]>
- Plan działania klienta: <category_prompts["Plan działania klienta"]>
- Propozycje interwencji: <category_prompts["Propozycje interwencji"]>
- Wątki do pogłębienia: <category_prompts["Wątki do pogłębienia"]>
- Wskazówki superwizyjne: <category_prompts["Wskazówki superwizyjne"]>
- Wstępne hipotezy diagnostyczne: <category_prompts["Wstępne hipotezy diagnostyczne"]>

- Speaker Role Inference: <footer.line1>
- HiTOP Dimensions:       <footer.line2>
- RAG Summary Chunk:      <footer.line3>
```

This is byte-identical in shape to the legacy modalities seeded by
`000008_modality_prompts_pl.up.sql` — the generator preserves the
canonical formatting (including the blank line before the footer).

---

## Validation rules

The script fails fast with a clear error message if the spec is wrong.
The rules:

| Field | Constraint | Why |
|---|---|---|
| `system_code` | Required, `^[A-Z][A-Z0-9_]{1,15}$` | Matches the immutable-after-create ADR; rejects lowercase / hyphens early. Stored in `patient_files.modality_code` so the regex also matches the proto's expected shape. |
| `display_name` | Required, non-empty string, ≤255 chars | Goes into the `modalities.display_name` column. ARB localisation owns the UI label; this is the fallback. |
| `general_instructions` | Required, non-empty string | The preamble — first thing the LLM sees. Empty here would give the worst possible report. |
| `category_prompts` | Required dict; **at least 1** entry; names are per-modality | Each modality picks its own section labels; names surface verbatim in `report_markdown` headers. Order is preserved from the JSON. |
| Each `category_prompts` key | Non-empty string, ≤100 chars, no newlines | Long names or newlines break the markdown header rendering in the report UI. |
| Each `category_prompts[name]` | Non-empty string | Prevents half-filled specs from shipping. |
| **Anywhere** in `general_instructions` or any category body | Must NOT contain `Speaker Role Inference`, `HiTOP Dimensions`, or `RAG Summary Chunk` | Migration `000016` explicitly stripped these from every existing modality (they made the LLM emit duplicate section headers; the values are now structured call-1 columns). The validator rejects on sight to keep the bug from coming back via copy-paste. |
| `footer` | Optional. If present, non-empty string. | **Recommended: omit entirely.** Only add a footer if you have a genuinely modality-specific closing instruction that belongs in the system prompt rather than the call-1 metadata pass. |

Test the validator yourself by feeding it a broken spec and seeing the
error message — it'll point at the exact field and offending value.

---

## Pitfalls

**1. SQL escaping.** Don't hand-edit the generated `.up.sql`. The Polish
prompts contain apostrophes, line breaks, and bullet lists; escaping
those inside a Postgres JSONB literal is bug-prone. Edit the JSON spec,
re-run the generator. Re-runs are idempotent — the clobber-guard lets
byte-identical regenerations pass through.

**2. JSON line breaks.** Inside the JSON, use `\n` for newlines (literal
escape sequence) — your editor doesn't need to insert real line breaks.
The generator converts properly when assembling the system prompt.

**3. Apostrophes in prompts.** Use single quotes inside the prompt text
freely. Both JSON parsing and SQL escaping handle them.

**4. The 7-category constraint.** If your modality "really" wants a
different section breakdown, that's a system-wide change to the report
schema, not a per-modality override. File it as a separate proposal —
the dispatcher and the UI cards are coupled to these 7 names.

**5. Modality code immutability.** Once `system_code` lands in
production and a `patient_files.modality_code` references it, you can
never rename it. Choose carefully. If you must rename, you're doing
data migration of every referencing row — out of scope for this script.

**6. `.gitignore`**. The backend `.gitignore` has `*.json` to keep
secrets out, but `migrations/modality_prompts/*.json` is whitelisted
as source-of-truth for the migration generator. Don't move the spec
files elsewhere without re-adding the whitelist entry.

**7. UPSERT semantics.** The generated migration uses
`ON CONFLICT (system_code) DO UPDATE`, so re-running it overwrites the
prompt. That's intentional for the iteration loop (tweak JSON → regen →
re-apply in staging). On prod, the migrator only applies new files —
to update an existing modality, generate a fresh migration with a new
6-digit prefix that re-INSERTs.

**8. Never edit the content of an already-applied migration.** The
migrator service tracks `schema_migrations.version` — once a number
is recorded, re-running the same version is a no-op. Editing the
`.up.sql` body in-place leaves the DB stuck on the original content
while git carries the corrected version. This actually happened on
2026-05-22: `000019_seed_gestalt_modality.up.sql` shipped with the
legacy footer bullets, the file was corrected in-place, and only an
explicit DB query showed staging was still buggy. **Fix:** add a
new numbered migration that re-UPSERTs the row. See
`000020_fix_gestalt_prompt.up.sql` for the canonical shape —
comment header explains the situation, body is the corrected
UPSERT, down migration is a no-op to avoid re-introducing the bug.

---

## Rolling back

Every generated `.up.sql` has a paired `.down.sql`:

```sql
DELETE FROM modalities WHERE system_code = 'IFS';
```

This deletes by code. It **will fail** if any `patient_files` reference
the modality_id of that row — intentional, per the immutability ADR.
If you need to roll back a modality that's already in use:

1. Decide where to migrate the existing `patient_files.modality_id`
   references (typically: re-point at UNIV).
2. Run the reassignment manually inside a transaction.
3. Then apply the `.down.sql`.

The down migration's header comment spells this out so the next person
hitting the FK failure isn't surprised.

---

## Source pointers

- Generator: [`superwizor-backend/migrations/add_modality.py`](../superwizor-backend/migrations/add_modality.py)
- Spec template: [`superwizor-backend/migrations/modality_prompts/gestalt.json`](../superwizor-backend/migrations/modality_prompts/gestalt.json)
- DB schema for modalities: `superwizor-backend/migrations/000005_clinical.up.sql`
- Legacy seed (UNIV/CBT/PSYCHO/PPT/ST/SYS/EFT/COACH): `000006_seed_modalities.up.sql` + `000008_modality_prompts_pl.up.sql`
- llm-worker prompt loader: `superwizor-backend/services/ai-pipeline-svc/internal/models/db.go::GetModalityPrompt`
- Flutter modality list: `flutter-app/superwizor/lib/constants/modalities.dart`
- Flutter modality picker: `flutter-app/superwizor/lib/widgets/modality_sheet.dart`
- gRPC contract: `superwizor-backend/proto/clinical/v1/clinical.proto` (`message Modality`, `rpc ListModalities`)
- Per-service refs: [`docs/agents/02_clinical-svc.md`](agents/02_clinical-svc.md), [`docs/agents/05_ai-pipeline-svc.md`](agents/05_ai-pipeline-svc.md), [`docs/agents/06_flutter-therapist-app.md`](agents/06_flutter-therapist-app.md)
