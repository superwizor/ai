package ontology

import "time"

// Typy dziedzinowe potoku S1-S5 (dok. 11, sekcja 4).
//
// Zyja w pkg/ontology, a nie w llm-workerze, z jednego powodu: walidator
// dziedzinowy (S3) jest wspoldzielony miedzy raportem a czatem
// (dok. 11 sekcja 7), a jego reguly operuja na tych ksztaltach. Typ w
// binarce workera zmusilby czat do importu Cloud Function.

// SpanKind rozroznia wypowiedz deklaratywna od opisu zachowania.
//
// Rozroznienie jest wymogiem dowodowym, nie metadanymi: min_evidence
// moze zadac spanu behawioralnego, bo deklaracja "jestem punktualny" i
// opis "przyszedl 20 minut po czasie" nie sa tym samym rodzajem dowodu.
type SpanKind string

const (
	SpanDeclarative SpanKind = "declarative"
	SpanBehavioral  SpanKind = "behavioral"
)

// ObservedBy mowi, czyja to obserwacja (v1.4, dok. 15).
type ObservedBy string

const (
	ObservedBySelf      ObservedBy = "self"      // samoopis klienta
	ObservedByTherapist ObservedBy = "therapist" // obserwacja terapeuty O KLIENCIE
)

// Span to jednostka dowodowa wyekstrahowana w S1.
type Span struct {
	ID        string
	SessionID string
	SessionAt time.Time
	Speaker   string
	// QuoteVerbatim to tekst zweryfikowany mechanicznie wzgledem
	// transkrypcji. Jesli nie przeszedl weryfikacji, span nie istnieje.
	QuoteVerbatim string
	Kind          SpanKind
	ObservedBy    ObservedBy
	// AboutPast oznacza span mowiacy WPROST o przeszlosci (dziecinstwo,
	// rodzina pochodzenia). Wylacznie taki span moze uzasadnic
	// twierdzenie etiologiczne — regula R5.
	AboutPast bool
	// RiskContent wyklucza span z wnioskowania (T22, dok. 14 sekcja 7).
	// Tresci ryzyka nie zasilaja S2/S2b/S1.5 — zadnych wnioskow, wzorcow
	// ani statystyk na ich bazie.
	RiskContent bool
	// FactKind (E4/T42a, docs/67 §3) oznacza span bedacy FAKTEM
	// sesyjnym: ustaleniem, agenda, pomiarem nastroju, metafora klienta.
	// Puste = zwykly span. Wartosci: FactKinds. Fakty sa mapowane na
	// twierdzenia DETERMINISTYCZNIE (fact_kind_map konstruktu), z
	// pominieciem S2 — fakt ze spanem nie potrzebuje inferencji.
	FactKind string
}

// FactKinds to zamkniety katalog rodzajow faktow sesyjnych (E4).
// Rozszerzenie katalogu = zmiana kontraktu S1 (nowa wersja promptu).
var FactKinds = []string{
	"agreement_client",    // praca domowa / zobowiazanie klienta
	"agreement_therapist", // zobowiazanie terapeuty (arkusz, material)
	"agenda_next",         // agenda kolejnej sesji
	"agenda_unaddressed",  // temat zgloszony, nieomowiony
	"mood_rating",         // pomiar nastroju podany przez klienta
	"client_metaphor",     // metafora klienta (PPT: kotwice jezykowe)
}

// QuoteRef to odnosnik dowodowy w twierdzeniu.
type QuoteRef struct {
	SpanID string
	Quote  string
}

// Claim to jedno twierdzenie zwrocone przez S2.
type Claim struct {
	ConstructID string
	// Categories: jedna pozycja dla konstruktu single-label, wiele dla
	// multi_label (M2), pusta gdy konstrukt nie ma katalogu.
	Categories      []string
	Evidence        []QuoteRef
	CounterEvidence []QuoteRef
	Status          EpistemicStatus
	Confidence      float64
	Reasoning       string
	// Etiological oznacza twierdzenie genetyczne (o genezie, dziecinstwie,
	// wzorcach miedzypokoleniowych). Ustawiane przez wolajacego na
	// podstawie klasyfikacji tresci, sprawdzane przez R5.
	Etiological bool
	// SubjectIsTherapist oznacza twierdzenie o stanie wewnetrznym
	// TERAPEUTY — R10 odrzuca je twardo.
	SubjectIsTherapist bool
	// Quantities to wartosci liczbowe wystepujace w twierdzeniu, wraz ze
	// spanem, z ktorego pochodza. R9 sprawdza, czy liczba faktycznie
	// padla w tym spanie.
	Quantities []Quantity
}

// Quantity to wartosc liczbowa uzyta w twierdzeniu.
type Quantity struct {
	// Raw to dokladny zapis liczby tak, jak wystapil w twierdzeniu
	// ("80%", "7/10"). Porownywany mechanicznie z trescia spanu.
	Raw string
	// SpanID wskazuje span, w ktorym liczba miala paść.
	SpanID string
	// FromEntry oznacza wartosc pochodzaca z rekordu aplikacji
	// towarzyszacej (entry_ref) — klient wpisal ja sam, wiec jest
	// stated_only z definicji i R9 jej nie kwestionuje.
	FromEntry bool
}

// StageResult to wynik jednego wywolania S2 dla jednego konstruktu.
type StageResult struct {
	ConstructID      string
	Claims           []Claim
	InsufficientData bool
	NoFit            bool
	Missing          string
}
