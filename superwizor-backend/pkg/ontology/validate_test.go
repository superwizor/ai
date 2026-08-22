package ontology

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// minimalna poprawna ontologia — punkt odniesienia dla testow negatywnych.
const okYAML = `
modality: test
version: 1.0.0
approved_by: []
constructs:
  alpha:
    label_pl: "Alfa"
    values: ["a", "b"]
    min_evidence: {spans: 2}
  beta:
    label_pl: "Beta"
    is_not: [alpha]
    requires: [alpha]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie, napiecie]
`

func mustParse(t *testing.T, y string) *Ontology {
	t.Helper()
	o, err := Parse([]byte(y))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	return o
}

func TestPoprawnaOntologiaPrzechodzi(t *testing.T) {
	if p := mustParse(t, okYAML).Validate(); len(p) != 0 {
		t.Fatalf("oczekiwano zera problemow, jest %d: %v", len(p), p)
	}
}

// hasProblem szuka fragmentu w liscie problemow.
func hasProblem(p []string, frag string) bool {
	for _, s := range p {
		if strings.Contains(s, frag) {
			return true
		}
	}
	return false
}

// TestStatusyPierwszejKlasySaWymagane pilnuje sedna architektury.
//
// Bez insufficient_data wraca objaw 4 z dok. 11 (nadmierne domykanie
// pol: "brak danych" przestaje byc legalna wartoscia). Bez no_fit enum
// wymusza wybor najblizszej kategorii — forced-choice bias. To nie sa
// pola opcjonalne i walidator ma tego bronic.
func TestStatusyPierwszejKlasySaWymagane(t *testing.T) {
	y := strings.Replace(okYAML,
		"epistemic_statuses: [observation, interpretation, theoretical_hypothesis,\n                     open_question, insufficient_data, no_fit]",
		"epistemic_statuses: [observation, interpretation]", 1)
	p := mustParse(t, y).Validate()
	if !hasProblem(p, "insufficient_data") {
		t.Errorf("brak insufficient_data nie zostal zglosozny: %v", p)
	}
	if !hasProblem(p, "no_fit") {
		t.Errorf("brak no_fit nie zostal zgloszony: %v", p)
	}
}

// TestPolitykiBezpieczenstwaNieDaSieRozluznic — R5 i R10 to klasy bledow,
// ktore ta architektura likwiduje; ontologia nie moze ich wylaczyc.
func TestPolitykiBezpieczenstwaNieDaSieRozluznic(t *testing.T) {
	for _, c := range []struct{ opis, from, to, frag string }{
		{"etiologia", "etiology_policy: strict", "etiology_policy: lenient", "etiology_policy"},
		{"granica terapeuty", "therapist_boundary: strict", "therapist_boundary: off", "therapist_boundary"},
	} {
		p := mustParse(t, strings.Replace(okYAML, c.from, c.to, 1)).Validate()
		if !hasProblem(p, c.frag) {
			t.Errorf("%s: rozluznienie przeszlo bez zgloszenia: %v", c.opis, p)
		}
	}
}

func TestWiszaceReferencjeSaLapane(t *testing.T) {
	y := strings.Replace(okYAML, "is_not: [alpha]", "is_not: [nieistnieje]", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "nieistnieje") {
		t.Errorf("wiszaca referencja przeszla: %v", p)
	}
}

func TestKonstruktNieMozeWskazywacSamNaSiebie(t *testing.T) {
	y := strings.Replace(okYAML, "requires: [alpha]", "requires: [beta]", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "sam na siebie") {
		t.Errorf("autoreferencja przeszla: %v", p)
	}
}

func TestProgDowodowyPonizejJednegoJestOdrzucany(t *testing.T) {
	y := strings.Replace(okYAML, "min_evidence: {spans: 2}", "min_evidence: {spans: 0}", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "proweniencji") {
		t.Errorf("spans=0 przeszlo — wymog proweniencji zniesiony: %v", p)
	}
}

