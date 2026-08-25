package ontopipe

import (
	"strings"
	"testing"
	"time"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Wynik z kompletem sekcji: hipotezy, wzmianki o wzorcach, pytania,
// no_fit — żeby każda sekcja miała co renderować.
func wynikPelny() Result {
	return Result{
		Report: Report{Constructs: []ConstructReport{
			{
				ConstructID: "konflikt",
				Hypotheses: []Hypothesis{{
					ID: "A", Claim: "Materiał daje się czytać jako napięcie.",
					Supporting: []string{"s01"}, EpistemicStatus: "interpretation",
					Confidence: 0.6,
				}},
				PatternNotices:       []string{"temat związku wraca trzeci raz"},
				UnknownYet:           []string{"nie znamy kontekstu rodzinnego"},
				NextSessionQuestions: []string{"co dzieje się przy próbie rozmowy?"},
			},
		}},
		NoFit: []string{"zasob"},
	}
}

func ontologiaZProfilem(t *testing.T, profil string) *ontology.Ontology {
	t.Helper()
	y := `
modality: test
version: 1.0.0
constructs:
  konflikt:
    label_pl: "Konflikt wewnetrzny"
    values: ["a", "b"]
    min_evidence: {spans: 1}
  zasob:
    label_pl: "Zasob"
    values: null
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
` + profil
	o, err := ontology.Parse([]byte(y))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if p := o.Validate(); len(p) != 0 {
		t.Fatalf("ontologia testowa nie przechodzi metaschematu: %v", p)
	}
	return o
}

// naglowki wyciaga kolejnosc sekcji "## " z markdownu.
func naglowki(md string) []string {
	var out []string
	for _, l := range strings.Split(md, "\n") {
		if strings.HasPrefix(l, "## ") {
			out = append(out, strings.TrimPrefix(l, "## "))
		}
	}
	return out
}

func TestKompozycjaDomyslna(t *testing.T) {
	o := ontologiaZProfilem(t, "")
	md := RenderMarkdown(o, wynikPelny(), RenderInput{SummaryShort: "Streszczenie sesji."})
	got := naglowki(md)
	oczekiwane := []string{
		"Bilans sesji", "Konflikt wewnetrzny", "Powiązania i wzorce",
		"Pytania i niewiadome", "Poza obecną taksonomią",
	}
	if strings.Join(got, "|") != strings.Join(oczekiwane, "|") {
		t.Fatalf("kolejnosc sekcji = %v, oczekiwano %v", got, oczekiwane)
	}
}

// TestProfilPrzestawiaSekcje — kompozycja Gestalt z dok. 15 §3.3:
// wzorce i pytania w górę, konstrukty interpretacyjne w dół. Silnik ten
// sam, kompozycja inna.
func TestProfilPrzestawiaSekcje(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  sections:
    patterns_and_relations: {weight: high}
    open_questions: {weight: high}
    interpretive_constructs: {weight: low}
  default_tone: phenomenological
`)
	md := RenderMarkdown(o, wynikPelny(), RenderInput{SummaryShort: "Streszczenie."})
	got := naglowki(md)
	oczekiwane := []string{
		"Powiązania i wzorce", "Pytania i niewiadome", "Bilans sesji",
		"Poza obecną taksonomią", "Konflikt wewnetrzny",
	}
	if strings.Join(got, "|") != strings.Join(oczekiwane, "|") {
		t.Fatalf("kolejnosc sekcji = %v, oczekiwano %v", got, oczekiwane)
	}
}

// TestWagaNieUkrywaTresci — waga steruje kolejnością, nigdy widocznością.
// Ukrycie zweryfikowanej treści byłoby decyzją o treści, a M5 zmienia
// wyłącznie kompozycję.
func TestWagaNieUkrywaTresci(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  sections:
    interpretive_constructs: {weight: low}
`)
	md := RenderMarkdown(o, wynikPelny(), RenderInput{})
	if !strings.Contains(md, "Materiał daje się czytać jako napięcie.") {
		t.Fatal("waga low usunela tresc hipotezy z raportu")
	}
}

