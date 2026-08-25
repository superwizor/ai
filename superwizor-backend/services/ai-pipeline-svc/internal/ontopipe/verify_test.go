package ontopipe

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Materiał wspólny: jedno zatwierdzone twierdzenie konstruktu `konflikt`
// oparte na spanie s01, plus span s07 mówiący wprost o przeszłości.
func materialS5() (SynthesisInput, map[string]ontology.Span) {
	in := SynthesisInput{Claims: []ontology.Claim{{
		ConstructID: "konflikt",
		Categories:  []string{"blizkosc-autonomia"},
		Status:      ontology.StatusInterpretation,
		Confidence:  0.7,
		Reasoning:   "Dwie nazwane daznosci w jednej wypowiedzi.",
		Evidence: []ontology.QuoteRef{
			{SpanID: "s01", Quote: "chcę być blisko, a jednocześnie duszę się"},
			{SpanID: "s07", Quote: "w dzieciństwie nikt nie pytał mnie o zdanie"},
		},
	}}}
	spans := map[string]ontology.Span{
		"s01": {ID: "s01", QuoteVerbatim: "chcę być blisko, a jednocześnie duszę się"},
		"s07": {ID: "s07", QuoteVerbatim: "w dzieciństwie nikt nie pytał mnie o zdanie",
			AboutPast: true},
	}
	return in, spans
}

func raport(h Hypothesis) Report {
	return Report{Constructs: []ConstructReport{{ConstructID: "konflikt",
		Hypotheses: []Hypothesis{h}}}}
}

func maNaruszenie(v []Violation, r VRule) bool {
	for _, x := range v {
		if x.Rule == r {
			return true
		}
	}
	return false
}

func opis(v []Violation) string {
	var b strings.Builder
	for _, x := range v {
		b.WriteString(x.String())
		b.WriteString("; ")
	}
	return b.String()
}

// ── V1 ──

func TestV1OdnosnikDoNieistniejacegoSpanu(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Napięcie między dwiema dążnościami.",
		Supporting: []string{"s99"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleReference) {
		t.Fatalf("V1 nie zlapala odnosnika do spanu spoza zatwierdzonych: %s", opis(v))
	}
}

func TestV1HipotezaBezOdnosnika(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Napięcie między dwiema dążnościami.",
		Supporting: nil, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleReference) {
		t.Fatalf("V1 przepuscila hipoteze bez ani jednego spanu: %s", opis(v))
	}
}

// ── V2 ──

func TestV2TerminSpozaZatwierdzonych(t *testing.T) {
	in, spans := materialS5()
	// "utrwalone" jest kategoria konstruktu `niezdecydowanie`, nie
	// `konflikt` — i nie zostalo zatwierdzone w tym przebiegu.
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Widać tu utrwalone niezdecydowanie klienta.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleForeign) {
		t.Fatalf("V2 przepuscila kategorie spoza zatwierdzonych: %s", opis(v))
	}
}

// TestV2ZnosiOdmiane: polska fleksja nie moze byc luka w regule.
// Dopasowanie doslowne przepuscilo by kazdy przypadek zalezny.
func TestV2ZnosiOdmiane(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Zachowanie nosi znamiona utrwalonego niezdecydowania.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleForeign) {
		t.Fatalf("V2 nie rozpoznala terminu w przypadku zaleznym: %s", opis(v))
	}
}

func TestV2NieAlarmujeNaZatwierdzonej(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Materiał czyta się jako blizkosc-autonomia w jednej wypowiedzi.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if maNaruszenie(v, VRuleForeign) {
		t.Fatalf("V2 falszywie oskarzyla zatwierdzona kategorie: %s", opis(v))
	}
}

// ── V3 ──

func TestV3EtiologiaBezSpanuOPrzeszlosci(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Wzorzec ukształtował się w dzieciństwie klienta.",
		Supporting:      []string{"s01"}, // s01 NIE mowi o przeszlosci
		EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleEtiology) {
		t.Fatalf("V3 przepuscila zdanie o genezie bez spanu o przeszlosci: %s", opis(v))
	}
}

func TestV3EtiologiaZeSpanemPrzechodzi(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Wzorzec ukształtował się w dzieciństwie klienta.",
		Supporting: []string{"s01", "s07"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if maNaruszenie(v, VRuleEtiology) {
		t.Fatalf("V3 odrzucila etiologie MAJACA span o przeszlosci: %s", opis(v))
	}
}

// ── V4 ──

func TestV4StatusPodniesiony(t *testing.T) {
	in, spans := materialS5()
	// Zrodlo ma interpretation; raport pisze observation.
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Klient przeżywa napięcie między dwiema dążnościami.",
		Supporting: []string{"s01"}, EpistemicStatus: "observation",
	}), in, spans)
	if !maNaruszenie(v, VRuleHierarchy) {
		t.Fatalf("V4 przepuscila interpretacje podana jako obserwacja: %s", opis(v))
	}
}

func TestV4OslabienieStatusuPrzechodzi(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Możliwe, że mamy do czynienia z napięciem dwóch dążności.",
		Supporting: []string{"s01"}, EpistemicStatus: "theoretical_hypothesis",
	}), in, spans)
	if maNaruszenie(v, VRuleHierarchy) {
		t.Fatalf("V4 zablokowala OSLABIENIE statusu, a wolno oslabiac: %s", opis(v))
	}
}

