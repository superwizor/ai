package ontopipe

import (
	"context"
	"strings"
	"testing"

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
	if v := Verify(testO(t), rep, in, spans); !maNaruszenie(v, VRuleHierarchy) {
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