func TestPusteSekcjeZnikaja(t *testing.T) {
	o := ontologiaZProfilem(t, "")
	res := wynikPelny()
	res.Report.Constructs[0].PatternNotices = nil
	res.Report.Constructs[0].UnknownYet = nil
	res.Report.Constructs[0].NextSessionQuestions = nil
	res.NoFit = nil
	md := RenderMarkdown(o, res, RenderInput{})
	for _, zakazany := range []string{"Powiązania i wzorce", "Pytania i niewiadome",
		"Poza obecną taksonomią", "Bilans sesji"} {
		if strings.Contains(md, zakazany) {
			t.Errorf("pusta sekcja %q nie znikla", zakazany)
		}
	}
}

// TestBanerEkstraktywnyPrzedKompozycja — ostrzeżenie nie jest sekcją,
// której kolejność profil mógłby zepchnąć na dół.
func TestBanerEkstraktywnyPrzedKompozycja(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  sections:
    session_summary: {weight: high}
`)
	res := wynikPelny()
	res.Extractive = true
	md := RenderMarkdown(o, res, RenderInput{SummaryShort: "Streszczenie."})
	if !strings.HasPrefix(md, "> **Raport w trybie ekstraktywnym.**") {
		t.Fatalf("baner nie stoi na poczatku:\n%.120s", md)
	}
}

// TestWzmiankiPodpisaneKonstruktem — wzmianka wyrwana z kontekstu
// przestaje mówić, CZEGO dotyczy powtarzalność.
func TestWzmiankiPodpisaneKonstruktem(t *testing.T) {
	o := ontologiaZProfilem(t, "")
	md := RenderMarkdown(o, wynikPelny(), RenderInput{})
	if !strings.Contains(md, "**Konflikt wewnetrzny:** temat związku wraca trzeci raz") {
		t.Fatalf("wzmianka bez podpisu konstruktu:\n%s", md)
	}
}

// TestTonTylkoDlaZnanegoProfilu — M5: ton zmienia szablon językowy S4.
// Ontologia bez profilu nie może go dostać, a fenomenologiczny musi
// nieść dyscyplinę "opis przed oceną".
func TestTonTylkoDlaZnanegoProfilu(t *testing.T) {
	bez := ontologiaZProfilem(t, "")
	if strings.Contains(buildS4Prompt(bez), "TON:") {
		t.Fatal("prompt S4 dostal ton bez profilu")
	}
	z := ontologiaZProfilem(t, `report_profile:
  default_tone: phenomenological
`)
	prompt := buildS4Prompt(z)
	if !strings.Contains(prompt, "fenomenologiczny") ||
		!strings.Contains(prompt, "Opis przed oceną") {
		t.Fatalf("ton fenomenologiczny nie trafil do promptu S4:\n%.200s", prompt)
	}
}

// TestMetaschematOdrzucaLiterowki — literówka w kluczu sekcji albo wadze
// działałaby jak brak wpisu: najgorszy rodzaj błędu, bo niewidoczny.
func TestMetaschematOdrzucaLiterowki(t *testing.T) {
	for _, zly := range []string{
		`report_profile:
  sections:
    patterns_and_relatoins: {weight: high}
`,
		`report_profile:
  sections:
    open_questions: {weight: wysoka}
`,
		`report_profile:
  default_tone: kliniczny
`,
	} {
		y := `
modality: test
version: 1.0.0
constructs:
  a:
    label_pl: "A"
    values: ["x"]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
` + zly
		o, err := ontology.Parse([]byte(y))
		if err != nil {
			t.Fatalf("parse: %v", err)
		}
		if p := o.Validate(); len(p) == 0 {
			t.Errorf("metaschemat przepuscil profil:\n%s", zly)
		}
	}
}

// ── uklad nazwanych sekcji (M5+) ──

func ontologiaZUkladem(t *testing.T) *ontology.Ontology {
	t.Helper()
	return ontologiaZProfilem(t, `report_profile:
  layout:
    - id: bilans
      title: "Bilans sesji"
      kind: summary
    - id: konflikty
      title: "Konflikty i Ukryte Potencjalności"
      kind: constructs
      constructs: [konflikt]
    - id: inspiracje
      title: "Inspiracje między sesjami"
      kind: suggestions
      guidance: "Charakter obserwacyjny albo zasobowy."
    - id: interwencje
      title: "Propozycje interwencji"
      kind: interventions
    - id: superwizja
      title: "Czego można było nie zauważyć"
      kind: overlooked
    - id: pytania
      title: "Pytania i niewiadome"
      kind: questions
`)
}

func wynikZPropozycjami() Result {
	res := wynikPelny()
	res.Approved = []ontology.Claim{{
		ConstructID: "konflikt",
		Categories:  []string{"a"},
		Status:      ontology.StatusInterpretation,
		Confidence:  0.8,
		Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "chcę być blisko, a duszę się"}},
		CounterEvidence: []ontology.QuoteRef{{SpanID: "s02",
			Quote: "w niedzielę było zupełnie inaczej"}},
	}}
	res.Report.Suggestions = []Suggestion{{
		Title: "Obserwacja napięcia", BasisConstruct: "konflikt",
		Target: "sfera kontaktu", Instruction: "Zauważaj momenty, w których…",
	}}
	res.Report.Interventions = []Intervention{{
		Name: "Praca z dwoma krzesłami", BasisConstruct: "konflikt",
		VerifyFirst: "czy klient rozpoznaje oba bieguny",
		Scenario:    "Zaproponuj eksperyment…",
	}}
	return res
}

// TestUkladRenderujeAnalogiczneSekcje — sekcje raportu analogiczne do
// soczewki: tytuły z ontologii, kolejność z układu.
func TestUkladRenderujeAnalogiczneSekcje(t *testing.T) {
	md := RenderMarkdown(ontologiaZUkladem(t), wynikZPropozycjami(),
		RenderInput{SummaryShort: "Esencja sesji."})
	got := naglowki(md)
	oczekiwane := []string{
		"Bilans sesji", "Konflikty i Ukryte Potencjalności",
		"Inspiracje między sesjami", "Propozycje interwencji",
		"Czego można było nie zauważyć", "Pytania i niewiadome",
		// Wzmianki o wzorcach i no_fit sa w wyniku, a uklad ich nie
		// przewidzial — niezmiennik "nigdy nie ukrywaj" dokleja je z
		// tytulami domyslnymi.
		"Powiązania i wzorce", "Poza obecną taksonomią",
	}
	if strings.Join(got, "|") != strings.Join(oczekiwane, "|") {
		t.Fatalf("sekcje = %v\noczekiwano %v", got, oczekiwane)
	}
	// Kotwice: cytat dowodowy w bilansie, wybrany przez KOD.
	if !strings.Contains(md, "Kotwice pamięciowe") ||
		!strings.Contains(md, "> chcę być blisko, a duszę się") {
		t.Error("bilans bez kotwic pamieciowych")
	}
	// Propozycja ugruntowana: nazwa konstruktu, nie identyfikator.
	if !strings.Contains(md, "Rozwija: Konflikt wewnetrzny") {
		t.Error("propozycja bez oparcia w konstrukcie")
	}
	if !strings.Contains(md, "Zanim zastosujesz, zweryfikuj: czy klient rozpoznaje oba bieguny") {
		t.Error("interwencja bez verify_first")
	}
	// Overlooked: kontrdowod z cytatem.
	if !strings.Contains(md, "> w niedzielę było zupełnie inaczej") {
		t.Error("kontrdowod nie trafil do 'czego mozna bylo nie zauwazyc'")
	}
}

// TestUkladNigdyNieUkrywa — konstrukt nieprzypisany do żadnej sekcji
// ląduje w sekcji końcowej. Ekspert steruje KSZTAŁTEM, nie tym, co
// terapeuta zobaczy.
func TestUkladNigdyNieUkrywa(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  layout:
    - id: bilans
      title: "Bilans sesji"
      kind: summary
`)
	res := wynikZPropozycjami()
	md := RenderMarkdown(o, res, RenderInput{SummaryShort: "Esencja."})
	if !strings.Contains(md, "## Pozostałe obserwacje") {
		t.Fatal("nieprzypisany konstrukt zniknal z raportu")
	}
	if !strings.Contains(md, "### Konflikt wewnetrzny") {
		t.Fatal("tresc nieprzypisanego konstruktu nie zostala wyrenderowana")
	}
	if !strings.Contains(md, "## Pytania i niewiadome") {
		t.Fatal("pytania spoza ukladu nie zostaly doklejone")
	}
}

