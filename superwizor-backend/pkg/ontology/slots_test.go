package ontology

import (
	"strings"
	"testing"
)

// Testy gramatyki E5 (T37): unie atomow i cele wielokrotne.
func TestParseSlotType(t *testing.T) {
	przypadki := []struct {
		typ    string
		atomow int
		blad   bool
	}{
		{"span_ref", 1, false},
		{"entry_ref", 1, false},
		{"construct_ref(cbt_episode)", 1, false},
		{"enum_ref(emotion)", 1, false},
		{"span_ref|entry_ref", 2, false},
		{"enum_ref(actual_capacity_primary|actual_capacity_secondary)", 1, false},
		{"span_ref|construct_ref(a|b)|entry_ref", 3, false},
		{"", 0, true},
		{"construct_ref(", 0, true},
		{"construct_ref()", 0, true},
		{"construct_ref(A)", 0, true},       // wielka litera — nie identyfikator
		{"span_ref||entry_ref", 0, true},    // pusty czlon unii
		{"slot_ref", 0, true},               // nieznany atom
		{"construct_ref(a|)", 0, true},      // pusty cel w nawiasie
	}
	for _, tc := range przypadki {
		atomy, err := ParseSlotType(tc.typ)
		if tc.blad {
			if err == nil {
				t.Errorf("%q: oczekiwano bledu, dostano %v", tc.typ, atomy)
			}
			continue
		}
		if err != nil {
			t.Errorf("%q: %v", tc.typ, err)
			continue
		}
		if len(atomy) != tc.atomow {
			t.Errorf("%q: %d atomow, oczekiwano %d", tc.typ, len(atomy), tc.atomow)
		}
	}
	// Unia wewnatrz nawiasu: JEDEN atom o DWOCH celach — nie dwa atomy.
	atomy, err := ParseSlotType("enum_ref(a|b)")
	if err != nil || len(atomy) != 1 || len(atomy[0].Refs) != 2 {
		t.Fatalf("enum_ref(a|b): %v %v", atomy, err)
	}
}

func TestWalidacjaSlotowE5(t *testing.T) {
	jeden := 1
	zero := 0
	o := &Ontology{Modality: "cbt", Version: "0.0.1",
		EpistemicStatuses: AllStatuses,
		EtiologyPolicy: "strict", TherapistBoundary: "strict",
		Constructs: map[string]*Construct{
			"mysl":   {LabelPL: "M", Kind: KindCategory},
			"emocja": {LabelPL: "E", Kind: KindCategory, Values: []string{"lek"}},
			"komp": {LabelPL: "K", Kind: KindComposite, Slots: map[string]*Slot{
				"a": {Type: "span_ref|entry_ref", Multiple: true, MinItems: &jeden},
				"b": {Type: "construct_ref(mysl|emocja)"},
				"c": {Type: "enum_ref(emocja)"},
			}},
		}}
	if p := o.Validate(); len(p) > 0 {
		t.Fatalf("poprawne unie nie przechodza: %v", p)
	}

	// enum_ref na konstrukt bez katalogu = zawsze pomylka.
	o.Constructs["komp"].Slots["c"].Type = "enum_ref(mysl)"
	if p := o.Validate(); len(p) == 0 || !strings.Contains(strings.Join(p, " "), "bez values") {
		t.Fatalf("enum_ref na values:null przeszedl: %v", p)
	}
	o.Constructs["komp"].Slots["c"].Type = "enum_ref(emocja)"

	// min_items bez multiple nie znaczy nic — wiec jest bledem.
	o.Constructs["komp"].Slots["b"].MinItems = &jeden
	if p := o.Validate(); len(p) == 0 {
		t.Fatal("min_items bez multiple przeszlo")
	}
	o.Constructs["komp"].Slots["b"].MinItems = nil

	o.Constructs["komp"].Slots["a"].MinItems = &zero
	if p := o.Validate(); len(p) == 0 {
		t.Fatal("min_items=0 przeszlo")
	}
}

