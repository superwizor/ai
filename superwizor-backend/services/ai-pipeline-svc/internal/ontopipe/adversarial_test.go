package ontopipe

import (
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Zestawy adversarialne dla R5 (etiologia) i R10 (granica terapeuty).
//
// DoD fazy F2: ZERO przepuszczen. Prog jest bezwzgledny, bo to sa dwie
// reguly, ktorych zlamanie widac w raporcie natychmiast i boli najbardziej
// — pierwsza produkuje spekulacje o dziecinstwie klienta ("mikrotrauma",
// "supermatka" z sekcji 2 dok. 11), druga zamienia superwizje w ocene
// terapeuty.
//
// Testujemy CALY lancuch: klasyfikator (classifyClaim) → walidator (R5/R10).
// Sam walidator nie wystarczy: on ufa fladze, a flage ustawia kod. Jesli
// klasyfikator przeoczy sformulowanie, R5 nigdy nie wystrzeli i test
// samego walidatora bedzie zielony przy dziurawym systemie.

// ── R5: etiologia bez spanu mowiacego wprost o przeszlosci ──

var etiologiaAdversarialna = []struct {
	nazwa string
	proza string
}{
	{"dziecinstwo wprost", "Wzorzec ukształtował się w dzieciństwie klienta."},
	{"dom rodzinny", "Klient wyniósł ten sposób reagowania z domu rodzinnego."},
	{"rodzina pochodzenia", "Trudność ma źródło w rodzinie pochodzenia."},
	{"od dziecka", "Od dziecka uczył się, że własne potrzeby są nieistotne."},
	{"jako dziecko", "Jako dziecko nie mógł liczyć na uwagę opiekunów."},
	{"wczesne doswiadczenia", "Wczesne doświadczenia relacyjne uformowały ten schemat."},
	{"korzenie", "Ten mechanizm ma korzenie w relacji z matką."},
	{"u zrodel", "U źródeł tego napięcia leży wczesna relacja z ojcem."},
	{"siega korzeniami", "Wzorzec sięga korzeniami do okresu dorastania."},
	{"z dziecinstwa", "To przekonanie pochodzi z dzieciństwa."},
	{"uksztaltowala", "Relacja z matką ukształtowała jego stosunek do bliskości."},
	{"wyniosla", "Wyniosła z domu przekonanie, że o wsparcie trzeba walczyć."},
}

func TestR5ZestawAdversarialny(t *testing.T) {
	o := testO(t)
	// Span NIE mowi o przeszlosci — kazde twierdzenie etiologiczne oparte
	// wylacznie na nim musi odpasc.
	spans := map[string]ontology.Span{
		"s01": {ID: "s01", SessionID: "sess", QuoteVerbatim: "trudno mi o tym mówić",
			AboutPast: false},
	}

	var przepuszczone []string
	for _, tc := range etiologiaAdversarialna {
		cl := ontology.Claim{
			ConstructID: "konflikt",
			Categories:  []string{"blizkosc-autonomia"},
			Status:      ontology.StatusInterpretation,
			Reasoning:   tc.proza,
			Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "trudno mi o tym mówić"}},
		}
		classifyClaim(&cl, spans)
		res := o.Validate3(ontology.StageResult{ConstructID: "konflikt",
			Claims: []ontology.Claim{cl}}, ontology.ValidateOptions{Spans: spans})

		if len(res.Approved) > 0 {
			przepuszczone = append(przepuszczone, tc.nazwa)
			continue
		}
		if len(res.Rejected) != 1 || res.Rejected[0].Reason != ontology.ReasonEtiology {
			przepuszczone = append(przepuszczone,
				tc.nazwa+" (odrzucone, ale nie przez R5: "+string(res.Rejected[0].Reason)+")")
		}
	}
	if len(przepuszczone) > 0 {
		t.Fatalf("R5 przepuscila %d/%d: %v", len(przepuszczone),
			len(etiologiaAdversarialna), przepuszczone)
	}
}

// TestR5NieBlokujeZeSpanemOPrzeszlosci: reguła ma odsiewać spekulację, a
// nie etiologię ugruntowaną. Bez tego testu „0 przepuszczeń" osiąga się
// trywialnie — odrzucając wszystko.
func TestR5NieBlokujeZeSpanemOPrzeszlosci(t *testing.T) {
	o := testO(t)
	spans := map[string]ontology.Span{
		"s07": {ID: "s07", SessionID: "sess",
			QuoteVerbatim: "w dzieciństwie nikt nie pytał mnie o zdanie", AboutPast: true},
	}
	for _, tc := range etiologiaAdversarialna {
		cl := ontology.Claim{
			ConstructID: "konflikt",
			Categories:  []string{"blizkosc-autonomia"},
			Status:      ontology.StatusInterpretation,
			Reasoning:   tc.proza,
			Evidence: []ontology.QuoteRef{{SpanID: "s07",
				Quote: "w dzieciństwie nikt nie pytał mnie o zdanie"}},
		}
		classifyClaim(&cl, spans)
		res := o.Validate3(ontology.StageResult{ConstructID: "konflikt",
			Claims: []ontology.Claim{cl}}, ontology.ValidateOptions{Spans: spans})
		if len(res.Approved) != 1 {
			t.Fatalf("%s: etiologia ZE spanem o przeszlosci odrzucona: %+v",
				tc.nazwa, res.Rejected)
		}
	}
}

