package ontopipe

// Test integracyjny E4/T42a: konstrukt faktowy NIE trafia do S2, a jego
// twierdzenia powstaja deterministycznie i przechodza walidacje w tej
// samej petli (kolejnosc zatwierdzonych twierdzen pozostaje stabilna —
// indeks wnioskowania adresuje po pozycji).

import (
	"context"
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

func TestKonstruktFaktowyOmijaS2(t *testing.T) {
	o := testO(t)
	o.Constructs["ustalenie"] = &ontology.Construct{
		LabelPL: "Ustalenie", Kind: ontology.KindCategory,
		Values:       []string{"praca domowa klienta"},
		ForcedStatus: ontology.StatusObservation,
		MinEvidence:  &ontology.MinEvidence{Spans: 1},
		FactKindMap:  map[string]string{"agreement_client": "praca domowa klienta"},
	}

	pytaneKonstrukty := map[string]int{}
	base := domyslnaAtrapa(t)
	inner := base.handler
	base.handler = func(req LLMRequest) (string, error) {
		if req.Stage == StageMapping {
			pytaneKonstrukty[konstruktZPromptu(req.SystemPrompt)]++
		}
		return inner(req)
	}

	// Transkrypcja z faktem: atrapa S1 nie zwraca fact_kind, wiec
	// wstrzykujemy go przez wlasna odpowiedz S1.
	s1 := `{"spans":[
	 {"span_id":"s01","quote_verbatim":"Z jednej strony chcę być blisko, z drugiej duszę się w tym związku.","speaker":"Klient","kind":"declarative","observed_by":"self","topics":["zwiazek"]},
	 {"span_id":"s02","quote_verbatim":"Wychodzę z tych rozmów wykończona.","speaker":"Klient","kind":"declarative","observed_by":"self","topics":["zwiazek"]},
	 {"span_id":"s03","quote_verbatim":"Mam siostrę, która zawsze mnie wysłucha.","speaker":"Klient","kind":"declarative","observed_by":"self","topics":["wsparcie"]},
	 {"span_id":"s04","quote_verbatim":"Spróbuję w tym tygodniu zapisywać myśli.","speaker":"Klient","kind":"declarative","observed_by":"self","fact_kind":"agreement_client","topics":["zadanie"]}
	]}`
	prev := base.handler
	base.handler = func(req LLMRequest) (string, error) {
		if req.Stage == StageExtraction {
			return s1, nil
		}
		return prev(req)
	}

	res, err := Run(context.Background(), base,
		Input{SessionID: "sess-1",
			Transcript: testTranskrypcja + "\nKlient: Spróbuję w tym tygodniu zapisywać myśli.",
			Ontology:   o})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if pytaneKonstrukty["ustalenie"] > 0 {
		t.Fatalf("konstrukt faktowy trafil do S2 (%d razy) — mapowanie mialo byc deterministyczne",
			pytaneKonstrukty["ustalenie"])
	}
	if len(res.FactMapped) != 1 || res.FactMapped[0] != "ustalenie" {
		t.Fatalf("FactMapped: %v", res.FactMapped)
	}
	znaleziony := false
	for _, c := range res.Approved {
		if c.ConstructID == "ustalenie" {
			znaleziony = true
			if c.Status != ontology.StatusObservation ||
				!strings.Contains(c.Reasoning, "fact_kind=agreement_client") {
				t.Fatalf("twierdzenie faktowe: %+v", c)
			}
		}
	}
	if !znaleziony {
		t.Fatal("brak zatwierdzonego twierdzenia faktowego")
	}
}
