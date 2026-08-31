package ontopipe

// S2k — relacje ciaglosci i rozliczenie pracy domowej (T42b, docs/67 §4).
//
// ══ Podzial rol ══
//
// PAROWANIE jest deterministyczne (kod): biezace twierdzenie laczy sie
// wylacznie z przeszlymi twierdzeniami TEGO SAMEGO konstruktu z
// PastContext (okno F7a + kanal semantyczny F7b). OSAD relacji
// (wzmacnia/oslabia/bez zwiazku) jest jedynym pytaniem do modelu — i
// jest zamkniety enumem w schemacie. Model nie wybiera par, nie tworzy
// ustalen, nie widzi transkrypcji.
//
// ══ Fail-open ══
//
// Ciaglosc jest wzmocnieniem raportu, nie bramka. Awaria S2k ustawia
// ContinuityFailed i raport wychodzi bez linkow — dokladnie jak brak
// historii. Odrzucenie pojedynczej relacji (nieznana para, dowod spoza
// sesji) zlicza DroppedLinks i nie dotyka reszty.

import (
	_ "embed"
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

//go:embed prompts/s2k_kontynuacje.txt
var promptS2K string

// maxPrzeszlychNaKonstrukt ogranicza pary per biezace twierdzenie:
// najnowsze przeszle twierdzenia wystarczaja, a kazda para to tokeny.
const maxPrzeszlychNaKonstrukt = 3

type paraKontynuacji struct {
	id       string
	claimIdx int
	past     PastClaim
}

// verdykty homework — enum schematu.
var werdyktyRozliczenia = []string{"omowiona_z_rezultatem", "wspomniana", "nie_wrocono"}

// zbierzPary buduje deterministycznie pary biezace<->przeszle.
func zbierzPary(res *Result, past *PastContext) []paraKontynuacji {
	perKonstrukt := map[string][]PastClaim{}
	for _, pc := range past.Claims {
		perKonstrukt[pc.ConstructID] = append(perKonstrukt[pc.ConstructID], pc)
	}
	var pary []paraKontynuacji
	for idx, cl := range res.Approved {
		przeszle := perKonstrukt[cl.ConstructID]
		if len(przeszle) > maxPrzeszlychNaKonstrukt {
			przeszle = przeszle[:maxPrzeszlychNaKonstrukt]
		}
		for _, pc := range przeszle {
			pary = append(pary, paraKontynuacji{
				id: fmt.Sprintf("p%02d", len(pary)+1), claimIdx: idx, past: pc,
			})
		}
	}
	return pary
}

// zbierzRozliczenia znajduje przeszle ustalenia "praca domowa klienta":
// twierdzenia konstruktu, ktorego fact_kind_map zawiera agreement_client,
// o kategorii z tej mapy.
func zbierzRozliczenia(o *ontology.Ontology, past *PastContext) []PastClaim {
	var out []PastClaim
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil {
			continue
		}
		kat, ok := c.FactKindMap["agreement_client"]
		if !ok {
			continue
		}
		for _, pc := range past.Claims {
			if pc.ConstructID != id {
				continue
			}
			pasuje := kat == "" && len(pc.Categories) == 0
			for _, k := range pc.Categories {
				if k == kat {
					pasuje = true
				}
			}
			if pasuje {
				out = append(out, pc)
			}
		}
	}
	return out
}

func schemaS2K(pary []paraKontynuacji, rozliczenia []PastClaim) map[string]any {
	idsPar := make([]any, 0, len(pary))
	for _, p := range pary {
		idsPar = append(idsPar, p.id)
	}
	props := map[string]any{}
	req := []any{}
	if len(pary) > 0 {
		props["links"] = map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"pair_id":  map[string]any{"type": "string", "enum": idsPar},
					"relation": map[string]any{"type": "string", "enum": []any{"wzmacnia", "oslabia", "bez_zwiazku"}},
				},
				"required": []any{"pair_id", "relation"},
			},
		}
		req = append(req, "links")
	}
	if len(rozliczenia) > 0 {
		idsHw := make([]any, 0, len(rozliczenia))
		for _, pc := range rozliczenia {
			idsHw = append(idsHw, pc.ID.String())
		}
		wer := make([]any, 0, len(werdyktyRozliczenia))
		for _, w := range werdyktyRozliczenia {
			wer = append(wer, w)
		}
		props["homework"] = map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"past_claim_id": map[string]any{"type": "string", "enum": idsHw},
					"verdict":       map[string]any{"type": "string", "enum": wer},
					"evidence_span_ids": map[string]any{
						"type": "array", "items": map[string]any{"type": "string"},
					},
				},
				"required": []any{"past_claim_id", "verdict"},
			},
		}
		req = append(req, "homework")
	}
	return map[string]any{"type": "object", "properties": props, "required": req}
}

