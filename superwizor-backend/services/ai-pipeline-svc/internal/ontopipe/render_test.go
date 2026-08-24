package ontopipe

import (
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Wynik z kompletem sekcji: hipotezy, wzmianki o wzorcach, pytania,
// no_fit — żeby każda sekcja miała co renderować.
func wynikPelny() Result {
	return Result{
		Report: Report{Constructs: []ConstructReport{
			{
				ConstructID: "konflikt",
				Hypotheses: []Hypothesis{{
					ID: "A", Claim: "Materiał daje się czytać jako napięcie.",
					Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
					Confidence: 0.6,
				}},
				PatternNotices:       []string{"temat związku wraca trzeci raz"},
				UnknownYet:           []string{"nie znamy kontekstu rodzinnego"},
				NextSessionQuestions: []string{"co dzieje się przy próbie rozmowy?"},
			},
		}},
		NoFit: []string{"zasob"},
	}
}

func ontologiaZProfilem(t *testing.T, profil string) *ontology.Ontology {
	t.Helper()
	y := `
modality: test
version: 1.0.0
constructs:
  konflikt:
    label_pl: "Konflikt wewnetrzny"
    values: ["a", "b"]
    min_evidence: {spans: 1}
  zasob:
    label_pl: "Zasob"
    values: null
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
` + profil
	o, err := ontology.Parse([]byte(y))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if p := o.Validate(); len(p) != 0 {
		t.Fatalf("ontologia testowa nie przechodzi metaschematu: %v", p)
	}
	return o
}

// naglowki wyciaga kolejnosc sekcji "## " z markdownu.
func naglowki(md string) []string {
	var out []string
	for _, l := range strings.Split(md, "\n") {
		if strings.HasPrefix(l, "## ") {
			out = append(out, strings.TrimPrefix(l, "## "))
		}
	}
	return out
}

func TestKompozycjaDomyslna(t *testing.T) {
	o := ontologiaZProfilem(t, "")
	md := RenderMarkdown(o, wynikPelny(), RenderInput{SummaryShort: "Streszczenie sesji."})
	got := naglowki(md)
	oczekiwane := []string{
		"Bilans sesji", "Konflikt wewnetrzny", "Powiązania i wzorce",
		"Pytania i niewiadome", "Poza obecną taksonomią",
	}
	if strings.Join(got, "|") != strings.Join(oczekiwane, "|") {
		t.Fatalf("kolejnosc sekcji = %v, oczekiwano %v", got, oczekiwane)
	}
}

// TestProfilPrzestawiaSekcje — kompozycja Gestalt z dok. 15 §3.3:
// wzorce i pytania w górę, konstrukty interpretacyjne w dół. Silnik ten
// sam, kompozycja inna.
func TestProfilPrzestawiaSekcje(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  sections:
    patterns_and_relations: {weight: high}
    open_questions: {weight: high}
    interpretive_constructs: {weight: low}
  default_tone: phenomenological
`)
	md := RenderMarkdown(o, wynikPelny(), RenderInput{SummaryShort: "Streszczenie."})
	got := naglowki(md)
	oczekiwane := []string{
		"Powiązania i wzorce", "Pytania i niewiadome", "Bilans sesji",
		"Poza obecną taksonomią", "Konflikt wewnetrzny",
	}
	if strings.Join(got, "|") != strings.Join(oczekiwane, "|") {
		t.Fatalf("kolejnosc sekcji = %v, oczekiwano %v", got, oczekiwane)
	}
}

// TestWagaNieUkrywaTresci — waga steruje kolejnością, nigdy widocznością.
// Ukrycie zweryfikowanej treści byłoby decyzją o treści, a M5 zmienia
// wyłącznie kompozycję.
func TestWagaNieUkrywaTresci(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  sections:
    interpretive_constructs: {weight: low}
`)
	md := RenderMarkdown(o, wynikPelny(), RenderInput{})
	if !strings.Contains(md, "Materiał daje się czytać jako napięcie.") {
		t.Fatal("waga low usunela tresc hipotezy z raportu")
	}
}

