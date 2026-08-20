package chat

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/appconfig"
)

// Regresja incydentu z 20.08.2026.
//
// Terapeuta dostal odmowe P2_MED, kliknal oferowana alternatywe
// "Pokaz cytaty na ten temat" i dostal sekcje "Wzmianki o 'ten Janko'"
// z prawdziwym cytatem "jeszcze raz ten Janko jaki ten?".
//
// Nic w tym nie bylo halucynacja: cytat przeszedl weryfikator
// deterministyczny, wiec naprawde padl. Zawiodlo pobieranie — pytanie
// skladalo sie wylacznie ze slow o samej prosbie, a wsrod nich "ten",
// ktore trafilo w krotki segment (punktacja premiuje krotkie).
func TestPrefillWithoutTopicIsNotSearched(t *testing.T) {
	// Dokladnie te teksty, ktore serwer oferuje po odmowie.
	for _, q := range []string{
		"Pokaż cytaty na ten temat",
		"Pokaż fragmenty sesji na ten temat",
		"Znajdź fragmenty na ten temat",
	} {
		if terms := SearchableTerms(q); len(terms) != 0 {
			t.Errorf("%q daje terminy %v — powinno byc puste, bo nie niesie tematu", q, terms)
		}
	}
}

// A prawdziwe pytanie kliniczne musi dalej dawac terminy — inaczej
// lekarstwo byloby gorsze od choroby.
func TestRealQuestionsStillProduceTerms(t *testing.T) {
	cases := map[string]string{
		"Kiedy mówiła o pracy?":                "prac",
		"Pokaż fragmenty o relacji z matką":    "matk",
		"Co mówił o lęku przed wystąpieniami?": "lek",
		"Znajdź cytaty o poczuciu winy":        "win",
	}
	for q, want := range cases {
		terms := SearchableTerms(q)
		if len(terms) == 0 {
			t.Errorf("%q nie dalo zadnych terminow", q)
			continue
		}
		var found bool
		for _, term := range terms {
			if strings.HasPrefix(term, want) || strings.HasPrefix(want, term) {
				found = true
			}
		}
		if !found {
			t.Errorf("%q -> %v, brak terminu zblizonego do %q", q, terms, want)
		}
	}
}

// Slowo "ten" nie moze byc terminem wyszukiwania: pasuje wszedzie.
func TestDemonstrativesAreNotSearchTerms(t *testing.T) {
	for _, w := range []string{"ten", "ta", "to", "tego", "tym", "taki"} {
		if terms := SearchableTerms("Pokaż " + w); len(terms) != 0 {
			t.Errorf("%q przetrwalo jako termin: %v", w, terms)
		}
	}
}

// Cala tura: pytanie bez tematu ma prosic o doprecyzowanie, a nie
// zwracac dowolny fragment.
func TestTopiclessQuestionAsksForClarification(t *testing.T) {
	segs := sampleSegments()
	// Segment krotki i pelen "ten" — dokladnie ten, ktory wygral
	// poprzednio.
	segs = append(segs, Segment{
		ID: uuid.New(), SessionID: segs[0].SessionID,
		Text: "jeszcze raz ten Janko jaki ten?", Speaker: "KLIENT",
		TsStartMs: 99000, SessionAt: segs[0].SessionAt,
	})
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A1_SEARCH","confidence":0.9,"risk_flag":false}`,
	}, segs)

	tq := turn()
	tq.Question = "Pokaż fragmenty sesji na ten temat"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Answer == nil || len(out.Answer.Sections) == 0 {
		t.Fatal("brak odpowiedzi")
	}
	body := out.Answer.Sections[0].Title + " " + out.Answer.Sections[0].Body
	if strings.Contains(body, "Janko") {
		t.Errorf("odpowiedz nadal siega po przypadkowy segment: %q", body)
	}
	if !strings.Contains(strings.ToLower(body), "doprecyzuj") {
		t.Errorf("oczekiwano prosby o doprecyzowanie, jest: %q", body)
	}
	// I zadne wywolanie generatora — nie ma czego generowac.
	if len(h.llm.calls) > 1 {
		t.Errorf("%d wywolan modelu; wystarczy klasyfikator", len(h.llm.calls))
	}
	_ = appconfig.KeyAIChatEnabled
}
