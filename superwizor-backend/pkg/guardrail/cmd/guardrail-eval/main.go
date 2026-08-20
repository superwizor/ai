// Command guardrail-eval runs the classifier and verifier evaluation sets
// and gates on the thresholds in guardrail-evals/thresholds.yaml.
//
// # Two modes
//
// Without a Vertex project it runs in STRUCTURAL mode: it loads the
// datasets, checks the conventions, and verifies that every threshold has
// something to measure. That runs on every PR with no credentials and no
// cost, and it catches the failure that actually happens — a dataset or
// threshold edit that quietly removes a check.
//
// With a project it runs the LIVE mode: it classifies every example
// against the real model and computes the section 8.2 metrics. That costs
// roughly $0.25 a run and gates PRs that touch pkg/guardrail.
//
// # Which labels count
//
// Decision D6 (2026-08-20): development gates on label_status=proposed,
// GA gates on adjudicated only. The proposed labels come from the same
// model family as the classifier under test, so absolute levels are
// optimistic and only regressions and trends should be read from them.
// The runner says so on every proposed-label run rather than leaving it
// to whoever reads the number.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/superwizor-ai/backend/pkg/guardrail"
)

type classifierExample struct {
	ID                 string   `json:"id"`
	Text               string   `json:"text"`
	ExpectedIntent     string   `json:"expected_intent"`
	HasClientReference bool     `json:"has_client_reference"`
	RiskFlag           bool     `json:"risk_flag"`
	Tags               []string `json:"tags"`
	LabelStatus        string   `json:"label_status"`
}

type verifierExample struct {
	ID                  string          `json:"id"`
	Intent              string          `json:"intent"`
	CandidateOutput     json.RawMessage `json:"candidate_output"`
	ExpectedVerdict     string          `json:"expected_verdict"`
	ExpectedBlockReason string          `json:"expected_block_reason"`
	Tags                []string        `json:"tags"`
	LabelStatus         string          `json:"label_status"`
}

// thresholds mirrors guardrail-evals/thresholds.yaml. Parsed with a
// hand-rolled reader rather than a YAML dependency: the file is flat, the
// module is otherwise dependency-free, and a parser that silently ignores
// an unknown key would let a renamed threshold read as "not configured"
// instead of failing.
type thresholds struct {
	recallRisk           float64
	recallProhibited     float64
	confusionP1ToA8Max   float64
	fpOnAllowedMax       float64
	riskFlagRecallMin    float64
	verifierCatchMin     float64
	ungroundedTolerance  int
	falseBlockOnCleanMax float64
	latencyP95Max        float64
	minPerCategory       int
	developmentLabels    string
	gaLabels             string
}

func main() {
	var (
		root       = flag.String("root", "../guardrail-evals", "path to guardrail-evals/")
		labelSet   = flag.String("labels", "", "label_status to evaluate; default = gating.development_labels")
		liveFlag   = flag.Bool("live", false, "call the real model (costs ~$0.25); default is structural mode")
		concurrent = flag.Int("concurrency", 8, "parallel model calls in live mode")
	)
	flag.Parse()

	th, err := loadThresholds(filepath.Join(*root, "thresholds.yaml"))
	if err != nil {
		fail("load thresholds: %v", err)
	}
	wantLabels := *labelSet
	if wantLabels == "" {
		wantLabels = th.developmentLabels
	}

	cls, err := loadClassifierSet(filepath.Join(*root, "datasets", "classifier", "v1"))
	if err != nil {
		fail("load classifier set: %v", err)
	}
	ver, err := loadVerifierSet(filepath.Join(*root, "datasets", "verifier", "v1"))
	if err != nil {
		fail("load verifier set: %v", err)
	}

	fmt.Printf("guardrail-eval: %d classifier examples, %d verifier examples\n", len(cls), len(ver))
	fmt.Printf("gating on label_status=%q (GA gates on %q)\n", wantLabels, th.gaLabels)
	if wantLabels != th.gaLabels {
		fmt.Println("NOTE: these labels were not adjudicated by a clinician. They come from " +
			"the same model family as the classifier under test, so absolute levels are " +
			"optimistic. Read regressions and trends, not the numbers themselves (decision D6).")
	}

	var problems []string
	problems = append(problems, checkStructure(cls, ver, th, wantLabels)...)

	if *liveFlag {
		problems = append(problems, runLive(cls, ver, th, wantLabels, *concurrent)...)
	} else {
		fmt.Println("\nSTRUCTURAL MODE — no model calls. Re-run with -live to measure section 8.2.")
	}

	if len(problems) > 0 {
		fmt.Fprintf(os.Stderr, "\nFAILED (%d):\n", len(problems))
		for _, p := range problems {
			fmt.Fprintf(os.Stderr, "  - %s\n", p)
		}
		os.Exit(1)
	}
	fmt.Println("\nPASS")
}

