package llmworker

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"os"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/appconfig"
)

func cichyLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

// atrapaDostepnosci podstawia wskaznik aktywnej wersji bez bazy.
type atrapaDostepnosci struct {
	version string
	err     error
}

func (a atrapaDostepnosci) ActiveVersion(context.Context, uuid.UUID) (string, error) {
	return a.version, a.err
}

// atrapaKonfiguracji podstawia wiersze app_config bez bazy. Ksztalt
// wiersza lustrzany wobec appconfig.selectAll: (key, value, organization_id).
type atrapaKonfiguracji struct{ wiersze [][3]any }

func (f atrapaKonfiguracji) Query(context.Context, string, ...any) (appconfig.Rows, error) {
	return &atrapaWierszy{w: f.wiersze}, nil
}

type atrapaWierszy struct {
	w [][3]any
	i int
}

func (r *atrapaWierszy) Next() bool { r.i++; return r.i <= len(r.w) }
func (r *atrapaWierszy) Err() error { return nil }
func (r *atrapaWierszy) Close()     {}
func (r *atrapaWierszy) Scan(dest ...any) error {
	row := r.w[r.i-1]
	*(dest[0].(*string)) = row[0].(string)
	*(dest[1].(*string)) = row[1].(string)
	if row[2] == nil {
		*(dest[2].(**uuid.UUID)) = nil
	} else {
		id := row[2].(uuid.UUID)
		*(dest[2].(**uuid.UUID)) = &id
	}
	return nil
}

// konfiguracjaZOntologia zwraca czytnik, w ktorym PPT ma wlaczony potok
// ontologiczny globalnie.
func konfiguracjaZOntologia(t *testing.T) *appconfig.Reader {
	t.Helper()
	r := appconfig.NewReader(atrapaKonfiguracji{wiersze: [][3]any{
		{appconfig.KeyReportPipeline("PPT"), appconfig.PipelineOntology, nil},
	}})
	if err := r.Refresh(context.Background()); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	return r
}

func sesja(code string) *SessionContext {
	return &SessionContext{
		ID:         uuid.New(),
		ModalityID: uuid.New(),
		SystemCode: code,
	}
}

// TestBramkaF0_OntologiaBezImplementacjiNiePsujeGeneracji to test bramki
// wyjsciowej fazy F0 z planu 16: "ustawienie `ontology` bez implementacji
// NIE psuje generacji raportu".
//
// Od F2 komplet warunkow (konfiguracja prosi + modalnosc ma AKTYWNA
// wersje) prowadzi do nowego potoku. Do F2 ta sama sytuacja konczyla sie
// legacy z powodem `pipeline_not_implemented` — bramka F0 pilnowala, ze
// wlaczenie przelacznika przed czasem nie psuje generacji. Bramka
// spelnila swoja role i zostaje zastapiona testem docelowego zachowania.
func TestOntologiaGdyKonfiguracjaIAktywnaWersja(t *testing.T) {
	cfg := konfiguracjaZOntologia(t)
	d := resolvePipeline(context.Background(), cfg,
		atrapaDostepnosci{version: "1.0.0"}, sesja("PPT"), cichyLogger())

	if d.Pipeline != appconfig.PipelineOntology {
		t.Fatalf("potok = %q, oczekiwano %q", d.Pipeline, appconfig.PipelineOntology)
	}
	if d.FallbackReason != "" {
		t.Errorf("powod spadku = %q przy udanym rozstrzygnieciu", d.FallbackReason)
	}
	// Wersja MUSI wrocic z rozstrzygnieciem: trafia na raport i bez niej
	// nie da sie po fakcie odtworzyc, czym raport powstal.
	if d.OntologyVersion != "1.0.0" {
		t.Errorf("wersja ontologii = %q, oczekiwano 1.0.0", d.OntologyVersion)
	}
}

// TestKonfiguracjaFaktyczniePrositOOntologie chroni przed testem, ktory
// zieleni sie z niewlasciwego powodu: jesli atrapa konfiguracji przestanie
// dzialac, pozostale testy fail-closed przestana cokolwiek sprawdzac, bo
// warunek `want == ontology` nigdy nie bedzie spelniony.
func TestKonfiguracjaFaktyczniePrositOOntologie(t *testing.T) {
	cfg := konfiguracjaZOntologia(t)
	got := cfg.Get(context.Background(), appconfig.KeyReportPipeline("PPT"), uuid.Nil)
	if got != appconfig.PipelineOntology {
		t.Fatalf("atrapa konfiguracji zwrocila %q — testy fail-closed byly by puste", got)
	}
}