// Test E9: prog dowodowy liczony wylacznie na spanach wskazanej roli.
func TestR2LiczyTylkoWskazanaRole(t *testing.T) {
	dwa := 2
	_ = dwa
	o := &Ontology{Modality: "cbt", Version: "0.0.1",
		Constructs: map[string]*Construct{
			"technika": {LabelPL: "T", Kind: KindCategory,
				Values:      []string{"psychoedukacja"},
				MinEvidence: &MinEvidence{Spans: 2, Speaker: "therapist"}},
		}}
	spany := map[string]Span{
		"s01": {ID: "s01", ObservedBy: ObservedByTherapist, Kind: SpanDeclarative},
		"s02": {ID: "s02", ObservedBy: ObservedBySelf, Kind: SpanDeclarative},
		"s03": {ID: "s03", ObservedBy: ObservedBySelf, Kind: SpanDeclarative},
	}
	claim := Claim{ConstructID: "technika", Categories: []string{"psychoedukacja"},
		Status: StatusObservation, Confidence: 0.8, Reasoning: "test",
		Evidence: []QuoteRef{{SpanID: "s01"}, {SpanID: "s02"}, {SpanID: "s03"}}}

	res := o.Validate3(StageResult{ConstructID: "technika", Claims: []Claim{claim}},
		ValidateOptions{Spans: spany})
	if len(res.Approved) != 0 {
		t.Fatalf("1 span terapeuty przy progu 2 — twierdzenie przeszlo (rola nie filtruje)")
	}
	znaleziony := false
	for _, r := range res.Rejected {
		if strings.Contains(r.Detail, "roli therapist") {
			znaleziony = true
		}
	}
	if !znaleziony {
		t.Fatalf("odrzucenie bez informacji o roli: %+v", res.Rejected)
	}

	// Dolozenie drugiego spanu terapeuty przepuszcza.
	spany["s04"] = Span{ID: "s04", ObservedBy: ObservedByTherapist, Kind: SpanDeclarative}
	claim.Evidence = append(claim.Evidence, QuoteRef{SpanID: "s04"})
	res = o.Validate3(StageResult{ConstructID: "technika", Claims: []Claim{claim}},
		ValidateOptions{Spans: spany})
	if len(res.Approved) != 1 {
		t.Fatalf("2 spany terapeuty przy progu 2 — odrzucone: %+v", res.Rejected)
	}
}

// Testy G7 (nota E7) i E10 — kanal ostrzezen.
func TestG7HomonimMiedzykonstruktowy(t *testing.T) {
	o := &Ontology{Modality: "ppt", Version: "0.0.1",
		Constructs: map[string]*Construct{
			"sfera":  {LabelPL: "Sfera", Kind: KindCategory, Values: []string{"kontakt", "cialo"}},
			"potenc": {LabelPL: "Potencjalnosc", Kind: KindCategory, Values: []string{"kontakt", "milosc"}},
		}}
	w := strings.Join(o.Warnings(), " ")
	if !strings.Contains(w, "(G7)") || !strings.Contains(w, "kontakt") {
		t.Fatalf("homonim bez glos nie dal ostrzezenia G7: %v", w)
	}
	// Rozbrojenie POLOWICZNE nie wystarcza.
	o.Constructs["sfera"].ValueGlosses = map[string]string{"kontakt": "sfera zycia"}
	w = strings.Join(o.Warnings(), " ")
	if !strings.Contains(w, "(G7)") {
		t.Fatalf("polowiczne glosy uciszyly G7: %v", w)
	}
	// Pelne rozbrojenie ucisza.
	o.Constructs["potenc"].ValueGlosses = map[string]string{"kontakt": "zdolnosc nawiazywania wiezi"}
	for _, x := range o.Warnings() {
		if strings.Contains(x, "(G7)") {
			t.Fatalf("G7 mimo glos po obu stronach: %v", x)
		}
	}
}

func TestE10BrakSekcjiWzorcow(t *testing.T) {
	o := &Ontology{Modality: "cbt", Version: "0.0.1",
		Constructs: map[string]*Construct{
			"k": {LabelPL: "K", Kind: KindCategory},
		},
		ReportProfile: &ReportProfile{Layout: []LayoutSection{
			{ID: "podsumowanie", Title: "Podsumowanie", Kind: LayoutSummary},
		}}}
	w := strings.Join(o.Warnings(), " ")
	if !strings.Contains(w, "patterns") || !strings.Contains(w, "out_of_taxonomy") {
		t.Fatalf("brak ostrzezen E10: %v", w)
	}
	o.ReportProfile.Layout = append(o.ReportProfile.Layout,
		LayoutSection{ID: "wzorce", Title: "Wzorce", Kind: LayoutPatterns},
		LayoutSection{ID: "poza", Title: "Poza", Kind: LayoutOutOfTaxonomy})
	for _, x := range o.Warnings() {
		if strings.Contains(x, "(E10)") {
			t.Fatalf("E10 mimo obecnych sekcji: %v", x)
		}
	}
}