func TestV4WiecejHipotezNizTwierdzen(t *testing.T) {
	in, spans := materialS5()
	rep := Report{Constructs: []ConstructReport{{ConstructID: "konflikt", Hypotheses: []Hypothesis{
		{ID: "A", Claim: "Pierwsza.", Supporting: []string{"s01"}, EpistemicStatus: "interpretation"},
		{ID: "B", Claim: "Druga.", Supporting: []string{"s01"}, EpistemicStatus: "interpretation"},
	}}}}
	if v := Verify(testO(t), rep, in, spans); !maNaruszenie(v, VRuleHierarchy) {
		t.Fatalf("V4 pozwolila rozmnozyc hipotezy ponad zatwierdzone twierdzenia: %s", opis(v))
	}
}

func TestV4KonstruktSpozaPrzebiegu(t *testing.T) {
	in, spans := materialS5()
	rep := Report{Constructs: []ConstructReport{{ConstructID: "zasob", Hypotheses: []Hypothesis{
		{ID: "A", Claim: "Klient ma wsparcie.", Supporting: []string{"s01"},
			EpistemicStatus: "observation"},
	}}}}
	if v := Verify(testO(t), rep, in, spans); !maNaruszenie(v, VRuleUnknownConstruct) {
		t.Fatalf("V4 przepuscila konstrukt, ktory nie wystapil w przebiegu: %s", opis(v))
	}
}

// ── V5 ──

func TestV5HipotezaTeoretycznaBezMarkera(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Konflikt wynika z niezaspokojonej potrzeby uznania.",
		Supporting: []string{"s01"}, EpistemicStatus: "theoretical_hypothesis",
	}), in, spans)
	if !maNaruszenie(v, VRuleMarker) {
		t.Fatalf("V5 przepuscila hipoteze teoretyczna bez jezyka modalnego: %s", opis(v))
	}
}

func TestV5WzmiankaOWzorcuBezWzorca(t *testing.T) {
	in, spans := materialS5()
	rep := Report{Constructs: []ConstructReport{{
		ConstructID:    "konflikt",
		Hypotheses:     []Hypothesis{{ID: "A", Claim: "Napięcie.", Supporting: []string{"s01"}, EpistemicStatus: "interpretation"}},
		PatternNotices: []string{"trzeci raz w materiale wraca temat pracy"},
	}}}
	if v := Verify(testO(t), rep, in, spans); !maNaruszenie(v, VRuleMarker) {
		t.Fatalf("V5 przepuscila meta-obserwacje bez policzonego wzorca: %s", opis(v))
	}
}

func TestV5WzmiankaZPoliczonymWzorcem(t *testing.T) {
	in, spans := materialS5()
	in.Patterns = []ontology.Pattern{{ID: "p1", Type: ontology.PatternRecurrence,
		Topics: []string{"zwiazek"}, SpanIDs: []string{"s01"}, Sessions: 1,
		Method: "temat wraca w 3 spanach"}}
	rep := Report{Constructs: []ConstructReport{{
		ConstructID:    "konflikt",
		Hypotheses:     []Hypothesis{{ID: "A", Claim: "Napięcie.", Supporting: []string{"s01"}, EpistemicStatus: "interpretation"}},
		PatternNotices: []string{"temat związku wraca w materiale"},
	}}}
	if v := Verify(testO(t), rep, in, spans); maNaruszenie(v, VRuleMarker) {
		t.Fatalf("V5 odrzucila wzmianke MAJACA policzony wzorzec: %s", opis(v))
	}
}

// ── V6 ──

func TestV6LiczbaBezPokrycia(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Klient wraca do tematu w 80% wypowiedzi.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleQuantity) {
		t.Fatalf("V6 przepuscila liczbe bez pokrycia w zrodle: %s", opis(v))
	}
}

func TestV6LiczbaSlowem(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Temat wraca trzykrotnie w tej sesji.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleQuantity) {
		t.Fatalf("V6 przepuscila liczebnik zapisany slowem: %s", opis(v))
	}
}

func TestV6LiczbaZCytatuPrzechodzi(t *testing.T) {
	in, spans := materialS5()
	in.Claims[0].Evidence = append(in.Claims[0].Evidence,
		ontology.QuoteRef{SpanID: "s01", Quote: "oceniam to na 7 na 10"})
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Klient ocenia natężenie na 7.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if maNaruszenie(v, VRuleQuantity) {
		t.Fatalf("V6 odrzucila liczbe, ktora PADLA w cytacie: %s", opis(v))
	}
}

// ── Regeneracja i tryb ekstraktywny ──

