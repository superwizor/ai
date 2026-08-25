// Package ontology reprezentuje ontologie modalnosci — warstwe, ktora
// egzekwuje wiernosc teorii szkoly terapeutycznej (docs/adr/
// reasoning_docs/11, sekcja 3).
//
// Zasada, z ktorej wynika ksztalt tego pakietu: "LLM proponuje,
// struktura rozporzadza". Typy tutaj sa ta struktura — enumy z `Values`
// trafiaja do JSON Schema wyjscia modelu, wiec model FIZYCZNIE nie moze
// zwrocic kategorii spoza taksonomii. Wiedza parametryczna modelu jest
// priorem generujacym kandydatow, nigdy zrodlem prawdy o katalogu.
//
// # Gdzie zyje tresc
//
// Do planu 16 v1.1 ontologia byla plikiem w repo (read-only w runtime).
// Od v1.2 zrodlem prawdy runtime jest AKTYWNA WERSJA W BAZIE, edytowana
// w Ontology Studio; pliki `ontology/<modality>/<semver>.yaml` sa
// seedami i dokumentacja formatu. Ten pakiet parsuje i waliduje jedno i
// drugie — ta sama implementacja obsluguje lint w CI i zapis w Studio,
// zeby nie powstaly dwa rozjezdzajace sie walidatory.
package ontology

// EpistemicStatus to status epistemiczny twierdzenia (dok. 11 sekcja 3.2).
//
// insufficient_data i no_fit sa wartosciami PIERWSZEJ KLASY, nie awaria:
// pierwsza mowi "za malo danych, by rozstrzygnac", druga "danych dosc,
// ale zjawisko nie miesci sie w zadnej kategorii taksonomii". Bez tej
// drugiej enum wymusza wybor najblizszej kategorii (forced-choice bias),
// a wysoki odsetek no_fit w produkcji jest sygnalem luki ontologii.
type EpistemicStatus string

const (
	StatusObservation           EpistemicStatus = "observation"
	StatusInterpretation        EpistemicStatus = "interpretation"
	StatusTheoreticalHypothesis EpistemicStatus = "theoretical_hypothesis"
	StatusOpenQuestion          EpistemicStatus = "open_question"
	StatusInsufficientData      EpistemicStatus = "insufficient_data"
	StatusNoFit                 EpistemicStatus = "no_fit"
)

// AllStatuses to komplet statusow z metaschematu. Kolejnosc jak w dok. 11.
var AllStatuses = []EpistemicStatus{
	StatusObservation, StatusInterpretation, StatusTheoreticalHypothesis,
	StatusOpenQuestion, StatusInsufficientData, StatusNoFit,
}

// RelationType to typ relacji miedzy twierdzeniami (S2b, dok. 11 sekcja 3.2).
type RelationType string

const (
	RelWspolwystepowanie RelationType = "wspolwystepowanie"
	RelNapiecie          RelationType = "napiecie"
	RelSekwencja         RelationType = "sekwencja"
	RelSprzecznosc       RelationType = "sprzecznosc"
	RelWzmocnienie       RelationType = "wzmocnienie"
	RelMediacja          RelationType = "mediacja"
	RelParalela          RelationType = "paralela"
)

var AllRelationTypes = []RelationType{
	RelWspolwystepowanie, RelNapiecie, RelSekwencja, RelSprzecznosc,
	RelWzmocnienie, RelMediacja, RelParalela,
}

// ConstructKind rozroznia konstrukt kategorialny od kompozytu (M1, v1.3).
type ConstructKind string

const (
	KindCategory  ConstructKind = "category"
	KindComposite ConstructKind = "composite"
)

// Ontology to jedna wersja ontologii jednej modalnosci.
type Ontology struct {
	Modality string `yaml:"modality"`
	Version  string `yaml:"version"`
	// ApprovedBy jest lustrem statusu `approved` z bazy. W plikach SEED
	// zawsze puste — import tworzy wersje `draft`.
	ApprovedBy []string `yaml:"approved_by"`

	Constructs map[string]*Construct `yaml:"constructs"`

	EpistemicStatuses []EpistemicStatus `yaml:"epistemic_statuses"`
	// EtiologyPolicy: "strict" = twierdzenia genetyczne wylacznie ze
	// spanem zrodlowym (regula R5 walidatora dziedzinowego).
	EtiologyPolicy string `yaml:"etiology_policy"`
	// TherapistBoundary: "strict" = zakaz inferencji o stanach
	// wewnetrznych terapeuty (R10, dok. 11 v1.4).
	TherapistBoundary string         `yaml:"therapist_boundary"`
	RelationTypes     []RelationType `yaml:"relation_types"`
	ReportProfile     *ReportProfile `yaml:"report_profile,omitempty"`
}

