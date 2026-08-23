package ontopipe

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Atrapa modelu. Caly potok S1-S5 przechodzi bez ani jednego platnego
// wywolania Vertexa — inaczej reguly S3 i S5 nie mialyby testu
// koncowego, bo nikt nie uruchamialby ich regularnie na CI.
type fakeLLM struct {
	// odp[model+znacznik] -> surowy JSON. Znacznik bierzemy z promptu,
	// zeby jedna atrapa obsluzyla rozne konstrukty.
	handler func(LLMRequest) (string, error)
	Zapytal []LLMRequest
}

func (f *fakeLLM) GenerateJSON(_ context.Context, req LLMRequest) (LLMResponse, error) {
	f.Zapytal = append(f.Zapytal, req)
	js, err := f.handler(req)
	if err != nil {
		return LLMResponse{}, err
	}
	return LLMResponse{JSON: js, InputTokens: 100, OutputTokens: 50}, nil
}

// konstruktZPromptu wyciaga id konstruktu z promptu S2.
func konstruktZPromptu(p string) string {
	for _, l := range strings.Split(p, "\n") {
		if strings.HasPrefix(l, "KONSTRUKT: ") {
			rest := strings.TrimPrefix(l, "KONSTRUKT: ")
			if i := strings.Index(rest, " —"); i > 0 {
				return rest[:i]
			}
			return rest
		}
	}
	return ""
}

const testOntologia = `
modality: test
version: 1.0.0
constructs:
  konflikt:
    label_pl: "Konflikt wewnetrzny"
    definition: "Napiecie miedzy dwoma daznosciami klienta."
    values: ["blizkosc-autonomia", "osiagniecia-odpoczynek"]
    is_not: [niezdecydowanie]
    min_evidence: {spans: 1}
    common_confusions:
      - input: "ambiwalencja"
        correct: "konflikt wymaga dwoch nazwanych daznosci"
  niezdecydowanie:
    label_pl: "Niezdecydowanie"
    values: ["chwilowe", "utrwalone"]
    min_evidence: {spans: 1}
  zasob:
    label_pl: "Zasob"
    values: ["wsparcie", "sprawczosc"]
    requires: [konflikt]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie, napiecie]
`

func testO(t *testing.T) *ontology.Ontology {
	t.Helper()
	o, err := ontology.Parse([]byte(testOntologia))
	if err != nil {
		t.Fatalf("parse ontologii testowej: %v", err)
	}
	if p := o.Validate(); len(p) != 0 {
		t.Fatalf("ontologia testowa nie przechodzi metaschematu: %v", p)
	}
	return o
}

const testTranskrypcja = `Klient: Z jednej strony chcę być blisko, z drugiej duszę się w tym związku.
Terapeuta: Co się dzieje, kiedy czuje pan to duszenie?
Klient: Wtedy wychodzę z domu na kilka godzin i nie odbieram telefonu.
Klient: Mam siostrę, która zawsze mnie wysłucha.
`

// jsonS1 sklada odpowiedz ekstrakcji z cytatami OBECNYMI w transkrypcji.
func jsonS1(t *testing.T) string {
	t.Helper()
	out := s1Output{Spans: []s1Span{
		{SpanID: "s01", Quote: "Z jednej strony chcę być blisko, z drugiej duszę się w tym związku.",
			Speaker: "Klient", Kind: "declarative", ObservedBy: "self",
			Topics: []string{"zwiazek"}},
		{SpanID: "s02", Quote: "Wtedy wychodzę z domu na kilka godzin i nie odbieram telefonu.",
			Speaker: "Klient", Kind: "behavioral", ObservedBy: "self",
			Topics: []string{"zwiazek", "wycofanie"}},
		{SpanID: "s03", Quote: "Mam siostrę, która zawsze mnie wysłucha.",
			Speaker: "Klient", Kind: "declarative", ObservedBy: "self",
			Topics: []string{"wsparcie"}},
	}}
	b, err := json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func jsonS2(construct, category, status, spanID, quote, reasoning string) string {
	return `{"construct_id":"` + construct + `","claims":[{"category":"` + category +
		`","epistemic_status":"` + status + `","confidence":0.7,"reasoning":"` + reasoning +
		`","evidence":[{"span_id":"` + spanID + `","quote":"` + quote +
		`"}]}],"insufficient_data":false,"no_fit":false}`
}

func jsonS4(constructID, hypID, claim, status, spanID string) string {
	return `{"constructs":[{"construct_id":"` + constructID + `","hypotheses":[{"id":"` +
		hypID + `","claim":"` + claim + `","supporting":["` + spanID +
		`"],"contradicting":[],"epistemic_status":"` + status +
		`","confidence":0.6}],"unknown_yet":[],"next_session_questions":[],"pattern_notices":[]}]}`
}

// domyslnaAtrapa zwraca poprawny przebieg calego potoku.
func domyslnaAtrapa(t *testing.T) *fakeLLM {
	t.Helper()
	// UWAGA: rozroznianie etapow po req.Model NIE DZIALA — ModelMapping i
	// ModelSynthesis to celowo ten sam model (oba Pro, dok. 11 sekcja 2a).
	// Etap poznajemy po prompcie: tylko S2 niesie naglowek KONSTRUKT.
	return &fakeLLM{handler: func(req LLMRequest) (string, error) {
		switch {
		case req.Model == ModelExtraction:
			return jsonS1(t), nil
		case konstruktZPromptu(req.SystemPrompt) != "":
			switch konstruktZPromptu(req.SystemPrompt) {
			case "konflikt":
				return jsonS2("konflikt", "blizkosc-autonomia", "interpretation", "s01",
					"Z jednej strony chcę być blisko, z drugiej duszę się w tym związku.",
					"Dwie nazwane daznosci w jednej wypowiedzi."), nil
			case "zasob":
				return jsonS2("zasob", "wsparcie", "observation", "s03",
					"Mam siostrę, która zawsze mnie wysłucha.",
					"Klient wskazuje konkretna osobe wspierajaca."), nil
			}
			return `{"construct_id":"?","claims":[],"insufficient_data":true,"no_fit":false}`, nil
		default:
			return jsonS4("konflikt", "A",
				"Materiał daje się czytać jako napięcie między bliskością a autonomią.",
				"interpretation", "s01"), nil
		}
	}}
}
