// llm-eval — offline matrix evaluator for the supervision-report LLM call.
//
// Why this exists:
//   Manual playground testing (Vertex AI Studio) is fine for a 1-off
//   "does X model handle Polish therapeutic content?" check, but it's
//   slow and unscientific when you want to compare 5 models × 2 output
//   formats × 10 transcripts. This tool runs that matrix in parallel,
//   captures input/output tokens + latency + raw response per cell,
//   computes an approximate cost from a hardcoded price table, and
//   emits a CSV summary plus the raw response files so you can read
//   them side-by-side.
//
// Use it before any model/format flip in production to validate that
// the cheaper option doesn't blow up quality. Pair the CSV with a
// human read of the raw outputs — token count alone doesn't tell you
// whether the report was faithful or hallucinated.
//
// Usage:
//
//   go run ./cmd/llm-eval \
//     -project superwizor-ai-25ecd \
//     -region europe-west4 \
//     -transcripts ./testdata/transcripts/*.txt \
//     -out ./tools/llm-eval-results
//
// Configure the model/format matrix in `defaultMatrix()` below — no
// flags for that, edit-as-needed since you'll iterate fast.

package main

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"google.golang.org/genai"
)

// PriceRow is per-million-token cost in USD, separate for input vs
// output. These are approximate Vertex AI list prices — verify at
// https://cloud.google.com/vertex-ai/generative-ai/pricing before
// quoting numbers externally. Used only for relative comparison in
// the summary table.
type PriceRow struct {
	InputPerM  float64
	OutputPerM float64
}

var priceTable = map[string]PriceRow{
	"gemini-3.1-pro":        {InputPerM: 1.25, OutputPerM: 5.00},
	"gemini-3.1-flash":      {InputPerM: 0.075, OutputPerM: 0.30},
	"gemini-3.1-flash-lite": {InputPerM: 0.0375, OutputPerM: 0.15},
	"gemini-2.5-pro":        {InputPerM: 1.25, OutputPerM: 5.00},
	"gemini-2.5-flash":      {InputPerM: 0.075, OutputPerM: 0.30},
}

// MatrixCell is one (model, format) combination to test. The full
// matrix is the cross-product of all cells with all input transcripts.
type MatrixCell struct {
	Label            string  // human-readable, e.g. "flash-lite-markdown"
	Model            string  // e.g. "gemini-3.1-flash-lite"
	Temperature      float32 // matches production: 0.1 for JSON, 0.3 for Markdown
	MaxOutputTokens  int32   // matches production caps
	ResponseMIMEType string  // "application/json" or "text/plain"
	// SystemPrompt is the prompt template with `{transcript}`,
	// `{reportLanguage}`, `{ragContext}`, and (for markdown cells
	// only) `{modalityPrompt}` placeholders. All substitutions
	// happen in runCell() so the dumped prompt files contain the
	// exact byte stream Vertex receives.
	SystemPrompt string
	// AttachSchema means the cell's response is constrained by the
	// report_schema.json `ResponseSchema` parameter — mirroring
	// production's metadata step. The schema file is copied into
	// promptsDir so it can be pasted into Vertex AI Studio's
	// "Response Schema" sidebar field.
	AttachSchema bool
}

// Modality system prompts — the contents of
// `modalities.therapist_ai_general_prompt[json]["system"]` for each
// system_code in the seeded modalities table (migration 000006).
// llm-worker loads these from PG at runtime via loadModalityPrompt();
// embedding them here keeps the eval offline and identical-by-byte
// for the seeded modalities (UNIV / CBT / PSYCHO).
//
// If you later seed more modalities or change the prompt text, sync
// this map by re-reading migration 000006_seed_modalities.up.sql.
var modalitySystemPrompts = map[string]string{
	"UNIV":   "You are a clinical supervision assistant analyzing therapy session transcripts. Provide observations grounded in evidence from the session, using neutral therapeutic language.",
	"CBT":    "You are a CBT-trained clinical supervision assistant. Analyze session transcripts through the lens of cognitive distortions, behavioral patterns, and the cognitive triangle (thoughts-feelings-behaviors). Reference Beck, Ellis, and Beck CBT frameworks.",
	"PSYCHO": "You are a psychodynamically-oriented clinical supervision assistant. Analyze session transcripts through the lens of unconscious dynamics, transference, defense mechanisms, and object relations. Reference Freud, Klein, and Kohut frameworks.",
}