// TestFailClosedNaKazdaWatpliwosc — niezmiennik planu 16 sekcja 2.1.
// Kazdy z tych przypadkow ma skonczyc sie stara sciezka, a NIE bledem
// generacji i nie nowym potokiem.
func TestFailClosedNaKazdaWatpliwosc(t *testing.T) {
	ctx := context.Background()
	cfg := konfiguracjaZOntologia(t) // wszystkie przypadki startuja z "ontology" w konfiguracji

	przypadki := []struct {
		opis  string
		avail ontologyAvailability
		sesja *SessionContext
		powod string
	}{
		{"brak kodu modalnosci", atrapaDostepnosci{version: "1.0.0"},
			sesja(""), fallbackUnknownModality},
		{"nieznany kod modalnosci", atrapaDostepnosci{version: "1.0.0"},
			sesja("NIEISTNIEJE"), ""},
		{"brak aktywnej wersji", atrapaDostepnosci{version: ""},
			sesja("PPT"), fallbackNoActiveOntology},
		// Wersja NIEPUSTA razem z bledem jest celowa: sprawdza, ze blad
		// jest badany PRZED wersja. Gdyby obsluga bledu zniknela, kod
		// poszedlby dalej z wersja "9.9.9" i zwrocil inny powod — czyli
		// test wykryje regresje, ktorej nie wykryl przy pustej wersji.
		{"blad odczytu bazy", atrapaDostepnosci{version: "9.9.9", err: errors.New("padlo")},
			sesja("PPT"), fallbackNoActiveOntology},
		{"brak implementacji dostepnosci", nil, sesja("PPT"), fallbackNoActiveOntology},
	}

	for _, c := range przypadki {
		d := resolvePipeline(ctx, cfg, c.avail, c.sesja, cichyLogger())
		if d.Pipeline != appconfig.PipelineLegacy {
			t.Errorf("%s: potok = %q, oczekiwano legacy", c.opis, d.Pipeline)
		}
		if c.powod != "" && d.FallbackReason != c.powod {
			t.Errorf("%s: powod = %q, oczekiwano %q", c.opis, d.FallbackReason, c.powod)
		}
	}
}

// TestNilKonfiguracjiNieWywracaGeneracji — worker nie moze paść przez
// nieskonfigurowany czytnik; raport ma powstac stara sciezka.
func TestNilKonfiguracjiNieWywracaGeneracji(t *testing.T) {
	d := resolvePipeline(context.Background(), nil,
		atrapaDostepnosci{version: "1.0.0"}, sesja("PPT"), cichyLogger())
	if d.Pipeline != appconfig.PipelineLegacy {
		t.Errorf("potok = %q, oczekiwano legacy", d.Pipeline)
	}
}

// TestPowodSpadkuRozroznia — powody prowadza do roznych dzialan
// operacyjnych, wiec nie moga byc zlane w jeden. "Brak aktywnej wersji"
// to zadanie dla admina (aktywuj w Studio); "ontologia nieuzywalna" to
// zadanie dla autora tresci; nieznany kod modalnosci to blad wdrozenia.
func TestPowodSpadkuRozroznia(t *testing.T) {
	powody := []string{fallbackNoActiveOntology, fallbackUnknownModality,
		fallbackOntologyUnusable}
	widziane := map[string]bool{}
	for _, p := range powody {
		if p == "" || widziane[p] {
			t.Fatalf("powody spadku musza byc rozroznialne w telemetrii: %v", powody)
		}
		widziane[p] = true
	}
}