func TestTrybEkstraktywnyPoDwochRegeneracjach(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	prob := 0
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelSynthesis && konstruktZPromptu(req.SystemPrompt) == "" {
			prob++
			// Uparcie podnosi status: zrodlo ma interpretation.
			return jsonS4("konflikt", "A", "Klient przeżywa napięcie.", "observation", "s01"), nil
		}
		return bazowy(req)
	}
	res, err := Run(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if prob != MaxRegeneracji+1 {
		t.Fatalf("prob syntezy %d, oczekiwano %d (pierwsza + %d regeneracje)",
			prob, MaxRegeneracji+1, MaxRegeneracji)
	}
	if !res.Extractive {
		t.Fatal("raport nie przeszedl w tryb ekstraktywny mimo trwalego naruszenia")
	}
	if len(res.Violations) == 0 {
		t.Fatal("tryb ekstraktywny bez zapisanych naruszen — nie ma o czym alertowac")
	}
	// Raport ekstraktywny musi nadal niesc material, nie byc pusty.
	if len(res.Report.Constructs) == 0 {
		t.Fatal("raport ekstraktywny jest pusty")
	}
}

func TestRegeneracjaDostajeNaruszeniaDoPoprawy(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	prob := 0
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelSynthesis && konstruktZPromptu(req.SystemPrompt) == "" {
			prob++
			if prob == 1 {
				return jsonS4("konflikt", "A", "Klient przeżywa napięcie.", "observation", "s01"), nil
			}
			return jsonS4("konflikt", "A", "Materiał daje się czytać jako napięcie.",
				"interpretation", "s01"), nil
		}
		return bazowy(req)
	}
	res, err := Run(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if res.Extractive {
		t.Fatalf("poprawiona synteza wyladowala w trybie ekstraktywnym: %v", res.Violations)
	}
	// Druga proba musiala dostac konkret, nie sam kod reguly.
	var drugaTresc string
	n := 0
	for _, req := range f.Zapytal {
		if req.Model == ModelSynthesis && konstruktZPromptu(req.SystemPrompt) == "" {
			n++
			if n == 2 {
				drugaTresc = req.UserContent
			}
		}
	}
	if !strings.Contains(drugaTresc, string(VRuleHierarchy)) {
		t.Fatalf("regeneracja nie dostala naruszenia do poprawy:\n%s", drugaTresc)
	}
	if !strings.Contains(drugaTresc, "observation") {
		t.Fatal("opis naruszenia nie mowi, co konkretnie bylo zle")
	}
}

// TestZakresPewnosciPilnujeKod: granice liczbowe znikły ze schematów, bo
// Vertex odrzucał całe żądanie ("too many states for serving"). Zakres
// musi więc pilnować kod — inaczej pewność 1.7 dojechałaby do raportu.
func TestZakresPewnosciPilnujeKod(t *testing.T) {
	for _, tc := range []struct{ wejscie, oczekiwane float64 }{
		{-0.5, 0}, {0, 0}, {0.62, 0.62}, {1, 1}, {1.7, 1},
	} {
		if got := clampConfidence(tc.wejscie); got != tc.oczekiwane {
			t.Errorf("clampConfidence(%v) = %v, oczekiwano %v",
				tc.wejscie, got, tc.oczekiwane)
		}
	}
}

// TestSchematyBezOgraniczenRozsadzajacychVertexa pilnuje granicy, której
// przekroczenie kosztowało pełny przebieg na produkcji: górna granica
// długości tablicy zagnieżdżonych obiektów albo tablicy nad dużym enumem
// mnoży automat stanów Vertexa do odrzucenia CAŁEGO żądania.
func TestSchematyBezOgraniczenRozsadzajacychVertexa(t *testing.T) {
	spans := schemaS1()["properties"].(map[string]any)["spans"].(map[string]any)
	if _, ma := spans["maxItems"]; ma {
		t.Error("S1: tablica spanow znowu ma maxItems — Vertex odrzuci schemat na dluzszej sesji")
	}

	in, _ := materialS5()
	h := schemaS4(in)["properties"].(map[string]any)["constructs"].(map[string]any)["items"].(map[string]any)
	hip := h["properties"].(map[string]any)["hypotheses"].(map[string]any)["items"].(map[string]any)
	sup := hip["properties"].(map[string]any)["supporting"].(map[string]any)
	if _, ma := sup["maxItems"]; ma {
		t.Error("S4: `supporting` znowu ma maxItems nad enumem spanow")
	}
	if _, mi := sup["minItems"]; !mi {
		t.Error("S4: `supporting` straciło minItems — wymog proweniencji zniknal")
	}
}

// TestOdnosnikDoSpanuToNieLiczba — regres z kanarka PPT (2026-08-23):
// surowe dopasowanie cyfr brało "s08" za liczbę osiem i R9 odrzuciła
// siedem poprawnych twierdzeń, bo ich uzasadnienia wskazywały spany po
// numerze. Reguła chroniąca przed fabrykowaną precyzją kasowała dokładnie
// te twierdzenia, które najstaranniej wskazywały źródło.
func TestOdnosnikDoSpanuToNieLiczba(t *testing.T) {
	for _, tc := range []struct {
		tekst      string
		oczekiwane []string
	}{
		{"wynika ze spanu s08", nil},
		{"spany s40 i s39 mowia to samo", nil},
		{"klient ocenia to na 7 na 10", []string{"7", "10"}},
		{"w s12 pada 80%", []string{"80%"}},
		{"chunk3 nie jest liczba, ale 5 juz tak", []string{"5"}},
	} {
		got := ProseNumbers(tc.tekst)
		if len(got) != len(tc.oczekiwane) {
			t.Errorf("ProseNumbers(%q) = %v, oczekiwano %v", tc.tekst, got, tc.oczekiwane)
			continue
		}
		for i := range got {
			if got[i] != tc.oczekiwane[i] {
				t.Errorf("ProseNumbers(%q)[%d] = %q, oczekiwano %q",
					tc.tekst, i, got[i], tc.oczekiwane[i])
			}
		}
	}
}

