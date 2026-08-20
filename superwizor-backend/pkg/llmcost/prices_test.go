package llmcost

import (
	"errors"
	"math"
	"testing"
	"time"
)

var at = time.Date(2026, 8, 20, 12, 0, 0, 0, time.UTC)

func TestCostMicroUSD_KnownRates(t *testing.T) {
	tests := []struct {
		name      string
		model     string
		in, out   int64
		wantMicro int64
	}{
		// 1M input at $0.30 == 300_000 uUSD exactly.
		{"flash 1M input", Gemini25Flash, 1_000_000, 0, 300_000},
		// 1M output at $2.50 == 2_500_000 uUSD exactly.
		{"flash 1M output", Gemini25Flash, 0, 1_000_000, 2_500_000},
		{"flash both", Gemini25Flash, 1_000_000, 1_000_000, 2_800_000},
		{"pro 1M input", Gemini25Pro, 1_000_000, 0, 1_250_000},
		{"pro 1M output", Gemini25Pro, 0, 1_000_000, 10_000_000},
		{"lite", Gemini25FlashLite, 1_000_000, 1_000_000, 500_000},
		{"2.0 flash", Gemini20Flash, 1_000_000, 1_000_000, 750_000},
		// Embeddings bill input only; output tokens must not add cost.
		{"embedding ignores output", TextEmbedding005, 1_000_000, 999_999, 25_000},
		{"zero", Gemini25Flash, 0, 0, 0},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := CostMicroUSD(tc.model, tc.in, tc.out, at)
			if err != nil {
				t.Fatalf("CostMicroUSD: %v", err)
			}
			if got != tc.wantMicro {
				t.Errorf("got %d uUSD, want %d", got, tc.wantMicro)
			}
		})
	}
}

// A single token must cost at least 1 uUSD rather than 0. Truncating
// division would let a stream of tiny calls run free against the quota.
func TestCostMicroUSD_RoundsUp(t *testing.T) {
	got, err := CostMicroUSD(Gemini25Flash, 1, 0, at)
	if err != nil {
		t.Fatalf("CostMicroUSD: %v", err)
	}
	if got != 1 {
		t.Errorf("1 input token: got %d uUSD, want 1 (rounded up from 0.3)", got)
	}
	// 3 tokens * 0.3 = 0.9 uUSD, still rounds to 1 — not to 0.
	if got, _ := CostMicroUSD(Gemini25Flash, 3, 0, at); got != 1 {
		t.Errorf("3 input tokens: got %d uUSD, want 1", got)
	}
	// 4 tokens * 0.3 = 1.2 uUSD -> 2.
	if got, _ := CostMicroUSD(Gemini25Flash, 4, 0, at); got != 2 {
		t.Errorf("4 input tokens: got %d uUSD, want 2", got)
	}
}

// Malformed UsageMetadata must never produce a negative charge, which
// would refund quota the caller never paid.
func TestCostMicroUSD_NegativeTokensClampToZero(t *testing.T) {
	got, err := CostMicroUSD(Gemini25Flash, -5_000_000, -5_000_000, at)
	if err != nil {
		t.Fatalf("CostMicroUSD: %v", err)
	}
	if got != 0 {
		t.Errorf("negative tokens: got %d uUSD, want 0", got)
	}
}

func TestUnknownModelIsAnError(t *testing.T) {
	_, err := CostMicroUSD("gemini-9.9-imaginary", 1000, 1000, at)
	var unknown ErrUnknownModel
	if !errors.As(err, &unknown) {
		t.Fatalf("want ErrUnknownModel, got %v", err)
	}
	if unknown.Model != "gemini-9.9-imaginary" {
		t.Errorf("error lost the model name: %q", unknown.Model)
	}
}

// Regression for the two bugs this package was created to fix. Both use
// the production report shape measured on 2026-08-20: 60450 input /
// 6418 output tokens on gemini-2.5-flash.
func TestRegression_HistoricalMispricing(t *testing.T) {
	const (
		inTok  int64 = 60_450
		outTok int64 = 6_418
	)

	got, err := CostUSD(Gemini25Flash, inTok, outTok, at)
	if err != nil {
		t.Fatalf("CostUSD: %v", err)
	}
	// 60450*0.30/1e6 + 6418*2.50/1e6 = 0.018135 + 0.016045
	want := 0.034180
	if math.Abs(got-want) > 1e-6 {
		t.Fatalf("correct cost: got %.6f, want %.6f", got, want)
	}

	// Bug 1: reports.llm_total_cost_usd used gemini-2.5-pro rates
	// ($1.25/$5.00 per million) for a flash workload.
	oldOverpriced := float64(inTok)*0.00000125 + float64(outTok)*0.000005
	if oldOverpriced <= got {
		t.Fatal("expected the old formula to overprice; the premise of the fix is wrong")
	}
	if ratio := oldOverpriced / got; ratio < 3.0 || ratio > 3.3 {
		t.Errorf("overpricing ratio %.2fx outside the expected 3.0-3.3x band", ratio)
	}

	// Bug 2: llm-worker's header comment quoted gemini-1.5-flash rates,
	// understating the real bill.
	oldUnderpriced := float64(inTok)*0.000000075 + float64(outTok)*0.0000003
	if oldUnderpriced >= got {
		t.Fatal("expected the quoted comment rates to underprice")
	}
}

// The quota reserver prices its estimate and its commit against one
// resolved Rate. Both paths must agree with the top-level helper.
func TestRateForMatchesTopLevel(t *testing.T) {
	r, err := RateFor(Gemini25Flash, at)
	if err != nil {
		t.Fatalf("RateFor: %v", err)
	}
	viaRate := r.CostMicroUSD(12_345, 6_789)
	viaFunc, err := CostMicroUSD(Gemini25Flash, 12_345, 6_789, at)
	if err != nil {
		t.Fatalf("CostMicroUSD: %v", err)
	}
	if viaRate != viaFunc {
		t.Errorf("Rate.CostMicroUSD=%d, CostMicroUSD=%d — must agree", viaRate, viaFunc)
	}
}

// Every exported model constant must be priced. Without this, adding a
// constant and forgetting the rate fails at runtime instead of in CI.
func TestEveryModelConstantIsPriced(t *testing.T) {
	for _, m := range []string{Gemini25Flash, Gemini25FlashLite, Gemini25Pro, Gemini20Flash, TextEmbedding005} {
		if _, err := RateFor(m, at); err != nil {
			t.Errorf("model constant %q has no rate: %v", m, err)
		}
	}
	if len(Models()) != 5 {
		t.Errorf("Models() returned %d entries, want 5", len(Models()))
	}
}

// Versioning must actually resolve by time: a later rate wins after its
// EffectiveFrom, the earlier one before it.
func TestVersioning_ResolvesByTime(t *testing.T) {
	saved := table
	t.Cleanup(func() { table = saved })

	cut := time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)
	table = append(append([]Rate{}, saved...), Rate{
		Model:            Gemini25Flash,
		InputPerMillion:  600_000,
		OutputPerMillion: 5_000_000,
		EffectiveFrom:    cut,
		Source:           "test",
	})

	before, err := CostMicroUSD(Gemini25Flash, 1_000_000, 0, cut.Add(-time.Hour))
	if err != nil {
		t.Fatalf("before: %v", err)
	}
	if before != 300_000 {
		t.Errorf("before cutover: got %d, want 300000", before)
	}

	after, err := CostMicroUSD(Gemini25Flash, 1_000_000, 0, cut)
	if err != nil {
		t.Fatalf("after: %v", err)
	}
	if after != 600_000 {
		t.Errorf("at cutover: got %d, want 600000", after)
	}
}