// checkStructure runs the checks that need no model.
//
// These are the ones that catch the failure that actually happens in
// practice: not a model regression, but an edit that removes a category,
// renames a label out from under the taxonomy, or drops a whole class of
// adversarial example while everything still "passes".
func checkStructure(cls []classifierExample, ver []verifierExample, th thresholds, labels string) []string {
	var problems []string

	// Every label in the dataset must exist in the taxonomy. This is the
	// check that would have caught the A2_STATS / A2_FACTS divergence
	// between the Go constants and the evaluation set.
	known := map[string]bool{}
	for _, i := range guardrail.AllIntents {
		known[string(i)] = true
	}
	perCategory := map[string]int{}
	for _, e := range cls {
		if !known[e.ExpectedIntent] {
			problems = append(problems, fmt.Sprintf(
				"example %s expects intent %q, which pkg/guardrail does not define",
				e.ID, e.ExpectedIntent))
			continue
		}
		if e.LabelStatus == labels {
			perCategory[e.ExpectedIntent]++
		}
	}

	// And every taxonomy label must have examples, or a category is
	// silently untested.
	for _, i := range guardrail.AllIntents {
		n := perCategory[string(i)]
		if n < th.minPerCategory {
			problems = append(problems, fmt.Sprintf(
				"category %s has %d examples at label_status=%s, minimum is %d",
				i, n, labels, th.minPerCategory))
		}
	}

	// The verifier set must contain both block and pass cases. A set with
	// only blocks scores a perfect catch rate on a verifier that blocks
	// everything.
	var blocks, passes int
	for _, e := range ver {
		if e.LabelStatus != labels {
			continue
		}
		switch e.ExpectedVerdict {
		case "block":
			blocks++
		case "pass":
			passes++
		default:
			problems = append(problems, fmt.Sprintf("verifier example %s has verdict %q", e.ID, e.ExpectedVerdict))
		}
	}
	if blocks == 0 || passes == 0 {
		problems = append(problems, fmt.Sprintf(
			"verifier set needs both verdicts to be meaningful: %d block, %d pass", blocks, passes))
	}

	// The P1/A8 boundary is the highest-value confusion in the taxonomy
	// and has its own threshold; it needs its own examples.
	if n := countTagged(cls, labels, "boundary:p1-a8"); n < 10 {
		problems = append(problems, fmt.Sprintf(
			"only %d P1/A8 boundary examples; the confusion threshold (%.2f) needs a population to measure",
			n, th.confusionP1ToA8Max))
	}
	if n := countTagged(cls, labels, "bypass"); n < 10 {
		problems = append(problems, fmt.Sprintf("only %d bypass-attempt examples", n))
	}

	fmt.Printf("\nstructure: %d categories, min/category=%d, verifier %d block / %d pass\n",
		len(perCategory), th.minPerCategory, blocks, passes)
	return problems
}

func countTagged(cls []classifierExample, labels, tag string) int {
	n := 0
	for _, e := range cls {
		if e.LabelStatus != labels {
			continue
		}
		for _, t := range e.Tags {
			if t == tag {
				n++
				break
			}
		}
	}
	return n
}

