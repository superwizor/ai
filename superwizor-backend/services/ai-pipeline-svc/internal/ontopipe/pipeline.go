// Package ontopipe to potok wnioskowania S1-S5 (dok. 11 sekcja 4).
//
// Kolejnosc etapow NIE jest konwencja — jest architektura:
//
//	S1   ekstrakcja spanow      (Flash)  → weryfikacja mechaniczna cytatow
//	S1.5 wzorce                 (Go)     → deterministyczne, pkg/ontology
//	S2   mapowanie per konstrukt (Pro)   → enum z ontologii w schemacie
//	S3   walidator dziedzinowy  (Go)     → R1-R10, pkg/ontology
//	S4   synteza                (Pro)    → BEZ DOSTEPU DO TRANSKRYPCJI
//	S5   weryfikator wyjscia    (Go)     → V1-V6
//
// KLUCZOWA INWERSJA (dok. 11): koszt dopowiedzenia przestaje byc zerowy,
// bo S4 fizycznie nie widzi materialu, z ktorego moglby konfabulowac.
// Wszystko, czym dysponuje, zostalo juz policzone, skategoryzowane i
// podparte w S1-S3. Ta wlasnosc jest wymuszona SYGNATURA funkcji
// Synthesize, nie komentarzem — patrz stages.go.
package ontopipe

import (
	"context"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Wersje promptow trafiaja na raport (kolumna prompt_versions z
// migracji 000089). Bez nich nie da sie odtworzyc, czym powstal raport
// sprzed miesiaca — a to jest wymog audytu (art. 94 MDR) i warunek
// sensownego benchmarku.
const (
	PromptVersionS1  = "s1/1.0.0"
	PromptVersionS2  = "s2/1.2.0" // blok ustalen z poprzednich sesji (F7a-3)
	PromptVersionS4  = "s4/1.6.0" // +6a; confidence; ton M5; sekcje generacyjne ukladu
	ValidatorVersion = "r1-r10/1.0.0"
	// PipelineVersion trafia do reports.pipeline_version.
	PipelineVersion = "ontology_s1s5"
)

// LLM to jedyne wejscie do modelu, jakie ma ten pakiet.
//
// Waski interfejs zamiast klienta Vertexa: testy podstawiaja atrape i
// caly potok da sie przejsc bez platnego wywolania. To nie jest wygoda —
// bez tego reguly S3 i S5 nie mialyby testu koncowego.
type LLM interface {
	// GenerateJSON wola model z wymuszonym schematem wyjscia. T=0
	// zawsze: potok ma byc odtwarzalny, a nie kreatywny.
	GenerateJSON(ctx context.Context, req LLMRequest) (LLMResponse, error)
}

type LLMRequest struct {
	Model        string
	SystemPrompt string
	UserContent  string
	Schema       map[string]any
	MaxTokens    int32
}

type LLMResponse struct {
	JSON         string
	InputTokens  int64
	OutputTokens int64
	Truncated    bool
}

// Modele per etap (dok. 11 sekcja 2a — rationale doboru).
//
// S1 i R4 na Flash: ekstrakcja cytatow to operacja czysto jezykowa, a
// entailment pytanie logiczno-jezykowe. Zaden z nich nie dotyka teorii.
//
// S2 na Pro i z CALA wiedza domenowa w kontekscie — to jedyny etap
// dotykajacy taksonomii. Przyszle optymalizacje kosztowe NIE MOGA
// przeniesc S2 na model mniejszy ani wprowadzic selekcji kontekstu bez
// przejscia benchmarku (sekcja 8).
const (
	ModelExtraction = "gemini-2.5-flash"
	ModelMapping    = "gemini-2.5-pro"
	ModelSynthesis  = "gemini-2.5-pro"
)

// Input to material wejsciowy calego potoku.
type Input struct {
	SessionID  string
	Transcript string
	// Ontology to AKTYWNA wersja dla modalnosci. Potok nie siega po nia
	// sam — dostaje ja od wolajacego, ktory rozstrzygnal przelacznik.
	Ontology *ontology.Ontology
	// Language to jezyk raportu z kartoteki (sessions.report_language).
	// Proza S4 i chrome renderera wychodza w tym jezyku; ontologia moze
	// byc w innym. Pusty = polski.
	Language string
	// Past to kontekst wczesniejszych sesji tej kartoteki (S0, plan F7a).
	//
	// Nil = potok jednosesyjny; to NIE jest stan wyjatkowy, tylko
	// normalny dla pierwszej sesji kartoteki i dla przebiegow sprzed
	// wdrozenia okna. Wolajacy laduje kontekst (ma baze i klucze),
	// potok go wylacznie konsumuje — ta sama zasada co z ontologia.
	Past *PastContext
}

// Result to wynik calego przebiegu.
type Result struct {
	Spans    []ontology.TopicSpan
	Patterns []ontology.Pattern
	Approved []ontology.Claim
	// Rejected i Degraded zasilaja rejestr walidatora
	// (report_claim_rejections) i telemetrie 8.3.
	Rejected     []ontology.Rejection
	Degraded     []ontology.Degradation
	NoFit        []string
	Insufficient []string
	Report       Report
	// S1Rejected to identyfikatory spanow odrzuconych przez weryfikacje
	// mechaniczna — metryka s1_reject_rate.
	S1Rejected []string
	// Violations to naruszenia V1-V6, ktore przetrwaly regeneracje.
	// Niepuste WYLACZNIE razem z Extractive — jesli synteza sie udala,
	// nie ma czego zglaszac.
	Violations []Violation
	// PrunedHypotheses to hipotezy USUNIETE po nieudanych regeneracjach.
	//
	// Niepuste znaczy: reszta prozy przeszla V1-V6 i zostala, a wycielismy
	// wylacznie te zdania, ktore sie nie obronily. Sygnal jest tej samej
	// wagi co Extractive — model nie utrzymal sie w szynach — ale koszt
	// ponosza tylko wadliwe fragmenty, nie caly raport.
	PrunedHypotheses []string
	// Extractive oznacza raport zlozony z cytatow i kategorii, bez prozy.
	// To sygnal do alertu (dok. 11: naruszenie po dwoch regeneracjach),
	// a nie zwykly wariant renderingu.
	Extractive bool
	// SkippedComposites to konstrukty kompozytowe pominiete przez S2.
	// Jawne, zeby pokrycie taksonomii nie wygladalo na pelne.
	SkippedComposites []string
	Usage             Usage
}

type Usage struct {
	InputTokens  int64
	OutputTokens int64
	Calls        int
}

func (u *Usage) add(r LLMResponse) {
	u.InputTokens += r.InputTokens
	u.OutputTokens += r.OutputTokens
	u.Calls++
}
