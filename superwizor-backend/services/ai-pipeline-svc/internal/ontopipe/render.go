package ontopipe

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"

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
// inna zmiana, a diff K4 ja pokazuje.
//
// ══ Jezyk raportu (2026-08-24) ══
//
// Raport wychodzi W JEZYKU KARTOTEKI (sessions.report_language), nie w
// jezyku ontologii. Ontologia moze byc polska (szkic CBT), a kartoteka
// angielska — proza S4 dostaje instrukcje jezykowa, a caly chrome
// renderera (naglowki, etykiety, baner trybu ekstraktywnego) przechodzi
// przez tabele `chrome`. Tytuly sekcji ukladu i etykiety konstruktow
// pochodza z ontologii: dla en uzywamy `title_en`/`label_en`, gdy autor
// je podal, z fallbackiem na wersje polska — brak tlumaczenia jest
// widoczny w raporcie, wiec sam sie zglasza ekspertowi.

// RenderInput to dane spoza wyniku potoku, ktore raport wolno pokazac.
type RenderInput struct {
	// SummaryShort z call-1 — sekcja "Bilans sesji". To STRESZCZENIE
	// przebiegu, nie wnioskowanie: call-1 liczy je dla kazdego raportu
	// (takze eksperymentalnego), wiec sekcja nie omija potoku — pokazuje
	// material, ktory istnieje niezaleznie od niego.
	SummaryShort string
	// Language to jezyk raportu z kartoteki (sessions.report_language,
	// np. "pl", "en-US"). Pusty = polski (zgodnosc wsteczna).
	Language string
	// Past to kontekst miedzysesyjny pokazany temu przebiegowi (F7a).
	// Renderer potrzebuje go, zeby cytat historyczny przywolany przez
	// S4 mial TRESC i DATE — bez tego odnosnik `s0821:s07` wypadalby
	// z raportu po cichu, bo nie ma go wsrod spanow biezacej sesji.
	Past *PastContext
}

// chrome to WSZYSTKIE stale napisy renderera w jednym jezyku.
//
// Jedna struktura zamiast rozsypanych literalow: dodanie napisu bez
// tlumaczenia nie ma jak przejsc niezauwazone, bo pole musi istniec w
// obu instancjach.
type chrome struct {
	statusy map[ontology.EpistemicStatus]string

	// dateFmt to format daty cytatu historycznego (referencyjny czas Go).
	dateFmt          string
	extractiveBanner string
	pozostale        string
	pytania          string
	wzorce           string
	pozaTaksonomia   string
	kotwice          string
	bilans           string
	rozwijaCel       string // fmt: label, target
	opieraSie        string // fmt: label, verify_first
	stopkaWarunkowa  string
	przeczy          string // fmt: label (po cytacie kontrdowodu)
	noFitOdnotowane  string // fmt: label
	brakDanych       string
	hipoteza         string // fmt: id
	pewnosc          string // fmt: %.0f
	wartoSprawdzic   string // fmt: pytanie
	noFitWstep       string
	// T42b (docs/67 par. 4): linie ciaglosci i rozliczenie.
	kontWzmacnia   string // fmt: data
	kontOslabia    string // fmt: data
	kontBezDanych  string // fmt: data
	rozliczenieTyt string
	werdykty       map[string]string // werdykt -> etykieta
}