// defaultMatrix mirrors the two-step prompt flow in production
// (llm-worker/main.go generateReport):
//
//	Step 1 (metadata, JSON):
//	  - Temperature 0.1, MaxOutputTokens 16384
//	  - ResponseMIMEType=application/json + ResponseSchema=report_schema.json
//	  - prompt = metadataPrompt template, no modality prefix
//
//	Step 2 (Markdown report, plain text):
//	  - Temperature 0.3, MaxOutputTokens 65536
//	  - ResponseMIMEType=text/plain, no schema
//	  - prompt = modalityPrompt + markdownPrompt template
//
// Both prompts are verbatim copies from llm-worker/main.go — keep
// them in sync when production changes. The eval template uses
// {transcript}, {reportLanguage}, {ragContext}, {modalityPrompt} as
// placeholders; substitution happens in runCell so dumped prompt
// files mirror what Vertex actually sees byte-for-byte.
func defaultMatrix() []MatrixCell {
	// ---------- Step 1: metadata JSON (verbatim from production) ----------
	const metadataPrompt = `
WAŻNE — KONTEKST DIARYZACJI I METADANYCH:
Transkrypt poniżej składa się z PONUMEROWANYCH chunków oddzielonych pauzami.
Chunki NIE mają jeszcze przypisanych mówców.

Twoje zadania:
1. Klastrowanie: Pogrupuj chunki w 2 (lub 3 dla par/rodzin) wirtualne grupy mówców.
2. Dedukcja ról: Określ rolę każdej grupy (therapist/patient/...).
3. Metadane: Wygeneruj krótki tytuł i streszczenie.

Wskazówki dot. klastrowania:
- Terapeuta: zadaje pytania, stosuje techniki, mówi krócej.
- Pacjent: opisuje odczucia, odpowiada, ma dłuższe wypowiedzi.

JĘZYK RAPORTU: {reportLanguage}

KONTEKST POPRZEDNICH SESJI:
{ragContext}

TRANSKRYPT BIEŻĄCEJ SESJI:
{transcript}

Wygeneruj TYLKO metadane zgodnie z podanym JSON Schema.

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
- title: max 100 znaków, jedno zdanie/fraza.
- summary_short: max 500 znaków, 2-3 zdania.
- evidence (cytaty z transkryptu): pojedynczy cytat, max 200 znaków.
- rag_summary_chunk: max 1500 znaków, kluczowe fakty dla pamięci długoterminowej.
- Pisz konkretami, NIE parafrazuj całych wypowiedzi.`

	// ---------- Step 2: Markdown report (verbatim from production) ----------
	// `{modalityPrompt}` placeholder is at position 0 — mirrors the
	// first %s in production's `reportPrompt := fmt.Sprintf("%s\n\n...", modalityPrompt, ...)`.
	const markdownPrompt = `{modalityPrompt}

JĘZYK RAPORTU: {reportLanguage}
Wygeneruj CAŁY raport w tym języku. Cytaty z transkryptu pozostaw w oryginale.
Sformatuj raport używając czytelnego Markdown (nagłówki ##, pogrubienia, cytaty).

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
- Raport powinien być WARTOŚCIOWY dla superwizora, NIE wielostronicowy.
- Każda sekcja: 2-5 zdań, max 1 akapit. Wyjątek: studium przypadku / hipotezy
  kliniczne — do 2 akapitów gdy uzasadnione.
- Cytaty z transkryptu: krótkie (1-2 zdania), tylko gdy bezpośrednio
  ilustrują obserwację. Nie cytuj dla samego cytowania.
- UNIKAJ powtórzeń między sekcjami — każda informacja w raporcie max raz.
- Pisz konkretami, używaj fachowego języka, ale nie nadużywaj żargonu.
- NIE rozwijaj sekcji o pola, których szablon nie wymaga.
- Pomijaj nagłówki sekcji jeśli ich treść byłaby pusta/spekulatywna.

KONTEKST POPRZEDNICH SESJI:
{ragContext}

TRANSKRYPT BIEŻĄCEJ SESJI:
{transcript}`

	models := []string{
		"gemini-3.1-pro",
		"gemini-3.1-flash",
		"gemini-3.1-flash-lite",
	}
	cells := make([]MatrixCell, 0, len(models)*2)
	for _, m := range models {
		cells = append(cells,
			MatrixCell{
				Label:            m + "-metadata-json",
				Model:            m,
				Temperature:      0.1,
				MaxOutputTokens:  16384,
				ResponseMIMEType: "application/json",
				SystemPrompt:     metadataPrompt,
				AttachSchema:     true,
			},
			MatrixCell{
				Label:            m + "-markdown-text",
				Model:            m,
				Temperature:      0.3,
				// Production uses 65536 for the Markdown step. Keep
				// parity so eval cost + truncation behaviour match.
				MaxOutputTokens:  65536,
				ResponseMIMEType: "text/plain",
				SystemPrompt:     markdownPrompt,
				AttachSchema:     false,
			},
		)
	}
	return cells
}