func TestPusteSekcjeZnikaja(t *testing.T) {
	o := ontologiaZProfilem(t, "")
	res := wynikPelny()
	res.Report.Constructs[0].PatternNotices = nil
	res.Report.Constructs[0].UnknownYet = nil
	res.Report.Constructs[0].NextSessionQuestions = nil
	res.NoFit = nil
	md := RenderMarkdown(o, res, RenderInput{})
	for _, zakazany := range []string{"Powiązania i wzorce", "Pytania i niewiadome",
		"Poza obecną taksonomią", "Bilans sesji"} {
		if strings.Contains(md, zakazany) {
			t.Errorf("pusta sekcja %q nie znikla", zakazany)
		}
	}
}

// TestBanerEkstraktywnyPrzedKompozycja — ostrzeżenie nie jest sekcją,
// której kolejność profil mógłby zepchnąć na dół.
func TestBanerEkstraktywnyPrzedKompozycja(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  sections:
    session_summary: {weight: high}
`)
	res := wynikPelny()
	res.Extractive = true
	md := RenderMarkdown(o, res, RenderInput{SummaryShort: "Streszczenie."})
	if !strings.HasPrefix(md, "> **Raport w trybie ekstraktywnym.**") {
		t.Fatalf("baner nie stoi na poczatku:\n%.120s", md)
	}
}

// TestWzmiankiPodpisaneKonstruktem — wzmianka wyrwana z kontekstu
// przestaje mówić, CZEGO dotyczy powtarzalność.
func TestWzmiankiPodpisaneKonstruktem(t *testing.T) {
	o := ontologiaZProfilem(t, "")
	md := RenderMarkdown(o, wynikPelny(), RenderInput{})
	if !strings.Contains(md, "**Konflikt wewnetrzny:** temat związku wraca trzeci raz") {
		t.Fatalf("wzmianka bez podpisu konstruktu:\n%s", md)
	}
}

// TestTonTylkoDlaZnanegoProfilu — M5: ton zmienia szablon językowy S4.
// Ontologia bez profilu nie może go dostać, a fenomenologiczny musi
// nieść dyscyplinę "opis przed oceną".
func TestTonTylkoDlaZnanegoProfilu(t *testing.T) {
	bez := ontologiaZProfilem(t, "")
	if strings.Contains(buildS4Prompt(bez), "TON:") {
		t.Fatal("prompt S4 dostal ton bez profilu")
	}
	z := ontologiaZProfilem(t, `report_profile:
  default_tone: phenomenological
`)
	prompt := buildS4Prompt(z)
	if !strings.Contains(prompt, "fenomenologiczny") ||
		!strings.Contains(prompt, "Opis przed oceną") {
		t.Fatalf("ton fenomenologiczny nie trafil do promptu S4:\n%.200s", prompt)
	}
}

// TestMetaschematOdrzucaLiterowki — literówka w kluczu sekcji albo wadze
// działałaby jak brak wpisu: najgorszy rodzaj błędu, bo niewidoczny.
func TestMetaschematOdrzucaLiterowki(t *testing.T) {
	for _, zly := range []string{
		`report_profile:
  sections:
    patterns_and_relatoins: {weight: high}
`,
		`report_profile:
  sections:
    open_questions: {weight: wysoka}
`,
		`report_profile:
  default_tone: kliniczny
`,
	} {
		y := `
modality: test
version: 1.0.0
constructs:
  a:
    label_pl: "A"
    values: ["x"]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
` + zly
		o, err := ontology.Parse([]byte(y))
		if err != nil {
			t.Fatalf("parse: %v", err)
		}
		if p := o.Validate(); len(p) == 0 {
			t.Errorf("metaschemat przepuscil profil:\n%s", zly)
		}
	}
}