func TestProgNiespelnialnyJestLapany(t *testing.T) {
	y := strings.Replace(okYAML, "min_evidence: {spans: 2}",
		"min_evidence: {spans: 2, behavioral: 3}", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "niespelnialny") {
		t.Errorf("behavioral > spans przeszlo: %v", p)
	}
}

func TestMultiLabelWymagaKatalogu(t *testing.T) {
	y := strings.Replace(okYAML, `    is_not: [alpha]`,
		"    multi_label: true\n    is_not: [alpha]", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "multi_label") {
		t.Errorf("multi_label bez values przeszlo: %v", p)
	}
}

const kompozytYAML = `
modality: test
version: 1.0.0
constructs:
  alpha:
    label_pl: "Alfa"
    values: ["a"]
    min_evidence: {spans: 1}
  epizod:
    label_pl: "Epizod"
    kind: composite
    slots:
      sytuacja: {type: span_ref, required: true}
      kategoria: {type: enum_ref(alpha), required: true}
      natezenie: {type: span_ref, quantity: true}
    min_complete_slots: 2
    quantities: {policy: stated_only, scale: "0-100"}
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
`

func TestKompozytPoprawnyPrzechodzi(t *testing.T) {
	if p := mustParse(t, kompozytYAML).Validate(); len(p) != 0 {
		t.Fatalf("kompozyt odrzucony: %v", p)
	}
}

// TestSlotIlosciowyWymagaPolityki — R9 egzekwuje polityke kwantyfikacji;
// slot ilosciowy bez niej przepuscilby liczbe bez reguly ograniczajacej.
func TestSlotIlosciowyWymagaPolityki(t *testing.T) {
	y := strings.Replace(kompozytYAML, `    quantities: {policy: stated_only, scale: "0-100"}
`, "", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "quantities.policy") {
		t.Errorf("slot quantity bez polityki przeszedl: %v", p)
	}
}

func TestKompozytBezSlotowJestOdrzucany(t *testing.T) {
	y := `
modality: test
version: 1.0.0
constructs:
  pusty:
    label_pl: "Pusty"
    kind: composite
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
`
	if p := mustParse(t, y).Validate(); !hasProblem(p, "wymaga slotow") {
		t.Errorf("kompozyt bez slotow przeszedl: %v", p)
	}
}

func TestNiepoprawnySemverJestLapany(t *testing.T) {
	y := strings.Replace(okYAML, "version: 1.0.0", "version: v1", 1)
	if p := mustParse(t, y).Validate(); !hasProblem(p, "semver") {
		t.Errorf("zly semver przeszedl: %v", p)
	}
}

// TestSeedyWRepoSaPoprawne — pliki ontologii w repozytorium musza
// przechodzic walidacje. To jest ten sam test, ktory w CI robi
// ontology-lint; tutaj chroni przed commitem zepsutego seeda.
func TestSeedyWRepoSaPoprawne(t *testing.T) {
	root := filepath.Join("..", "..", "ontology")
	matches, err := filepath.Glob(filepath.Join(root, "*", "*.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) == 0 {
		t.Skip("brak seedow w repo")
	}
	for _, f := range matches {
		if strings.Contains(f, "_meta") {
			continue // metaschemat to dokumentacja formatu, nie ontologia
		}
		data, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		o, err := Parse(data)
		if err != nil {
			t.Errorf("%s: %v", f, err)
			continue
		}
		if p := o.Validate(); len(p) > 0 {
			t.Errorf("%s: %d problem(ow): %v", f, len(p), p)
		}
		// Seed z niepustym approved_by udawalby autoryzacje, ktorej nie
		// bylo — import ma tworzyc wersje draft (plan 16 sekcja 6.1).
		if o.IsApproved() {
			t.Errorf("%s: seed ma niepuste approved_by — import musi tworzyc draft", f)
		}
	}
}