// Construct to jedna kategoria/kompozyt taksonomii.
type Construct struct {
	LabelPL string `yaml:"label_pl"`
	// LabelEN to etykieta dla raportow w jezyku angielskim (raport
	// wychodzi w jezyku KARTOTEKI, nie ontologii). Opcjonalna — brak
	// tlumaczenia renderuje label_pl, co samo zglasza luke ekspertowi.
	LabelEN    string   `yaml:"label_en,omitempty"`
	Aliases    []string `yaml:"aliases,omitempty"`
	Definition string   `yaml:"definition,omitempty"`
	Source     *Source  `yaml:"source,omitempty"`

	Kind             ConstructKind    `yaml:"kind,omitempty"`
	Slots            map[string]*Slot `yaml:"slots,omitempty"`
	MinCompleteSlots *int             `yaml:"min_complete_slots,omitempty"`

	// Values null = konstrukt bez katalogu zamknietego. Niepusta lista
	// trafia do JSON Schema jako enum.
	Values     []string    `yaml:"values,omitempty"`
	MultiLabel bool        `yaml:"multi_label,omitempty"`
	Quantities *Quantities `yaml:"quantities,omitempty"`
	// ForcedStatus wymusza status konstruktu niezaleznie od sadu modelu
	// (np. core_belief CBT -> zawsze theoretical_hypothesis).
	ForcedStatus EpistemicStatus `yaml:"forced_status,omitempty"`

	IsNot    []string `yaml:"is_not,omitempty"`
	Requires []string `yaml:"requires,omitempty"`

	MinEvidence      *MinEvidence `yaml:"min_evidence,omitempty"`
	CommonConfusions []Confusion  `yaml:"common_confusions,omitempty"`
	Examples         []string     `yaml:"examples,omitempty"`
	CounterExamples  []string     `yaml:"counter_examples,omitempty"`
	// FallbackRendering: jak renderowac przy niespelnionym `requires`
	// (R3 degraduje, NIGDY nie podnosi rangi).
	FallbackRendering string `yaml:"fallback_rendering,omitempty"`
}

// Source wiaze definicje z literatura — ontologia jest zrodlem prawdy
// zamiast modelu, wiec sama musi byc audytowalna.
type Source struct {
	WorkID  string `yaml:"work_id"`
	Edition string `yaml:"edition"`
	Pages   string `yaml:"pages"`
}

// Slot to jeden typowany element kompozytu (M1).
type Slot struct {
	Type     string `yaml:"type"`
	Required bool   `yaml:"required,omitempty"`
	KindHint string `yaml:"kind_hint,omitempty"`
	// Quantity: slot dopuszcza wartosc liczbowa; podlega polityce
	// Quantities i regule R9 (liczba bez spanu = twarde odrzucenie).
	Quantity bool `yaml:"quantity,omitempty"`
}

// Quantities to polityka wartosci liczbowych (M3).
type Quantities struct {
	// Policy: "stated_only" — liczba dopuszczalna WYLACZNIE ze spanem,
	// w ktorym padla. Fabrykowana precyzja jest konfabulacja.
	Policy string `yaml:"policy"`
	Scale  string `yaml:"scale,omitempty"`
}

// MinEvidence to prog dowodowy konstruktu (R2).
type MinEvidence struct {
	Spans      int  `yaml:"spans"`
	Sessions   *int `yaml:"sessions,omitempty"`
	Behavioral *int `yaml:"behavioral,omitempty"`
}

// Confusion to wpis w zywym rejestrze antywzorcow. Zasilany feedbackiem
// i bledami benchmarku.
type Confusion struct {
	Input   string `yaml:"input"`
	Correct string `yaml:"correct"`
	Note    string `yaml:"note,omitempty"`
}

// Sekcje raportu (M5). Kanoniczna lista — walidator odrzuca klucze
// spoza niej, bo literowka w nazwie sekcji ("patterns_and_relatoins")
// dzialalaby jak brak wpisu i nikt by sie nie dowiedzial.
const (
	SectionSessionSummary = "session_summary"
	SectionInterpretive   = "interpretive_constructs"
	SectionPatterns       = "patterns_and_relations"
	SectionOpenQuestions  = "open_questions"
	SectionOutOfTaxonomy  = "out_of_taxonomy"
)

// ReportSections to komplet znanych sekcji W KOLEJNOSCI DOMYSLNEJ.
// Kolejnosc jest czescia kontraktu: profil bez wag (albo z wagami
// rownymi) renderuje dokladnie w tym porzadku.
var ReportSections = []string{
	SectionSessionSummary, SectionInterpretive, SectionPatterns,
	SectionOpenQuestions, SectionOutOfTaxonomy,
}

