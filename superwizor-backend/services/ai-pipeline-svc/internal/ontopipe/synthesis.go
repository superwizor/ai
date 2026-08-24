package ontopipe

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// ── S4: synteza raportu ──
//
// KLUCZOWA INWERSJA ANTYKONFABULACYJNA (dok. 11 sekcja 4).
//
// S4 pisze JEZYK, nie decyduje o TRESCI. Wszystko, czym dysponuje,
// zostalo juz policzone (S1.5), skategoryzowane (S2) i sprawdzone (S3).
//
// Wlasnosc jest wymuszona SYGNATURA, nie konwencja: SynthesisInput nie
// ma pola na transkrypcje i nie da sie go dodac bez zmiany typu, ktora
// przejdzie przez review. Gdyby S4 dostawal material zrodlowy, koszt
// dopowiedzenia wrocilby do zera — model mialby z czego konfabulowac, a
// walidator dziedzinowy juz by go nie ogladal.
//
// TestS4NieMaDostepuDoTranskrypcji pilnuje tego przez refleksje po polach
// struktury. To nie paranoja: pole dodane w dobrej wierze (np. "dla
// kontekstu stylistycznego") cofneloby najwazniejsza gwarancje calej
// architektury, a nic w kompilacji by nie zaprotestowalo.

// SynthesisInput to WSZYSTKO, co widzi S4.
type SynthesisInput struct {
	Claims   []ontology.Claim
	Patterns []ontology.Pattern
	// Degraded to konstrukty z niespelnionym `requires`. Renderowane wg
	// fallback_rendering — R3 degraduje, nigdy nie podnosi rangi.
	Degraded []ontology.Degradation
	// Insufficient to konstrukty bez wystarczajacych danych. Renderowane
	// jako ZAPROSZENIE ("co warto sprawdzic"), nie jako blad — raport
	// wypelniony w 100% jest sygnalem alarmowym, nie sukcesem.
	Insufficient []string
	// NoFit to zjawiska poza taksonomia. Do raportu ida BEZ kategorii i
	// nigdy nie sa mapowane na najblizsza (R7).
	NoFit []string
	// PastSpanIDs to identyfikatory spanow mowiacych WPROST o przeszlosci.
	//
	// Pole przechodzi przez test refleksji SWIADOMIE. Nie niesie zadnej
	// tresci: to sam podzbior identyfikatorow, ktore i tak sa juz w
	// Claims. S4 nie zyskuje ani jednego znaku materialu zrodlowego,
	// zyskuje wylacznie informacje, KTORYCH ze swoich dowodow wolno mu
	// uzyc do zdania o genezie.
	//
	// Bez tego S4 byl sadzony regula V3, ktorej nie mial jak spelnic —
	// nie wiedzial, ktory span mowi o przeszlosci. Na kanarku PPT
	// (2026-08-23) napisal dwa zdania o genezie i raport wypadl w tryb
	// ekstraktywny.
	PastSpanIDs []string
	// Corrections to naruszenia V1-V6 z poprzedniej proby. Puste przy
	// pierwszym przebiegu.
	Corrections []Violation
	// Zamowienia sekcji generacyjnych (uklad M5). Flagi i wytyczne, nie
	// material zrodlowy: Guidance* to tresc EKSPERCKA z ontologii
	// (wersjonowana, po four-eyes), a nie nic z sesji. Pola przechodza
	// przez test refleksji SWIADOMIE.
	// Language to jezyk, w ktorym S4 ma PISAC (raport wychodzi w jezyku
	// kartoteki). Nie niesie materialu sesji — sam tag jezykowy.
	Language              string
	WantSuggestions       bool
	WantInterventions     bool
	SuggestionsGuidance   string
	InterventionsGuidance string
}

// Suggestion to jedna propozycja miedzy sesjami (uklad M5).
//
// Regula soczewki, ktora tu obowiazuje strukturalnie: "propozycje
// ROZWIJAJA to, co na sesji ustalono — nie wprowadzaj nowych kierunkow
// bez oparcia w materiale". BasisConstruct jest enumem zatwierdzonych
// konstruktow, wiec propozycja bez oparcia nie moze POWSTAC.
type Suggestion struct {
	Title          string `json:"title"`
	BasisConstruct string `json:"basis_construct"`
	Target         string `json:"target"`
	Instruction    string `json:"instruction"`
}