// ── R10: twierdzenia, ktorych podmiotem jest terapeuta ──

var granicaTerapeutyAdversarialna = []struct {
	nazwa string
	proza string
}{
	{"terapeuta czuje", "Terapeuta czuje bezradność wobec milczenia klienta."},
	{"terapeutka odczuwa", "Terapeutka odczuwa narastającą frustrację w tej sesji."},
	{"lek terapeuty", "Jego lęk przed konfrontacją powstrzymuje terapeutę od pytania."},
	{"kontrtransfer", "Reakcja terapeuty ma charakter kontrtransferencyjny."},
	{"terapeuta przezywa", "Terapeuta przeżywa tę scenę jako atak na siebie."},
	{"terapeuta boi sie", "Terapeuta boi się poruszyć temat straty."},
	{"terapeuta ma poczucie", "Terapeuta ma poczucie, że traci kontakt z klientem."},
	{"zniecierpliwienie", "W głosie terapeuty słychać zniecierpliwienie tym wątkiem."},
	{"bezradnosc prowadzacego", "Bezradność prowadzącego sesję udziela się klientowi."},
	{"frustracja superwizora", "Frustracja superwizora wobec tempa pracy jest wyczuwalna."},
}

func TestR10ZestawAdversarialny(t *testing.T) {
	o := testO(t)
	spans := map[string]ontology.Span{
		"s01": {ID: "s01", SessionID: "sess", QuoteVerbatim: "trudno mi o tym mówić",
			ObservedBy: ontology.ObservedByTherapist},
	}

	var przepuszczone []string
	for _, tc := range granicaTerapeutyAdversarialna {
		cl := ontology.Claim{
			ConstructID: "konflikt",
			Categories:  []string{"blizkosc-autonomia"},
			Status:      ontology.StatusInterpretation,
			Reasoning:   tc.proza,
			Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "trudno mi o tym mówić"}},
		}
		classifyClaim(&cl, spans)
		res := o.Validate3(ontology.StageResult{ConstructID: "konflikt",
			Claims: []ontology.Claim{cl}}, ontology.ValidateOptions{Spans: spans})

		if len(res.Approved) > 0 {
			przepuszczone = append(przepuszczone, tc.nazwa)
			continue
		}
		if res.Rejected[0].Reason != ontology.ReasonTherapist {
			przepuszczone = append(przepuszczone,
				tc.nazwa+" (odrzucone przez "+string(res.Rejected[0].Reason)+", nie R10)")
		}
	}
	if len(przepuszczone) > 0 {
		t.Fatalf("R10 przepuscila %d/%d: %v", len(przepuszczone),
			len(granicaTerapeutyAdversarialna), przepuszczone)
	}
}

// TestR10NieBlokujeObserwacjiTerapeutyOKliencie: wypowiedzi terapeuty
// pozostaja legalnymi DOWODAMI. Zakaz dotyczy twierdzen, ktorych PODMIOTEM
// jest terapeuta — nie tego, kto obserwowal.
func TestR10NieBlokujeObserwacjiTerapeutyOKliencie(t *testing.T) {
	o := testO(t)
	spans := map[string]ontology.Span{
		"s01": {ID: "s01", SessionID: "sess",
			QuoteVerbatim: "zauważyłem, że pan milknie przy tym temacie",
			ObservedBy:    ontology.ObservedByTherapist},
	}
	cl := ontology.Claim{
		ConstructID: "konflikt",
		Categories:  []string{"blizkosc-autonomia"},
		Status:      ontology.StatusInterpretation,
		Reasoning:   "Terapeuta obserwuje, że klient milknie przy temacie bliskości.",
		Evidence: []ontology.QuoteRef{{SpanID: "s01",
			Quote: "zauważyłem, że pan milknie przy tym temacie"}},
	}
	classifyClaim(&cl, spans)
	res := o.Validate3(ontology.StageResult{ConstructID: "konflikt",
		Claims: []ontology.Claim{cl}}, ontology.ValidateOptions{Spans: spans})
	if len(res.Approved) != 1 {
		t.Fatalf("obserwacja terapeuty O KLIENCIE odrzucona przez R10: %+v", res.Rejected)
	}
}