// CellResult is one row in the output CSV: a single (transcript,
// model, format) cell with everything we measured. Raw response is
// written to a separate .txt file under the run directory; the
// CSV row links to it via RawOutputPath.
type CellResult struct {
	Timestamp     time.Time
	TranscriptID  string
	CellLabel     string
	Model         string
	ResponseMIME  string
	InputTokens   int32
	OutputTokens  int32
	DurationMs    int64
	CostUSD       float64
	Success       bool
	Error         string
	RawOutputPath string
}

func main() {
	var (
		projectID   = flag.String("project", os.Getenv("GCP_PROJECT_ID"), "GCP project ID (defaults to $GCP_PROJECT_ID)")
		region      = flag.String("region", "europe-west4", "Vertex AI region")
		transcripts = flag.String("transcripts", "", "glob pattern for transcript .txt files (e.g. ./testdata/transcripts/*.txt)")
		outDir      = flag.String("out", "./llm-eval-results", "output directory for the run (timestamped subdir per run)")
		// promptsDir is a STABLE location (no timestamp) so the latest
		// substituted prompt for each (transcript, format) overwrites
		// the previous one. The intent: copy-paste the file body into
		// Vertex AI Studio for manual single-shot testing without
		// hunting through timestamped run directories.
		promptsDir  = flag.String("prompts-out", "./prompts", "directory to dump fully-substituted prompts + response schema for manual Vertex Studio testing (overwritten per run)")
		modality    = flag.String("modality", "UNIV", "modality system_code (UNIV|CBT|PSYCHO) — prepended to the Markdown report prompt, matching production loadModalityPrompt()")
		reportLang  = flag.String("report-language", "pl-PL", "value for {reportLanguage} placeholder (sessions.report_language in PG)")
		schemaPath  = flag.String("schema", "./cmd/llm-worker/schemas/report_schema.json", "path to the metadata-step response schema; copied into promptsDir for Vertex Studio")
		parallelism = flag.Int("parallel", 4, "max concurrent Vertex AI calls")
		dryRun      = flag.Bool("dry-run", false, "print the matrix without invoking Vertex")
	)
	flag.Parse()

	if *projectID == "" {
		fatal("project required (flag -project or $GCP_PROJECT_ID)")
	}
	if *transcripts == "" {
		fatal("transcripts glob required (flag -transcripts)")
	}

	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	// Resolve the modality system prompt up-front. Error loud if the
	// caller asks for one we don't have seeded — better than silently
	// substituting empty string and producing a misleading eval.
	modalityPromptText, ok := modalitySystemPrompts[*modality]
	if !ok {
		fatal(fmt.Sprintf("unknown modality %q — supported: UNIV, CBT, PSYCHO (matches migration 000006 seed)", *modality))
	}
	slog.Info("modality resolved",
		"system_code", *modality,
		"prompt_len_chars", len(modalityPromptText))

	// Load + cache the response schema. Two reasons:
	//  1. Production uses it as ResponseSchema for the metadata step,
	//     so attaching it via genai.Schema gives identical
	//     constrained-output behaviour in the eval.
	//  2. The same file is copied into promptsDir so it can be
	//     pasted into Vertex AI Studio's "Response Schema" panel
	//     when manually replicating the metadata step.
	schemaBytes, schemaErr := os.ReadFile(*schemaPath)
	if schemaErr != nil {
		// Non-fatal — we degrade to unconstrained JSON if the schema
		// can't be read. Log loud so the user knows the eval is
		// no longer faithful to production.
		slog.Warn("response schema not loaded — metadata cells will run UNCONSTRAINED",
			"path", *schemaPath, "err", schemaErr)
	}
	var schemaMap map[string]any
	if len(schemaBytes) > 0 {
		if err := json.Unmarshal(schemaBytes, &schemaMap); err != nil {
			slog.Warn("response schema unparseable — metadata cells will run UNCONSTRAINED",
				"path", *schemaPath, "err", err)
			schemaMap = nil
		}
	}

	files, err := filepath.Glob(*transcripts)
	if err != nil || len(files) == 0 {
		fatal(fmt.Sprintf("no transcripts matched %q: %v", *transcripts, err))
	}
	slog.Info("loaded transcripts", "count", len(files))

	matrix := defaultMatrix()
	slog.Info("matrix size", "cells", len(matrix), "total_runs", len(matrix)*len(files))

	if *dryRun {
		fmt.Println("=== matrix (dry run, not invoking Vertex) ===")
		for _, c := range matrix {
			fmt.Printf("  %-50s model=%s temp=%.1f maxTok=%d mime=%s\n",
				c.Label, c.Model, c.Temperature, c.MaxOutputTokens, c.ResponseMIMEType)
		}
		fmt.Println("\n=== transcripts ===")
		for _, f := range files {
			fmt.Printf("  %s\n", f)
		}
		return
	}

	// Stamp the run directory with a timestamp so multiple runs don't
	// clobber each other.
	runDir := filepath.Join(*outDir, time.Now().Format("2006-01-02-150405"))
	if err := os.MkdirAll(runDir, 0o755); err != nil {
		fatal(fmt.Sprintf("mkdir runDir: %v", err))
	}
	slog.Info("run directory", "path", runDir)

	// Stable prompts directory — overwritten each run, no timestamp.
	// Lets you grab the latest substituted prompt for copy-paste into
	// Vertex AI Studio without diving through run dirs.
	if err := os.MkdirAll(*promptsDir, 0o755); err != nil {
		fatal(fmt.Sprintf("mkdir promptsDir: %v", err))
	}
	slog.Info("prompts directory", "path", *promptsDir)

	// Drop the response schema next to the prompts so the manual
	// Vertex Studio workflow is "copy prompt + paste schema". File
	// is overwritten on every eval run.
	if len(schemaBytes) > 0 {
		if err := os.WriteFile(filepath.Join(*promptsDir, "response_schema.json"), schemaBytes, 0o644); err != nil {
			slog.Warn("copy schema to promptsDir failed", "err", err)
		}
	}

	ctx := context.Background()
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		Project:  *projectID,
		Location: *region,
		Backend:  genai.BackendVertexAI,
	})
	if err != nil {
		fatal(fmt.Sprintf("vertex client: %v", err))
	}

	// Read all transcripts up front; small files, cheap.
	transcriptsByID := make(map[string]string, len(files))
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			slog.Warn("read transcript failed, skipping", "file", f, "err", err)
			continue
		}
		id := strings.TrimSuffix(filepath.Base(f), filepath.Ext(f))
		transcriptsByID[id] = string(b)
	}

	// Bound concurrency so we don't hammer Vertex (it has per-region
	// QPS limits per project).
	sem := make(chan struct{}, *parallelism)
	var wg sync.WaitGroup
	resultsCh := make(chan CellResult, len(matrix)*len(transcriptsByID))

	subst := substitutions{
		ReportLanguage: *reportLang,
		RAGContext:     "", // production loadRAGContext stub returns "" in Faza 2
		ModalityPrompt: modalityPromptText,
		SchemaMap:      schemaMap,
	}

	for tID, tBody := range transcriptsByID {
		for _, cell := range matrix {
			wg.Add(1)
			sem <- struct{}{}
			go func(tID, tBody string, cell MatrixCell) {
				defer wg.Done()
				defer func() { <-sem }()
				r := runCell(ctx, client, runDir, *promptsDir, tID, tBody, cell, subst)
				// Surface the error string in the live log on
				// failure — debugging via the CSV after the fact
				// is tedious. On success keep the line concise.
				if r.Success {
					slog.Info("cell done",
						"transcript", tID,
						"cell", cell.Label,
						"input_tok", r.InputTokens,
						"output_tok", r.OutputTokens,
						"duration_ms", r.DurationMs,
						"cost_usd", fmt.Sprintf("%.4f", r.CostUSD))
				} else {
					slog.Error("cell FAILED",
						"transcript", tID,
						"cell", cell.Label,
						"duration_ms", r.DurationMs,
						"error", r.Error)
				}
				resultsCh <- r
			}(tID, tBody, cell)
		}
	}
	wg.Wait()
	close(resultsCh)

	// Drain into a slice + write CSV.
	results := make([]CellResult, 0, len(matrix)*len(transcriptsByID))
	for r := range resultsCh {
		results = append(results, r)
	}
	if err := writeCSV(runDir, results); err != nil {
		fatal(fmt.Sprintf("write CSV: %v", err))
	}

	printSummary(results)
}