var chromePL = chrome{
	statusy: map[ontology.EpistemicStatus]string{
		ontology.StatusObservation:           "obserwacja",
		ontology.StatusInterpretation:        "interpretacja",
		ontology.StatusTheoreticalHypothesis: "hipoteza teoretyczna",
		ontology.StatusOpenQuestion:          "pytanie otwarte",
		ontology.StatusInsufficientData:      "brak wystarczających danych",
		ontology.StatusNoFit:                 "poza taksonomią",
	},
	dateFmt: "02.01",
	extractiveBanner: "> **Raport w trybie ekstraktywnym.** Synteza nie przeszła " +
		"weryfikacji wyjścia, więc poniżej znajdziesz zatwierdzone kategorie " +
		"wraz z cytatami, bez prozy interpretacyjnej.\n\n",
	pozostale:       "Pozostałe obserwacje",
	pytania:         "Pytania i niewiadome",
	wzorce:          "Powiązania i wzorce",
	pozaTaksonomia:  "Poza obecną taksonomią",
	kotwice:         "**Kotwice pamięciowe**\n\n",
	bilans:          "Bilans sesji",
	rozwijaCel:      "Rozwija: %s. Cel: %s.\n\n",
	opieraSie:       "Opiera się na: %s. Zanim zastosujesz, zweryfikuj: %s\n\n",
	stopkaWarunkowa: "_Propozycje warunkowe — decyzja i odpowiedzialność należą do terapeuty._\n\n",
	przeczy:         "— przeczy: %s",
	noFitOdnotowane: "- %s: zjawisko nie mieści się w taksonomii — odnotowane bez etykiety\n",
	brakDanych:      "Na obecnym etapie brak wystarczających danych.\n\n",
	hipoteza:        "**Hipoteza %s** _(%s",
	pewnosc:         ", pewność %.0f%%",
	wartoSprawdzic:  "- Warto sprawdzić: %s\n",
	noFitWstep: "W materiale pojawiły się zjawiska, których obecna ontologia " +
		"nie obejmuje. Zostały odnotowane bez nadawania im kategorii:\n\n",
	kontWzmacnia:   "_Kontynuacja: potwierdza ustalenie z %s._\n\n",
	kontOslabia:    "_Kontynuacja: osłabia ustalenie z %s._\n\n",
	kontBezDanych:  "_Kontynuacja: bez nowych danych w tej sesji (ostatnio %s)._\n\n",
	rozliczenieTyt: "**Rozliczenie poprzedniej pracy domowej**\n\n",
	werdykty: map[string]string{
		"omowiona_z_rezultatem": "omówiona z rezultatem",
		"wspomniana":            "wspomniana, bez omówienia wyniku",
		"nie_wrocono":           "nie wrócono do niej",
	},
}

var chromeEN = chrome{
	statusy: map[ontology.EpistemicStatus]string{
		ontology.StatusObservation:           "observation",
		ontology.StatusInterpretation:        "interpretation",
		ontology.StatusTheoreticalHypothesis: "theoretical hypothesis",
		ontology.StatusOpenQuestion:          "open question",
		ontology.StatusInsufficientData:      "insufficient data",
		ontology.StatusNoFit:                 "outside the taxonomy",
	},
	dateFmt: "Jan 2",
	extractiveBanner: "> **Extractive-mode report.** The synthesis did not pass " +
		"output verification, so below you will find the approved categories " +
		"with quotes, without interpretive prose.\n\n",
	pozostale:       "Other observations",
	pytania:         "Questions and unknowns",
	wzorce:          "Connections and patterns",
	pozaTaksonomia:  "Outside the current taxonomy",
	kotwice:         "**Memory anchors**\n\n",
	bilans:          "Session summary",
	rozwijaCel:      "Builds on: %s. Goal: %s.\n\n",
	opieraSie:       "Based on: %s. Before applying, verify: %s\n\n",
	stopkaWarunkowa: "_Conditional suggestions — the decision and responsibility rest with the therapist._\n\n",
	przeczy:         "— contradicts: %s",
	noFitOdnotowane: "- %s: the phenomenon does not fit the taxonomy — noted without a label\n",
	brakDanych:      "Insufficient data at this stage.\n\n",
	hipoteza:        "**Hypothesis %s** _(%s",
	pewnosc:         ", confidence %.0f%%",
	wartoSprawdzic:  "- Worth checking: %s\n",
	noFitWstep: "The material contains phenomena the current ontology does not " +
		"cover. They are noted without assigning categories:\n\n",
	kontWzmacnia:   "_Continuity: supports the finding from %s._\n\n",
	kontOslabia:    "_Continuity: weakens the finding from %s._\n\n",
	kontBezDanych:  "_Continuity: no new data this session (last seen %s)._\n\n",
	rozliczenieTyt: "**Previous homework follow-up**\n\n",
	werdykty: map[string]string{
		"omowiona_z_rezultatem": "discussed with outcome",
		"wspomniana":            "mentioned, outcome not discussed",
		"nie_wrocono":           "not revisited",
	},
}

// chromeFor wybiera tabele napisow po jezyku raportu.
//
// Polski jest domyslny (pusty tag = zgodnosc wsteczna); KAZDY inny tag
// dostaje angielski chrome — proza S4 i tak pisze w zadanym jezyku, a
// angielskie etykiety sa zrozumialym mianownikiem dla tagow, ktorych
// nie tlumaczymy (de, fr, ...), w przeciwienstwie do polskich.
func chromeFor(lang string) chrome {
	l := strings.ToLower(strings.TrimSpace(lang))
	if l == "" || l == "pl" || strings.HasPrefix(l, "pl-") {
		return chromePL
	}
	return chromeEN
}