// TestSchematS4TylkoNaZamowienie — modalność bez sekcji generacyjnych
// nie płaci za generację, której nie wyrenderuje.
func TestSchematS4TylkoNaZamowienie(t *testing.T) {
	in, _ := materialS5()
	bez := schemaS4(in)["properties"].(map[string]any)
	if _, ma := bez["suggestions"]; ma {
		t.Error("schemat ma suggestions bez zamowienia")
	}
	in.WantSuggestions = true
	in.WantInterventions = true
	z := schemaS4(in)["properties"].(map[string]any)
	if _, ma := z["suggestions"]; !ma {
		t.Error("schemat nie ma suggestions mimo zamowienia")
	}
	// basis_construct to enum ZATWIERDZONYCH konstruktow — propozycja bez
	// oparcia nie moze powstac.
	sug := z["suggestions"].(map[string]any)["items"].(map[string]any)
	basis := sug["properties"].(map[string]any)["basis_construct"].(map[string]any)
	if _, ma := basis["enum"]; !ma {
		t.Error("basis_construct bez enumu — oparcie byloby proszone, nie wymuszone")
	}
}

func TestWytyczneZOntologiiTrafiajaDoPromptu(t *testing.T) {
	in, _ := materialS5()
	in.WantSuggestions = true
	in.SuggestionsGuidance = "Charakter obserwacyjny (etapy 1-2) albo zasobowy (etap 3)."
	var b strings.Builder
	appendGenerativeGuidance(&b, in)
	if !strings.Contains(b.String(), "etapy 1-2") {
		t.Fatal("wytyczne eksperckie nie trafily do promptu S4")
	}
	if !strings.Contains(b.String(), "basis_construct") {
		t.Fatal("prompt nie tlumaczy reguly oparcia")
	}
}

