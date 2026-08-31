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
	PromptVersionS1  = "s1/1.1.0" // fact_kind — fakty sesyjne (E4/T42a, docs/67)
	PromptVersionS2  = "s2/1.4.0" // dopisek homonimow miedzykonstruktowych "(tu: ...)" (nota E7); 1.3.0: glosy; 1.2.0: blok ustalen F7a-3
	PromptVersionS4  = "s4/1.7.0" // +6a; confidence; ton M5; sekcje generacyjne ukladu
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
	// Stage nazywa etap potoku ("S1", "S2", "S4"). Osobne pole, bo model
	// NIE jest identyfikatorem etapu: od 2026-08-25 wszystkie trzy chodza
	// na Flash, a wczesniej S2 i S4 dzielily Pro. Kod, ktory rozpoznawal
	// etap po `Model`, przez cala te historie dzialal przypadkiem i
	// przewrocil sie przy zmianie modelu.
	Stage        string
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

// Modele per etap.
//
// ══ Historia tej decyzji ══
//
// Dok. 11 §2a stawial S2 na Pro „z CALA wiedza domenowa w kontekscie",
// z jawnym zastrzezeniem: optymalizacje kosztowe NIE MOGA przeniesc S2
// na model mniejszy BEZ PRZEJSCIA BENCHMARKU. Przenosimy — i wlasnie
// dlatego benchmark jest czescia tej zmiany, nie obietnica na potem.
//
// ══ Dlaczego to jest do obrony ══
//
// Potok od poczatku NIE OPIERA SIE na rozumowaniu modelu. Myslenie jest
// wylaczone na kazdym etapie (Pro dostawal 128 tokenow, czyli minimum
// jakie przyjmuje, Flash zero) wlasnie dlatego, ze etapy sa
// strukturalne: S1 kopiuje cytaty i tak sprawdzane mechanicznie, S2
// wybiera z ENUMU kategorii i moze wskazac tylko istniejacy span, S4
// przepisuje zatwierdzone byty pod okiem V1-V7. Wieksza inteligencja
// modelu ma tu malo miejsca, zeby sie ujawnic — pilnuje go schemat
// i kod, nie zdolnosc do dlugiego wnioskowania.
//
// ══ Ile to kosztowalo ══
//
// S2 jest wolane RAZ NA KONSTRUKT (14 wywolan dla szkicu PPT), za
// kazdym razem z pelna lista spanow sesji. To tam szedl caly rachunek:
// raport eksperymentalny na Pro kosztowal okolo $0,45 wobec $0,028 za
// raport legacy — szesnastokrotnie wiecej.
//
// ══ Czego pilnowac ══
//
// Benchmark porownuje TE SAMA sesje przed i po: liczbe zatwierdzonych
// twierdzen, rozklad odrzucen R1-R10, naruszenia V1-V7 i to, czy raport
// nie wpadl w tryb ekstraktywny. Spadek jakosci na ktorymkolwiek z tych
// wymiarow uniewaznia oszczednosc — raport, ktoremu terapeuta nie ufa,
// nie jest tanszy, tylko bezuzyteczny.
const (
	ModelExtraction = "gemini-2.5-flash"
	ModelMapping    = "gemini-2.5-flash"
	ModelSynthesis  = "gemini-2.5-flash"
)

// Nazwy etapow. Sa stale wlasnie dlatego, ze modele nie sa: etap to
// miejsce w potoku, model to dzisiejsza decyzja kosztowa i te dwie
// rzeczy musza dac sie rozroznic w telemetrii i w testach.
const (
	StageExtraction = "S1"
	StageMapping    = "S2"
	StageSynthesis  = "S4"
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
	// FactMapped to konstrukty zmapowane deterministycznie z faktow
	// sesyjnych (E4/T42a) — z pominieciem S2. Do proweniencji i testow.
	FactMapped []string

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