// TestV2NieBlokujeSlownikaInnychKonstruktow — drugi regres z tego samego
// kanarka: "nadzieja" (wartość potencjalności pierwotnej) w akapicie o
// formie przetwarzania konfliktu wypchnęła raport w tryb ekstraktywny.
// To najzwyklejsze polskie słowo, użyte zgodnie z sensem.
func TestV2NieBlokujeSlownikaInnychKonstruktow(t *testing.T) {
	in, spans := materialS5()
	// "chwilowe" jest wartoscia konstruktu `niezdecydowanie`, nie `konflikt`.
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Napięcie ma charakter chwilowego wahania między dążnościami.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if maNaruszenie(v, VRuleForeign) {
		t.Fatalf("V2 zablokowala slowo z innego konstruktu: %s", opis(v))
	}
}

// TestV2NadalLapieSasiadaZTejSamejListy — zawężenie nie może wyłączyć
// reguły: sięgnięcie po sąsiednią kategorię TEGO SAMEGO konstruktu to
// dokładnie ryzyko, po które V2 istnieje.
func TestV2NadalLapieSasiadaZTejSamejListy(t *testing.T) {
	in, spans := materialS5()
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: "Materiał układa się w osiagniecia-odpoczynek.",
		Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
	}), in, spans)
	if !maNaruszenie(v, VRuleForeign) {
		t.Fatalf("V2 przepuscila niezatwierdzona kategorie TEGO SAMEGO konstruktu: %s", opis(v))
	}
}

// TestMultiLabelBezGornejGranicy — CBT `cognitive_distortion` ma 12
// wartości; górna granica długości NAD ENUMEM wywracała cały etap S2
// ("too many states for serving", kanarek 2026-08-23). Powtórki odsiewa
// teraz dedup przy dekodowaniu.
func TestMultiLabelBezGornejGranicy(t *testing.T) {
	o, err := ontology.Parse([]byte(`
modality: test
version: 1.0.0
constructs:
  zniekształcenie:
    label_pl: "Zniekształcenie"
    multi_label: true
    values: ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
`))
	if err != nil {
		t.Fatal(err)
	}
	sch, err := o.SchemaForConstruct("zniekształcenie", ontology.SchemaOptions{})
	if err != nil {
		t.Fatal(err)
	}
	kat := sch["properties"].(map[string]any)["claims"].(map[string]any)["items"].(map[string]any)["properties"].(map[string]any)["category"].(map[string]any)
	if _, ma := kat["maxItems"]; ma {
		t.Error("multi_label znowu ma maxItems nad enumem — Vertex odrzuci cały etap S2")
	}
	if _, mi := kat["minItems"]; !mi {
		t.Error("multi_label stracil minItems — pusta lista etykiet przestala byc bledem")
	}
}

func TestDedupEtykiet(t *testing.T) {
	got := dedupCategories([]string{"katastrofizacja", "imperatywy", "katastrofizacja", ""})
	if len(got) != 2 || got[0] != "katastrofizacja" || got[1] != "imperatywy" {
		t.Fatalf("dedupCategories = %v, oczekiwano [katastrofizacja imperatywy]", got)
	}
}

// TestV2NieBlokujeCzesciZatwierdzonejKategorii — regres z kanarka PPT:
// zatwierdzono `otwartość/szczerość`, a rejestr pomyłek notuje „szczerość"
// jako wariant nazwy. Raport, który napisał ZATWIERDZONĄ kategorię,
// wypadał na V2 za słowo, które sam w niej zawiera, i szedł w tryb
// ekstraktywny za różnicę kosmetyczną.
func TestV2NieBlokujeCzesciZatwierdzonejKategorii(t *testing.T) {
	o, err := ontology.Parse([]byte(`
modality: test
version: 1.0.0
constructs:
  potencjalnosc:
    label_pl: "Potencjalność"
    values: ["otwartość/szczerość", "punktualność"]
    min_evidence: {spans: 1}
    common_confusions:
      - {input: "szczerość", correct: "otwartość/szczerość"}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
`))
	if err != nil {
		t.Fatal(err)
	}
	in := SynthesisInput{Claims: []ontology.Claim{{
		ConstructID: "potencjalnosc",
		Categories:  []string{"otwartość/szczerość"},
		Status:      ontology.StatusInterpretation,
		Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "mówię wprost"}},
	}}}
	spans := map[string]ontology.Span{"s01": {ID: "s01", QuoteVerbatim: "mówię wprost"}}
	rep := Report{Constructs: []ConstructReport{{ConstructID: "potencjalnosc",
		Hypotheses: []Hypothesis{{ID: "A",
			Claim:      "Materiał wskazuje na szczerość jako sposób bycia w relacji.",
			Supporting: []string{"s01"}, EpistemicStatus: "interpretation"}}}}}

	if v := Verify(o, rep, in, spans); maNaruszenie(v, VRuleForeign) {
		t.Fatalf("V2 zablokowala slowo zawarte w ZATWIERDZONEJ kategorii: %s", opis(v))
	}
	// Sasiad z tej samej listy nadal ma byc lapany.
	rep.Constructs[0].Hypotheses[0].Claim = "Materiał wskazuje na punktualność."
	if v := Verify(o, rep, in, spans); !maNaruszenie(v, VRuleForeign) {
		t.Fatal("V2 przestala lapac niezatwierdzona kategorie tego samego konstruktu")
	}
}