func jestEN(lang string) bool {
	l := strings.ToLower(strings.TrimSpace(lang))
	return !(l == "" || l == "pl" || strings.HasPrefix(l, "pl-"))
}

// RenderMarkdown sklada raport z wyniku potoku.
func RenderMarkdown(o *ontology.Ontology, res Result, in RenderInput) string {
	var b strings.Builder
	ch := chromeFor(in.Language)
	en := jestEN(in.Language)

	// Cytaty spanow po identyfikatorze — hipotezy przywoluja dowody
	// CYTATEM, nie identyfikatorem (feedback 2026-08-24: "Dane za: s08"
	// nie mowi terapeucie nic).
	cytaty := map[string]string{}
	for _, s := range res.Spans {
		cytaty[s.ID] = s.QuoteVerbatim
	}
	// Cytat z wczesniejszej sesji dostaje DATE. Bez niej terapeuta
	// czytalby material sprzed tygodni jako wypowiedz z dzisiejszego
	// spotkania — a to zmienia znaczenie kazdego zdania, ktore sie na
	// nim opiera.
	if in.Past != nil {
		for _, ps := range in.Past.Spans {
			cytaty[ps.Addr] = fmt.Sprintf("(%s) %s",
				ps.SessionDate.Format(ch.dateFmt), ps.Quote)
		}
	}

	if res.Extractive {
		// Tryb ekstraktywny musi byc OZNACZONY w samym raporcie, nie
		// tylko w telemetrii — i PRZED kompozycja: ostrzezenie nie jest
		// sekcja, ktorej kolejnosc profil moglby zepchnac na dol.
		b.WriteString(ch.extractiveBanner)
	}

	if o.ReportProfile != nil && len(o.ReportProfile.Layout) > 0 {
		renderLayout(&b, o, res, in, ch, en, cytaty)
		return b.String()
	}

	for _, sekcja := range sectionOrder(o) {
		switch sekcja {
		case ontology.SectionSessionSummary:
			renderSummary(&b, ch, in.SummaryShort)
		case ontology.SectionInterpretive:
			renderInterpretive(&b, o, res, in.Past, nil, ch, en, cytaty)
		case ontology.SectionPatterns:
			renderTitled(&b, ch.wzorce, func(bb *strings.Builder) bool {
				return renderPatternsBody(bb, o, res, en)
			})
		case ontology.SectionOpenQuestions:
			renderTitled(&b, ch.pytania, func(bb *strings.Builder) bool {
				return renderQuestionsBody(bb, o, res, ch, en)
			})
		case ontology.SectionOutOfTaxonomy:
			renderTitled(&b, ch.pozaTaksonomia, func(bb *strings.Builder) bool {
				return renderNoFitBody(bb, o, res, ch, en)
			})
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
func renderLayout(b *strings.Builder, o *ontology.Ontology, res Result, in RenderInput,
	ch chrome, en bool, cytaty map[string]string) {
	przypisane := map[string]bool{}
	pokryte := map[string]bool{}
	for _, sec := range o.ReportProfile.Layout {
		pokryte[sec.Kind] = true
		for _, id := range sec.Constructs {
			przypisane[id] = true
		}
	}

	for _, sec := range o.ReportProfile.Layout {
		tytul := tytulSekcji(sec, en)
		switch sec.Kind {
		case ontology.LayoutSummary:
			renderSummarySection(b, ch, tytul, in.SummaryShort, res)
		case ontology.LayoutConstructs:
			naleza := map[string]bool{}
			for _, id := range sec.Constructs {
				naleza[id] = true
			}
			renderTitled(b, tytul, func(bb *strings.Builder) bool {
				return renderInterpretive(bb, o, res, in.Past, naleza, ch, en, cytaty)
			})
		case ontology.LayoutSuggestions:
			renderSuggestions(b, o, ch, en, tytul, res.Report.Suggestions)
		case ontology.LayoutInterventions:
			renderInterventions(b, o, ch, en, tytul, res.Report.Interventions)
		case ontology.LayoutOverlooked:
			renderOverlooked(b, o, ch, en, tytul, res)
		case ontology.LayoutQuestions:
			renderTitled(b, tytul, func(bb *strings.Builder) bool {
				return renderQuestionsBody(bb, o, res, ch, en)
			})
		case ontology.LayoutPatterns:
			renderTitled(b, tytul, func(bb *strings.Builder) bool {
				return renderPatternsBody(bb, o, res, en)
			})
		case ontology.LayoutOutOfTaxonomy:
			renderTitled(b, tytul, func(bb *strings.Builder) bool {
				return renderNoFitBody(bb, o, res, ch, en)
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
		renderTitled(b, ch.pozostale, func(bb *strings.Builder) bool {
			return renderInterpretive(bb, o, res, in.Past, nieprzypisane, ch, en, cytaty)
		})
	}
	if !pokryte[ontology.LayoutQuestions] {
		renderTitled(b, ch.pytania, func(bb *strings.Builder) bool {
			return renderQuestionsBody(bb, o, res, ch, en)
		})
	}
	if !pokryte[ontology.LayoutPatterns] {
		renderTitled(b, ch.wzorce, func(bb *strings.Builder) bool {
			return renderPatternsBody(bb, o, res, en)
		})
	}
	if !pokryte[ontology.LayoutOutOfTaxonomy] {
		renderTitled(b, ch.pozaTaksonomia, func(bb *strings.Builder) bool {
			return renderNoFitBody(bb, o, res, ch, en)
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
func renderSummarySection(b *strings.Builder, ch chrome, title, summary string, res Result) {
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
		b.WriteString(ch.kotwice)
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

func renderSuggestions(b *strings.Builder, o *ontology.Ontology, ch chrome, en bool,
	title string, sug []Suggestion) {
	if len(sug) == 0 {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	for _, s := range sug {
		fmt.Fprintf(b, "**%s**\n\n", s.Title)
		fmt.Fprintf(b, ch.rozwijaCel, labelFor(o, s.BasisConstruct, en), s.Target)
		fmt.Fprintf(b, "%s\n\n", s.Instruction)
	}
}

func renderInterventions(b *strings.Builder, o *ontology.Ontology, ch chrome, en bool,
	title string, iv []Intervention) {
	if len(iv) == 0 {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", title)
	for _, i := range iv {
		fmt.Fprintf(b, "**%s**\n\n", i.Name)
		fmt.Fprintf(b, ch.opieraSie, labelFor(o, i.BasisConstruct, en), i.VerifyFirst)
		fmt.Fprintf(b, "%s\n\n", i.Scenario)
	}
	b.WriteString(ch.stopkaWarunkowa)
}

// renderOverlooked to "czego mozna bylo nie zauwazyc" — zlozone w KODZIE
// z materialu, ktory juz przeszedl potok: kontrdowody zatwierdzonych
// twierdzen, zjawiska poza taksonomia, konstrukty zdegradowane. To sa
// dokladnie funkcje D1 ("ten fragment przeczy...", "tego moglas nie
// zauwazyc") zebrane w jedno miejsce.
func renderOverlooked(b *strings.Builder, o *ontology.Ontology, ch chrome, en bool,
	title string, res Result) {
	var tmp strings.Builder
	widziane := map[string]bool{}
	for _, c := range res.Approved {
		for _, q := range c.CounterEvidence {
			if widziane[q.SpanID] || strings.TrimSpace(q.Quote) == "" {
				continue
			}
			widziane[q.SpanID] = true
			fmt.Fprintf(&tmp, "> %s\n\n"+ch.przeczy+"\n\n", q.Quote, labelFor(o, c.ConstructID, en))
		}
	}
	for _, id := range res.NoFit {
		fmt.Fprintf(&tmp, ch.noFitOdnotowane, labelFor(o, id, en))
	}
	for _, d := range res.Degraded {
		fmt.Fprintf(&tmp, "- %s: %s\n", labelFor(o, d.ConstructID, en), d.To)
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

func renderSummary(b *strings.Builder, ch chrome, summary string) {
	if strings.TrimSpace(summary) == "" {
		return
	}
	fmt.Fprintf(b, "## %s\n\n", ch.bilans)
	b.WriteString(strings.TrimSpace(summary))
	b.WriteString("\n\n")
}

// renderInterpretive renderuje konstrukty; `tylko` != nil zaweza do
// wskazanych (uklad), nil = wszystkie (kompozycja domyslna). Zwraca, czy
// cokolwiek wypisano. W trybie ukladu naglowki konstruktow schodza
// poziom nizej (###), bo sekcje ukladu zajmuja poziom ##.
func renderInterpretive(b *strings.Builder, o *ontology.Ontology, res Result,
	past *PastContext, tylko map[string]bool, ch chrome, en bool, cytaty map[string]string) bool {
	naglowek := "## %s\n\n"
	if tylko != nil {
		naglowek = "### %s\n\n"
	}
	// T42b: linki ciaglosci per konstrukt — DETERMINISTYCZNA linia pod
	// hipotezami, nie proza S4. Relacja pochodzi z zapisanego linku,
	// wiec data i kierunek nie moga sie "poprawic" w syntezie.
	linkiPerKonstrukt := map[string][]ContinuityLink{}
	for _, l := range res.ContinuityLinks {
		linkiPerKonstrukt[l.ConstructID] = append(linkiPerKonstrukt[l.ConstructID], l)
	}
	cokolwiek := false
	for _, cr := range res.Constructsy() {
		if tylko != nil && !tylko[cr.ConstructID] {
			continue
		}
		cokolwiek = true
		fmt.Fprintf(b, naglowek, labelFor(o, cr.ConstructID, en))

		if len(cr.Hypotheses) == 0 {
			// Pole bez twierdzen renderuje sie jako ZAPROSZENIE, nie jako
			// blad. Raport wypelniony w 100% jest sygnalem alarmowym.
			b.WriteString(ch.brakDanych)
		}

		for _, h := range cr.Hypotheses {
			st := ch.statusy[ontology.EpistemicStatus(h.EpistemicStatus)]
			if st == "" {
				st = h.EpistemicStatus
			}
			fmt.Fprintf(b, ch.hipoteza, h.ID, st)
			if h.Confidence > 0 {
				fmt.Fprintf(b, ch.pewnosc, h.Confidence*100)
			}
			b.WriteString(")_\n\n")
			fmt.Fprintf(b, "%s\n\n", bezOdnosnikow(h.Claim))

			// Dowody CYTATEM, nie identyfikatorem (2026-08-24: "Dane za:
			// s08, s28" nie mowi terapeucie nic). Cytaty przeszly
			// weryfikacje mechaniczna w S1 — kod tylko je przywoluje.
			// Limit trzech na hipoteze: dowod ma ilustrowac, nie
			// przedrukowywac transkrypcji.
			wypisane := 0
			for _, id := range h.Supporting {
				q := strings.TrimSpace(cytaty[id])
				if q == "" {
					continue
				}
				fmt.Fprintf(b, "> %s\n\n", q)
				wypisane++
				if wypisane == 3 {
					break
				}
			}
			// Dane przeciw sa FUNKCJA raportu, nie jego defektem —
			// "ten fragment przeczy pierwszej hipotezie" to jedna z
			// rzeczy, po ktore terapeuta siega. Cytat + oznaczenie,
			// zeby kontrdowodu nie dalo sie pomylic z poparciem.
			for _, id := range h.Contradicting {
				q := strings.TrimSpace(cytaty[id])
				if q == "" {
					continue
				}
				fmt.Fprintf(b, "> %s\n\n"+ch.przeczy+"\n\n", q, labelFor(o, cr.ConstructID, en))
			}
			b.WriteString("\n")
		}

		// T42b: kontynuacje tego konstruktu (docs/67 par. 4).
		for _, l := range linkiPerKonstrukt[cr.ConstructID] {
			format := ch.kontWzmacnia
			if l.Relation == "oslabia" {
				format = ch.kontOslabia
			}
			fmt.Fprintf(b, format, l.PastSessionDate.Format(ch.dateFmt))
		}
		if len(linkiPerKonstrukt[cr.ConstructID]) == 0 && len(cr.Hypotheses) == 0 {
			if ostatnia, ok := ostatniaData(past, cr.ConstructID); ok {
				fmt.Fprintf(b, ch.kontBezDanych, ostatnia.Format(ch.dateFmt))
			}
		}
		// Rozliczenie pracy domowej przy konstrukcie faktowym ustalen.
		if c := o.Constructs[cr.ConstructID]; c != nil {
			if _, ok := c.FactKindMap["agreement_client"]; ok && len(res.HomeworkVerdicts) > 0 {
				b.WriteString(ch.rozliczenieTyt)
				for _, h := range res.HomeworkVerdicts {
					et := ch.werdykty[h.Verdict]
					if et == "" {
						et = h.Verdict
					}
					fmt.Fprintf(b, "- (%s) %q — %s\n",
						h.PastSessionDate.Format(ch.dateFmt), h.Quote, et)
				}
				b.WriteString("\n")
			}
		}
	}
	return cokolwiek
}

func renderPatternsBody(b *strings.Builder, o *ontology.Ontology, res Result, en bool) bool {
	cokolwiek := false
	for _, cr := range res.Constructsy() {
		for _, p := range cr.PatternNotices {
			cokolwiek = true
			fmt.Fprintf(b, "- **%s:** %s\n", labelFor(o, cr.ConstructID, en), p)
		}
	}
	if cokolwiek {
		b.WriteString("\n")
	}
	return cokolwiek
}

func renderQuestionsBody(b *strings.Builder, o *ontology.Ontology, res Result,
	ch chrome, en bool) bool {
	cokolwiek := false
	for _, cr := range res.Constructsy() {
		if len(cr.UnknownYet) == 0 && len(cr.NextSessionQuestions) == 0 {
			continue
		}
		cokolwiek = true
		fmt.Fprintf(b, "**%s**\n\n", labelFor(o, cr.ConstructID, en))
		for _, u := range cr.UnknownYet {
			fmt.Fprintf(b, "- %s\n", u)
		}
		for _, q := range cr.NextSessionQuestions {
			fmt.Fprintf(b, ch.wartoSprawdzic, q)
		}
		b.WriteString("\n")
	}
	return cokolwiek
}

func renderNoFitBody(b *strings.Builder, o *ontology.Ontology, res Result,
	ch chrome, en bool) bool {
	if len(res.NoFit) == 0 {
		return false
	}
	b.WriteString(ch.noFitWstep)
	for _, id := range res.NoFit {
		fmt.Fprintf(b, "- %s\n", labelFor(o, id, en))
	}
	b.WriteString("\n")
	return true
}

// odnosnikWProzie lapie identyfikator spanu wpisany w zdanie:
// `(s04)`, `(s01, s12)`, `(s0820:s42)`. Wzorzec jest WASKI — celuje w
// nawias z samymi odnosnikami, zeby nie zjesc nawiasu z trescia.
var odnosnikWProzie = regexp.MustCompile(
	`\s*\(s\d{2,4}(?::s\d+)?(?:\s*,\s*s\d{2,4}(?::s\d+)?)*\)`)

// bezOdnosnikow usuwa identyfikatory spanow z prozy.
//
// Prompt tego zakazuje (regula 12), ale zakaz w prompcie jest prosba, a
// nie gwarancja — i model ja lamie tym chetniej, im wiecej adresow
// zobaczy w wejsciu. Po wprowadzeniu kontekstu miedzysesyjnego liczba
// odnosnikow w prozie skoczyla z zera do trzydziestu trzech na raport
// (pomiar 25.08). Dla terapeuty „(s04)" jest numerem katalogowym, po
// ktorym nie ma jak niczego sprawdzic — cytat pod hipoteza mowi sam za
// siebie, wiec odnosnik jest wylacznie szumem.
func bezOdnosnikow(s string) string {
	out := odnosnikWProzie.ReplaceAllString(s, "")
	// Usuniecie odnosnika zostawia czasem spacje przed kropka.
	out = strings.ReplaceAll(out, " .", ".")
	out = strings.ReplaceAll(out, " ,", ",")
	return strings.TrimSpace(out)
}

// labelFor zwraca etykiete konstruktu w jezyku raportu.
//
// Fallback na label_pl jest SWIADOMY: polska etykieta w angielskim
// raporcie jest widoczna od razu i sama zglasza brak tlumaczenia
// ekspertowi — identyfikator techniczny nie zglasza niczego.
func labelFor(o *ontology.Ontology, id string, en bool) string {
	c := o.Constructs[id]
	if c == nil {
		return id
	}
	if en && c.LabelEN != "" {
		return c.LabelEN
	}
	if c.LabelPL != "" {
		return c.LabelPL
	}
	return id
}

// tytulSekcji zwraca tytul sekcji ukladu w jezyku raportu, z tym samym
// swiadomym fallbackiem co labelFor.
func tytulSekcji(sec ontology.LayoutSection, en bool) string {
	if en && sec.TitleEN != "" {
		return sec.TitleEN
	}
	return sec.Title
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

// ostatniaData zwraca date najnowszego przeszlego twierdzenia konstruktu
// — dla linii "bez nowych danych" (T42b).
func ostatniaData(past *PastContext, constructID string) (t time.Time, ok bool) {
	if past == nil {
		return t, false
	}
	for _, pc := range past.Claims {
		if pc.ConstructID == constructID && pc.SessionDate.After(t) {
			t, ok = pc.SessionDate, true
		}
	}
	return t, ok
}
