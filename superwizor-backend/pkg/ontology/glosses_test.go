package ontology

import (
	"strings"
	"testing"
)

// konstruktZGlosami buduje minimalna ontologie z jednym konstruktem o
// zadanych values i glosach — wspolny fundament testow tabelarycznych.
func ontologiaZGlosami(t *testing.T, values []string, glosses map[string]string) *Ontology {
	t.Helper()
	o := &Ontology{
		Modality: "ppt", Version: "0.0.1",
		Constructs: map[string]*Construct{
			"kat": {LabelPL: "Testowy", Kind: KindCategory,
				Values: values, ValueGlosses: glosses},
		},
	}
	return o
}

func problemyGlos(o *Ontology) []string {
	var out []string
	for _, p := range o.Validate() {
		if strings.Contains(p, "value_glosses") || strings.Contains(p, "(G") {
			out = append(out, p)
		}
	}
	return out
}

func TestGlosyReguly(t *testing.T) {
	dluga := strings.Repeat("a", 121)
	przypadki := []struct {
		nazwa   string
		values  []string
		glosses map[string]string
		blad    string // pusty = oczekujemy PASS
	}{
		{"bez glos, bez pary", []string{"a", "b"}, nil, ""},
		{"G1 klucz spoza values", []string{"a"}, map[string]string{"c": "opis"}, "(G1)"},
		// Literowka w diakrytyku NIE moze przechodzic: glosujemy kanon.
		{"G1 diakrytyk", []string{"pewność"}, map[string]string{"pewnosc": "opis"}, "(G1)"},
		{"G2 glosy przy pustym katalogu", nil, map[string]string{"a": "opis"}, "(G2)"},
		{"G3 pusta", []string{"a"}, map[string]string{"a": "  "}, "(G3)"},
		{"G3 121 znakow", []string{"a"}, map[string]string{"a": dluga}, "(G3)"},
		{"G3 nowa linia", []string{"a"}, map[string]string{"a": "x\ny"}, "(G3)"},
		{"G3 markdown", []string{"a"}, map[string]string{"a": "opis **wazny**"}, "(G3)"},
		{"G4 glosa rowna innej wartosci", []string{"a", "b"}, map[string]string{"a": "b"}, "(G4)"},
		{"G4 glosa rowna kluczowi", []string{"a"}, map[string]string{"a": "a"}, "(G4)"},
		{"G6 para bez glos w konstrukcie z glosami",
			[]string{"pewność", "pewność siebie", "miłość"},
			map[string]string{"miłość": "zdolnosc do wiezi"}, "(G6)"},
		{"G6 para z glosami obu stron",
			[]string{"pewność", "pewność siebie"},
			map[string]string{"pewność": "decyzyjność", "pewność siebie": "ufność we własne siły"}, ""},
		{"para bez relacji podlancucha bez glos", []string{"miłość", "zaufanie"},
			map[string]string{"miłość": "zdolnosc do wiezi"}, ""},
	}
	for _, tc := range przypadki {
		t.Run(tc.nazwa, func(t *testing.T) {
			p := problemyGlos(ontologiaZGlosami(t, tc.values, tc.glosses))
			if tc.blad == "" {
				if len(p) > 0 {
					t.Fatalf("oczekiwano PASS, dostano: %v", p)
				}
				return
			}
			if len(p) == 0 {
				t.Fatalf("oczekiwano bledu %s, lint przeszedl", tc.blad)
			}
			znaleziony := false
			for _, x := range p {
				if strings.Contains(x, tc.blad) {
					znaleziony = true
				}
			}
			if !znaleziony {
				t.Fatalf("oczekiwano %s w %v", tc.blad, p)
			}
		})
	}
}

// TestG6BezGlosJestOstrzezeniem dokumentuje swiadome odstepstwo od planu:
// para podlancuchowa w konstrukcie BEZ glos nie moze wywracac seedow
// sprzed istnienia pola (DoD: ppt/0.1.0 przechodzi bez zmian), wiec idzie
// kanalem ostrzezen. Gdy ktos "naprawi" to na ERROR, ten test przypomni
// o sprzecznosci, ktora wtedy wroci.
func TestG6BezGlosJestOstrzezeniem(t *testing.T) {
	o := ontologiaZGlosami(t, []string{"pewność", "pewność siebie"}, nil)
	if p := problemyGlos(o); len(p) > 0 {
		t.Fatalf("konstrukt bez glos ma blokowac lint? %v", p)
	}
	w := o.Warnings()
	if len(w) == 0 || !strings.Contains(strings.Join(w, " "), "(G6)") {
		t.Fatalf("brak ostrzezenia G6: %v", w)
	}
}

func TestG5AliasInnegoKonstruktu(t *testing.T) {
	o := &Ontology{
		Modality: "ppt", Version: "0.0.1",
		Constructs: map[string]*Construct{
			"kat": {LabelPL: "A", Kind: KindCategory, Values: []string{"wzór"},
				ValueGlosses: map[string]string{"wzór": "opis"}},
			"inny": {LabelPL: "B", Kind: KindCategory, Aliases: []string{"wzór"}},
		},
	}
	w := o.Warnings()
	if len(w) == 0 || !strings.Contains(w[0], "(G5)") {
		t.Fatalf("oczekiwano ostrzezenia G5, dostano: %v", w)
	}
	if p := problemyGlos(o); len(p) > 0 {
		t.Fatalf("G5 ma byc ostrzezeniem, nie bledem: %v", p)
	}
}

func TestSubstringValuePairsDeterministyczne(t *testing.T) {
	pary := SubstringValuePairs([]string{"pewność siebie", "miłość", "pewność", "Pewność"})
	// "pewność"/"Pewność" to duplikat po normalizacji — nie para.
	for _, p := range pary {
		if strings.EqualFold(p[0], p[1]) {
			t.Fatalf("duplikat uznany za pare: %v", p)
		}
	}
	if len(pary) < 2 { // pewność⊂pewność siebie oraz Pewność⊂pewność siebie
		t.Fatalf("oczekiwano par dla obu wariantow, dostano %v", pary)
	}
	if pary[0][0] > pary[1][0] {
		t.Fatalf("kolejnosc niedeterministyczna: %v", pary)
	}
}
