package chat

import (
	"context"
	"strings"
	"testing"
)

// Regresja produkcyjna z 20.08.2026 (A8 17:42, A7 18:29): odpowiedz
// przekroczyla MaxTokens, Vertex ucial JSON w polowie, dekodowanie
// padlo i tura wyszla jako blok 'schema' — twarda odmowa za usterke,
// ktora byla NASZYM limitem, nie trescia modelu.

// Obciecie -> jedno ponowienie z wiekszym budzetem.
func TestTruncatedGenerationIsRetriedOnce(t *testing.T) {
	segs := sampleSegments()
	good := `{"hypotheses":[{"title":"H","body":"b","quotes":[{"session_id":"` +
		segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
		`","text":"W pracy czuję ciągłe napięcie"}]}]}`
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"Uciete...`, // wywolanie 1: uciety JSON
		good,                                 // wywolanie 2: retry, pelny
		`{"violation":false,"code":"none"}`,
	}, segs)
	h.llm.truncated = map[int]bool{1: true}

	tq := turn()
	tq.Question = "Jak rozumieć jej napięcie w pracy?"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeAnswered {
		t.Fatalf("outcome = %v, want answered — retry mial uratowac ture", out.Kind)
	}

	// Drugie wywolanie generatora MUSI isc z wiekszym budzetem.
	var budgets []int32
	for _, c := range h.llm.calls {
		if strings.Contains(c.UserContent, "FRAGMENTY TRANSKRYPCJI") {
			budgets = append(budgets, c.MaxTokens)
		}
	}
	if len(budgets) != 2 {
		t.Fatalf("wywolan generatora: %d, oczekiwano 2 (oryginal + retry)", len(budgets))
	}
	if budgets[0] != maxGenerationTokens || budgets[1] != retryGenerationTokens {
		t.Errorf("budzety = %v, oczekiwano [%d %d]", budgets, maxGenerationTokens, retryGenerationTokens)
	}
	rec := h.recs.last()
	if rec.VerifierResult != "pass" {
		t.Errorf("verifier_result = %q — udany retry nie moze zostawic sladu bloku", rec.VerifierResult)
	}
}

// Gdy nawet retry nie daje dekodowalnego JSON — terapeuta dostaje
// material zrodlowy, nie sciane, a log dowodowy niesie block/schema.
func TestSchemaBlockFallsBackToSourceMaterial(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A7_TEMPLATE_MAP","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Uciete`,  // oryginal: smieci
		`{"sections":[{"title":"Dalej u`, // retry: dalej smieci
	}, segs)
	h.llm.truncated = map[int]bool{1: true, 2: true}

	tq := turn()
	tq.Question = "Zastosuj model równowagi do napięcia w pracy"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeDegraded || out.Meta.DegradeReason != "verifier_block" {
		t.Fatalf("outcome=%v reason=%q, want degraded/verifier_block", out.Kind, out.Meta.DegradeReason)
	}
	if out.Answer == nil || len(out.Answer.Sections) == 0 || len(out.Answer.Sections[0].Quotes) == 0 {
		t.Fatal("fallback bez materialu zrodlowego")
	}
	rec := h.recs.last()
	if rec.VerifierResult != "block" || rec.BlockReason != "schema" {
		t.Errorf("evidence: %q/%q, want block/schema", rec.VerifierResult, rec.BlockReason)
	}
	if rec.GroundingQuoteCount == 0 {
		t.Error("GroundingQuoteCount=0 mimo serwowanych cytatow — prog 8.3 mierzylby falszywy alarm")
	}
}

// A4 nie ma materialu zrodlowego — tam blok schematu pozostaje odmowa.
func TestEducationSchemaBlockStaysARefusal(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A4_EDU","confidence":0.95,"risk_flag":false}`,
		`nie-json`,
		`nadal-nie-json`,
	}, sampleSegments())
	h.llm.truncated = map[int]bool{1: true}

	tq := turn()
	tq.Question = "Czym różni się ekspozycja od desensytyzacji?"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeVerifierBlocked {
		t.Fatalf("outcome = %v, want verifier blocked (A4 nie ma na co spasc)", out.Kind)
	}
}
