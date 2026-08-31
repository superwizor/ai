package ontology

import (
	"strings"
	"testing"
)

func ontologiaFaktowa(t *testing.T) *Ontology {
	t.Helper()
	return &Ontology{Modality: "cbt", Version: "0.0.1",
		EpistemicStatuses: AllStatuses, EtiologyPolicy: "strict",
		TherapistBoundary: "strict",
		Constructs: map[string]*Construct{
			"ustalenie": {LabelPL: "Ustalenie", Kind: KindCategory,
				Values:       []string{"praca domowa klienta", "agenda kolejnej sesji"},
				ForcedStatus: StatusObservation,
				MinEvidence:  &MinEvidence{Spans: 1},
				FactKindMap: map[string]string{
					"agreement_client": "praca domowa klienta",
					"agenda_next":      "agenda kolejnej sesji",
				}},
			"nastroj": {LabelPL: "Nastroj", Kind: KindCategory, Values: nil,
				ForcedStatus: StatusObservation, MinEvidence: &MinEvidence{Spans: 1},
				FactKindMap:  map[string]string{"mood_rating": ""}},
			"zwykly": {LabelPL: "Zwykly", Kind: KindCategory,
				Values: []string{"a"}},
		}}
}

func TestLintFaktow(t *testing.T) {
	o := ontologiaFaktowa(t)
	if p := o.Validate(); len(p) > 0 {
		t.Fatalf("poprawna mapa faktow nie przechodzi: %v", p)
	}
	// F1: klucz spoza katalogu
	o.Constructs["ustalenie"].FactKindMap["zmyslony"] = "praca domowa klienta"
	if p := o.Validate(); len(p) == 0 || !strings.Contains(strings.Join(p, " "), "(F1)") {
		t.Fatalf("F1 nie zadzialalo: %v", p)
	}
	delete(o.Constructs["ustalenie"].FactKindMap, "zmyslony")
	// F2: kategoria spoza values
	o.Constructs["ustalenie"].FactKindMap["agreement_client"] = "nie ma takiej"
	if p := o.Validate(); len(p) == 0 || !strings.Contains(strings.Join(p, " "), "(F2)") {
		t.Fatalf("F2 nie zadzialalo: %v", p)
	}
	o.Constructs["ustalenie"].FactKindMap["agreement_client"] = "praca domowa klienta"
	// F3: dwa konstrukty na ten sam fact_kind
	o.Constructs["nastroj"].FactKindMap["agreement_client"] = ""
	if p := o.Validate(); len(p) == 0 || !strings.Contains(strings.Join(p, " "), "(F3)") {
		t.Fatalf("F3 nie zadzialalo: %v", p)
	}
	delete(o.Constructs["nastroj"].FactKindMap, "agreement_client")
	// F4: fakt bez forced_status observation
	o.Constructs["ustalenie"].ForcedStatus = ""
	if p := o.Validate(); len(p) == 0 || !strings.Contains(strings.Join(p, " "), "(F4)") {
		t.Fatalf("F4 nie zadzialalo: %v", p)
	}
	o.Constructs["ustalenie"].ForcedStatus = StatusObservation
}

func TestMapFactsDeterministycznie(t *testing.T) {
	o := ontologiaFaktowa(t)
	spans := []TopicSpan{
		{Span: Span{ID: "s01", SessionID: "x", QuoteVerbatim: "Sprobuje zapisywac mysli.",
			Kind: SpanDeclarative, ObservedBy: ObservedBySelf, FactKind: "agreement_client"}},
		{Span: Span{ID: "s02", SessionID: "x", QuoteVerbatim: "Dzisiaj jakies 4 na 10.",
			Kind: SpanDeclarative, ObservedBy: ObservedBySelf, FactKind: "mood_rating"}},
		{Span: Span{ID: "s03", SessionID: "x", QuoteVerbatim: "Zwykla wypowiedz.",
			Kind: SpanDeclarative, ObservedBy: ObservedBySelf}},
	}
	wyniki := o.MapFacts(spans)
	if len(wyniki) != 2 {
		t.Fatalf("konstruktow faktowych z twierdzeniami: %d, oczekiwano 2: %+v", len(wyniki), wyniki)
	}
	perKonstrukt := map[string]StageResult{}
	for _, sr := range wyniki {
		perKonstrukt[sr.ConstructID] = sr
	}
	u := perKonstrukt["ustalenie"]
	if len(u.Claims) != 1 || u.Claims[0].Categories[0] != "praca domowa klienta" {
		t.Fatalf("ustalenie: %+v", u.Claims)
	}
	if u.Claims[0].Status != StatusObservation || u.Claims[0].Confidence != 1.0 {
		t.Fatalf("fakt nie jest obserwacja z pewnoscia 1.0: %+v", u.Claims[0])
	}
	n := perKonstrukt["nastroj"]
	if len(n.Claims) != 1 || len(n.Claims[0].Categories) != 0 {
		t.Fatalf("nastroj (values null) ma miec pusta kategorie: %+v", n.Claims)
	}
	// Twierdzenia faktowe przechodza S3 ta sama sciezka.
	spanIdx := map[string]Span{}
	for _, sp := range spans {
		spanIdx[sp.ID] = sp.Span
	}
	res := o.Validate3(u, ValidateOptions{Spans: spanIdx})
	if len(res.Approved) != 1 {
		t.Fatalf("fakt odrzucony w S3: %+v", res.Rejected)
	}
}