// substitutions bundles the runtime values that get pasted into the
// SystemPrompt template placeholders. Mirrors production's:
//
//	reportPrompt := fmt.Sprintf(template, modalityPrompt, reportLanguage, ragContext, transcriptText)
//
// We pass it as a struct (rather than four positional args) because
// runCell already has a long parameter list and this is the kind of
// data clump that's begging for a record.
type substitutions struct {
	ReportLanguage string
	RAGContext     string
	ModalityPrompt string
	// SchemaMap is the parsed report_schema.json — used to populate
	// vertexai.GenerationConfig.ResponseSchema for cells that have
	// AttachSchema=true. Nil means no schema constraint.
	SchemaMap map[string]any
}

// applySubstitutions does the four production placeholder replacements
// in a single pass. Order doesn't matter because the placeholders
// don't appear inside each other's content.
func applySubstitutions(template string, s substitutions, transcript string) string {
	out := template
	out = strings.ReplaceAll(out, "{modalityPrompt}", s.ModalityPrompt)
	out = strings.ReplaceAll(out, "{reportLanguage}", s.ReportLanguage)
	out = strings.ReplaceAll(out, "{ragContext}", s.RAGContext)
	out = strings.ReplaceAll(out, "{transcript}", transcript)
	return out
}

func runCell(ctx context.Context, client *genai.Client, runDir, promptsDir, tID, tBody string, cell MatrixCell, subst substitutions) CellResult {
	start := time.Now()
	r := CellResult{
		Timestamp:    start,
		TranscriptID: tID,
		CellLabel:    cell.Label,
		Model:        cell.Model,
		ResponseMIME: cell.ResponseMIMEType,
	}

	cfg := &genai.GenerateContentConfig{
		Temperature:      genai.Ptr[float32](cell.Temperature),
		TopP:             genai.Ptr[float32](0.95),
		MaxOutputTokens:  cell.MaxOutputTokens,
		ResponseMIMEType: cell.ResponseMIMEType,
	}
	// Attach the response schema for metadata cells — mirrors
	// production's `ResponseSchema: schemaToVertexSchema(schema)`
	// on the metadata step. Markdown cells leave it nil (production
	// also nils it for the text/plain step).
	if cell.AttachSchema && subst.SchemaMap != nil {
		cfg.ResponseSchema = schemaToVertexSchema(subst.SchemaMap)
	}

	prompt := applySubstitutions(cell.SystemPrompt, subst, tBody)

	// Dump the substituted prompt to the stable directory so it can
	// be copy-pasted into Vertex AI Studio for single-shot manual
	// testing. We key by (transcriptID, format) — not by full cell
	// label — because the prompt depends only on those two; all
	// three models for a given format would otherwise overwrite each
	// other with identical content.
	formatSuffix := "markdown"
	if cell.ResponseMIMEType == "application/json" {
		formatSuffix = "metadata"
	}
	promptPath := filepath.Join(promptsDir, fmt.Sprintf("%s__%s.txt", tID, formatSuffix))
	if err := os.WriteFile(promptPath, []byte(prompt), 0o644); err != nil {
		// Non-fatal — eval still runs, we just lose the manual-test artefact.
		slog.Warn("write prompt file failed", "path", promptPath, "err", err)
	}

	resp, err := client.Models.GenerateContent(ctx, cell.Model, genai.Text(prompt), cfg)
	r.DurationMs = time.Since(start).Milliseconds()

	if err != nil {
		r.Success = false
		r.Error = err.Error()
		return r
	}
	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		r.Success = false
		r.Error = "no candidates returned"
		return r
	}

	var out strings.Builder
	for _, part := range resp.Candidates[0].Content.Parts {
		if part.Text != "" {
			out.WriteString(part.Text)
		}
	}

	if resp.UsageMetadata != nil {
		r.InputTokens = resp.UsageMetadata.PromptTokenCount
		r.OutputTokens = resp.UsageMetadata.CandidatesTokenCount
	}
	if p, ok := priceTable[cell.Model]; ok {
		r.CostUSD = float64(r.InputTokens)/1_000_000*p.InputPerM +
			float64(r.OutputTokens)/1_000_000*p.OutputPerM
	}

	// Write the raw output to a file so the human reviewer can read it.
	// Sanitize the filename — labels contain colons that play badly with
	// some shells. (We picked dashes already, but defence in depth.)
	safeLabel := strings.NewReplacer(":", "-", "/", "-", " ", "_").Replace(cell.Label)
	ext := ".txt"
	if cell.ResponseMIMEType == "application/json" {
		ext = ".json"
	}
	outPath := filepath.Join(runDir, fmt.Sprintf("%s__%s%s", tID, safeLabel, ext))
	_ = os.WriteFile(outPath, []byte(out.String()), 0o644)
	r.RawOutputPath = outPath
	r.Success = true
	return r
}