// TestPrzelacznikJestWolanyWSciezceProdukcyjnej pilnuje luki, ktora
// realnie powstala 22.08.2026.
//
// resolvePipeline, jego testy i implementacja odczytu z bazy istnialy —
// ale ProcessTranscript nigdy ich nie wolal. Wszystkie testy jednostkowe
// przechodzily, bramka F0 wygladala na zamknieta, a w produkcji
// przelacznika nie bylo. Ujawnil to dopiero golangci-lint ("unused"),
// czyli przypadek.
//
// Test czyta zrodlo, bo alternatywa (uruchomienie ProcessTranscript)
// wymaga Pub/Suba, bazy i Vertexa. Sprawdzana jest OBECNOSC WYWOLANIA,
// nie jego wynik — wynik pokrywaja pozostale testy w tym pliku.
func TestPrzelacznikJestWolanyWSciezceProdukcyjnej(t *testing.T) {
	src, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatalf("odczyt main.go: %v", err)
	}
	kod := string(src)

	if !strings.Contains(kod, "pipelineFor(ctx, session, logger)") {
		t.Error("ProcessTranscript nie wola pipelineFor — przelacznik, ktorego nikt nie pyta, " +
			"nie jest przelacznikiem")
	}
	// Slad na raporcie: bez niego nie da sie po fakcie powiedziec, czym
	// raport powstal (plan 16 §2.3). Od F2 to komplet — nazwa potoku,
	// wersja ontologii, wersje promptow i walidatora.
	if !strings.Contains(kod, "pipelineProvenance(pipeline)") {
		t.Error("wynik rozstrzygniecia nie trafia do persistReport — raport bez sladu potoku")
	}
	// Galaz ontologiczna musi byc WOLANA, nie tylko istniec — dokladnie
	// ta luka powstala 22.08 przy samym resolvePipeline.
	if !strings.Contains(kod, "runOntologyPipeline(ctx, logger, session,") {
		t.Error("ProcessTranscript nie wola potoku ontologicznego — implementacja bez sciezki " +
			"produkcyjnej to ten sam blad, co przelacznik, ktorego nikt nie pyta")
	}
	if !strings.Contains(kod, "ontopipe.Persist(ctx,") {
		t.Error("graf twierdzen nie jest utrwalany — raport bez proweniencji do spanow")
	}
	if !strings.Contains(kod, "report_pipeline_fallback") {
		t.Error("spadek na legacy nie jest raportowany — telemetria nie zobaczy, " +
			"ze ktos wlaczyl ontologie bez aktywnej wersji")
	}

	// Tryb eksperymentalny musi KONCZYC SIE przed lustrami produkcyjnymi.
	// Etykiety mowcow nadpisalyby sesje, pamiec RAG zasilalaby przyszle
	// raporty produkcyjne trescia z niezautoryzowanej ontologii, a
	// session.status_changed wyslalby push "Raport gotowy" o czyms, co
	// nie jest materialem klinicznym.
	iEksperyment := strings.Index(kod, "Raport eksperymentalny KONCZY SIE TUTAJ")
	if iEksperyment < 0 {
		t.Fatal("brak wczesnego wyjscia dla raportu eksperymentalnego")
	}
	for _, lustro := range []string{
		"generateAndSaveSpeakerLabels(ctx, session,",
		"persistRAGMemoryV2(ctx, session,",
		`publishSessionStatusChanged(ctx, ev.SessionID, "done")`,
	} {
		i := strings.Index(kod, lustro)
		if i >= 0 && i < iEksperyment {
			t.Errorf("lustro produkcyjne %q stoi PRZED wyjsciem eksperymentu — "+
				"raport eksperymentalny by je uruchomil", lustro)
		}
	}
}

