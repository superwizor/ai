package chat

import (
	"context"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// Rozklad czasu tury na skladniki.
//
// guardrail_decisions zapisuje tylko sume, a suma nie mowi, ktory krok
// przycinac. Ten test to przyrzad pomiarowy, nie brama — niczego nie
// oblewa, wypisuje liczby. Uzyty 20.08.2026 do ustalenia, ze limit
// MaxTokens 4096 kosztowal 5,4 s wobec 2048 przy identycznym wyjsciu.
//
// Uruchomienie kosztuje kilka wywolan modelu (~$0.01):
//
//	GOOGLE_CLOUD_PROJECT=... go test ./internal/chat/ -run Latency -v
func TestTurnLatencyBreakdown(t *testing.T) {
	if os.Getenv("GOOGLE_CLOUD_PROJECT") == "" {
		t.Skip("brak GOOGLE_CLOUD_PROJECT — pomiar pominiety")
	}
	ctx := context.Background()
	llm, err := NewVertexLLM(ctx, VertexConfigFromEnv())
	if err != nil {
		t.Fatalf("klient: %v", err)
	}

	// Kontekst tej samej wielkosci, co produkcyjny.
	var b strings.Builder
	for i := 0; b.Len() < DefaultMaxContextChars; i++ {
		b.WriteString("[segment_id=seg-" + strconv.Itoa(i) +
			" session_id=ses-1 2026-06-01 KLIENT] W pracy czuje ciagle napiecie i nie umiem odpuscic.\n")
	}
	body := b.String()[:DefaultMaxContextChars]

	step := func(name string, f func() (Usage, error)) time.Duration {
		start := time.Now()
		u, err := f()
		d := time.Since(start)
		if err != nil {
			t.Logf("%-26s %6.2fs  BLAD: %v", name, d.Seconds(), err)
			return d
		}
		t.Logf("%-26s %6.2fs  tokeny %d/%d", name, d.Seconds(), u.InputTokens, u.OutputTokens)
		return d
	}

	var total time.Duration
	total += step("klasyfikator", func() (Usage, error) {
		r, e := llm.Generate(ctx, GenerateRequest{Model: ClassifierModel,
			SystemPrompt: guardrail.ClassifierPromptV2, UserContent: "Od czego zaczac kolejna sesje?",
			ResponseSchema: guardrail.ClassifierSchema, Temperature: 0, MaxTokens: 2048})
		return r.Usage, e
	})
	total += step("embedding", func() (Usage, error) {
		_, u, e := llm.Embed(ctx, "od czego zaczac kolejna sesje")
		return u, e
	})

	a5, _ := guardrail.SchemaFor(guardrail.A5Prep)
	total += step("generator (produkcyjny)", func() (Usage, error) {
		r, e := llm.Generate(ctx, GenerateRequest{Model: GeneratorModel,
			SystemPrompt:   groundedSystemPrompts[guardrail.A5Prep],
			UserContent:    "PYTANIE TERAPEUTY:\nOd czego zaczac kolejna sesje?\n\nFRAGMENTY TRANSKRYPCJI:\n" + body,
			ResponseSchema: a5, Temperature: 0.3, MaxTokens: maxGenerationTokens})
		return r.Usage, e
	})
	total += step("weryfikator", func() (Usage, error) {
		v := guardrail.Verifier{Caller: modelCaller{llm}, Model: GeneratorModel}
		vd := v.VerifyContent(ctx, guardrail.A5Prep, []guardrail.Unit{
			{Kind: "section", Text: "Warto wrocic do watku napiecia w pracy."}})
		return Usage{InputTokens: vd.Cost.InputTokens, OutputTokens: vd.Cost.OutputTokens}, nil
	})

	t.Logf("%-26s %6.2fs  (bez pobierania i KMS)", "SUMA wywolan modelu", total.Seconds())
	t.Logf("budzet ADR p95: 1.50s — przekroczony %.1fx", total.Seconds()/1.5)
}