// TestS4WieKtoreSpanyMowiaOPrzeszlosci — S4 był sądzony regułą V3, której
// nie miał jak spełnić: nie wiedział, który span mówi o przeszłości.
func TestS4WieKtoreSpanyMowiaOPrzeszlosci(t *testing.T) {
	in := SynthesisInput{
		Claims: []ontology.Claim{{
			ConstructID: "konflikt",
			Evidence: []ontology.QuoteRef{
				{SpanID: "s01", Quote: "teraz mi trudno"},
				{SpanID: "s07", Quote: "w dzieciństwie nikt nie pytał"},
			},
		}},
		PastSpanIDs: []string{"s07"},
	}
	tekst := renderSynthesisInput(in)
	if !strings.Contains(tekst, "[s07 PRZESZLOSC]") {
		t.Errorf("span o przeszlosci nie jest oznaczony:\n%s", tekst)
	}
	if strings.Contains(tekst, "[s01 PRZESZLOSC]") {
		t.Errorf("span BEZ przeszlosci dostal oznaczenie:\n%s", tekst)
	}
}

// TestPromptS4NiesieRegulaEtiologii: reguła, po której raport najczęściej
// wykłada się w tryb ekstraktywny, musi być w prompcie, a nie tylko w
// weryfikatorze.
func TestPromptS4NiesieRegulaEtiologii(t *testing.T) {
	for _, oczekiwane := range []string{"GENEZIE", "PRZESZŁOŚĆ", "next_session_questions"} {
		if !strings.Contains(promptS4Base, oczekiwane) {
			t.Errorf("prompt S4 nie zawiera %q — S4 jest sadzony regula, ktorej nie zna",
				oczekiwane)
		}
	}
}

// TestPrzycinanieRatujeResztePrezy — kanarek PPT: JEDNO zdanie o genezie
// wśród dwudziestu hipotez kasowało prozę pod wszystkimi. Przycięcie
// usuwa wadliwą hipotezę i zostawia resztę, która przeszła V1–V6.
func TestPrzycinanieRatujeResztePrezy(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelSynthesis && konstruktZPromptu(req.SystemPrompt) == "" {
			// Dwie hipotezy: druga uparcie podnosi status.
			return `{"constructs":[{"construct_id":"konflikt","hypotheses":[` +
				`{"id":"A","claim":"Materiał daje się czytać jako napięcie.",` +
				`"supporting":["s01"],"contradicting":[],"epistemic_status":"interpretation","confidence":0.6},` +
				`{"id":"B","claim":"Klient przeżywa napięcie.",` +
				`"supporting":["s01"],"contradicting":[],"epistemic_status":"observation","confidence":0.9}` +
				`],"unknown_yet":[],"next_session_questions":[],"pattern_notices":[]}]}`, nil
		}
		return bazowy(req)
	}
	res, err := Run(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if res.Extractive {
		t.Fatalf("caly raport poszedl w tryb ekstraktywny mimo jednej wadliwej hipotezy: %v",
			res.Violations)
	}
	if len(res.PrunedHypotheses) != 1 || res.PrunedHypotheses[0] != "konflikt/B" {
		t.Fatalf("usuniete = %v, oczekiwano [konflikt/B]", res.PrunedHypotheses)
	}
	// Dobra hipoteza MUSI zostac — inaczej przyciecie jest tylko drozszym
	// trybem ekstraktywnym.
	var zostale []string
	for _, cr := range res.Report.Constructs {
		for _, h := range cr.Hypotheses {
			zostale = append(zostale, cr.ConstructID+"/"+h.ID)
		}
	}
	if len(zostale) != 1 || zostale[0] != "konflikt/A" {
		t.Fatalf("zostale hipotezy = %v, oczekiwano [konflikt/A]", zostale)
	}
	// Naruszenia zostaja w wyniku: sygnal alarmowy nie moze zniknac.
	if len(res.Violations) == 0 {
		t.Fatal("przyciecie skasowalo slad naruszen — telemetria nic nie zobaczy")
	}
}

// TestPrzycinanieNieRatujeGdyWszystkoWadliwe — gdy nie zostaje żadna
// proza, raport ekstraktywny jest lepszy niż same puste sekcje: niesie
// przynajmniej cytaty i kategorie.
func TestPrzycinanieNieRatujeGdyWszystkoWadliwe(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelSynthesis && konstruktZPromptu(req.SystemPrompt) == "" {
			return jsonS4("konflikt", "A", "Klient przeżywa napięcie.", "observation", "s01"), nil
		}
		return bazowy(req)
	}
	res, err := Run(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if !res.Extractive {
		t.Fatal("raport bez ani jednej obronionej hipotezy nie poszedl w tryb ekstraktywny")
	}
}

