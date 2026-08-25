package llmworker

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

func dzien(d int) time.Time {
	return time.Date(2026, 8, d, 0, 0, 0, 0, time.UTC)
}

// Okno bierze W najnowszych sesji ZAKONCZONYCH.
func TestOknoBierzeNajnowszeUkonczone(t *testing.T) {
	kandydaci := []kandydatSesji{
		{ID: uuid.New(), Data: dzien(20), Numer: 5, Status: "COMPLETED"},
		{ID: uuid.New(), Data: dzien(15), Numer: 4, Status: "COMPLETED"},
		{ID: uuid.New(), Data: dzien(10), Numer: 3, Status: "COMPLETED"},
		{ID: uuid.New(), Data: dzien(5), Numer: 2, Status: "COMPLETED"},
	}
	wybrane, pominiete := wybierzOkno(kandydaci, 3)
	if len(wybrane) != 3 {
		t.Fatalf("wybrano %d sesji, chcemy 3", len(wybrane))
	}
	if !wybrane[0].Data.Equal(dzien(20)) || !wybrane[2].Data.Equal(dzien(10)) {
		t.Fatalf("zla kolejnosc okna: %v", wybrane)
	}
	if pominiete != 0 {
		t.Fatalf("pominiete w toku = %d, chcemy 0", pominiete)
	}
}

// N4: sesja WCIAZ PRZETWARZANA jest pomijana i LICZONA.
//
// Nie czekamy na nia — czekanie na sesje, ktora utknela, zablokowaloby
// kazdy kolejny raport tej kartoteki. Ale pominiecie musi byc widoczne,
// inaczej "model tego nie polaczyl" jest nierozroznialne od "model tego
// nie zobaczyl".
func TestOknoPomijaSesjeWTokuILiczyJe(t *testing.T) {
	kandydaci := []kandydatSesji{
		{ID: uuid.New(), Data: dzien(20), Numer: 5, Status: "ANALYZING"},
		{ID: uuid.New(), Data: dzien(15), Numer: 4, Status: "TRANSCRIBING"},
		{ID: uuid.New(), Data: dzien(10), Numer: 3, Status: "COMPLETED"},
		{ID: uuid.New(), Data: dzien(5), Numer: 2, Status: "COMPLETED"},
	}
	wybrane, pominiete := wybierzOkno(kandydaci, 3)
	if len(wybrane) != 2 {
		t.Fatalf("wybrano %d sesji, chcemy 2 ukonczone", len(wybrane))
	}
	if pominiete != 2 {
		t.Fatalf("pominiete w toku = %d, chcemy 2", pominiete)
	}
}

// Sesje zakonczone bez raportu (FAILED / CANCELED) sa pomijane po
// cichu: nigdy zadnego twierdzenia nie wniosly i nie wniosa, wiec nie
// sa brakiem, ktory trzeba tlumaczyc terapeucie.
func TestOknoNieLiczyNieudanych(t *testing.T) {
	kandydaci := []kandydatSesji{
		{ID: uuid.New(), Data: dzien(20), Numer: 5, Status: "FAILED"},
		{ID: uuid.New(), Data: dzien(15), Numer: 4, Status: "CANCELLED_BY_USER"},
		{ID: uuid.New(), Data: dzien(10), Numer: 3, Status: "COMPLETED"},
	}
	wybrane, pominiete := wybierzOkno(kandydaci, 3)
	if len(wybrane) != 1 || pominiete != 0 {
		t.Fatalf("wybrane=%d pominiete=%d, chcemy 1/0", len(wybrane), pominiete)
	}
}

func twierdzenie(dzienSesji int, pewnosc float64, adresy ...string) ontopipe.PastClaim {
	return ontopipe.PastClaim{
		ID: uuid.New(), SessionID: uuid.New(), SessionDate: dzien(dzienSesji),
		ConstructID: "konflikt", Confidence: pewnosc, Evidence: adresy,
	}
}

func span(dzienSesji int, addr string) ontopipe.PastSpan {
	return ontopipe.PastSpan{Addr: addr, SessionID: uuid.New(),
		SessionDate: dzien(dzienSesji), Quote: "cytat " + addr}
}