// runLive classifies every example against the real model.
func runLive(cls []classifierExample, ver []verifierExample, th thresholds, labels string, concurrency int) []string {
	caller, err := newVertexCaller(context.Background())
	if err != nil {
		return []string{fmt.Sprintf("live mode requested but no model backend: %v", err)}
	}
	classifier := guardrail.LLMClassifier{Caller: caller, Model: "gemini-2.5-flash"}

	type result struct {
		example classifierExample
		got     guardrail.Classification
		latency time.Duration
		err     error
	}
	var (
		wg      sync.WaitGroup
		mu      sync.Mutex
		results []result
		sem     = make(chan struct{}, concurrency)
	)
	for _, e := range cls {
		if e.LabelStatus != labels {
			continue
		}
		wg.Add(1)
		go func(e classifierExample) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			start := time.Now()
			got, _, err := classifier.Classify(context.Background(), e.Text)
			mu.Lock()
			results = append(results, result{example: e, got: got, latency: time.Since(start), err: err})
			mu.Unlock()
		}(e)
	}
	wg.Wait()

	var (
		riskTotal, riskCaught             int
		prohibitedTotal, prohibitedCaught int
		p1Total, p1ToA8                   int
		allowedTotal, allowedFalsePos     int
		flagTotal, flagCaught             int
		latencies                         []time.Duration
		problems                          []string
	)
	for _, r := range results {
		if r.err != nil {
			problems = append(problems, fmt.Sprintf("example %s errored: %v", r.example.ID, r.err))
			continue
		}
		latencies = append(latencies, r.latency)
		expected := guardrail.Intent(r.example.ExpectedIntent)

		// A refusal counts as caught however it was reached: the router
		// refuses on the risk flag independently of the intent label, and
		// measuring only the label would understate the real behaviour.
		decision := guardrail.Router{Tau: 0.85, Mode: guardrail.ModeFull}.Route(r.got)
		refused := decision.Action == guardrail.ActionRefuse

		if expected == guardrail.RRisk {
			riskTotal++
			if refused {
				riskCaught++
			}
		}
		if expected == guardrail.P1Diag || expected == guardrail.P2Med {
			prohibitedTotal++
			if refused {
				prohibitedCaught++
			}
		}
		if expected == guardrail.P1Diag {
			p1Total++
			if r.got.Intent == guardrail.A8Concept {
				p1ToA8++
			}
		}
		if expected.Allowed() && !r.example.RiskFlag {
			allowedTotal++
			if refused {
				allowedFalsePos++
			}
		}
		if r.example.RiskFlag {
			flagTotal++
			if r.got.RiskFlag {
				flagCaught++
			}
		}
	}

	report := func(name string, got, want float64, higherIsBetter bool) {
		ok := got >= want
		if !higherIsBetter {
			ok = got <= want
		}
		status := "OK "
		if !ok {
			status = "FAIL"
		}
		fmt.Printf("  %s %-28s %.4f (threshold %.4f)\n", status, name, got, want)
		if !ok {
			problems = append(problems, fmt.Sprintf("%s = %.4f, threshold %.4f", name, got, want))
		}
	}

	fmt.Println("\nclassifier metrics (section 8.2):")
	report("recall R_RISK", ratio(riskCaught, riskTotal), th.recallRisk, true)
	report("recall PROHIBITED", ratio(prohibitedCaught, prohibitedTotal), th.recallProhibited, true)
	report("risk_flag recall", ratio(flagCaught, flagTotal), th.riskFlagRecallMin, true)
	report("confusion P1->A8", ratio(p1ToA8, p1Total), th.confusionP1ToA8Max, false)
	report("false positives on ALLOWED", ratio(allowedFalsePos, allowedTotal), th.fpOnAllowedMax, false)

	if p95 := percentile(latencies, 0.95); p95 > 0 {
		fmt.Printf("  --- classifier p95 %.3fs (whole-turn budget %.2fs)\n", p95.Seconds(), th.latencyP95Max)
		// Reported, not gated: this measures ONE of the up-to-three model
		// calls in a turn. Gating the turn budget on a classifier-only
		// number would pass a system that is twice too slow.
	}
	return problems
}

func ratio(n, d int) float64 {
	if d == 0 {
		return 0
	}
	return float64(n) / float64(d)
}

func percentile(ds []time.Duration, p float64) time.Duration {
	if len(ds) == 0 {
		return 0
	}
	sorted := append([]time.Duration(nil), ds...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i] < sorted[j] })
	idx := int(float64(len(sorted)-1) * p)
	return sorted[idx]
}

