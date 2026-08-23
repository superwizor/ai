package ontology

import "testing"

const transkrypcja = `[KLIENT] Ciągle myślę, że i tak wszystko się posypie.
[TERAPEUTA] Co się dzieje w ciele, kiedy tak myślisz?
[KLIENT] Jak szef nic nie powie, to znaczy, że coś jest nie tak.
[KLIENT] I believe I am not good enough for this job.`

func TestCytatDoslownyPrzechodzi(t *testing.T) {
	ok, sim := VerifyQuote(transkrypcja, "i tak wszystko się posypie", DefaultQuoteThreshold)
	if !ok {
		t.Errorf("doslowny cytat odrzucony (podobienstwo %.2f)", sim)
	}
}

// TestRoznicaInterpunkcjiIWielkosciLiterPrzechodzi — transkrypcja mowy
// stawia interpunkcje niekonsekwentnie; to nie jest fabrykacja.
func TestRoznicaInterpunkcjiIWielkosciLiterPrzechodzi(t *testing.T) {
	for _, cytat := range []string{
		"Ciągle myślę że i tak wszystko się posypie",
		"CIĄGLE MYŚLĘ, ŻE I TAK WSZYSTKO SIĘ POSYPIE",
		"ciągle  myślę,   że i tak   wszystko się posypie",
	} {
		if ok, sim := VerifyQuote(transkrypcja, cytat, DefaultQuoteThreshold); !ok {
			t.Errorf("%q odrzucone (podobienstwo %.2f)", cytat, sim)
		}
	}
}

// TestTlumaczenieJestOdrzucane to przypadek z produkcji: 21.08 model
// przetlumaczyl angielski cytat na polski, a weryfikator czatu slusznie
// to zablokowal. Ta sama klasa bledu nie moze przejsc w raporcie.
func TestTlumaczenieJestOdrzucane(t *testing.T) {
	ok, sim := VerifyQuote(transkrypcja,
		"Wierzę, że nie jestem wystarczająco dobry do tej pracy", DefaultQuoteThreshold)
	if ok {
		t.Errorf("tlumaczenie cytatu przeszlo (podobienstwo %.2f)", sim)
	}
}

// TestZmianaSlowaJestOdrzucana — pojedyncze slowo zmienia znaczenie,
// wiec prog musi byc na tyle wysoki, zeby to zlapac.
func TestZmianaSlowaJestOdrzucana(t *testing.T) {
	ok, sim := VerifyQuote(transkrypcja,
		"Ciągle myślę, że i tak wszystko się ułoży", DefaultQuoteThreshold)
	if ok {
		t.Errorf("podmienione slowo przeszlo (podobienstwo %.2f)", sim)
	}
}

// TestWstawienieSlowaJestOdrzucane — miara pozycyjna karze wstawienie
// natychmiast; odleglosc edycyjna by je wybaczyla.
func TestWstawienieSlowaJestOdrzucane(t *testing.T) {
	ok, sim := VerifyQuote(transkrypcja,
		"Ciągle bardzo myślę, że i tak wszystko się posypie", DefaultQuoteThreshold)
	if ok {
		t.Errorf("wstawione slowo przeszlo (podobienstwo %.2f)", sim)
	}
}

func TestZmyslonyCytatJestOdrzucany(t *testing.T) {
	ok, _ := VerifyQuote(transkrypcja,
		"Moja matka zawsze wymagała ode mnie perfekcji", DefaultQuoteThreshold)
	if ok {
		t.Error("cytat, ktorego nie ma w transkrypcji, przeszedl")
	}
}

func TestPustyCytatJestOdrzucany(t *testing.T) {
	if ok, _ := VerifyQuote(transkrypcja, "", DefaultQuoteThreshold); ok {
		t.Error("pusty cytat przeszedl")
	}
	if ok, _ := VerifyQuote(transkrypcja, "   ", DefaultQuoteThreshold); ok {
		t.Error("cytat z samych spacji przeszedl")
	}
}

func TestCytatDluzszyNizZrodloJestOdrzucany(t *testing.T) {
	if ok, _ := VerifyQuote("krótko", "znacznie dłuższy tekst niż źródło", DefaultQuoteThreshold); ok {
		t.Error("cytat dluzszy niz transkrypcja przeszedl")
	}
}

// TestOgonkiNieSaIgnorowane — usuniecie diakrytykow przepuscilo by
// "sąd" jako "sad". To sa rozne slowa.
//
// Para MUSI miec rowna dlugosc: przy roznej odrzuca ja sam pomiar
// pozycyjny, wiec test przechodzilby niezaleznie od normalizacji i nie
// bronilby niczego. Pierwsza wersja tego testu uzywala "może"/"morze" i
// miala wlasnie ta wade.
func TestOgonkiNieSaIgnorowane(t *testing.T) {
	if ok, sim := VerifyQuote("to był sąd nad nim", "to był sad nad nim",
		DefaultQuoteThreshold); ok {
		t.Errorf("podmiana ogonka zmieniajaca slowo przeszla (podobienstwo %.2f)", sim)
	}
}

func TestVerifySpansOdsiewaIRaportuje(t *testing.T) {
	spany := []Span{
		{ID: "ok1", QuoteVerbatim: "i tak wszystko się posypie"},
		{ID: "zle1", QuoteVerbatim: "czegoś takiego nigdy nie powiedział"},
		{ID: "ok2", QuoteVerbatim: "coś jest nie tak"},
	}
	przyjete, odrzucone := VerifySpans(transkrypcja, spany, 0)
	if len(przyjete) != 2 {
		t.Errorf("przyjetych %d, oczekiwano 2", len(przyjete))
	}
	if len(odrzucone) != 1 || odrzucone[0] != "zle1" {
		t.Errorf("odrzucone = %v, oczekiwano [zle1]", odrzucone)
	}
}