// TestNaruszenieNiesieZdanieKtoreOdpadlo — rejestr ma powiedzieć, KTÓRE
// zdanie naruszyło regułę, a nie tylko że naruszyło. Bez tego strojenie
// promptu S4 opiera się na kodzie reguły i nazwie konstruktu, czyli na
// niczym.
//
// Treść doklejana jest w jednym miejscu dla wszystkich reguł — inaczej
// dodanie nowej cicho gubiłoby materiał do strojenia.
func TestNaruszenieNiesieZdanieKtoreOdpadlo(t *testing.T) {
	in, spans := materialS5()
	const zdanie = "Klient przeżywa napięcie między dwiema dążnościami."
	v := Verify(testO(t), raport(Hypothesis{
		ID: "A", Claim: zdanie,
		Supporting: []string{"s01"}, EpistemicStatus: "observation",
	}), in, spans)

	if len(v) == 0 {
		t.Fatal("brak naruszenia — test nie ma czego sprawdzic")
	}
	for _, n := range v {
		if n.HypothesisID == "" {
			continue // naruszenie na poziomie konstruktu
		}
		if n.HypothesisText != zdanie {
			t.Errorf("%s: tresc = %q, oczekiwano zdania, ktore odpadlo", n.Rule, n.HypothesisText)
		}
		if n.HypothesisStatus != "observation" {
			t.Errorf("%s: status = %q, oczekiwano observation", n.Rule, n.HypothesisStatus)
		}
		if len(n.HypothesisSpans) != 1 || n.HypothesisSpans[0] != "s01" {
			t.Errorf("%s: spany = %v, oczekiwano [s01]", n.Rule, n.HypothesisSpans)
		}
	}
}

// TestEtykietaMowcyToNieLiczba — wyszło z rejestru odrzuceń po migracji
// 000095, czyli dokładnie z mechanizmu, który po to powstał.
//
// Model uzasadniał twierdzenie zdaniem „Klientka (Speaker 2) opisuje
// swoje zachowanie…", a R9 czytała „2" jako liczbę bez pokrycia i
// kasowała całe twierdzenie. Etykieta mówcy pochodzi z NASZEGO
// renderowania spanów — model cytował to, co sam dostał.
func TestEtykietaMowcyToNieLiczba(t *testing.T) {
	for _, tc := range []struct {
		tekst      string
		oczekiwane []string
	}{
		{"Klientka (Speaker 2) opisuje swoje zachowanie", nil},
		{"Mówca 1 milczy, mówca 2 dopytuje", nil},
		{"prokrastynacja to ogniwo 4 łańcucha", nil},
		{"w sesji 3 wracał ten sam temat", nil},
		{"klient ocenia napięcie na 7", []string{"7"}},
		{"Speaker 2 mówi, że pije 3 razy w tygodniu", []string{"3"}},
	} {
		got := ProseNumbers(tc.tekst)
		if len(got) != len(tc.oczekiwane) {
			t.Errorf("ProseNumbers(%q) = %v, oczekiwano %v", tc.tekst, got, tc.oczekiwane)
			continue
		}
		for i := range got {
			if got[i] != tc.oczekiwane[i] {
				t.Errorf("ProseNumbers(%q)[%d] = %q, oczekiwano %q",
					tc.tekst, i, got[i], tc.oczekiwane[i])
			}
		}
	}
}

// TestPewnoscWymaganaTakzeWS4 — S4 przepisuje pewność z twierdzenia
// źródłowego, więc pominięcie pola gubi ją tak samo jak w S2.
func TestPewnoscWymaganaTakzeWS4(t *testing.T) {
	in, _ := materialS5()
	h := schemaS4(in)["properties"].(map[string]any)["constructs"].(map[string]any)["items"].(map[string]any)["properties"].(map[string]any)["hypotheses"].(map[string]any)["items"].(map[string]any)
	req, _ := h["required"].([]any)
	for _, r := range req {
		if r == "confidence" {
			return
		}
	}
	t.Fatalf("confidence nie jest wymagane w S4 (wymagane: %v)", req)
}

// Kanarki 24.08: przycinanie budowalo Report od zera i przenosilo same
// Constructs — sekcje generacyjne znikaly z KAZDEGO raportu, ktory
// przeszedl przez prune (czyli z kazdego z choc jednym naruszeniem V).
func TestPrzycinaniePrzenosiSekcjeGeneracyjne(t *testing.T) {
	rep := Report{
		Constructs: []ConstructReport{
			{ConstructID: "need", Hypotheses: []Hypothesis{{ID: "h1", Claim: "x"}, {ID: "h2", Claim: "y"}}},
			{ConstructID: "resource", Hypotheses: []Hypothesis{{ID: "h3", Claim: "z"}}},
		},
		Suggestions: []Suggestion{
			{Title: "A", BasisConstruct: "need"},
			{Title: "B", BasisConstruct: "resource"},
		},
		Interventions: []Intervention{
			{Name: "I1", BasisConstruct: "resource"},
		},
	}

	// Naruszenie na poziomie JEDNEJ hipotezy (klasa V2) — propozycje
	// maja przezyc w komplecie.
	po, _ := pruneViolating(rep, []Violation{
		{Rule: VRuleForeign, ConstructID: "need", HypothesisID: "h1"},
	})
	if len(po.Suggestions) != 2 || len(po.Interventions) != 1 {
		t.Fatalf("po przycieciu hipotezy: suggestions=%d interventions=%d, chcemy 2/1",
			len(po.Suggestions), len(po.Interventions))
	}

	// Konstrukt usuniety W CALOSCI — propozycja na nim oparta traci
	// ugruntowanie i idzie razem z nim; reszta zostaje.
	po, usuniete := pruneViolating(rep, []Violation{
		{Rule: VRuleUnknownConstruct, ConstructID: "resource"},
	})
	if len(po.Suggestions) != 1 || po.Suggestions[0].BasisConstruct != "need" {
		t.Fatalf("po usunieciu konstruktu: zostalo %v, chcemy tylko need", po.Suggestions)
	}
	if len(po.Interventions) != 0 {
		t.Fatalf("interwencja na usunietym konstrukcie ma zniknac, jest %v", po.Interventions)
	}
	znalezione := false
	for _, u := range usuniete {
		if u == "intervention/resource" {
			znalezione = true
		}
	}
	if !znalezione {
		t.Fatalf("rejestr usunietych nie odnotowal interwencji: %v", usuniete)
	}
}