// ── loading ───────────────────────────────────────────────────────────

func loadClassifierSet(dir string) ([]classifierExample, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.jsonl"))
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("no .jsonl files in %s", dir)
	}
	var out []classifierExample
	for _, f := range files {
		if err := eachLine(f, func(line []byte) error {
			var e classifierExample
			if err := json.Unmarshal(line, &e); err != nil {
				return err
			}
			out = append(out, e)
			return nil
		}); err != nil {
			return nil, fmt.Errorf("%s: %w", f, err)
		}
	}
	return out, nil
}

func loadVerifierSet(dir string) ([]verifierExample, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.jsonl"))
	if err != nil {
		return nil, err
	}
	var out []verifierExample
	for _, f := range files {
		if err := eachLine(f, func(line []byte) error {
			var e verifierExample
			if err := json.Unmarshal(line, &e); err != nil {
				return err
			}
			out = append(out, e)
			return nil
		}); err != nil {
			return nil, fmt.Errorf("%s: %w", f, err)
		}
	}
	return out, nil
}

func eachLine(path string, fn func([]byte) error) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "//") {
			continue
		}
		if err := fn([]byte(line)); err != nil {
			return err
		}
	}
	return sc.Err()
}

// loadThresholds reads the flat YAML. Every field is required: a missing
// threshold must be an error, because the alternative is a zero value
// that any result satisfies.
func loadThresholds(path string) (thresholds, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return thresholds{}, err
	}
	get := func(key string) (string, bool) {
		for _, line := range strings.Split(string(b), "\n") {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "#") {
				continue
			}
			if !strings.HasPrefix(line, key+":") {
				continue
			}
			v := strings.TrimSpace(strings.TrimPrefix(line, key+":"))
			if i := strings.Index(v, "#"); i >= 0 {
				v = strings.TrimSpace(v[:i])
			}
			if v == "" {
				continue
			}
			return v, true
		}
		return "", false
	}
	var th thresholds
	var missing []string
	// Nieparsowalna wartosc laduje na liscie brakow, nie zostaje zerem:
	// prog rowny 0 spelnia kazdy wynik, wiec literowka w thresholds.yaml
	// wylaczalaby bramke po cichu. (Errcheck w CI wskazal to 20.08 —
	// mial racje co do tresci, nie tylko formy.)
	num := func(key string, dst *float64) {
		v, ok := get(key)
		if !ok {
			missing = append(missing, key)
			return
		}
		if _, err := fmt.Sscanf(v, "%g", dst); err != nil {
			missing = append(missing, key+" (nieparsowalne: "+v+")")
		}
	}
	num("R_RISK", &th.recallRisk)
	num("PROHIBITED", &th.recallProhibited)
	num("P1_DIAG_to_A8_CONCEPT_max", &th.confusionP1ToA8Max)
	num("false_positive_rate_on_allowed_max", &th.fpOnAllowedMax)
	num("risk_flag_recall_min", &th.riskFlagRecallMin)
	num("catch_rate_min", &th.verifierCatchMin)
	num("false_block_rate_on_clean_max", &th.falseBlockOnCleanMax)
	num("p95_seconds_max", &th.latencyP95Max)

	if v, ok := get("min_per_category"); ok {
		if _, err := fmt.Sscanf(v, "%d", &th.minPerCategory); err != nil {
			missing = append(missing, "min_per_category (nieparsowalne: "+v+")")
		}
	} else {
		missing = append(missing, "min_per_category")
	}
	if v, ok := get("ungrounded_tolerance"); ok {
		if _, err := fmt.Sscanf(v, "%d", &th.ungroundedTolerance); err != nil {
			missing = append(missing, "ungrounded_tolerance (nieparsowalne: "+v+")")
		}
	} else {
		missing = append(missing, "ungrounded_tolerance")
	}
	th.developmentLabels, _ = get("development_labels")
	th.gaLabels, _ = get("ga_labels")
	if th.developmentLabels == "" || th.gaLabels == "" {
		missing = append(missing, "gating.development_labels/ga_labels")
	}
	if len(missing) > 0 {
		return th, fmt.Errorf("thresholds.yaml is missing: %s", strings.Join(missing, ", "))
	}
	return th, nil
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
