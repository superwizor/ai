package ontopipe

import (
	"fmt"
	"sort"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Rendering raportu do markdownu.
//
// Robi to KOD, nie model. Struktura przestrzeni hipotez jest juz
// rozstrzygnieta w S4 i sprawdzona w S5 — oddanie modelowi jeszcze
// jednego przebiegu "na ladny zapis" otwieraloby droge do zmiany tresci
// po weryfikacji, czyli omijalo caly potok tylnymi drzwiami.
//
// ══ Kompozycja sekcji (M5, dok. 15 §3.3) ══
//
// Raport sklada sie z nazwanych sekcji, a `report_profile` ontologii
// steruje ich KOLEJNOSCIA (wagi high/normal/low). Waga nigdy nie ukrywa
// tresci — ukrycie zweryfikowanej tresci byloby decyzja o tresci, a M5
// zmienia wylacznie kompozycje. Sekcja pusta znika sama.
//
// Kompozycja jest wlasnoscia ONTOLOGII, nie promptu: edytuje sie ja w
// Ontology Studio, przechodzi przez wersjonowanie i four-eyes jak kazda
// inna zmiana, a diff K4 ja pokazuje. To odpowiedz na pytanie "jak
// edytowac sekcje raportu" — nie przez prompt, ktory jest baza legacy,
// tylko przez profil w tresci, ktora i tak podlega przegladowi.

// RenderInput to dane spoza wyniku potoku, ktore raport wolno pokazac.
type RenderInput struct {
	// SummaryShort z call-1 — sekcja "Bilans sesji". To STRESZCZENIE
	// przebiegu, nie wnioskowanie: call-1 liczy je dla kazdego raportu
	// (takze eksperymentalnego), wiec sekcja nie omija potoku — pokazuje
	// material, ktory istnieje niezaleznie od niego.
	SummaryShort string
}

// statusPL nazywa status epistemiczny w jezyku raportu.
//
// Rozroznienie ma byc WIDOCZNE: terapeuta czyta raport, zeby wiedziec,
// co jest zapisem, a co interpretacja. Ukrycie tej roznicy w jednolitej
// prozie znosi glowna wartosc formatu.
var statusPL = map[ontology.EpistemicStatus]string{
	ontology.StatusObservation:           "obserwacja",
	ontology.StatusInterpretation:        "interpretacja",
	ontology.StatusTheoreticalHypothesis: "hipoteza teoretyczna",
	ontology.StatusOpenQuestion:          "pytanie otwarte",
	ontology.StatusInsufficientData:      "brak wystarczających danych",
	ontology.StatusNoFit:                 "poza taksonomią",
}

// RenderMarkdown sklada raport z wyniku potoku.
func RenderMarkdown(o *ontology.Ontology, res Result, in RenderInput) string {
	var b strings.Builder

	if res.Extractive {
		// Tryb ekstraktywny musi byc OZNACZONY w samym raporcie, nie
		// tylko w telemetrii — i PRZED kompozycja: ostrzezenie nie jest
		// sekcja, ktorej kolejnosc profil moglby zepchnac na dol.
		b.WriteString("> **Raport w trybie ekstraktywnym.** Synteza nie przeszła " +
			"weryfikacji wyjścia, więc poniżej znajdziesz zatwierdzone kategorie " +
			"wraz z cytatami, bez prozy interpretacyjnej.\n\n")
	}

	for _, sekcja := range sectionOrder(o) {
		switch sekcja {
		case ontology.SectionSessionSummary:
			renderSummary(&b, in.SummaryShort)
		case ontology.SectionInterpretive:
			renderInterpretive(&b, o, res)
		case ontology.SectionPatterns:
			renderPatterns(&b, o, res)
		case ontology.SectionOpenQuestions:
			renderQuestions(&b, o, res)
		case ontology.SectionOutOfTaxonomy:
			renderNoFit(&b, o, res)
		}
	}
	return b.String()
}

// sectionOrder zwraca sekcje w kolejnosci wynikajacej z profilu.
//
// Sortowanie STABILNE po kubelkach wag: remisy zachowuja kolejnosc
// kanoniczna z ontology.ReportSections. Dwa przebiegi na tej samej
// ontologii daja ten sam dokument — inaczej benchmark porownuje szum.
func sectionOrder(o *ontology.Ontology) []string {
	waga := func(sekcja string) int {
		if o.ReportProfile == nil {
			return 1
		}
		sec, ok := o.ReportProfile.Sections[sekcja]
		if !ok {
			return 1
		}
		switch sec.Weight {
		case ontology.WeightHigh:
			return 0
		case ontology.WeightLow:
			return 2
		default:
			return 1
		}
	}
	out := append([]string{}, ontology.ReportSections...)
	sort.SliceStable(out, func(i, j int) bool { return waga(out[i]) < waga(out[j]) })
	return out
}

func renderSummary(b *strings.Builder, summary string) {
	if strings.TrimSpace(summary) == "" {
		return
	}
	b.WriteString("## Bilans sesji\n\n")
	b.WriteString(strings.TrimSpace(summary))
	b.WriteString("\n\n")
}

func renderInterpretive(b *strings.Builder, o *ontology.Ontology, res Result) {
	for _, cr := range res.Constructsy() {
		fmt.Fprintf(b, "## %s\n\n", labelFor(o, cr.ConstructID))

		if len(cr.Hypotheses) == 0 {
			// Pole bez twierdzen renderuje sie jako ZAPROSZENIE, nie jako
			// blad. Raport wypelniony w 100% jest sygnalem alarmowym.
			b.WriteString("Na obecnym etapie brak wystarczających danych.\n\n")
		}

		for _, h := range cr.Hypotheses {
			st := statusPL[ontology.EpistemicStatus(h.EpistemicStatus)]
			if st == "" {
				st = h.EpistemicStatus
			}
			fmt.Fprintf(b, "**Hipoteza %s** _(%s", h.ID, st)
			if h.Confidence > 0 {
				fmt.Fprintf(b, ", pewność %.0f%%", h.Confidence*100)
			}
			b.WriteString(")_\n\n")
			fmt.Fprintf(b, "%s\n\n", h.Claim)

			if len(h.Supporting) > 0 {
				fmt.Fprintf(b, "- Dane za: %s\n", strings.Join(h.Supporting, ", "))
			}
			if len(h.Contradicting) > 0 {
				// Dane przeciw sa FUNKCJA raportu, nie jego defektem —
				// "ten fragment przeczy pierwszej hipotezie" to jedna z
				// rzeczy, po ktore terapeuta siega.
				fmt.Fprintf(b, "- Dane przeciw: %s\n", strings.Join(h.Contradicting, ", "))
			}
			b.WriteString("\n")
		}
	}
}

// renderPatterns agreguje meta-obserwacje w jedna sekcje.
//
// Nazwa "Powiazania i wzorce" za dok. 11 §4. Kazda wzmianka jest
// podpisana konstruktem, bo wyrwana z kontekstu przestaje mowic, CZEGO
// dotyczy powtarzalnosc. Same wzorce S1.5 tu nie wchodza: wzorzec nigdy
// nie jest teza i moze wystapic wylacznie jako wzmianka, ktora przeszla
// S4 i V5.
func renderPatterns(b *strings.Builder, o *ontology.Ontology, res Result) {
	var ma bool
	for _, cr := range res.Constructsy() {
		if len(cr.PatternNotices) > 0 {
			ma = true
		}
	}
	if !ma {
		return
	}
	b.WriteString("## Powiązania i wzorce\n\n")
	for _, cr := range res.Constructsy() {
		for _, p := range cr.PatternNotices {
			fmt.Fprintf(b, "- **%s:** %s\n", labelFor(o, cr.ConstructID), p)
		}
	}
	b.WriteString("\n")
}

// renderQuestions agreguje niewiadome i pytania na kolejna sesje.
//
// Format przestrzeni hipotez traktuje pola bez danych jako ZAPROSZENIE
// ("co warto sprawdzic"), nie blad — sekcja zbiera je w jednym miejscu,
// zeby terapeuta przygotowujacy kolejna sesje nie zbieral ich po calym
// dokumencie.
func renderQuestions(b *strings.Builder, o *ontology.Ontology, res Result) {
	var ma bool
	for _, cr := range res.Constructsy() {
		if len(cr.UnknownYet) > 0 || len(cr.NextSessionQuestions) > 0 {
			ma = true
		}
	}
	if !ma {
		return
	}
	b.WriteString("## Pytania i niewiadome\n\n")
	for _, cr := range res.Constructsy() {
		if len(cr.UnknownYet) == 0 && len(cr.NextSessionQuestions) == 0 {
			continue
		}
		fmt.Fprintf(b, "**%s**\n\n", labelFor(o, cr.ConstructID))
		for _, u := range cr.UnknownYet {
			fmt.Fprintf(b, "- %s\n", u)
		}
		for _, q := range cr.NextSessionQuestions {
			fmt.Fprintf(b, "- Warto sprawdzić: %s\n", q)
		}
		b.WriteString("\n")
	}
}

func renderNoFit(b *strings.Builder, o *ontology.Ontology, res Result) {
	if len(res.NoFit) == 0 {
		return
	}
	b.WriteString("## Poza obecną taksonomią\n\n")
	b.WriteString("W materiale pojawiły się zjawiska, których obecna ontologia " +
		"nie obejmuje. Zostały odnotowane bez nadawania im kategorii:\n\n")
	for _, id := range res.NoFit {
		fmt.Fprintf(b, "- %s\n", labelFor(o, id))
	}
	b.WriteString("\n")
}

func labelFor(o *ontology.Ontology, id string) string {
	if c := o.Constructs[id]; c != nil && c.LabelPL != "" {
		return c.LabelPL
	}
	return id
}

// Constructsy zwraca sekcje raportu w kolejnosci deterministycznej.
//
// Kolejnosc alfabetyczna po identyfikatorze, a nie kolejnosc zwrocona
// przez model: dwa przebiegi na tym samym materiale maja dac ten sam
// dokument, inaczej benchmark porownuje szum.
func (r Result) Constructsy() []ConstructReport {
	out := append([]ConstructReport{}, r.Report.Constructs...)
	sort.Slice(out, func(i, j int) bool { return out[i].ConstructID < out[j].ConstructID })
	return out
}
