# llm-eval

Offline matrix evaluator for the supervision-report LLM call. Runs a
fixed set of transcripts through a configurable matrix of (model,
output-format) combinations, captures tokens / latency / cost / raw
output per cell, and emits a CSV + JSON summary you can sort / pivot.

Designed to validate model + format flips before pushing them to
production. Pair the CSV with a human read of the raw outputs —
token count alone doesn't tell you whether the report was faithful
or hallucinated.

## Quick start

```bash
# 1. Drop one or more transcripts into ./testdata/transcripts/
#    as plain .txt files. Each filename (sans extension) becomes
#    the transcript_id in the results.
mkdir -p ./testdata/transcripts
cp ~/Downloads/session-865b7557.txt ./testdata/transcripts/865b7557.txt

# 2. (Optional) Edit the matrix in main.go: defaultMatrix(). The
#    default covers gemini-3.1-{pro,flash,flash-lite} × {json, markdown}.

# 3. Dry-run to confirm the matrix:
go run ./cmd/llm-eval \
  -project superwizor-ai-25ecd \
  -transcripts "./testdata/transcripts/*.txt" \
  -dry-run

# 4. Real run (parallel, bounded at 4 concurrent Vertex calls):
go run ./cmd/llm-eval \
  -project superwizor-ai-25ecd \
  -transcripts "./testdata/transcripts/*.txt" \
  -out ./llm-eval-results
```

Cost on the default 3-model × 2-format × 1-transcript matrix: ~$0.10
(Pro dominates; Flash and Flash-lite are pennies).

## Output layout

```
llm-eval-results/
└── 2026-05-11-145320/                   # one dir per run, timestamped
    ├── summary.csv                       # one row per (transcript, cell)
    ├── summary.json                      # aggregate per (model, mime)
    ├── 865b7557__gemini-3.1-pro-metadata-json.json
    ├── 865b7557__gemini-3.1-pro-markdown-text.txt
    ├── 865b7557__gemini-3.1-flash-metadata-json.json
    ├── 865b7557__gemini-3.1-flash-markdown-text.txt
    ├── 865b7557__gemini-3.1-flash-lite-metadata-json.json
    └── 865b7557__gemini-3.1-flash-lite-markdown-text.txt
```

`summary.csv` columns:

| column          | meaning |
|-----------------|---------|
| `timestamp`     | RFC3339 of when the cell started |
| `transcript_id` | filename minus extension |
| `cell_label`    | e.g. `gemini-3.1-flash-markdown-text` |
| `model`         | model id passed to Vertex |
| `response_mime` | `application/json` or `text/plain` |
| `input_tokens`  | `usage_metadata.prompt_token_count` |
| `output_tokens` | `usage_metadata.candidates_token_count` |
| `duration_ms`   | wall clock for the GenerateContent call |
| `cost_usd`      | derived from a hardcoded price table — verify against [Vertex pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing) before quoting externally |
| `success`       | `true` / `false` |
| `error`         | first 200 chars of error message, if any |
| `raw_output_path` | absolute path to the saved response file |

Console at end of run also prints an aggregate table per
`(model, mime)` so you can eyeball "Flash is 17× cheaper than Pro for
the same task" without opening the CSV.

## What to evaluate beyond tokens

The CSV gives you the quantitative side. For each `raw_output_path`,
open the file and judge:

1. **Faithfulness** — are observations grounded in the transcript or
   hallucinated? Read with the transcript next to you.
2. **Specificity** — vague generalities ("the patient seemed anxious")
   vs. concrete evidence ("at chunk 7 patient said 'I can't sleep
   before sessions'").
3. **Schema obedience (JSON only)** — `speaker_role_inference.speaker_groups`
   correctly populated? Title under 100 chars? Or did it freelance?
4. **Polish quality** — idiomatic vs. Anglicized clinical phrasing.
   Flash-lite occasionally drops on niche terms.
5. **Length discipline** — is Markdown a single readable page or wall
   of text?

Don't trust automated metrics for "is the report good." There's no
ground truth, and superficial similarity (e.g. token-overlap
between Pro and Flash outputs) doesn't measure clinical usefulness.

## Editing the matrix

`defaultMatrix()` in `main.go` is the source of truth. Common edits:

- **Add a model**: append to the `models` slice. Add a price row
  in `priceTable` if it's new.
- **Change a prompt**: edit `metadataPrompt` or `markdownPrompt`
  constants. Keep `{transcript}` as the substitution token.
- **Ablate a single knob**: copy a cell, change one param. E.g. to
  test temperature 0.0 vs 0.3 on the same model:
  ```go
  cells = append(cells,
    MatrixCell{Label: "flash-temp-0.0", Model: "gemini-3.1-flash", Temperature: 0.0, ...},
    MatrixCell{Label: "flash-temp-0.3", Model: "gemini-3.1-flash", Temperature: 0.3, ...},
  )
  ```

## When to use this vs. Vertex AI Studio

| Use Studio when... | Use llm-eval when... |
|---|---|
| Eyeballing one or two prompts | Comparing ≥3 models × ≥2 formats × ≥3 transcripts |
| Iterating on prompt wording | Sealing a decision with measurable numbers |
| Exploring a new feature (audio in, etc.) | Validating a cost cut before production deploy |

Studio is faster for exploration; llm-eval is faster for the matrix.
