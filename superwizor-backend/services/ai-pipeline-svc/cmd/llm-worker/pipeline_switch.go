package llmworker

import (
	"context"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/appconfig"
)

// Przelacznik potoku raportu (plan 16, sekcja 2.1-2.2).
//
// Wdrozenie nowego potoku wnioskowania (S1-S5, dok. 11) idzie MODALNOSC
// PO MODALNOSCI, z mozliwoscia natychmiastowego powrotu do dotychczasowej
// generacji. Powrot ma byc zmiana konfiguracji (<= 30 s propagacji przez
// TTL czytnika appconfig), nie deployem i nie rollbackiem kodu — dokladnie
// jak kill-switch czatu, ktory ten wzorzec juz sprawdzil w boju.
//
// Dlatego rozstrzyganie mieszka w OSOBNYM PLIKU, a galaz `legacy` w
// ProcessTranscript pozostaje niezmieniona takze na poziomie diffa:
// wiarygodnosc przelacznika bierze sie stad, ze stara sciezka nie zostala
// "przy okazji" zrefaktoryzowana.

// pipelineDecision to rozstrzygniecie dla jednej generacji raportu.
//
// Rozstrzygamy RAZ, na poczatku generacji, i stemplujemy wynik na
// raporcie. Raport w locie konczy sie potokiem, w ktorym wystartowal —
// przelaczenie w trakcie nie moze zmienic mu polowy przebiegu.
type pipelineDecision struct {
	// Pipeline to nazwa wybranej sciezki: appconfig.PipelineLegacy albo
	// appconfig.PipelineOntology.
	Pipeline string
	// FallbackReason jest niepuste, gdy konfiguracja PROSILA o potok
	// ontologiczny, ale warunki nie byly spelnione. Wtedy Pipeline ==
	// legacy, a to pole mowi dlaczego — zasila telemetrie
	// report_pipeline_fallback i panel Jakosci.
	FallbackReason string
}

// Powody spadku na legacy. Rozdzielone, bo prowadza do roznych dzialan:
// brak aktywnej wersji to zadanie dla admina (aktywuj), brak kodu
// modalnosci to blad konfiguracji, a not_implemented znika wraz z F2.
const (
	fallbackNoActiveOntology = "no_active_ontology"
	fallbackUnknownModality  = "unknown_modality_code"
	fallbackNotImplemented   = "pipeline_not_implemented"
)

// ontologyAvailability mowi, czy modalnosc ma aktywna wersje ontologii.
//
// Interfejs, nie funkcja: w F0 podstawiamy implementacje czytajaca
// modalities.active_ontology_version_id, a testy podstawiaja atrape bez
// bazy. Aktywacje ustawia WYLACZNIE SUPERWIZOR_ADMIN na wersji
// `approved` z zielonym benchmarkiem (plan 16, sekcja 4.1) — worker tego
// nie sprawdza ponownie, tylko ufa wskaznikowi.
type ontologyAvailability interface {
	// ActiveVersion zwraca semver aktywnej wersji albo "" gdy brak.
	ActiveVersion(ctx context.Context, modalityID uuid.UUID) (string, error)
}