// Kanarek 149156fb (24.08): JEDNO V5 na wzmiance wzorcowej zrzucalo caly
// raport do trybu ekstraktywnego, bo bramka przycietego raportu liczyla
// usuniete HIPOTEZY (`len(usuniete) > 0`), a przyciecie samej wzmianki
// niczego do niej nie dodaje. Rozstrzyga ponowna weryfikacja, nie licznik.
func TestV5NaWzmianceNieDajeTrybuEkstraktywnego(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelSynthesis && konstruktZPromptu(req.SystemPrompt) == "" {
			// Kazda proba: hipoteza CZYSTA + wzmianka o wzorcu, ktorego
			// S1.5 nie policzyl (V5 na notatce, bez HypothesisID).
			return `{"constructs":[{"construct_id":"konflikt","hypotheses":[{"id":"A",` +
				`"claim":"Materiał daje się czytać jako napięcie.",` +
				`"supporting":["s01"],"contradicting":[],` +
				`"epistemic_status":"interpretation","confidence":0.6}],` +
				`"unknown_yet":[],"next_session_questions":[],` +
				`"pattern_notices":["temat wraca trzeci raz"]}]}`, nil
		}
		return bazowy(req)
	}
	res, err := Run(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if res.Extractive {
		t.Fatalf("V5 na wzmiance zrzucil raport do trybu ekstraktywnego: %v",
			res.Violations)
	}
	var konflikt *ConstructReport
	for i := range res.Report.Constructs {
		if res.Report.Constructs[i].ConstructID == "konflikt" {
			konflikt = &res.Report.Constructs[i]
		}
	}
	if konflikt == nil || len(konflikt.Hypotheses) == 0 {
		t.Fatal("proza hipotez nie przetrwala przyciecia wzmianki")
	}
	if len(konflikt.PatternNotices) != 0 {
		t.Fatalf("wzmianka bez wzorca miala zostac przycieta: %v",
			konflikt.PatternNotices)
	}
}

// ── F7a-4: V7, ciaglosc miedzysesyjna ──

func wejscieZHistoria() SynthesisInput {
	return SynthesisInput{
		Claims: []ontology.Claim{{
			ConstructID: "konflikt",
			Categories:  []string{"blizkosc-autonomia"},
			Status:      ontology.StatusInterpretation,
			Evidence: []ontology.QuoteRef{
				{SpanID: "s01", Quote: "duszę się"},
				{SpanID: "s0821:s07", Quote: "wtedy też się dusiłem"},
			},
		}},
		EarlierSessionSpans: map[string]time.Time{
			"s0821:s07": time.Date(2026, 8, 21, 0, 0, 0, 0, time.UTC),
		},
	}
}

func raportZHipoteza(claim string, supporting ...string) Report {
	return Report{Constructs: []ConstructReport{{
		ConstructID: "konflikt",
		Hypotheses: []Hypothesis{{
			ID: "A", Claim: claim, Supporting: supporting,
			EpistemicStatus: "interpretation", Confidence: 0.6,
		}},
	}}}
}

// Zdanie o powrocie watku BEZ cytatu z tamtego spotkania jest
// twierdzeniem o historii, ktorego nikt nie sprawdzil.
func TestV7_CiaglascBezCytatuHistorycznego(t *testing.T) {
	in := wejscieZHistoria()
	spans := map[string]ontology.Span{
		"s01":       {ID: "s01", QuoteVerbatim: "duszę się", SessionID: "dzis"},
		"s0821:s07": {ID: "s0821:s07", QuoteVerbatim: "wtedy też się dusiłem", SessionID: "wczesniej"},
	}
	rep := raportZHipoteza(
		"Napięcie utrzymuje się między sesjami i wraca ponownie.", "s01")
	if v := Verify(testO(t), rep, in, spans); !maNaruszenie(v, VRuleContinuity) {
		t.Fatalf("V7 nie zlapal ciaglosci bez zakotwiczenia: %v", v)
	}
}