// Wagi sekcji. Waga steruje KOLEJNOSCIA, nigdy widocznoscia — ukrycie
// zweryfikowanej tresci byloby decyzja o tresci, a M5 zmienia wylacznie
// kompozycje (dok. 15 §3.3: "nie zmienia walidacji ani statusow").
const (
	WeightHigh   = "high"
	WeightNormal = "normal"
	WeightLow    = "low"
)

// KnownTones to tony jezykowe S4 o ZDEFINIOWANYM dzialaniu. Enum jest
// celowo ciasny: ton, ktorego szablon S4 nie zna, bylby po cichu
// ignorowany — a to dokladnie ta klasa pulapki, ktora metaschemat ma
// wykluczac. Nowy ton = nowy szablon + wpis tutaj, swiadomie.
var KnownTones = []string{"phenomenological"}

// Rodzaje sekcji ukladu (M5+). Kazdy rodzaj to KLOCEK renderera —
// uklad mowi, ktore klocki, w jakiej kolejnosci i pod jakim tytulem.
const (
	LayoutSummary       = "summary"         // esencja z call-1 + kotwice pamieciowe
	LayoutConstructs    = "constructs"      // przestrzen hipotez wskazanych konstruktow
	LayoutSuggestions   = "suggestions"     // propozycje miedzy sesjami (S4, ugruntowane)
	LayoutInterventions = "interventions"   // propozycje interwencji (S4, ugruntowane)
	LayoutOverlooked    = "overlooked"      // "czego mozna bylo nie zauwazyc"
	LayoutQuestions     = "questions"       // niewiadome + pytania na kolejna sesje
	LayoutPatterns      = "patterns"        // wzmianki o wzorcach
	LayoutOutOfTaxonomy = "out_of_taxonomy" // no_fit
)

var LayoutKinds = []string{
	LayoutSummary, LayoutConstructs, LayoutSuggestions, LayoutInterventions,
	LayoutOverlooked, LayoutQuestions, LayoutPatterns, LayoutOutOfTaxonomy,
}

// ReportProfile to kompozycja raportu (M5).
//
// Dwa poziomy: `sections` (wagi high/normal/low nad sekcjami domyslnymi)
// dla modalnosci, ktorym wystarczy kolejnosc — oraz `layout` (uklad
// nazwanych sekcji z przypisaniem konstruktow) dla modalnosci, ktore
// odwzorowuja strukture znana terapeutom z raportow legacy. WZAJEMNIE
// WYKLUCZAJACE: obecnosc obu to blad walidacji, bo dwie rownolegle
// definicje kolejnosci nie maja rozstrzygniecia.
type ReportProfile struct {
	Sections    map[string]SectionProfile `yaml:"sections,omitempty"`
	Layout      []LayoutSection           `yaml:"layout,omitempty"`
	DefaultTone string                    `yaml:"default_tone,omitempty"`
}

// LayoutSection to jedna sekcja ukladu.
type LayoutSection struct {
	ID    string `yaml:"id"`
	Title string `yaml:"title"`
	// TitleEN — tytul sekcji dla raportow angielskich; opcjonalny,
	// fallback na Title (ta sama zasada co label_en konstruktu).
	TitleEN string `yaml:"title_en,omitempty"`
	Kind    string `yaml:"kind"`
	// Constructs przypisuje konstrukty do sekcji rodzaju `constructs`.
	// Konstrukt moze nalezec do JEDNEJ sekcji; nieprzypisane laduja w
	// sekcji koncowej — uklad nigdy nie ukrywa zweryfikowanej tresci.
	Constructs []string `yaml:"constructs,omitempty"`
	// Guidance to wytyczne generacyjne dla S4 (wylacznie rodzaje
	// suggestions/interventions). Zyja w ontologii, nie w prompcie:
	// sa trescia ekspercka, wersjonowana i podlegajaca four-eyes.
	Guidance string `yaml:"guidance,omitempty"`
}

type SectionProfile struct {
	Weight string `yaml:"weight"`
}

// IsApproved mowi, czy tresc niesie autoryzacje ekspercka.
//
// UWAGA: to NIE wystarcza do serwowania na produkcji. Aktywacja jest
// osobna operacja (wskaznik active_version_id ustawiany wylacznie przez
// SUPERWIZOR_ADMIN na wersji approved z zielonym benchmarkiem) — status
// != live, plan 16 v1.2 sekcja 1.
func (o *Ontology) IsApproved() bool { return len(o.ApprovedBy) > 0 }

// ConstructIDs zwraca posortowane identyfikatory — determinizm jest tu
// warunkiem powtarzalnosci promptow S2 i diffow w Studio.
func (o *Ontology) ConstructIDs() []string {
	out := make([]string, 0, len(o.Constructs))
	for id := range o.Constructs {
		out = append(out, id)
	}
	sortStrings(out)
	return out
}
