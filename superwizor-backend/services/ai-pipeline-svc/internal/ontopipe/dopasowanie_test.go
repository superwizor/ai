package ontopipe

import (
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Dopasowanie znacznikow dzialalo jak WOREK SLOW: slowa frazy mogly lezec
// w dowolnych miejscach tekstu, a krotkie slowo pasowalo jako podciag
// innego slowa. "od dziecka" znajdowalo sie wiec w kazdym zdaniu, ktore
// mialo gdziekolwiek "od" (odpoczynek, podzial) i jakiekolwiek "dzieci"
// (kanarek PPT 2026-09-28). Zdania ponizej sa wymyslone — testuja
// mechanizm, nie konkretna sesje.

func TestZnacznikiEtiologiiTylkoJakoCiaglaFraza(t *testing.T) {
	nieEtiologiczne := []string{
		"Klient mówi o zmęczeniu po pracy i o tym, że wieczorem odpoczywa z dziećmi.",
		"Podział zadań w zespole obejmuje też opiekę nad dzieckiem sąsiadki.",
		"Jako rodzic klient planuje wakacje z dziećmi.",
		"Rodzinne spotkania w domu klient uważa za męczące.",
	}
	for _, s := range nieEtiologiczne {
		if m := firstTermPresent(s, etiologyMarkers); m != "" {
			t.Errorf("falszywy znacznik etiologii %q w: %s", m, s)
		}
	}

	etiologiczne := []string{
		"Klient od dziecka unikał sporów.",
		"W dzieciństwie często się przeprowadzał.",
		"W domu rodzinnym nie mówiło się o pieniądzach.",
		"Jako dziecko opiekował się młodszym bratem.",
		"Przekonanie ukształtowało się bardzo wcześnie.",
		"Wyniósł z domu nawyk oszczędzania.",
		"Ta obawa ma korzenie w szkolnych doświadczeniach.",
	}
	for _, s := range etiologiczne {
		if m := firstTermPresent(s, etiologyMarkers); m == "" {
			t.Errorf("przeoczony znacznik etiologii w: %s", s)
		}
	}
}

func TestGranicaTerapeutyWObrebieZdania(t *testing.T) {
	przypadki := []struct {
		uzasadnienie string
		terapeuta    bool
	}{
		// "prowadzi" bralo sie za "prowadzacy" (rdzen obciety do
		// "prowadz"), a "ma poczucie" skladalo sie z "ma" w dowolnym
		// slowie i "poczucie" z innego miejsca.
		{"Klient odczuwa napięcie przed egzaminem, co prowadzi do unikania nauki.", false},
		{"Marta opisuje swoje poczucie winy, co prowadzi do przeprosin.", false},
		// Oba znaczniki, ale w roznych zdaniach i o roznych osobach.
		{"Klient czuje niepokój. Terapeutka proponuje ćwiczenie oddechowe.", false},
		// Prawdziwe twierdzenia o terapeucie.
		{"Terapeuta czuje zniecierpliwienie wobec milczenia klienta.", true},
		{"Prowadząca sesję odczuwa frustrację, gdy klient zmienia temat.", true},
		{"Widać, że terapeutka ma poczucie bezradności.", true},
	}
	for _, p := range przypadki {
		cl := ontology.Claim{Reasoning: p.uzasadnienie}
		classifyClaim(&cl, nil)
		if cl.SubjectIsTherapist != p.terapeuta {
			t.Errorf("SubjectIsTherapist=%v, oczekiwano %v: %s",
				cl.SubjectIsTherapist, p.terapeuta, p.uzasadnienie)
		}
	}
}

func TestFrazaWielowyrazowaMusiBycCiagla(t *testing.T) {
	przypadki := []struct {
		tekst, termin string
		jest          bool
	}{
		{"Brakuje mu troski o siebie.", "troska o siebie", true},
		{"Troska o dom pochłania go, a dla siebie nie ma chwili.", "troska o siebie", false},
		{"Na poprzedniej sesji klient mówił o tym samym.", "poprzedniej sesji", true},
		{"W poprzedniej pracy było podobnie, a na sesji wraca to w innej formie.", "poprzedniej sesji", false},
		{"Być może chodzi o lęk przed oceną.", "byc moze", true},
		{"Nie mogę być tam, gdzie możemy się spotkać.", "byc moze", false},
		{"Wzorzec dotyczy tematu nieobecności w domu.", "nieobecność w domu", true},
		// Krotkie slowo dopasowuje sie jako CALE slowo, nie podciag.
		{"Czasami wraca później.", "czas", false},
		{"Nie ma na to czas.", "czas", true},
	}
	for _, p := range przypadki {
		if got := firstTermPresent(p.tekst, []string{p.termin}) != ""; got != p.jest {
			t.Errorf("%q w %q: %v, oczekiwano %v", p.termin, p.tekst, got, p.jest)
		}
	}
}
