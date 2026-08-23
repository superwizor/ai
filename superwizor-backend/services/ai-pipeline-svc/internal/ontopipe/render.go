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
func RenderMarkdown(o *ontology.Ontology, res Result) string {
	var b strings.Builder

	if res.Extractive {
		// Tryb ekstraktywny musi byc OZNACZONY w samym raporcie, nie
		// tylko w telemetrii. Terapeuta ma prawo wiedziec, ze dostaje
		// material surowy, bo synteza nie przeszla weryfikacji.
		b.WriteString("> **Raport w trybie ekstraktywnym.** Synteza nie przeszła " +
			"weryfikacji wyjścia, więc poniżej znajdziesz zatwierdzone kategorie " +
			"wraz z cytatami, bez prozy interpretacyjnej.\n\n")
	}

	for _, cr := range res.Constructsy() {
		c := o.Constructs[cr.ConstructID]
		nazwa := cr.ConstructID
		if c != nil && c.LabelPL != "" {
			nazwa = c.LabelPL
		}
		fmt.Fprintf(&b, "## %s\n\n", nazwa)

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
			fmt.Fprintf(&b, "**Hipoteza %s** _(%s", h.ID, st)
			if h.Confidence > 0 {
				fmt.Fprintf(&b, ", pewność %.0f%%", h.Confidence*100)
			}
			b.WriteString(")_\n\n")
			fmt.Fprintf(&b, "%s\n\n", h.Claim)

			if len(h.Supporting) > 0 {
				fmt.Fprintf(&b, "- Dane za: %s\n", strings.Join(h.Supporting, ", "))
			}
			if len(h.Contradicting) > 0 {
				// Dane przeciw sa FUNKCJA raportu, nie jego defektem —
				// "ten fragment przeczy pierwszej hipotezie" to jedna z
				// rzeczy, po ktore terapeuta siega.
				fmt.Fprintf(&b, "- Dane przeciw: %s\n", strings.Join(h.Contradicting, ", "))
			}
			b.WriteString("\n")
		}

		if len(cr.PatternNotices) > 0 {
			b.WriteString("**Powtarzalność w materiale**\n\n")
			for _, p := range cr.PatternNotices {
				fmt.Fprintf(&b, "- %s\n", p)
			}
			b.WriteString("\n")
		}
		if len(cr.UnknownYet) > 0 {
			b.WriteString("**Czego jeszcze nie wiemy**\n\n")
			for _, u := range cr.UnknownYet {
				fmt.Fprintf(&b, "- %s\n", u)
			}
			b.WriteString("\n")
		}
		if len(cr.NextSessionQuestions) > 0 {
			b.WriteString("**Warto sprawdzić na kolejnej sesji**\n\n")
			for _, q := range cr.NextSessionQuestions {
				fmt.Fprintf(&b, "- %s\n", q)
			}
			b.WriteString("\n")
		}
	}

	if len(res.NoFit) > 0 {
		b.WriteString("## Poza obecną taksonomią\n\n")
		b.WriteString("W materiale pojawiły się zjawiska, których obecna ontologia " +
			"nie obejmuje. Zostały odnotowane bez nadawania im kategorii:\n\n")
		for _, id := range res.NoFit {
			nazwa := id
			if c := o.Constructs[id]; c != nil && c.LabelPL != "" {
				nazwa = c.LabelPL
			}
			fmt.Fprintf(&b, "- %s\n", nazwa)
		}
		b.WriteString("\n")
	}
	return b.String()
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
