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

	vertexai "cloud.google.com/go/vertexai/genai"
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
	// SystemPrompt is the full prompt template. {transcript} is
	// substituted with the test transcript body. Keep this close to
	// what production sends so the eval reflects real behaviour.
	SystemPrompt string
}

// defaultMatrix mirrors the two-step prompt flow in production
// (llm-worker/main.go) — metadata JSON step and Markdown report
// step — across the model lineup we care about. Edit freely when
// you want to ablate one knob (e.g. temperature, prompt wording).
func defaultMatrix() []MatrixCell {
	const metadataPrompt = `WAŻNE — KONTEKST DIARYZACJI I METADANYCH:
Transkrypt poniżej składa się z PONUMEROWANYCH chunków oddzielonych pauzami.
Chunki NIE mają jeszcze przypisanych mówców.

Twoje zadania:
1. Klastrowanie: Pogrupuj chunki w 2 (lub 3 dla par/rodzin) wirtualne grupy mówców.
2. Dedukcja ról: Określ rolę każdej grupy (therapist/patient/...).
3. Metadane: Wygeneruj krótki tytuł i streszczenie.

JĘZYK RAPORTU: pl-PL

TRANSKRYPT BIEŻĄCEJ SESJI:
{transcript}

Wygeneruj TYLKO metadane jako JSON z polami: title (string, <=100 znaków),
summary_short (string, <=500 znaków), speaker_groups (array of {role, chunk_indices, confidence, evidence}).`

	const markdownPrompt = `Jesteś asystentem superwizora klinicznego analizującym transkrypt sesji
terapeutycznej. Pisz w stylu klinicznym, używaj fachowego języka.

JĘZYK RAPORTU: pl-PL
Wygeneruj raport w czytelnym Markdown (nagłówki ##, pogrubienia, cytaty).

ZASADY ZWIĘZŁOŚCI:
- Każda sekcja: 2-5 zdań, max 1 akapit.
- Cytaty: krótkie, tylko gdy ilustrują obserwację.
- UNIKAJ powtórzeń między sekcjami.
- Pomijaj nagłówki sekcji jeśli treść byłaby pusta.

TRANSKRYPT BIEŻĄCEJ SESJI:
{transcript}

Wygeneruj raport o sekcjach: główne tematy, obserwacje przymierza,
interwencje terapeuty, ocena ryzyka, rekomendacje na następną sesję.`

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
			},
			MatrixCell{
				Label:            m + "-markdown-text",
				Model:            m,
				Temperature:      0.3,
				MaxOutputTokens:  16384,
				ResponseMIMEType: "text/plain",
				SystemPrompt:     markdownPrompt,
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
		projectID     = flag.String("project", os.Getenv("GCP_PROJECT_ID"), "GCP project ID (defaults to $GCP_PROJECT_ID)")
		region        = flag.String("region", "europe-west4", "Vertex AI region")
		transcripts   = flag.String("transcripts", "", "glob pattern for transcript .txt files (e.g. ./testdata/transcripts/*.txt)")
		outDir        = flag.String("out", "./llm-eval-results", "output directory for the run")
		parallelism   = flag.Int("parallel", 4, "max concurrent Vertex AI calls")
		dryRun        = flag.Bool("dry-run", false, "print the matrix without invoking Vertex")
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

	ctx := context.Background()
	client, err := vertexai.NewClient(ctx, *projectID, *region)
	if err != nil {
		fatal(fmt.Sprintf("vertex client: %v", err))
	}
	defer client.Close()

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

	for tID, tBody := range transcriptsByID {
		for _, cell := range matrix {
			wg.Add(1)
			sem <- struct{}{}
			go func(tID, tBody string, cell MatrixCell) {
				defer wg.Done()
				defer func() { <-sem }()
				r := runCell(ctx, client, runDir, tID, tBody, cell)
				slog.Info("cell done",
					"transcript", tID,
					"cell", cell.Label,
					"input_tok", r.InputTokens,
					"output_tok", r.OutputTokens,
					"duration_ms", r.DurationMs,
					"cost_usd", fmt.Sprintf("%.4f", r.CostUSD),
					"success", r.Success)
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

func runCell(ctx context.Context, client *vertexai.Client, runDir, tID, tBody string, cell MatrixCell) CellResult {
	start := time.Now()
	r := CellResult{
		Timestamp:    start,
		TranscriptID: tID,
		CellLabel:    cell.Label,
		Model:        cell.Model,
		ResponseMIME: cell.ResponseMIMEType,
	}

	model := client.GenerativeModel(cell.Model)
	model.GenerationConfig = vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](cell.Temperature),
		TopP:             vertexai.Ptr[float32](0.95),
		MaxOutputTokens:  vertexai.Ptr[int32](cell.MaxOutputTokens),
		ResponseMIMEType: cell.ResponseMIMEType,
	}

	prompt := strings.ReplaceAll(cell.SystemPrompt, "{transcript}", tBody)

	resp, err := model.GenerateContent(ctx, vertexai.Text(prompt))
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
		if t, ok := part.(vertexai.Text); ok {
			out.WriteString(string(t))
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