// Kontekst miedzysesyjny (S0, plan F7a-2) musi byc WOLANY w obu
// galeziach ontologicznych i doniesiony az do zapisu proweniencji.
//
// Ta sama klasa bledu co przy przelaczniku 22.08 i przy uprawnieniu
// publikacji llm-workera (dwukrotnie): kod istnial, testy jednostkowe
// przechodzily, a w produkcji nikt go nie wolal. Loader bez wywolania
// daje raport jednosesyjny, ktory wyglada dokladnie tak samo jak raport
// z kontekstem — cisza jest tu nierozroznialna od poprawnosci.
func TestKontekstMiedzysesyjnyJestWolanyIZapisywany(t *testing.T) {
	src, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatalf("odczyt main.go: %v", err)
	}
	kod := string(src)

	// Eksperyment i produkcja: rozne wartosci flagi klasy potoku, bo
	// twierdzenia niosa slownictwo swojej ontologii i mieszanie klas
	// wpuszczaloby szkic do materialu klinicznego.
	if !strings.Contains(kod, "loadPastContext(ctx, logger, session, true)") {
		t.Error("galaz eksperymentalna nie laduje kontekstu miedzysesyjnego")
	}
	if !strings.Contains(kod, "loadPastContext(ctx, logger, session, false)") {
		t.Error("galaz produkcyjna nie laduje kontekstu miedzysesyjnego")
	}
	// Kontekst MUSI dojechac do potoku...
	if strings.Count(kod, "metadataPayload, o, pastContext)") != 2 {
		t.Error("kontekst nie trafia do runOntologyPipeline w obu galeziach")
	}
	// ...i do zapisu: co przebieg zobaczyl, jest czescia proweniencji
	// raportu (dok. 65 §N2), a nie metryka poboczna.
	if !strings.Contains(kod, "Past: pastContext,") {
		t.Error("kontekst nie trafia do ontopipe.Persist — raport bez zapisu swojego wejscia")
	}
}

// Indeks semantyczny (F7b-1) musi byc WOLANY, a klasa potoku ma isc
// z prov.Pipeline — czyli z tej samej wartosci, ktora trafia do
// reports.pipeline_version.
//
// Uzycie `pipeline.Pipeline` dawaloby "ontology" takze dla eksperymentu
// (stempel eksperymentalny doklada sie osobno), wiec pozniejszy filtr
// klasy nie trafialby w nic — i wygladaloby to jak brak historii, nie
// jak blad. Ta sama klasa pomylki co dwukrotnie przeoczone uprawnienie
// publikacji: kod istnieje, testy przechodza, a w produkcji cisza.
func TestIndeksSemantycznyWolanyZWlasciwaKlasa(t *testing.T) {
	src, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatalf("odczyt main.go: %v", err)
	}
	kod := string(src)

	if !strings.Contains(kod, "indexInference(ctx, logger, session, repID, ontoRes, prov.Pipeline)") {
		t.Error("indeks wnioskowania nie jest zasilany albo dostaje zla klase potoku")
	}
	// Kolejnosc: PO zapisie grafu twierdzen. Indeksujemy to, co
	// faktycznie stalo sie czescia raportu.
	iPersist := strings.Index(kod, "ontopipe.Persist(ctx,")
	iIndex := strings.Index(kod, "indexInference(ctx,")
	if iPersist < 0 || iIndex < 0 || iIndex < iPersist {
		t.Error("indeksowanie przed zapisem grafu albo brak wywolania")
	}
}

// Semantyka (F7b-2) musi DOKLADAC do okna, nie zastepowac go — i musi
// byc wolana w obu galeziach z wlasciwa klasa potoku.
//
// Kolejnosc w zrodle jest tu trescia, nie stylem: gdyby semantyka szla
// przed oknem albo zamiast niego, jeden zle dobrany prog odcinalby caly
// kontekst po cichu, a raport wygladalby jak raport bez historii.
func TestSemantykaDokladaDoOkna(t *testing.T) {
	src, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatalf("odczyt main.go: %v", err)
	}
	kod := string(src)

	if strings.Count(kod, "dolaczSemantyczne(ctx, logger, session, pastContext,") != 2 {
		t.Error("semantyka nie jest wolana w obu galeziach ontologicznych")
	}
	// Klasa potoku po obu stronach granicy: eksperyment widzi wylacznie
	// eksperymentalna historie, produkcja wylacznie produkcyjna.
	if !strings.Contains(kod, "PipelineExperimental)") {
		t.Error("galaz eksperymentalna pyta indeks bez swojej klasy")
	}
	if !strings.Contains(kod, "appconfig.PipelineOntology)") {
		t.Error("galaz produkcyjna pyta indeks bez swojej klasy")
	}
	// Okno ZAWSZE pierwsze.
	iOkno := strings.Index(kod, "loadPastContext(ctx, logger, session, true)")
	iSem := strings.Index(kod, "dolaczSemantyczne(ctx, logger, session, pastContext,")
	if iOkno < 0 || iSem < 0 || iSem < iOkno {
		t.Error("semantyka wolana przed oknem albo w ogole")
	}
}