func renderS2KInput(res *Result, past *PastContext, pary []paraKontynuacji,
	rozliczenia []PastClaim, spans []ontology.TopicSpan) string {

	var b strings.Builder
	cytatPrzeszlego := func(pc PastClaim) string {
		for _, addr := range pc.Evidence {
			if sp, ok := past.SpanByAddr(addr); ok {
				return sp.Quote
			}
		}
		return ""
	}
	if len(pary) > 0 {
		b.WriteString("PARY DO ROZSTRZYGNIECIA\n")
		for _, p := range pary {
			cl := res.Approved[p.claimIdx]
			fmt.Fprintf(&b, "\n[%s] konstrukt: %s\n", p.id, cl.ConstructID)
			fmt.Fprintf(&b, "  DZIS: kategorie=%v status=%s\n", cl.Categories, cl.Status)
			for i, q := range cl.Evidence {
				if i == 2 {
					break
				}
				fmt.Fprintf(&b, "    cytat: %q\n", q.Quote)
			}
			fmt.Fprintf(&b, "  WCZESNIEJ (%s): kategorie=%v status=%s\n",
				p.past.SessionDate.Format("02.01"), p.past.Categories, p.past.Status)
			if q := cytatPrzeszlego(p.past); q != "" {
				fmt.Fprintf(&b, "    cytat: %q\n", q)
			}
		}
	}
	if len(rozliczenia) > 0 {
		b.WriteString("\nPRZESZLE USTALENIA PRACY DOMOWEJ\n")
		for _, pc := range rozliczenia {
			fmt.Fprintf(&b, "- id=%s (%s): %q\n", pc.ID, pc.SessionDate.Format("02.01"),
				cytatPrzeszlego(pc))
		}
		b.WriteString("\nSPANY DZISIEJSZEJ SESJI (dowody werdyktow)\n")
		for _, sp := range spans {
			if sp.RiskContent {
				continue
			}
			fmt.Fprintf(&b, "- %s: %q\n", sp.ID, sp.QuoteVerbatim)
		}
	}
	return b.String()
}

type s2kOut struct {
	Links []struct {
		PairID   string `json:"pair_id"`
		Relation string `json:"relation"`
	} `json:"links"`
	Homework []struct {
		PastClaimID     string   `json:"past_claim_id"`
		Verdict         string   `json:"verdict"`
		EvidenceSpanIDs []string `json:"evidence_span_ids"`
	} `json:"homework"`
}

// RunContinuity wykonuje S2k. Fail-open — patrz naglowek pliku.
func RunContinuity(ctx context.Context, llm LLM, o *ontology.Ontology,
	res *Result, past *PastContext, spans []ontology.TopicSpan, u *Usage) {

	if past == nil || len(past.Claims) == 0 {
		return
	}
	pary := zbierzPary(res, past)
	rozliczenia := zbierzRozliczenia(o, past)
	if len(pary) == 0 && len(rozliczenia) == 0 {
		return
	}

	resp, err := llm.GenerateJSON(ctx, LLMRequest{
		Stage:        StageContinuity,
		Model:        ModelMapping,
		SystemPrompt: promptS2K,
		UserContent:  renderS2KInput(res, past, pary, rozliczenia, spans),
		Schema:       schemaS2K(pary, rozliczenia),
		MaxTokens:    4096,
	})
	if err != nil {
		res.ContinuityFailed = true
		return
	}
	u.add(resp)

	var out s2kOut
	if err := json.Unmarshal([]byte(resp.JSON), &out); err != nil {
		res.ContinuityFailed = true
		return
	}

	paraPoID := map[string]paraKontynuacji{}
	for _, p := range pary {
		paraPoID[p.id] = p
	}
	for _, l := range out.Links {
		p, ok := paraPoID[l.PairID]
		if !ok {
			// Nieznana para = relacja bez tozsamosci. Odrzucamy RELACJE,
			// nie raport; schemat enumem czyni to malo prawdopodobnym,
			// wiec kazdy przypadek jest wart zliczenia.
			res.DroppedLinks++
			continue
		}
		if l.Relation != "wzmacnia" && l.Relation != "oslabia" {
			continue // bez_zwiazku nie tworzy linku
		}
		res.ContinuityLinks = append(res.ContinuityLinks, ContinuityLink{
			ClaimIdx:        p.claimIdx,
			ConstructID:     res.Approved[p.claimIdx].ConstructID,
			PastClaimID:     p.past.ID,
			PastSessionDate: p.past.SessionDate,
			Relation:        l.Relation,
		})
	}

	znaneSpany := map[string]bool{}
	for _, sp := range spans {
		znaneSpany[sp.ID] = true
	}
	werdyktPoID := map[string]HomeworkVerdict{}
	for _, h := range out.Homework {
		w := HomeworkVerdict{Verdict: h.Verdict}
		for _, sid := range h.EvidenceSpanIDs {
			if znaneSpany[sid] {
				w.EvidenceSpanIDs = append(w.EvidenceSpanIDs, sid)
			}
		}
		// Werdykt "wrocono" bez ani jednego istniejacego dowodu degraduje
		// do nie_wrocono — twierdzenie o rozliczeniu bez sladu w sesji
		// byloby dokladnie ta konfabulacja, ktorej potok zakazuje.
		if w.Verdict != "nie_wrocono" && len(w.EvidenceSpanIDs) == 0 {
			w.Verdict = "nie_wrocono"
			res.DroppedLinks++
		}
		werdyktPoID[h.PastClaimID] = w
	}
	for _, pc := range rozliczenia {
		w, ok := werdyktPoID[pc.ID.String()]
		if !ok {
			w = HomeworkVerdict{Verdict: "nie_wrocono"}
		}
		w.PastClaimID = pc.ID
		w.PastSessionDate = pc.SessionDate
		for _, addr := range pc.Evidence {
			if sp, ok := past.SpanByAddr(addr); ok {
				w.Quote = sp.Quote
				break
			}
		}
		res.HomeworkVerdicts = append(res.HomeworkVerdicts, w)
	}
}