// resolvePipeline rozstrzyga, ktorym potokiem generowac raport.
//
// FAIL-CLOSED NA LEGACY jest tu niezmiennikiem, nie zachowaniem
// domyslnym: kazda watpliwosc — nieznany kod modalnosci, brak aktywnej
// ontologii, blad odczytu bazy — konczy sie stara sciezka. Odwrotny
// kierunek (watpliwosc -> nowy potok) nie istnieje w tym kodzie i nie
// powinien powstac.
func resolvePipeline(
	ctx context.Context,
	cfg *appconfig.Reader,
	avail ontologyAvailability,
	sc *SessionContext,
	logger *slog.Logger,
) pipelineDecision {
	legacy := pipelineDecision{Pipeline: appconfig.PipelineLegacy}

	if cfg == nil || sc == nil || sc.SystemCode == "" {
		if sc != nil && sc.SystemCode == "" {
			logger.Warn("przelacznik potoku: brak system_code modalnosci — legacy",
				"modality_id", sc.ModalityID)
			return pipelineDecision{Pipeline: appconfig.PipelineLegacy,
				FallbackReason: fallbackUnknownModality}
		}
		return legacy
	}

	want := cfg.Get(ctx, appconfig.KeyReportPipeline(sc.SystemCode), sc.OrganizationID)
	if want != appconfig.PipelineOntology {
		// Wartosc pusta (klucz niezadeklarowany), "legacy" albo smiec —
		// wszystko to ta sama odpowiedz.
		return legacy
	}

	if avail == nil {
		return pipelineDecision{Pipeline: appconfig.PipelineLegacy,
			FallbackReason: fallbackNoActiveOntology}
	}
	version, err := avail.ActiveVersion(ctx, sc.ModalityID)
	if err != nil {
		// Blad odczytu NIE jest powodem, zeby zaryzykowac nowy potok.
		logger.Warn("przelacznik potoku: odczyt aktywnej ontologii nieudany — legacy",
			"error", err, "system_code", sc.SystemCode)
		return pipelineDecision{Pipeline: appconfig.PipelineLegacy,
			FallbackReason: fallbackNoActiveOntology}
	}
	if version == "" {
		logger.Warn("przelacznik potoku: brak AKTYWNEJ wersji ontologii — legacy",
			"system_code", sc.SystemCode,
			"wskazowka", "aktywacja: /admin/ontologies, wymaga statusu approved i zielonego benchmarku")
		return pipelineDecision{Pipeline: appconfig.PipelineLegacy,
			FallbackReason: fallbackNoActiveOntology}
	}

	// F0: potok istnieje jako rozstrzygniecie, ale nie ma jeszcze
	// implementacji (ontopipe wchodzi w F2). Zwracamy legacy z jawnym
	// powodem — to jest wlasnie test bramki F0: ustawienie `ontology`
	// przed czasem NIE MOZE zepsuc generacji raportu.
	logger.Info("przelacznik potoku: ontologia zadana, implementacja jeszcze nie gotowa — legacy",
		"system_code", sc.SystemCode, "ontology_version", version)
	return pipelineDecision{Pipeline: appconfig.PipelineLegacy,
		FallbackReason: fallbackNotImplemented}
}

// pipelineConfig to czytnik konfiguracji dla przelacznika.
//
// Osobny od reszty workera i inicjalizowany leniwie, bo llm-worker jest
// Cloud Function bez func main(): init() nie ma gwarancji, ze pula bazy
// jest gotowa, a pierwszy odczyt i tak nastepuje dopiero przy pierwszym
// raporcie.
var pipelineConfig *appconfig.Reader

// pipelineFor rozstrzyga potok dla jednej generacji i jest JEDYNYM
// punktem, w ktorym ProcessTranscript pyta o przelacznik.
//
// Rozstrzygamy RAZ, na poczatku generacji: raport w locie konczy sie
// potokiem, w ktorym wystartowal.
func pipelineFor(ctx context.Context, sc *SessionContext, logger *slog.Logger) pipelineDecision {
	if pipelineConfig == nil && dbPool != nil {
		pipelineConfig = appconfig.NewReader(appconfigPool{dbPool})
	}
	return resolvePipeline(ctx, pipelineConfig, activeOntologyFromDB{}, sc, logger)
}

// appconfigPool adaptuje pule do waskiego interfejsu appconfig.
type appconfigPool struct{ pool *pgxpool.Pool }

func (a appconfigPool) Query(ctx context.Context, sql string, args ...any) (appconfig.Rows, error) {
	rows, err := a.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	return rows, nil
}

// activeOntologyFromDB czyta wskaznik aktywnej wersji z bazy.
type activeOntologyFromDB struct{}

func (activeOntologyFromDB) ActiveVersion(ctx context.Context, modalityID uuid.UUID) (string, error) {
	var version *string
	err := dbPool.QueryRow(ctx, `
		SELECT ov.version
		  FROM modalities m
		  JOIN ontology_versions ov ON ov.id = m.active_ontology_version_id
		 WHERE m.id = $1`, modalityID).Scan(&version)
	if err != nil {
		// Brak wiersza = brak aktywnej wersji, nie awaria. Wolajacy i tak
		// rozstrzyga oba przypadki na legacy, ale rozroznienie trzyma
		// logi czyste z falszywych bledow.
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	if version == nil {
		return "", nil
	}
	return *version, nil
}
