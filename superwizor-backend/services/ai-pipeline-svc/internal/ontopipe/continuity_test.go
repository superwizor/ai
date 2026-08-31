package ontopipe

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

func pastZTwierdzeniami(t *testing.T) *PastContext {
	t.Helper()
	data := time.Date(2026, 8, 20, 10, 0, 0, 0, time.UTC)
	sesja := uuid.New()
	return &PastContext{
		Claims: []PastClaim{
			{ID: uuid.New(), SessionID: sesja, SessionDate: data,
				ConstructID: "konflikt", Categories: []string{"blizkosc-autonomia"},
				Status: ontology.StatusInterpretation, Evidence: []string{"s0820:s01"}},
			{ID: uuid.New(), SessionID: sesja, SessionDate: data,
				ConstructID: "ustalenie", Categories: []string{"praca domowa klienta"},
				Status: ontology.StatusObservation, Evidence: []string{"s0820:s02"}},
		},
		Spans: []PastSpan{
			{Addr: "s0820:s01", SessionID: sesja, SessionDate: data,
				Quote: "Duszę się w tym związku."},
			{Addr: "s0820:s02", SessionID: sesja, SessionDate: data,
				Quote: "Spróbuję zapisywać myśli przez tydzień."},
		},
	}
}

func ontologiaZUstaleniem(t *testing.T) *ontology.Ontology {
	o := testO(t)
	o.Constructs["ustalenie"] = &ontology.Construct{
		LabelPL: "Ustalenie", Kind: ontology.KindCategory,
		Values:       []string{"praca domowa klienta"},
		ForcedStatus: ontology.StatusObservation,
		MinEvidence:  &ontology.MinEvidence{Spans: 1},
		FactKindMap:  map[string]string{"agreement_client": "praca domowa klienta"},
	}
	return o
}

func TestS2kParowanieIWerdykty(t *testing.T) {
	o := ontologiaZUstaleniem(t)
	past := pastZTwierdzeniami(t)
	res := Result{Approved: []ontology.Claim{
		{ConstructID: "konflikt", Categories: []string{"blizkosc-autonomia"},
			Status: ontology.StatusInterpretation,
			Evidence: []ontology.QuoteRef{{SpanID: "s01", Quote: "Znowu się duszę."}}},
	}}
	spans := []ontology.TopicSpan{
		{Span: ontology.Span{ID: "s01", QuoteVerbatim: "Znowu się duszę."}},
		{Span: ontology.Span{ID: "s02", QuoteVerbatim: "Zapisywałam myśli, było trudno, ale mam pięć wpisów."}},
	}

	var widzianySchemat map[string]any
	f := &fakeLLM{handler: func(req LLMRequest) (string, error) {
		if req.Stage != StageContinuity {
			t.Fatalf("nieoczekiwany etap %s", req.Stage)
		}
		widzianySchemat = req.Schema
		return `{"links":[{"pair_id":"p01","relation":"wzmacnia"},
		         {"pair_id":"p99","relation":"oslabia"}],
		 "homework":[{"past_claim_id":"` + past.Claims[1].ID.String() + `",
		              "verdict":"omowiona_z_rezultatem","evidence_span_ids":["s02"]}]}`, nil
	}}
	RunContinuity(context.Background(), f, o, &res, past, spans, &res.Usage)

	if widzianySchemat == nil {
		t.Fatal("S2k nie zostal wywolany")
	}
	if len(res.ContinuityLinks) != 1 {
		t.Fatalf("linkow %d, oczekiwano 1 (p99 = nieznana para, odrzucona): %+v",
			len(res.ContinuityLinks), res.ContinuityLinks)
	}
	l := res.ContinuityLinks[0]
	if l.Relation != "wzmacnia" || l.ConstructID != "konflikt" ||
		l.PastClaimID != past.Claims[0].ID {
		t.Fatalf("link: %+v", l)
	}
	if res.DroppedLinks != 1 {
		t.Fatalf("DroppedLinks=%d, oczekiwano 1 (nieznana para)", res.DroppedLinks)
	}
	if len(res.HomeworkVerdicts) != 1 || res.HomeworkVerdicts[0].Verdict != "omowiona_z_rezultatem" {
		t.Fatalf("werdykty: %+v", res.HomeworkVerdicts)
	}
	if res.HomeworkVerdicts[0].Quote == "" {
		t.Fatal("werdykt bez cytatu przeszlego ustalenia")
	}
}

