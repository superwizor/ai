package ontopipe

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// ── S1: ekstrakcja jednostek dowodowych ──

type s1Span struct {
	SpanID          string   `json:"span_id"`
	Quote           string   `json:"quote_verbatim"`
	Speaker         string   `json:"speaker"`
	Kind            string   `json:"kind"`
	Topics          []string `json:"topics"`
	ObservedBy      string   `json:"observed_by"`
	AboutPast       bool     `json:"about_past"`
	RiskContent     bool     `json:"risk_content"`
	SilenceBeforeMs int      `json:"silence_before_ms"`
}

type s1Output struct {
	Spans []s1Span `json:"spans"`
}

// ExtractSpans wykonuje S1 i ODSIEWA spany, ktorych cytaty nie sa w
// transkrypcji.
//
// Weryfikacja mechaniczna jest czescia tego etapu, nie osobnym krokiem —
// span, ktory jej nie przeszedl, nie moze opuscic S1. Inaczej reszta
// potoku sprawdzalaby jedynie, czy model WSKAZAL span, a nie czy
// powiedzial prawde o jego tresci.
func ExtractSpans(ctx context.Context, llm LLM, in Input, u *Usage) ([]ontology.TopicSpan, []string, error) {
	resp, err := llm.GenerateJSON(ctx, LLMRequest{
		Model:        ModelExtraction,
		SystemPrompt: promptS1,
		UserContent:  "TRANSKRYPCJA SESJI:\n" + in.Transcript,
		Schema:       schemaS1(),
		// S1 na dlugiej sesji produkuje SETKI spanow, a kazdy niesie cytat
		// doslowny. 8192 wystarczalo w testach na krotkim materiale i
		// urwalo sie na pierwszej prawdziwej sesji (382 chunki). Limit jest
		// tu granica bezpieczenstwa, nie narzedziem kontroli kosztu —
		// kosztem steruje dobor modelu (Flash) i to, ze S1 jest jednym
		// wywolaniem na sesje.
		MaxTokens: 32768,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("ontopipe: S1: %w", err)
	}
	u.add(resp)

	var out s1Output
	if err := json.Unmarshal([]byte(resp.JSON), &out); err != nil {
		return nil, nil, fmt.Errorf("ontopipe: S1 dekodowanie: %w", err)
	}

	spans := make([]ontology.Span, 0, len(out.Spans))
	topics := map[string][]string{}
	silence := map[string]int{}
	for _, s := range out.Spans {
		kind := ontology.SpanDeclarative
		if s.Kind == string(ontology.SpanBehavioral) {
			kind = ontology.SpanBehavioral
		}
		obs := ontology.ObservedBySelf
		if s.ObservedBy == string(ontology.ObservedByTherapist) {
			obs = ontology.ObservedByTherapist
		}
		spans = append(spans, ontology.Span{
			ID:            s.SpanID,
			SessionID:     in.SessionID,
			Speaker:       s.Speaker,
			QuoteVerbatim: s.Quote,
			Kind:          kind,
			ObservedBy:    obs,
			AboutPast:     s.AboutPast,
			RiskContent:   s.RiskContent,
		})
		topics[s.SpanID] = s.Topics
		silence[s.SpanID] = s.SilenceBeforeMs
	}

	accepted, rejected := ontology.VerifySpans(in.Transcript, spans, ontology.DefaultQuoteThreshold)

	out2 := make([]ontology.TopicSpan, 0, len(accepted))
	for _, s := range accepted {
		out2 = append(out2, ontology.TopicSpan{
			Span:            s,
			Topics:          topics[s.ID],
			SilenceBeforeMs: silence[s.ID],
		})
	}
	return out2, rejected, nil
}

// ── S2: mapowanie per konstrukt ──

type s2Claim struct {
	Category        json.RawMessage `json:"category"`
	Evidence        []s2Quote       `json:"evidence"`
	CounterEvidence []s2Quote       `json:"counter_evidence"`
	EpistemicStatus string          `json:"epistemic_status"`
	Confidence      float64         `json:"confidence"`
	Reasoning       string          `json:"reasoning"`
}

type s2Quote struct {
	SpanID string `json:"span_id"`
	Quote  string `json:"quote"`
}

type s2Output struct {
	ConstructID      string    `json:"construct_id"`
	Claims           []s2Claim `json:"claims"`
	InsufficientData bool      `json:"insufficient_data"`
	NoFit            bool      `json:"no_fit"`
	Missing          string    `json:"missing"`
}

// MapConstruct wykonuje S2 dla JEDNEGO konstruktu.
//
// Osobne wywolanie na typ konstruktu, nigdy "cala konceptualizacja
// naraz" — schemat mieszajacy poziomy pojeciowe produkuje objaw 2
// (potrzeba = zasob = potencjalnosc w jednym worku).
//
// SPANY RYZYKA SA ODSIEWANE PRZED WYSLANIEM (T22): model nie dostaje ich
// nawet do przeczytania, wiec nie moze na nich wnioskowac. Filtrowanie
// dopiero w walidatorze byloby slabsze — tresc juz bylaby w kontekscie.
func MapConstruct(ctx context.Context, llm LLM, o *ontology.Ontology, constructID string,
	spans []ontology.TopicSpan, past *PastContext, u *Usage) (ontology.StageResult, error) {

	schema, err := o.SchemaForConstruct(constructID, ontology.SchemaOptions{})
	if err != nil {
		return ontology.StageResult{}, err
	}

	usable := make([]ontology.TopicSpan, 0, len(spans))
	for _, s := range spans {
		if s.RiskContent {
			continue
		}
		usable = append(usable, s)
	}

	resp, err := llm.GenerateJSON(ctx, LLMRequest{
		Model:        ModelMapping,
		SystemPrompt: buildS2Prompt(o, constructID, past),
		UserContent:  renderSpans(usable, past.SpansForConstruct(constructID)),
		Schema:       schema,
		MaxTokens:    4096,
	})
	if err != nil {
		return ontology.StageResult{}, fmt.Errorf("ontopipe: S2 %s: %w", constructID, err)
	}
	u.add(resp)

	var raw s2Output
	if err := json.Unmarshal([]byte(resp.JSON), &raw); err != nil {
		return ontology.StageResult{}, fmt.Errorf("ontopipe: S2 %s dekodowanie: %w", constructID, err)
	}

	res := ontology.StageResult{
		ConstructID:      constructID,
		InsufficientData: raw.InsufficientData,
		NoFit:            raw.NoFit,
		Missing:          raw.Missing,
	}
	for _, c := range raw.Claims {
		res.Claims = append(res.Claims, ontology.Claim{
			ConstructID:     constructID,
			Categories:      decodeCategories(c.Category),
			Evidence:        toQuoteRefs(c.Evidence),
			CounterEvidence: toQuoteRefs(c.CounterEvidence),
			Status:          ontology.EpistemicStatus(c.EpistemicStatus),
			Confidence:      clampConfidence(c.Confidence),
			Reasoning:       c.Reasoning,
		})
	}
	return res, nil
}

// decodeCategories obsluguje oba ksztalty: string (single-label) i
// tablice (multi_label, M2). Schemat wymusza wlasciwy, ale dekoder musi
// znac oba, bo jeden konstrukt zmienia ksztalt w zaleznosci od ontologii.
func decodeCategories(raw json.RawMessage) []string {
	if len(raw) == 0 {
		return nil
	}
	var one string
	if err := json.Unmarshal(raw, &one); err == nil {
		if one == "" {
			return nil
		}
		return []string{one}
	}
	var many []string
	if err := json.Unmarshal(raw, &many); err == nil {
		return dedupCategories(many)
	}
	return nil
}

// dedupCategories usuwa powtorki z listy multi_label.
//
// Schemat nie ma juz gornej granicy dlugosci (rozsadzala automat stanow
// Vertexa przy dwunastu zniekształceniach CBT), wiec powtorki odsiewa
// kod. Kolejnosc pierwszego wystapienia zostaje: jest deterministyczna i
// odpowiada temu, co model uznal za najwazniejsze.
func dedupCategories(in []string) []string {
	seen := make(map[string]bool, len(in))
	out := make([]string, 0, len(in))
	for _, v := range in {
		if v == "" || seen[v] {
			continue
		}
		seen[v] = true
		out = append(out, v)
	}
	return out
}

func toQuoteRefs(qs []s2Quote) []ontology.QuoteRef {
	out := make([]ontology.QuoteRef, 0, len(qs))
	for _, q := range qs {
		out = append(out, ontology.QuoteRef{SpanID: q.SpanID, Quote: q.Quote})
	}
	return out
}

// renderSpans sklada material dla S2. Spany numerowane identyfikatorem,
// zeby model mial czym sie odwolac w evidence.
func renderSpans(spans []ontology.TopicSpan, historyczne []PastSpan) string {
	var b strings.Builder
	b.WriteString("FRAGMENTY SESJI:\n")
	for _, s := range spans {
		fmt.Fprintf(&b, "[%s | %s | %s] %s\n", s.ID, s.Speaker, s.Kind, s.QuoteVerbatim)
	}
	if len(historyczne) == 0 {
		return b.String()
	}
	// Blok historyczny jest ODDZIELONY i inaczej zaadresowany
	// (`s0821:s07` zamiast `s07`), zeby model nie mogl pomylic materialu
	// dzisiejszego z wczesniejszym ani przy cytowaniu, ani przy
	// liczeniu pokrycia.
	b.WriteString("\nFRAGMENTY WCZESNIEJSZYCH SESJI (kontekst ciaglosci):\n")
	for _, s := range historyczne {
		fmt.Fprintf(&b, "[%s | %s | %s | %s] %s\n",
			s.Addr, s.SessionDate.Format("02.01"), s.Speaker, s.Kind, s.Quote)
	}
	return b.String()
}
