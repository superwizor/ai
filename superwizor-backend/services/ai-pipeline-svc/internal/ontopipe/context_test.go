package ontopipe

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

func data(d int) time.Time {
	return time.Date(2026, 8, d, 0, 0, 0, 0, time.UTC)
}

// Adres miedzysesyjny musi rozrozniac spany o tym samym `span_ref`
// z roznych sesji — lokalny ref jest unikalny tylko w transkrypcji.
func TestAdresSpanuNiesieDate(t *testing.T) {
	a := SpanAddr(data(21), "s07")
	b := SpanAddr(data(5), "s07")
	if a != "s0821:s07" {
		t.Fatalf("adres = %q, chcemy s0821:s07", a)
	}
	if a == b {
		t.Fatal("ten sam ref z roznych sesji dostal ten sam adres")
	}
	if b != "s0805:s07" {
		t.Fatalf("dzien jednocyfrowy bez zera wiodacego: %q", b)
	}
}

// Rekurencja miedzysesyjna pyta, w ILU SESJACH wystapilo haslo — temat
// powtorzony piec razy w jednej sesji jest watkiem rozmowy, w trzech
// sesjach jest wzorcem.
func TestLiczenieHaselPoSesjach(t *testing.T) {
	p := &PastContext{SessionTopics: []PastSessionTopics{
		{SessionID: uuid.New(), Topics: []string{"praca", "praca", "matka"}},
		{SessionID: uuid.New(), Topics: []string{"praca"}},
	}}
	licznik := p.TopicSessionCounts()
	if licznik["praca"] != 2 {
		t.Errorf("praca w %d sesjach, chcemy 2 (powtorzenie w jednej sesji nie liczy sie podwojnie)",
			licznik["praca"])
	}
	if licznik["matka"] != 1 {
		t.Errorf("matka w %d sesjach, chcemy 1", licznik["matka"])
	}
}

// Nil-owy kontekst to NORMALNY stan (pierwsza sesja kartoteki), wiec
// wszystkie odczyty musza go znosic bez paniki.
func TestPustyKontekstJestBezpieczny(t *testing.T) {
	var p *PastContext
	if p.SessionCount() != 0 {
		t.Error("SessionCount na nil")
	}
	if len(p.TopicSessionCounts()) != 0 {
		t.Error("TopicSessionCounts na nil")
	}
	if len(p.ClaimsForConstruct("x")) != 0 {
		t.Error("ClaimsForConstruct na nil")
	}
	if _, ok := p.SpanByAddr("s0821:s07"); ok {
		t.Error("SpanByAddr na nil zwrocil trafienie")
	}
}

// S2 dostaje ustalenia WLASNEGO konstruktu, najnowsze pierwsze.
func TestUstaleniaPerKonstruktNajnowszePierwsze(t *testing.T) {
	p := &PastContext{Claims: []PastClaim{
		{ID: uuid.New(), ConstructID: "konflikt", SessionDate: data(10),
			Status: ontology.StatusInterpretation},
		{ID: uuid.New(), ConstructID: "zasob", SessionDate: data(20)},
		{ID: uuid.New(), ConstructID: "konflikt", SessionDate: data(20)},
	}}
	got := p.ClaimsForConstruct("konflikt")
	if len(got) != 2 {
		t.Fatalf("twierdzen konstruktu = %d, chcemy 2", len(got))
	}
	if !got[0].SessionDate.Equal(data(20)) {
		t.Fatal("najnowsze ustalenie nie jest pierwsze")
	}
}

// S2 widzi WYLACZNIE spany, ktore uziemialy TEN konstrukt.
//
// Rozdzial poziomow pojeciowych jest powodem, dla ktorego S2 jest wolane
// osobno na konstrukt — pokazanie kazdemu konstruktowi calej historii
// cofneloby ten rozdzial i pomnozylo koszt przez liczbe konstruktow.
func TestSpanyHistoryczneZawezoneDoKonstruktu(t *testing.T) {
	p := &PastContext{
		Claims: []PastClaim{
			{ID: uuid.New(), ConstructID: "konflikt", SessionDate: data(21),
				Evidence: []string{"s0821:s07"}},
			{ID: uuid.New(), ConstructID: "zasob", SessionDate: data(21),
				Evidence: []string{"s0821:s09"}},
		},
		Spans: []PastSpan{
			{Addr: "s0821:s07", SessionDate: data(21), Quote: "o konflikcie"},
			{Addr: "s0821:s09", SessionDate: data(21), Quote: "o zasobie"},
		},
	}
	got := p.SpansForConstruct("konflikt")
	if len(got) != 1 || got[0].Addr != "s0821:s07" {
		t.Fatalf("spany konstruktu = %v, chcemy wylacznie s0821:s07", got)
	}
	if len(p.SpansForConstruct("nieznany")) != 0 {
		t.Error("konstrukt bez historii dostal spany")
	}
}