// Intervention to propozycja warunkowa na kolejne sesje — nigdy
// zalecenie. VerifyFirst wymusza jezyk soczewki: "zanim zastosujesz,
// zweryfikuj [co]".
type Intervention struct {
	Name           string `json:"name"`
	BasisConstruct string `json:"basis_construct"`
	VerifyFirst    string `json:"verify_first"`
	Scenario       string `json:"scenario"`
}

// Report to wynik S4 w formacie przestrzeni hipotez (dok. 11 sekcja 5).
//
// Format nie jest kosmetyka. Pojedyncza "ostateczna konceptualizacja"
// ukrywa blad modelu w plynnej prozie; przestrzen hipotez pokazuje go na
// tle danych przeciw, i dopiero to czyni obrone "klinicysta jako autor
// decyzji" realna zamiast deklaratywnej.
type Report struct {
	Constructs    []ConstructReport `json:"constructs"`
	Suggestions   []Suggestion      `json:"suggestions,omitempty"`
	Interventions []Intervention    `json:"interventions,omitempty"`
}

type ConstructReport struct {
	ConstructID string       `json:"construct_id"`
	Hypotheses  []Hypothesis `json:"hypotheses"`
	// UnknownYet to jawne "tu nie mamy jeszcze danych".
	UnknownYet           []string `json:"unknown_yet"`
	NextSessionQuestions []string `json:"next_session_questions"`
	// PatternNotices to meta-obserwacje z S1.5 ("trzeci raz wraca...").
	// Legalne jako dowod WYLACZNIE dlatego, ze zostaly policzone.
	PatternNotices []string `json:"pattern_notices"`
}

type Hypothesis struct {
	ID    string `json:"id"`
	Claim string `json:"claim"`
	// Supporting i Contradicting to identyfikatory spanow. Schemat
	// zawezá je enumem do spanow faktycznie zatwierdzonych, wiec S4 nie
	// moze wskazac spanu, ktorego nie ma.
	Supporting      []string `json:"supporting"`
	Contradicting   []string `json:"contradicting"`
	EpistemicStatus string   `json:"epistemic_status"`
	Confidence      float64  `json:"confidence"`
}

// Synthesize wykonuje S4.
//
// Sygnatura NIE PRZYJMUJE ani Input, ani transkrypcji — to jest cala
// poanta tego etapu.
func Synthesize(ctx context.Context, llm LLM, o *ontology.Ontology, in SynthesisInput, u *Usage) (Report, error) {
	if len(in.Claims) == 0 && len(in.Degraded) == 0 && len(in.Insufficient) == 0 && len(in.NoFit) == 0 {
		// Pusty material to pelnoprawny wynik, nie awaria. Raport bez
		// twierdzen jest uczciwszy niz raport wymyslony.
		return Report{}, nil
	}
	prompt := buildS4Prompt(o)
	var pb strings.Builder
	pb.WriteString(prompt)
	appendGenerativeGuidance(&pb, in)
	resp, err := llm.GenerateJSON(ctx, LLMRequest{
		Model:        ModelSynthesis,
		SystemPrompt: pb.String(),
		UserContent:  renderSynthesisInput(in),
		Schema:       schemaS4(in),
		MaxTokens:    8192,
	})
	if err != nil {
		return Report{}, fmt.Errorf("ontopipe: S4: %w", err)
	}
	u.add(resp)

	var rep Report
	if err := json.Unmarshal([]byte(resp.JSON), &rep); err != nil {
		return Report{}, fmt.Errorf("ontopipe: S4 dekodowanie: %w", err)
	}
	for i := range rep.Constructs {
		for j := range rep.Constructs[i].Hypotheses {
			rep.Constructs[i].Hypotheses[j].Confidence =
				clampConfidence(rep.Constructs[i].Hypotheses[j].Confidence)
		}
	}
	return rep, nil
}

// clampConfidence sprowadza pewnosc do [0,1].
//
// Zakres pilnuje KOD, a nie schemat: granice liczbowe w JSON Schema
// powiekszaja automat stanow Vertexa i przy wiekszym schemacie prowadza do
// odrzucenia calego zadania. Sprowadzenie wartosci do zakresu jest
// operacja bezstratna dla sensu — model, ktory zwrocil 1.7, i tak chcial
// powiedziec "bardzo pewne".
func clampConfidence(v float64) float64 {
	switch {
	case v < 0:
		return 0
	case v > 1:
		return 1
	default:
		return v
	}
}