func writeCSV(runDir string, results []CellResult) error {
	f, err := os.Create(filepath.Join(runDir, "summary.csv"))
	if err != nil {
		return err
	}
	defer f.Close()
	w := csv.NewWriter(f)
	defer w.Flush()
	_ = w.Write([]string{
		"timestamp", "transcript_id", "cell_label", "model", "response_mime",
		"input_tokens", "output_tokens", "duration_ms", "cost_usd",
		"success", "error", "raw_output_path",
	})
	for _, r := range results {
		_ = w.Write([]string{
			r.Timestamp.Format(time.RFC3339),
			r.TranscriptID,
			r.CellLabel,
			r.Model,
			r.ResponseMIME,
			fmt.Sprintf("%d", r.InputTokens),
			fmt.Sprintf("%d", r.OutputTokens),
			fmt.Sprintf("%d", r.DurationMs),
			fmt.Sprintf("%.6f", r.CostUSD),
			fmt.Sprintf("%t", r.Success),
			truncate(r.Error, 200),
			r.RawOutputPath,
		})
	}
	return nil
}

func printSummary(results []CellResult) {
	type aggKey struct {
		Model, MIME string
	}
	type agg struct {
		Runs        int
		Failures    int
		TotalInput  int32
		TotalOutput int32
		TotalMs     int64
		TotalCost   float64
	}
	by := map[aggKey]*agg{}
	for _, r := range results {
		k := aggKey{r.Model, r.ResponseMIME}
		a, ok := by[k]
		if !ok {
			a = &agg{}
			by[k] = a
		}
		a.Runs++
		if !r.Success {
			a.Failures++
		}
		a.TotalInput += r.InputTokens
		a.TotalOutput += r.OutputTokens
		a.TotalMs += r.DurationMs
		a.TotalCost += r.CostUSD
	}

	fmt.Println("\n=== Aggregate per (model, format) ===")
	fmt.Printf("%-25s  %-18s  %5s  %4s  %10s  %10s  %10s  %12s\n",
		"model", "mime", "runs", "fail", "avg_in_tok", "avg_out_tok", "avg_ms", "avg_cost_usd")
	for k, a := range by {
		avgIn := float64(a.TotalInput) / float64(a.Runs)
		avgOut := float64(a.TotalOutput) / float64(a.Runs)
		avgMs := float64(a.TotalMs) / float64(a.Runs)
		avgCost := a.TotalCost / float64(a.Runs)
		fmt.Printf("%-25s  %-18s  %5d  %4d  %10.0f  %10.0f  %10.0f  %12.6f\n",
			k.Model, k.MIME, a.Runs, a.Failures, avgIn, avgOut, avgMs, avgCost)
	}

	// Emit JSON too for downstream tooling.
	js, _ := json.MarshalIndent(by, "", "  ")
	_ = os.WriteFile(filepath.Join(filepath.Dir(results[0].RawOutputPath), "summary.json"), js, 0o644)
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, "fatal:", msg)
	os.Exit(2)
}