func TestS2kWerdyktBezDowoduDegradujeSie(t *testing.T) {
	o := ontologiaZUstaleniem(t)
	past := pastZTwierdzeniami(t)
	res := Result{}
	f := &fakeLLM{handler: func(req LLMRequest) (string, error) {
		return `{"homework":[{"past_claim_id":"` + past.Claims[1].ID.String() + `",
		         "verdict":"wspomniana","evidence_span_ids":["s_nie_istnieje"]}]}`, nil
	}}
	RunContinuity(context.Background(), f, o, &res, past,
		[]ontology.TopicSpan{{Span: ontology.Span{ID: "s01"}}}, &res.Usage)
	if len(res.HomeworkVerdicts) != 1 || res.HomeworkVerdicts[0].Verdict != "nie_wrocono" {
		t.Fatalf("werdykt bez istniejacego dowodu mial zdegradowac do nie_wrocono: %+v",
			res.HomeworkVerdicts)
	}
	if res.DroppedLinks != 1 {
		t.Fatalf("degradacja ma byc zliczona: DroppedLinks=%d", res.DroppedLinks)
	}
}

func TestS2kBrakHistoriiZeroWywolan(t *testing.T) {
	o := testO(t)
	res := Result{}
	f := &fakeLLM{handler: func(req LLMRequest) (string, error) {
		t.Fatal("S2k wywolane bez historii")
		return "", nil
	}}
	RunContinuity(context.Background(), f, o, &res, nil, nil, &res.Usage)
	RunContinuity(context.Background(), f, o, &res, &PastContext{}, nil, &res.Usage)
}

func TestRenderKontynuacjiIRozliczenia(t *testing.T) {
	o := ontologiaZUstaleniem(t)
	past := pastZTwierdzeniami(t)
	res := Result{
		Report: Report{Constructs: []ConstructReport{
			{ConstructID: "konflikt", Hypotheses: []Hypothesis{
				{ID: "A", Claim: "Napięcie bliskość-autonomia utrzymuje się.",
					EpistemicStatus: "interpretation", Confidence: 0.7,
					Supporting: []string{"s01"}},
			}},
			{ConstructID: "ustalenie", Hypotheses: []Hypothesis{
				{ID: "B", Claim: "Klientka przyjęła nowe zadanie.",
					EpistemicStatus: "observation", Confidence: 1.0,
					Supporting: []string{"s02"}},
			}},
		}},
		Spans: []ontology.TopicSpan{
			{Span: ontology.Span{ID: "s01", QuoteVerbatim: "Znowu się duszę."}},
			{Span: ontology.Span{ID: "s02", QuoteVerbatim: "Spróbuję nagrywać notatki."}},
		},
		ContinuityLinks: []ContinuityLink{
			{ClaimIdx: 0, ConstructID: "konflikt", PastClaimID: past.Claims[0].ID,
				PastSessionDate: past.Claims[0].SessionDate, Relation: "wzmacnia"},
		},
		HomeworkVerdicts: []HomeworkVerdict{
			{PastClaimID: past.Claims[1].ID, PastSessionDate: past.Claims[1].SessionDate,
				Quote: "Spróbuję zapisywać myśli przez tydzień.", Verdict: "omowiona_z_rezultatem"},
		},
	}
	// Dedupe: trzy linki tej samej relacji do jednego konstruktu daja
	// JEDNA linie (z najnowsza data) — 40 identycznych linii w kanarku
	// 3cab94e9 bylo szumem, nie informacja.
	res.ContinuityLinks = append(res.ContinuityLinks,
		ContinuityLink{ClaimIdx: 0, ConstructID: "konflikt", PastClaimID: past.Claims[0].ID,
			PastSessionDate: past.Claims[0].SessionDate.AddDate(0, 0, -7), Relation: "wzmacnia"},
		ContinuityLink{ClaimIdx: 0, ConstructID: "konflikt", PastClaimID: past.Claims[1].ID,
			PastSessionDate: past.Claims[0].SessionDate, Relation: "wzmacnia"})
	md := RenderMarkdown(o, res, RenderInput{Past: past})
	if n := strings.Count(md, "Kontynuacja: potwierdza"); n != 1 {
		t.Fatalf("linii kontynuacji %d, oczekiwano 1 (dedupe per relacja):\n%s", n, md)
	}
	if !strings.Contains(md, "potwierdza ustalenie z 20.08") {
		t.Fatalf("brak linii kontynuacji z NAJNOWSZA data:\n%s", md)
	}
	if !strings.Contains(md, "Rozliczenie poprzedniej pracy domowej") ||
		!strings.Contains(md, "omówiona z rezultatem") {
		t.Fatalf("brak bloku rozliczenia:\n%s", md)
	}
	if !strings.Contains(md, "(20.08)") {
		t.Fatalf("rozliczenie bez daty:\n%s", md)
	}
}
