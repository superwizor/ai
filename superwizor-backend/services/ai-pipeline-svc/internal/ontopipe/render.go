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

	if o.ReportProfile != nil && len(o.ReportProfile.Layout) > 0 {
		renderLayout(&b, o, res, in)
		return b.String()
	}

	for _, sekcja := range sectionOrder(o) {
		switch sekcja {
		case ontology.SectionSessionSummary:
			renderSummary(&b, in.SummaryShort)
		case ontology.SectionInterpretive:
			renderInterpretive(&b, o, res, nil)
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

// renderLayout renderuje uklad nazwanych sekcji (M5+).
//
// NIEZBYWALNY niezmiennik: uklad nigdy nie ukrywa zweryfikowanej tresci.
// Konstrukty nieprzypisane do zadnej sekcji laduja w sekcji koncowej,
// a pytania, wzmianki o wzorcach i no_fit — jesli uklad ich nie
// przewidzial — sa doklejane z tytulami domyslnymi. Ekspert steruje
// KSZTALTEM, nie tym, co terapeuta zobaczy.
func renderLayout(b *strings.Builder, o *ontology.Ontology, res Result, in RenderInput) {
	przypisane := map[string]bool{}
	pokryte := map[string]bool{}
	for _, sec := range o.ReportProfile.Layout {
		pokryte[sec.Kind] = true
		for _, id := range sec.Constructs {
			przypisane[id] = true
		}
	}

	for _, sec := range o.ReportProfile.Layout {
		switch sec.Kind {
		case ontology.LayoutSummary:
			renderSummarySection(b, sec.Title, in.SummaryShort, res)
		case ontology.LayoutConstructs:
			naleza := map[string]bool{}
			for _, id := range sec.Constructs {
				naleza[id] = true
			}
			renderTitled(b, sec.Title, func(bb *strings.Builder) bool {
				return renderInterpretive(bb, o, res, naleza)
			})
		case ontology.LayoutSuggestions:
			renderSuggestions(b, o, sec.Title, res.Report.Suggestions)
		case ontology.LayoutInterventions:
			renderInterventions(b, o, sec.Title, res.Report.Interventions)
		case ontology.LayoutOverlooked:
			renderOverlooked(b, o, sec.Title, res)
		case ontology.LayoutQuestions:
			renderTitled(b, sec.Title, func(bb *strings.Builder) bool {
				return renderQuestionsBody(bb, o, res)
			})
		case ontology.LayoutPatterns:
			renderTitled(b, sec.Title, func(bb *strings.Builder) bool {
				return renderPatternsBody(bb, o, res)
			})
		case ontology.LayoutOutOfTaxonomy:
			renderTitled(b, sec.Title, func(bb *strings.Builder) bool {
				return renderNoFitBody(bb, o, res)
			})
		}
	}

	// ── nigdy nie ukrywaj ──
	nieprzypisane := map[string]bool{}
	maNieprzypisane := false
	for _, cr := range res.Constructsy() {
		if !przypisane[cr.ConstructID] {
			nieprzypisane[cr.ConstructID] = true
			maNieprzypisane = true
		}
	}
	if maNieprzypisane {
		renderTitled(b, "Pozostałe obserwacje", func(bb *strings.Builder) bool {
			return renderInterpretive(bb, o, res, nieprzypisane)
		})
	}
	if !pokryte[ontology.LayoutQuestions] {
		renderTitled(b, "Pytania i niewiadome", func(bb *strings.Builder) bool {
			return renderQuestionsBody(bb, o, res)
		})
	}
	if !pokryte[ontology.LayoutPatterns] {
		renderTitled(b, "Powiązania i wzorce", func(bb *strings.Builder) bool {
			return renderPatternsBody(bb, o, res)
		})
	}
	if !pokryte[ontology.LayoutOutOfTaxonomy] {
		renderTitled(b, "Poza obecną taksonomią", func(bb *strings.Builder) bool {
			return renderNoFitBody(bb, o, res)
		})
	}
}

// renderTitled renderuje sekcje z tytulem WYLACZNIE, gdy tresc istnieje —
// pusta sekcja znika razem z naglowkiem.
func renderTitled(b *strings.Builder, title string, body func(*strings.Builder) bool) {
	var tmp strings.Builder
	if !body(&tmp) {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	b.WriteString(tmp.String())
}

// renderSummarySection to esencja + kotwice pamieciowe.
//
// Kotwice wybiera KOD: cytaty dowodowe twierdzen o najwyzszej pewnosci,
// bez powtorzen spanow, maksymalnie cztery. Zaden model nie decyduje,
// co jest kotwica — dowod juz przeszedl weryfikacje mechaniczna i S3.
func renderSummarySection(b *strings.Builder, title, summary string, res Result) {
	kotwice := pickAnchors(res.Approved, 4)
	if strings.TrimSpace(summary) == "" && len(kotwice) == 0 {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	if strings.TrimSpace(summary) != "" {
		b.WriteString(strings.TrimSpace(summary))
		b.WriteString("\n\n")
	}
	if len(kotwice) > 0 {
		b.WriteString("**Kotwice pamięciowe**\n\n")
		for _, k := range kotwice {
			fmt.Fprintf(b, "> %s\n\n", k.Quote)
		}
	}
}

type anchor struct{ Quote string }

func pickAnchors(claims []ontology.Claim, limit int) []anchor {
	posortowane := append([]ontology.Claim{}, claims...)
	sort.SliceStable(posortowane, func(i, j int) bool {
		return posortowane[i].Confidence > posortowane[j].Confidence
	})
	widziane := map[string]bool{}
	var out []anchor
	for _, c := range posortowane {
		for _, q := range c.Evidence {
			if widziane[q.SpanID] || strings.TrimSpace(q.Quote) == "" {
				continue
			}
			widziane[q.SpanID] = true
			out = append(out, anchor{Quote: q.Quote})
			break // jeden cytat na twierdzenie — kotwice maja byc ROZNE
		}
		if len(out) == limit {
			break
		}
	}
	return out
}

func renderSuggestions(b *strings.Builder, o *ontology.Ontology, title string, sug []Suggestion) {
	if len(sug) == 0 {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	for _, s := range sug {
		fmt.Fprintf(b, "**%s**\n\n", s.Title)
		fmt.Fprintf(b, "Rozwija: %s. Cel: %s.\n\n", labelFor(o, s.BasisConstruct), s.Target)
		fmt.Fprintf(b, "%s\n\n", s.Instruction)
	}
}

func renderInterventions(b *strings.Builder, o *ontology.Ontology, title string, iv []Intervention) {
	if len(iv) == 0 {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	for _, i := range iv {
		fmt.Fprintf(b, "**%s**\n\n", i.Name)
		fmt.Fprintf(b, "Opiera się na: %s. Zanim zastosujesz, zweryfikuj: %s\n\n",
			labelFor(o, i.BasisConstruct), i.VerifyFirst)
		fmt.Fprintf(b, "%s\n\n", i.Scenario)
	}
	b.WriteString("_Propozycje warunkowe — decyzja i odpowiedzialność należą do terapeuty._\n\n")
}

// renderOverlooked to "czego mozna bylo nie zauwazyc" — zlozone w KODZIE
// z materialu, ktory juz przeszedl potok: kontrdowody zatwierdzonych
// twierdzen, zjawiska poza taksonomia, konstrukty zdegradowane. To sa
// dokladnie funkcje D1 ("ten fragment przeczy...", "tego moglas nie
// zauwazyc") zebrane w jedno miejsce.
func renderOverlooked(b *strings.Builder, o *ontology.Ontology, title string, res Result) {
	var tmp strings.Builder
	widziane := map[string]bool{}
	for _, c := range res.Approved {
		for _, q := range c.CounterEvidence {
			if widziane[q.SpanID] || strings.TrimSpace(q.Quote) == "" {
				continue
			}
			widziane[q.SpanID] = true
			fmt.Fprintf(&tmp, "> %s\n\n— przeczy: %s\n\n", q.Quote, labelFor(o, c.ConstructID))
		}
	}
	for _, id := range res.NoFit {
		fmt.Fprintf(&tmp, "- %s: zjawisko nie mieści się w taksonomii — odnotowane bez etykiety\n", labelFor(o, id))
	}
	for _, d := range res.Degraded {
		fmt.Fprintf(&tmp, "- %s: %s\n", labelFor(o, d.ConstructID), d.To)
	}
	if tmp.Len() == 0 {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	b.WriteString(tmp.String())
	b.WriteString("\n")
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

// renderInterpretive renderuje konstrukty; `tylko` != nil zaweza do
// wskazanych (uklad), nil = wszystkie (kompozycja domyslna). Zwraca, czy
// cokolwiek wypisano. W trybie ukladu naglowki konstruktow schodza
// poziom nizej (###), bo sekcje ukladu zajmuja poziom ##.
func renderInterpretive(b *strings.Builder, o *ontology.Ontology, res Result, tylko map[string]bool) bool {
	naglowek := "## %s\n\n"
	if tylko != nil {
		naglowek = "### %s\n\n"
	}
	cokolwiek := false
	for _, cr := range res.Constructsy() {
		if tylko != nil && !tylko[cr.ConstructID] {
			continue
		}
		cokolwiek = true
		fmt.Fprintf(b, naglowek, labelFor(o, cr.ConstructID))

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
	return cokolwiek
}

// renderPatterns agreguje meta-obserwacje w jedna sekcje.
//
// Nazwa "Powiazania i wzorce" za dok. 11 §4. Kazda wzmianka jest
// podpisana konstruktem, bo wyrwana z kontekstu przestaje mowic, CZEGO
// dotyczy powtarzalnosc. Same wzorce S1.5 tu nie wchodza: wzorzec nigdy
// nie jest teza i moze wystapic wylacznie jako wzmianka, ktora przeszla
// S4 i V5.
func renderPatterns(b *strings.Builder, o *ontology.Ontology, res Result) {
	renderTitled(b, "Powiązania i wzorce", func(bb *strings.Builder) bool {
		return renderPatternsBody(bb, o, res)
	})
}

func renderPatternsBody(b *strings.Builder, o *ontology.Ontology, res Result) bool {
	cokolwiek := false
	for _, cr := range res.Constructsy() {
		for _, p := range cr.PatternNotices {
			cokolwiek = true
			fmt.Fprintf(b, "- **%s:** %s\n", labelFor(o, cr.ConstructID), p)
		}
	}
	if cokolwiek {
		b.WriteString("\n")
	}
	return cokolwiek
}

// renderQuestions agreguje niewiadome i pytania na kolejna sesje.
//
// Format przestrzeni hipotez traktuje pola bez danych jako ZAPROSZENIE
// ("co warto sprawdzic"), nie blad — sekcja zbiera je w jednym miejscu,
// zeby terapeuta przygotowujacy kolejna sesje nie zbieral ich po calym
// dokumencie.
func renderQuestions(b *strings.Builder, o *ontology.Ontology, res Result) {
	renderTitled(b, "Pytania i niewiadome", func(bb *strings.Builder) bool {
		return renderQuestionsBody(bb, o, res)
	})
}

func renderQuestionsBody(b *strings.Builder, o *ontology.Ontology, res Result) bool {
	cokolwiek := false
	for _, cr := range res.Constructsy() {
		if len(cr.UnknownYet) == 0 && len(cr.NextSessionQuestions) == 0 {
			continue
		}
		cokolwiek = true
		fmt.Fprintf(b, "**%s**\n\n", labelFor(o, cr.ConstructID))
		for _, u := range cr.UnknownYet {
			fmt.Fprintf(b, "- %s\n", u)
		}
		for _, q := range cr.NextSessionQuestions {
			fmt.Fprintf(b, "- Warto sprawdzić: %s\n", q)
		}
		b.WriteString("\n")
	}
	return cokolwiek
}

func renderNoFit(b *strings.Builder, o *ontology.Ontology, res Result) {
	renderTitled(b, "Poza obecną taksonomią", func(bb *strings.Builder) bool {
		return renderNoFitBody(bb, o, res)
	})
}

func renderNoFitBody(b *strings.Builder, o *ontology.Ontology, res Result) bool {
	if len(res.NoFit) == 0 {
		return false
	}
	b.WriteString("W materiale pojawiły się zjawiska, których obecna ontologia " +
		"nie obejmuje. Zostały odnotowane bez nadawania im kategorii:\n\n")
	for _, id := range res.NoFit {
		fmt.Fprintf(b, "- %s\n", labelFor(o, id))
	}
	b.WriteString("\n")
	return true
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