// Feedback 2026-08-24: "Dane za: s08, s28" nie mowi terapeucie nic —
// dowody maja byc przytoczone CYTATEM, bez etykiety identyfikatorow.
func TestCytatyZamiastIdentyfikatorowSpanow(t *testing.T) {
	res := wynikPelny()
	res.Spans = []ontology.TopicSpan{
		{Span: ontology.Span{ID: "s01", QuoteVerbatim: "chcę być blisko, a duszę się"}},
		{Span: ontology.Span{ID: "s02", QuoteVerbatim: "w niedzielę było zupełnie inaczej"}},
	}
	res.Report.Constructs[0].Hypotheses[0].Contradicting = []string{"s02"}
	md := RenderMarkdown(ontologiaZUkladem(t), res, RenderInput{})

	if strings.Contains(md, "Dane za") || strings.Contains(md, "Dane przeciw") {
		t.Fatalf("raport nadal pokazuje etykiety identyfikatorow:\n%s", md)
	}
	if strings.Contains(md, "s01") || strings.Contains(md, "s02") {
		t.Fatalf("surowe identyfikatory spanow w raporcie:\n%s", md)
	}
	if !strings.Contains(md, "> chcę być blisko, a duszę się") {
		t.Error("brak cytatu dowodowego przy hipotezie")
	}
	if !strings.Contains(md, "> w niedzielę było zupełnie inaczej") ||
		!strings.Contains(md, "— przeczy: Konflikt wewnetrzny") {
		t.Error("kontrdowod bez cytatu albo bez oznaczenia")
	}
}

