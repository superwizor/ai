package chat

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
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

// Regresja incydentu 19:28 (A10, block 'fabricated'): transkrypcja
// angielska, pytanie polskie — model przetlumaczyl cytat. Deterministyczny
// weryfikator slusznie odrzucil, ale jedyna reakcja byl fallback.
// Samonaprawa daje modelowi wlasna odpowiedz z poleceniem skopiowania
// cytatow 1:1; werdykt liczy sie OD NOWA, wiec gwarancja nie slabnie.
func TestQuoteRepairFixesUnfaithfulQuote(t *testing.T) {
	segs := sampleSegments()
	english := Segment{
		ID: uuid.New(), SessionID: segs[0].SessionID,
		Text:    "I'm just feeling down a lot, and I can't really snap out of it.",
		Speaker: "KLIENT", TsStartMs: 50000, SessionAt: segs[0].SessionAt,
	}
	segs = append(segs, english)

	badQuote := `{"hypotheses":[{"title":"Kierunek","body":"Warto rozważyć pracę z nastrojem.","quotes":[{"session_id":"` +
		english.SessionID.String() + `","segment_id":"` + english.ID.String() +
		`","text":"Czuję się ostatnio bardzo przygnębiona i nie umiem się otrząsnąć."}]}]}` // tlumaczenie!
	fixedQuote := `{"hypotheses":[{"title":"Kierunek","body":"Warto rozważyć pracę z nastrojem.","quotes":[{"session_id":"` +
		english.SessionID.String() + `","segment_id":"` + english.ID.String() +
		`","text":"I'm just feeling down a lot, and I can't really snap out of it."}]}]}`

	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A10_TREAT","confidence":0.95,"risk_flag":false}`,
		badQuote,
		fixedQuote,
		`{"violation":false,"code":"none"}`,
	}, segs)

	tq := turn()
	tq.Question = "Jakie kierunki warto rozważyć?" // bez terminow lapiacych
	// polskie segmenty: wyszukiwanie nic nie trafia i spada na PELNY
	// material (tak jak realna tura z 19:28 — polskie pytanie nad
	// angielska transkrypcja), wiec angielski segment jest w segMap
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeAnswered {
		t.Fatalf("outcome = %v, want answered — naprawa miala uratowac ture (reason=%q)",
			out.Kind, out.Meta.DegradeReason)
	}

	// Wywolanie naprawcze: niesie wlasna odpowiedz modelu i wylacznie
	// polecenie poprawy cytatow.
	var repairCall *GenerateRequest
	for i := range h.llm.calls {
		if strings.Contains(h.llm.calls[i].UserContent, "NAPRAW WYLACZNIE CYTATY") {
			repairCall = &h.llm.calls[i]
		}
	}
	if repairCall == nil {
		t.Fatal("brak wywolania naprawczego")
	}
	if !strings.Contains(repairCall.UserContent, "przygnębiona") {
		t.Error("naprawa nie dostala wlasnej (blednej) odpowiedzi do poprawy")
	}
	if repairCall.Temperature != 0 {
		t.Errorf("naprawa przy T=%v — kopiowanie cytatow ma byc deterministyczne", repairCall.Temperature)
	}

	// Reguly cytowania musza siedziec w promptcie SYSTEMOWYM generatora.
	if !strings.Contains(repairCall.SystemPrompt, "NIE tlumacz") {
		t.Error("prompt systemowy nie niesie zakazu tlumaczenia cytatow")
	}

	// Zwyciezca jest odpowiedz naprawiona, z cytatem doslownym.
	var served string
	for _, sec := range out.Answer.Sections {
		for _, q := range sec.Quotes {
			served += q.Text
		}
	}
	if !strings.Contains(served, "feeling down a lot") {
		t.Errorf("serwowany cytat nie jest doslowny: %q", served)
	}
	if h.recs.last().VerifierResult != "pass" {
		t.Errorf("po udanej naprawie verifier_result=%q, want pass", h.recs.last().VerifierResult)
	}
}