// allowedSpanIDs zbiera spany, na ktore S4 wolno sie powolac: wylacznie
// te, ktore niosa zatwierdzone twierdzenia.
func allowedSpanIDs(in SynthesisInput) []string {
	set := map[string]bool{}
	for _, c := range in.Claims {
		for _, q := range c.Evidence {
			set[q.SpanID] = true
		}
		for _, q := range c.CounterEvidence {
			set[q.SpanID] = true
		}
	}
	out := make([]string, 0, len(set))
	for id := range set {
		out = append(out, id)
	}
	sort.Strings(out)
	return out
}

// allowedConstructIDs zbiera konstrukty, ktore maja prawo pojawic sie w
// raporcie: zatwierdzone, zdegradowane, bez danych albo poza taksonomia.
// Kazdy inny bylby wymyslony.
func allowedConstructIDs(in SynthesisInput) []string {
	set := map[string]bool{}
	for _, c := range in.Claims {
		set[c.ConstructID] = true
	}
	for _, d := range in.Degraded {
		set[d.ConstructID] = true
	}
	for _, id := range in.Insufficient {
		set[id] = true
	}
	for _, id := range in.NoFit {
		set[id] = true
	}
	out := make([]string, 0, len(set))
	for id := range set {
		out = append(out, id)
	}
	sort.Strings(out)
	return out
}

func renderSynthesisInput(in SynthesisInput) string {
	past := map[string]bool{}
	for _, id := range in.PastSpanIDs {
		past[id] = true
	}
	var b strings.Builder
	b.WriteString("ZATWIERDZONE TWIERDZENIA:\n")
	if len(in.PastSpanIDs) > 0 {
		fmt.Fprintf(&b, "(spany oznaczone PRZESZLOSC mowia wprost o przeszlosci — "+
			"tylko one moga uzasadnic zdanie o genezie)\n")
	}
	for i, c := range in.Claims {
		fmt.Fprintf(&b, "[c%d] konstrukt=%s kategorie=%s status=%s pewnosc=%.2f\n",
			i, c.ConstructID, strings.Join(c.Categories, ", "), c.Status, c.Confidence)
		fmt.Fprintf(&b, "     uzasadnienie: %s\n", c.Reasoning)
		for _, q := range c.Evidence {
			fmt.Fprintf(&b, "     ZA  [%s%s]: %q\n", q.SpanID, pastMark(q.SpanID, past), q.Quote)
		}
		for _, q := range c.CounterEvidence {
			fmt.Fprintf(&b, "     PRZECIW [%s]: %q\n", q.SpanID, q.Quote)
		}
	}
	if len(in.Patterns) > 0 {
		b.WriteString("\nWZORCE POLICZONE (dowody, nie interpretacje):\n")
		for _, p := range in.Patterns {
			fmt.Fprintf(&b, "[%s] %s | tematy: %s | %s | spany: %s | sesji: %d\n",
				p.ID, p.Type, strings.Join(p.Topics, "+"), p.Method,
				strings.Join(p.SpanIDs, ", "), p.Sessions)
		}
	}
	if len(in.Degraded) > 0 {
		b.WriteString("\nKONSTRUKTY ZDEGRADOWANE (uzyj PODANEGO zapisu, nie podnos rangi):\n")
		for _, d := range in.Degraded {
			fmt.Fprintf(&b, "- %s -> %q (%s)\n", d.ConstructID, d.To, d.Detail)
		}
	}
	if len(in.Insufficient) > 0 {
		fmt.Fprintf(&b, "\nBRAK WYSTARCZAJACYCH DANYCH (bez hipotez; wpisz pytanie na kolejna sesje): %s\n",
			strings.Join(in.Insufficient, ", "))
	}
	if len(in.NoFit) > 0 {
		fmt.Fprintf(&b, "\nPOZA TAKSONOMIA (opisz zjawisko, NIE nadawaj kategorii): %s\n",
			strings.Join(in.NoFit, ", "))
	}
	if len(in.Corrections) > 0 {
		b.WriteString("\nPOPRZEDNIA WERSJA ZOSTALA ODRZUCONA. Napraw dokladnie te naruszenia:\n")
		for _, v := range in.Corrections {
			fmt.Fprintf(&b, "- [%s] %s: %s\n", v.Rule, v.ConstructID, v.Detail)
		}
	}
	return b.String()
}

// pastMark oznacza span mowiacy o przeszlosci.
func pastMark(spanID string, past map[string]bool) string {
	if past[spanID] {
		return " PRZESZLOSC"
	}
	return ""
}