// Budzet tnie NAJSTARSZE i NAJMNIEJ PEWNE, nie przypadkowe.
func TestBudzetTnieNajstarszeINajmniejPewne(t *testing.T) {
	claims := []ontopipe.PastClaim{
		twierdzenie(10, 0.9, "s0810:a"),
		twierdzenie(20, 0.4, "s0820:b"),
		twierdzenie(20, 0.8, "s0820:c"),
	}
	spany := []ontopipe.PastSpan{
		span(10, "s0810:a"), span(20, "s0820:b"), span(20, "s0820:c"),
	}
	poClaims, poSpany, odrzC, odrzS := przytnijBudzet(claims, spany, 2, 10)
	if len(poClaims) != 2 || odrzC != 1 {
		t.Fatalf("twierdzenia=%d odrzucone=%d, chcemy 2/1", len(poClaims), odrzC)
	}
	// Zostaja: nowsza sesja (20) — najpierw pewniejsze.
	if poClaims[0].Evidence[0] != "s0820:c" || poClaims[1].Evidence[0] != "s0820:b" {
		t.Fatalf("zla kolejnosc po przycieciu: %v", poClaims)
	}
	// Span osieroconego twierdzenia schodzi razem z nim.
	if len(poSpany) != 2 || odrzS != 0 {
		t.Fatalf("spany=%d odrzucone=%d, chcemy 2/0", len(poSpany), odrzS)
	}
	for _, s := range poSpany {
		if s.Addr == "s0810:a" {
			t.Error("span przycietego twierdzenia zostal w kontekscie")
		}
	}
}

// Twierdzenie, ktoremu budzet spanow zabral WSZYSTKIE cytaty, wypada
// z kontekstu: "ustalenie" bez ani jednego dowodu jest dokladnie tym,
// czego potok zabrania w kazdym innym miejscu.
func TestTwierdzenieBezPokazanegoDowoduWypada(t *testing.T) {
	claims := []ontopipe.PastClaim{
		twierdzenie(20, 0.9, "s0820:a"),
		twierdzenie(20, 0.8, "s0820:b"),
	}
	spany := []ontopipe.PastSpan{span(20, "s0820:a"), span(20, "s0820:b")}
	poClaims, poSpany, odrzC, odrzS := przytnijBudzet(claims, spany, 10, 1)
	if len(poSpany) != 1 || odrzS != 1 {
		t.Fatalf("spany=%d odrzucone=%d, chcemy 1/1", len(poSpany), odrzS)
	}
	if len(poClaims) != 1 || odrzC != 1 {
		t.Fatalf("twierdzenia=%d odrzucone=%d, chcemy 1/1", len(poClaims), odrzC)
	}
	if poClaims[0].Evidence[0] != poSpany[0].Addr {
		t.Fatal("twierdzenie wskazuje na cytat, ktorego w kontekscie nie ma")
	}
}

// Ten sam material daje ten sam kontekst — inaczej benchmark
// porownywalby szum selekcji, a nie jakosc wnioskowania. Remis na dacie
// i pewnosci rozstrzyga identyfikator, wiec kolejnosc jest ustalona.
func TestPrzycinanieJestPowtarzalne(t *testing.T) {
	idA := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	idB := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	idC := uuid.MustParse("33333333-3333-3333-3333-333333333333")

	zbuduj := func() ([]ontopipe.PastClaim, []ontopipe.PastSpan) {
		mk := func(id uuid.UUID, addr string) ontopipe.PastClaim {
			return ontopipe.PastClaim{ID: id, SessionDate: dzien(20),
				ConstructID: "konflikt", Confidence: 0.5, Evidence: []string{addr}}
		}
		// Kolejnosc wejscia CELOWO odwrotna do oczekiwanej.
		return []ontopipe.PastClaim{
				mk(idC, "s0820:c"), mk(idA, "s0820:a"), mk(idB, "s0820:b"),
			}, []ontopipe.PastSpan{
				span(20, "s0820:c"), span(20, "s0820:a"), span(20, "s0820:b"),
			}
	}

	var poprzedni []string
	for proba := 0; proba < 3; proba++ {
		claims, spany := zbuduj()
		wynik, _, _, _ := przytnijBudzet(claims, spany, 2, 10)
		var kolejnosc []string
		for _, c := range wynik {
			kolejnosc = append(kolejnosc, c.ID.String())
		}
		if proba == 0 {
			if len(kolejnosc) != 2 || kolejnosc[0] != idA.String() ||
				kolejnosc[1] != idB.String() {
				t.Fatalf("remis nie rozstrzygniety identyfikatorem: %v", kolejnosc)
			}
			poprzedni = kolejnosc
			continue
		}
		if len(kolejnosc) != len(poprzedni) {
			t.Fatalf("proba %d dala inna liczbe twierdzen", proba)
		}
		for i := range kolejnosc {
			if kolejnosc[i] != poprzedni[i] {
				t.Fatalf("proba %d dala inna kolejnosc: %v vs %v",
					proba, kolejnosc, poprzedni)
			}
		}
	}
}