// Limit trzech cytatow na hipoteze: dowod ilustruje, nie przedrukowuje
// transkrypcji.
func TestCytatyMajaLimitTrzech(t *testing.T) {
	res := wynikPelny()
	res.Report.Constructs[0].Hypotheses[0].Supporting =
		[]string{"s01", "s02", "s03", "s04"}
	res.Spans = []ontology.TopicSpan{
		{Span: ontology.Span{ID: "s01", QuoteVerbatim: "cytat pierwszy"}},
		{Span: ontology.Span{ID: "s02", QuoteVerbatim: "cytat drugi"}},
		{Span: ontology.Span{ID: "s03", QuoteVerbatim: "cytat trzeci"}},
		{Span: ontology.Span{ID: "s04", QuoteVerbatim: "cytat czwarty"}},
	}
	md := RenderMarkdown(ontologiaZUkladem(t), res, RenderInput{})
	for _, chce := range []string{"cytat pierwszy", "cytat drugi", "cytat trzeci"} {
		if !strings.Contains(md, chce) {
			t.Errorf("brak %q", chce)
		}
	}
	if strings.Contains(md, "cytat czwarty") {
		t.Error("czwarty cytat przekracza limit")
	}
}

// Raport wychodzi w jezyku KARTOTEKI: chrome po angielsku, tytuly z
// title_en/label_en, fallback na polski tam, gdzie autor nie przetlumaczyl.
func TestRaportPoAngielsku(t *testing.T) {
	o := ontologiaZProfilem(t, `report_profile:
  layout:
    - id: bilans
      title: "Bilans sesji"
      title_en: "Session balance"
      kind: summary
    - id: konflikty
      title: "Konflikty"
      title_en: "Conflicts"
      kind: constructs
      constructs: [konflikt]
    - id: pytania
      title: "Pytania i niewiadome"
      kind: questions
`)
	o.Constructs["konflikt"].LabelEN = "Inner conflict"
	res := wynikPelny()
	md := RenderMarkdown(o, res, RenderInput{
		SummaryShort: "Session essence.", Language: "en-US",
	})

	for _, chce := range []string{
		"## Session balance",
		"## Conflicts",
		"### Inner conflict",
		"**Hypothesis A**",
		"interpretation",
		"confidence 60%",
		// pytania nie maja title_en — fallback na tytul autorski
		"## Pytania i niewiadome",
		// zasob (no_fit) nie ma label_en — fallback na label_pl,
		// w doklejonej sekcji z chrome EN
		"## Outside the current taxonomy",
		"- Zasob",
		"Worth checking:",
	} {
		if !strings.Contains(md, chce) {
			t.Errorf("brak %q w raporcie EN:\n%s", chce, md)
		}
	}
	for _, nieChce := range []string{"Hipoteza", "pewność", "Warto sprawdzić"} {
		if strings.Contains(md, nieChce) {
			t.Errorf("polski chrome %q w raporcie EN", nieChce)
		}
	}
}

// Instrukcja jezykowa trafia do promptu S4 wylacznie dla jezykow
// niepolskich.
func TestJezykRaportuWPrompcieS4(t *testing.T) {
	var b strings.Builder
	appendGenerativeGuidance(&b, SynthesisInput{Language: "en-US"})
	if !strings.Contains(b.String(), "JEZYK RAPORTU: en-US") {
		t.Fatalf("brak instrukcji jezykowej: %s", b.String())
	}
	b.Reset()
	appendGenerativeGuidance(&b, SynthesisInput{Language: "pl"})
	if strings.Contains(b.String(), "JEZYK RAPORTU") {
		t.Fatal("instrukcja jezykowa dla polskiego jest zbedna")
	}
}

// Cytat z wczesniejszej sesji MUSI trafic do raportu z data.
//
// Bez tego odnosnik `s0821:s07` wypadalby po cichu (nie ma go wsrod
// spanow biezacej sesji), a hipoteza o ciaglosci zostawalaby bez
// dowodu — czyli dokladnie tak, jak wygladalby blad.
func TestCytatHistorycznyMaDate(t *testing.T) {
	res := wynikPelny()
	res.Spans = []ontology.TopicSpan{
		{Span: ontology.Span{ID: "s01", QuoteVerbatim: "dzisiejsza wypowiedź"}},
	}
	res.Report.Constructs[0].Hypotheses[0].Supporting = []string{"s01", "s0821:s07"}
	past := &PastContext{Spans: []PastSpan{{
		Addr:        "s0821:s07",
		SessionDate: time.Date(2026, 8, 21, 0, 0, 0, 0, time.UTC),
		Quote:       "wtedy mówił inaczej",
	}}}

	md := RenderMarkdown(ontologiaZUkladem(t), res, RenderInput{Past: past})
	if !strings.Contains(md, "> (21.08) wtedy mówił inaczej") {
		t.Fatalf("brak datowanego cytatu historycznego:\n%s", md)
	}
	if !strings.Contains(md, "> dzisiejsza wypowiedź") {
		t.Error("cytat z biezacej sesji nie powinien dostac daty")
	}
	if strings.Contains(md, "s0821:s07") {
		t.Error("surowy adres historyczny wyciekl do raportu")
	}
}