// ---------- response-schema → genai.Schema conversion ----------
//
// Copied verbatim from llm-worker/main.go (functions
// `mapSchemaType` and `schemaToVertexSchema`). Duplicated rather
// than imported because llm-eval is dev-only tooling and must not
// pin a `replace` directive or share an internal package with the
// production binary.
//
// Keep in sync when llm-worker adds support for new JSON Schema
// keywords (e.g. minLength, maxItems) — Vertex AI's structured
// output respects those, so propagating them through the converter
// is what enforces brevity at the model level.

func mapSchemaType(t string) genai.Type {
	switch t {
	case "string":
		return genai.TypeString
	case "number":
		return genai.TypeNumber
	case "integer":
		return genai.TypeInteger
	case "boolean":
		return genai.TypeBoolean
	case "array":
		return genai.TypeArray
	case "object":
		return genai.TypeObject
	default:
		return genai.TypeUnspecified
	}
}

func schemaToVertexSchema(s map[string]any) *genai.Schema {
	if s == nil {
		return nil
	}
	vs := &genai.Schema{}

	if t, ok := s["type"].(string); ok {
		vs.Type = mapSchemaType(t)
	}
	if d, ok := s["description"].(string); ok {
		vs.Description = d
	}
	if e, ok := s["enum"].([]any); ok {
		for _, val := range e {
			if str, ok := val.(string); ok {
				vs.Enum = append(vs.Enum, str)
			}
		}
	}
	if p, ok := s["properties"].(map[string]any); ok {
		vs.Properties = make(map[string]*genai.Schema)
		for k, v := range p {
			if vMap, ok := v.(map[string]any); ok {
				vs.Properties[k] = schemaToVertexSchema(vMap)
			}
		}
	}
	if i, ok := s["items"].(map[string]any); ok {
		vs.Items = schemaToVertexSchema(i)
	}
	if req, ok := s["required"].([]any); ok {
		for _, val := range req {
			if str, ok := val.(string); ok {
				vs.Required = append(vs.Required, str)
			}
		}
	}

	return vs
}
