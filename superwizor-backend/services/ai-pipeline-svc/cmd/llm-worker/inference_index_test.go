package llmworker

import (
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

func wynikDoIndeksu() ontopipe.Result {
	return ontopipe.Result{
		Approved: []ontology.Claim{
			{ConstructID: "konflikt", Categories: []string{"blizkosc-autonomia"},
				Status: ontology.StatusInterpretation, Confidence: 0.7,
				Reasoning: "Dwie dążności w jednej wypowiedzi."},
			{ConstructID: "zasob", Status: ontology.StatusObservation,
				Confidence: 0.9, Reasoning: ""}, // bez uzasadnienia
		},
		Report: ontopipe.Report{Constructs: []ontopipe.ConstructReport{{
			ConstructID: "konflikt",
			Hypotheses: []ontopipe.Hypothesis{
				{ID: "A", Claim: "Napięcie daje się czytać jako konflikt bliskości.",
					EpistemicStatus: "interpretation", Confidence: 0.6},
				{ID: "B", Claim: "  ", EpistemicStatus: "interpretation"},
			},
		}}},
	}
}

// Poziomy sa rozdzielone JUZ NA ZAPISIE (dok. 65 §N1): twierdzenie moze
// byc dowodem, hipoteza nigdy. Gdyby oba lezaly w jednym worku,
// pierwsze zapytanie, ktore o tym zapomni, zamieni powtorzona
// interpretacje w uzasadnienie.
func TestIndeksRozdzielaPoziomy(t *testing.T) {
	wpisy := zbierzWpisy(wynikDoIndeksu())

	var claims, hipotezy int
	for _, w := range wpisy {
		switch w.kind {
		case "claim":
			claims++
		case "hypothesis":
			hipotezy++
		default:
			t.Fatalf("nieznany rodzaj wpisu: %q", w.kind)
		}
	}
	if claims != 1 {
		t.Errorf("twierdzen = %d, chcemy 1 (drugie bez uzasadnienia — pomijane)", claims)
	}
	if hipotezy != 1 {
		t.Errorf("hipotez = %d, chcemy 1 (druga pusta — pomijana)", hipotezy)
	}
}

// Kategoria wchodzi do tekstu wektora: „blizkosc-autonomia" niesie sens,
// po ktorym watek ma sie odnalezc za pol roku.
func TestTekstWektoraNiesieKategorie(t *testing.T) {
	for _, w := range zbierzWpisy(wynikDoIndeksu()) {
		if w.kind != "claim" {
			continue
		}
		if !strings.Contains(w.tekst, "blizkosc-autonomia") ||
			!strings.Contains(w.tekst, "Dwie dążności") {
			t.Fatalf("tekst wektora bez kategorii albo bez uzasadnienia: %q", w.tekst)
		}
	}
}

// Adres wpisu musi byc STABILNY miedzy przebiegami tego samego raportu —
// to na nim stoi idempotencja zapisu (Pub/Sub potrafi dostarczyc
// zdarzenie powtornie).
func TestAdresyWpisowSaStabilne(t *testing.T) {
	a := zbierzWpisy(wynikDoIndeksu())
	b := zbierzWpisy(wynikDoIndeksu())
	if len(a) != len(b) {
		t.Fatalf("rozna liczba wpisow: %d vs %d", len(a), len(b))
	}
	for i := range a {
		if a[i].itemRef != b[i].itemRef || a[i].kind != b[i].kind {
			t.Fatalf("adres niestabilny: %s/%s vs %s/%s",
				a[i].kind, a[i].itemRef, b[i].kind, b[i].itemRef)
		}
	}
	// Hipoteza adresowana konstruktem i identyfikatorem — dwie hipotezy
	// „A" w roznych konstruktach nie moga sie zderzyc.
	for _, w := range a {
		if w.kind == "hypothesis" && !strings.Contains(w.itemRef, "/") {
			t.Errorf("adres hipotezy bez konstruktu: %q", w.itemRef)
		}
	}
}