// Ta sama teza Z cytatem z tamtego spotkania przechodzi — o to chodzi
// w calym F7a.
func TestV7_CiaglascZCytatemHistorycznymPrzechodzi(t *testing.T) {
	in := wejscieZHistoria()
	spans := map[string]ontology.Span{
		"s01":       {ID: "s01", QuoteVerbatim: "duszę się", SessionID: "dzis"},
		"s0821:s07": {ID: "s0821:s07", QuoteVerbatim: "wtedy też się dusiłem", SessionID: "wczesniej"},
	}
	rep := raportZHipoteza(
		"Napięcie utrzymuje się między sesjami.", "s01", "s0821:s07")
	if v := Verify(testO(t), rep, in, spans); maNaruszenie(v, VRuleContinuity) {
		t.Fatalf("V7 odrzucil zakotwiczona ciaglosc: %v", v)
	}
}

// Potok jednosesyjny: regula SPI. Bez tego kazde zdanie ze slowem
// „wraca" padaloby w raportach, ktore nie maja zadnej historii.
func TestV7_SpiBezKontekstuHistorycznego(t *testing.T) {
	in := SynthesisInput{Claims: []ontology.Claim{{
		ConstructID: "konflikt",
		Categories:  []string{"blizkosc-autonomia"},
		Status:      ontology.StatusInterpretation,
		Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "duszę się"}},
	}}}
	spans := map[string]ontology.Span{
		"s01": {ID: "s01", QuoteVerbatim: "duszę się", SessionID: "dzis"},
	}
	rep := raportZHipoteza("Temat wraca ponownie w tej rozmowie.", "s01")
	if v := Verify(testO(t), rep, in, spans); maNaruszenie(v, VRuleContinuity) {
		t.Fatalf("V7 zadzialal bez kontekstu historycznego: %v", v)
	}
}

// Ustalenia i oznaczenia MUSZA byc widoczne w wejsciu S4 — model czyta
// tekst, nie strukture Go.
func TestWejscieS4NiesieUstaleniaIOznaczenia(t *testing.T) {
	in := wejscieZHistoria()
	in.PriorFindings = []PriorFinding{{
		ConstructID: "konflikt",
		Categories:  []string{"blizkosc-autonomia"},
		Status:      ontology.StatusInterpretation,
		Confidence:  0.7,
		SessionDate: time.Date(2026, 8, 21, 0, 0, 0, 0, time.UTC),
		Evidence:    []string{"s0821:s07"},
	}}
	tekst := renderSynthesisInput(in)
	for _, chce := range []string{
		"USTALENIA Z POPRZEDNICH SPOTKAN",
		"21.08 | konflikt: blizkosc-autonomia",
		// Oznaczenie przy cytacie: bez niego model nie wie, ze ten
		// konkretny cytat jest z innego spotkania.
		"s0821:s07 · SPOTKANIE 21.08",
		"NIE dowod",
	} {
		if !strings.Contains(tekst, chce) {
			t.Errorf("wejscie S4 bez %q:\n%s", chce, tekst)
		}
	}
}

// Kanarek 25.08: S4 dostawal ustalenia z poprzednich spotkan i regule
// „ciaglosc tylko z cytatem", ale enum dozwolonych spanow nie zawieral
// ANI JEDNEGO adresu historycznego. Model nie mial jak spelnic reguly —
// osiem zdan o ciaglosci padlo na V7 w jednym przebiegu.
func TestSchematS4DopuszczaAdresyHistoryczne(t *testing.T) {
	// Scenariusz DOKLADNIE z kanarka: kontekst historyczny zostal
	// pokazany przebiegowi, ale S2 nie oparl na nim zadnego
	// zatwierdzonego twierdzenia. Wczesniejsza wersja tego testu brala
	// wejscie, w ktorym adres siedzial w dowodach twierdzenia — czyli
	// trafial do enumu STARA sciezka i test przechodzil takze bez
	// poprawki (sprawdzone przez celowe zepsucie).
	in := SynthesisInput{
		Claims: []ontology.Claim{{
			ConstructID: "konflikt",
			Categories:  []string{"blizkosc-autonomia"},
			Status:      ontology.StatusInterpretation,
			Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "duszę się"}},
		}},
		EarlierSessionSpans: map[string]time.Time{
			"s0821:s07": time.Date(2026, 8, 21, 0, 0, 0, 0, time.UTC),
		},
	}
	schemat := schemaS4(in)
	props := schemat["properties"].(map[string]any)
	konstrukty := props["constructs"].(map[string]any)
	items := konstrukty["items"].(map[string]any)
	hip := items["properties"].(map[string]any)["hypotheses"].(map[string]any)
	hitems := hip["items"].(map[string]any)["properties"].(map[string]any)
	sup := hitems["supporting"].(map[string]any)
	enum, ok := sup["items"].(map[string]any)["enum"].([]any)
	if !ok {
		t.Fatal("brak enumu spanow w schemacie S4")
	}
	var maHistoryczny, maBiezacy bool
	for _, e := range enum {
		if e == "s0821:s07" {
			maHistoryczny = true
		}
		if e == "s01" {
			maBiezacy = true
		}
	}
	if !maHistoryczny {
		t.Errorf("enum bez adresu historycznego — regula V7 jest nie do spelnienia: %v", enum)
	}
	if !maBiezacy {
		t.Errorf("enum zgubil span biezacej sesji: %v", enum)
	}
}