// Ten sam cytat w raporcie angielskim — data w formacie czytelnym dla
// odbiorcy, nie polskim.
func TestCytatHistorycznyPoAngielsku(t *testing.T) {
	res := wynikPelny()
	res.Spans = nil
	res.Report.Constructs[0].Hypotheses[0].Supporting = []string{"s0821:s07"}
	past := &PastContext{Spans: []PastSpan{{
		Addr:        "s0821:s07",
		SessionDate: time.Date(2026, 8, 21, 0, 0, 0, 0, time.UTC),
		Quote:       "he said otherwise then",
	}}}

	md := RenderMarkdown(ontologiaZUkladem(t), res, RenderInput{
		Past: past, Language: "en-US",
	})
	if !strings.Contains(md, "> (Aug 21) he said otherwise then") {
		t.Fatalf("data historyczna nie po angielsku:\n%s", md)
	}
}

// Pomiar 25.08: po wprowadzeniu kontekstu miedzysesyjnego liczba
// identyfikatorow spanow w PROZIE skoczyla z zera do trzydziestu trzech
// na raport — model zaczal odwzorowywac adresy, ktore zobaczyl w
// wejsciu. Dla terapeuty „(s04)" jest numerem katalogowym bez wartosci;
// pod hipoteza i tak stoi cytat.
func TestOdnosnikiSpanowZnikajaZProzy(t *testing.T) {
	przypadki := []struct{ wejscie, oczekiwane string }{
		{"Klient dystansuje się (s04).", "Klient dystansuje się."},
		{"Widać to w dwóch miejscach (s01, s12) i wraca dziś.",
			"Widać to w dwóch miejscach i wraca dziś."},
		{"Wątek wrócił po poprzedniej sesji (s0820:s42).",
			"Wątek wrócił po poprzedniej sesji."},
		{"Bez odnośników zdanie zostaje nietknięte.",
			"Bez odnośników zdanie zostaje nietknięte."},
		// Nawias z TRESCIA musi przetrwac — wzorzec celuje w same
		// identyfikatory, nie w kazdy nawias.
		{"Para (małżeństwo od 12 lat) rozmawia rzeczowo.",
			"Para (małżeństwo od 12 lat) rozmawia rzeczowo."},
		{"Napięcie rośnie (sesja poprzednia była spokojna).",
			"Napięcie rośnie (sesja poprzednia była spokojna)."},
	}
	for _, p := range przypadki {
		if got := bezOdnosnikow(p.wejscie); got != p.oczekiwane {
			t.Errorf("bezOdnosnikow(%q)\n = %q\n chcemy %q", p.wejscie, got, p.oczekiwane)
		}
	}
}

// Scrubber musi dzialac na PROZIE renderowanego raportu, nie tylko
// w izolacji — inaczej poprawka istnieje i nic nie robi.
func TestRaportNieNiesieOdnosnikowWProzie(t *testing.T) {
	res := wynikPelny()
	res.Spans = []ontology.TopicSpan{
		{Span: ontology.Span{ID: "s01", QuoteVerbatim: "duszę się"}},
	}
	res.Report.Constructs[0].Hypotheses[0].Claim =
		"Napięcie wraca po poprzedniej sesji (s01) i rośnie (s0820:s42)."
	md := RenderMarkdown(ontologiaZUkladem(t), res, RenderInput{})
	if strings.Contains(md, "(s01)") || strings.Contains(md, "(s0820:s42)") {
		t.Fatalf("odnosniki zostaly w raporcie:\n%s", md)
	}
	if !strings.Contains(md, "Napięcie wraca po poprzedniej sesji i rośnie.") {
		t.Fatalf("zdanie po czyszczeniu wyglada zle:\n%s", md)
	}
}
