package chat

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// execute runs the retrieval and generation for one routed intent.
//
// Each branch decides what material the intent may see. That decision is
// made HERE, in code, not by a prompt asking the model to restrain
// itself: A4_EDU retrieves nothing, and there is no path through this
// function that hands it client material.
func (s Service) execute(ctx context.Context, t Turn, d guardrail.Decision, history []HistoryTurn) (*Answer, []ModelCost, guardrail.Verdict, int, error) {
	switch d.Intent {
	case guardrail.A2Stats, guardrail.A6Admin:
		// No model call at all. This is why an exhausted quota still
		// serves these, and why a verifier has nothing to check.
		a, err := s.executeStats(ctx, t)
		return a, nil, guardrail.Verdict{}, 0, err

	case guardrail.A4Edu:
		return s.executeEducation(ctx, t)

	default:
		return s.executeGrounded(ctx, t, d, history)
	}
}

// executeStats answers A2/A6 from SQL.
func (s Service) executeStats(ctx context.Context, t Turn) (*Answer, error) {
	st, err := s.Retriever.Stats(ctx, t.PatientFileID)
	if err != nil {
		return nil, err
	}
	var b strings.Builder
	fmt.Fprintf(&b, "Liczba sesji: %d\n", st.SessionCount)
	if !st.FirstSessionAt.IsZero() {
		fmt.Fprintf(&b, "Pierwsza sesja: %s\n", st.FirstSessionAt.Format("2006-01-02"))
		fmt.Fprintf(&b, "Ostatnia sesja: %s\n", st.LastSessionAt.Format("2006-01-02"))
	}
	if st.LongestGapDays > 0 {
		fmt.Fprintf(&b, "Najdłuższa przerwa: %d dni\n", st.LongestGapDays)
	}
	if st.CancelledCount > 0 {
		fmt.Fprintf(&b, "Odwołane: %d\n", st.CancelledCount)
	}
	fmt.Fprintf(&b, "Raporty: %d\n", st.ReportsAvailable)

	return &Answer{Sections: []Section{{
		Title: "Statystyki", Body: b.String(), Kind: "stats",
	}}}, nil
}

// eduSystemPrompt is A4's instruction. It states the constraint that the
// code already enforces — that no client material is present — so the
// model does not invent a client to be helpful about.
const eduSystemPrompt = `Jesteś partnerem w gabinecie dla psychoterapeuty.
Odpowiadasz na pytanie OGÓLNOZAWODOWE.

NIE MASZ DOSTĘPU do żadnych danych klienta i nie wolno Ci ich zakładać.
Jeśli pytanie wymaga odniesienia do konkretnego klienta, odpowiedz, że w
tym trybie odpowiadasz wyłącznie ogólnie.

Odpowiadaj po polsku, rzeczowo, bez oceny ryzyka.`

// executeEducation answers A4 with NO client context.
//
// The absence is the feature. There is no retrieval call in this
// function, no patient file ID reaches the model, and
// TestEducationNeverReceivesClientContext asserts it stays that way.
func (s Service) executeEducation(ctx context.Context, t Turn) (*Answer, []ModelCost, guardrail.Verdict, int, error) {
	schema, _ := guardrail.SchemaFor(guardrail.A4Edu)

	// A4 dostaje soczewke WYLACZNIE, gdy pytanie samo wymienia modalnosc
	// ("jak konceptualizacja wyglada w podejsciu CBT?"). Modalnosc
	// prowadzonej terapii jest informacja o kliencie, a definicyjna
	// wlasnoscia A4 jest brak kontekstu klienta — wiec kartoteki tu nie
	// odpytujemy w ogole (pilnuje tego test).
	eduPrompt := eduSystemPrompt
	if lens, ok := s.resolveLens(ctx, t, guardrail.A4Edu); ok {
		eduPrompt = eduPrompt + "\n\n" + lens.Render()
	}

	resp, err := s.LLM.Generate(ctx, GenerateRequest{
		Model:          GeneratorModel,
		SystemPrompt:   eduPrompt,
		UserContent:    "PYTANIE:\n" + t.Question,
		ResponseSchema: schema,
		Temperature:    0.2,
		MaxTokens:      2048,
	})
	costs := []ModelCost{{Model: GeneratorModel,
		InputTokens: resp.Usage.InputTokens, OutputTokens: resp.Usage.OutputTokens}}
	if err != nil {
		return nil, costs, guardrail.Verdict{}, 0, err
	}

	if resp.Truncated {
		slog.WarnContext(ctx, "chat.generation_truncated_retry",
			"intent", "A4_EDU", "max_tokens", 2048)
		retry, rerr := s.LLM.Generate(ctx, GenerateRequest{
			Model: GeneratorModel, SystemPrompt: eduPrompt,
			UserContent: "PYTANIE:\n" + t.Question, ResponseSchema: schema,
			Temperature: 0.2, MaxTokens: retryGenerationTokens,
		})
		costs = append(costs, ModelCost{Model: GeneratorModel,
			InputTokens: retry.Usage.InputTokens, OutputTokens: retry.Usage.OutputTokens})
		if rerr == nil {
			resp = retry
		}
	}

	m, err := decodeModelAnswer(resp.Text)
	if err != nil {
		// A4 nie ma materialu zrodlowego, na ktory moglby spasc — tu
		// odmowa pozostaje jedyna uczciwa odpowiedzia.
		return nil, costs, guardrail.Verdict{Blocked: true, Reason: guardrail.BlockSchema}, 0, nil
	}
	var answer Answer
	var units []guardrail.Unit
	for _, sec := range m.Sections {
		answer.Sections = append(answer.Sections, Section{Title: sec.Title, Body: sec.Body, Kind: "summary"})
		units = append(units, guardrail.Unit{Kind: "section", Text: sec.Title + "\n" + sec.Body})
	}

	v := guardrail.Verifier{Caller: modelCaller{s.LLM}, Model: GeneratorModel}
	verdict := v.VerifyContent(ctx, guardrail.A4Edu, units)
	if verdict.Cost.Model != "" {
		costs = append(costs, ModelCost{Model: verdict.Cost.Model,
			InputTokens: verdict.Cost.InputTokens, OutputTokens: verdict.Cost.OutputTokens})
	}
	return &answer, costs, verdict, 0, nil
}

// quoteRules to bezwzgledne zasady cytowania, wspolne dla wszystkich
// intencji uziemionych.
const quoteRules = `

ZASADY CYTOWANIA (bezwzgledne):
- Cytat kopiuj 1:1 z fragmentow, W ORYGINALNYM JEZYKU wypowiedzi.
  NIE tlumacz, nawet gdy odpowiadasz po polsku, a fragment jest po
  angielsku.
- Zachowaj powtorzenia, zajakniecia i bledy transkrypcji — to zapis
  mowy, nie tekst do redakcji.
- Mozesz skrocic srodek cytatu znacznikiem [...] — czesci przed i po
  musza pozostac doslowne.
- segment_id i session_id przepisuj dokladnie z naglowka fragmentu.`

// maxGenerationTokens caps the generated answer.
//
// 2048, not 4096. Measured 2026-08-20 on a real A5 turn: the model
// produced 903 output tokens at 2048 and 912 at 4096 — the same answer —
// but took 7.4 s instead of 12.8 s. The cap changes how the model plans
// its output, so the larger value bought five and a half seconds of
// latency for nine tokens of content.
//
// Not lower: at 1024 the same call returned 139 tokens, which is a
// truncated answer, and a truncated hypothesis is worse than a slow one.
const maxGenerationTokens int32 = 2048

// groundedSystemPrompts are the per-intent instructions for everything
// that works from client material.
var groundedSystemPrompts = map[guardrail.Intent]string{
	guardrail.A1Search: `Jesteś partnerem w gabinecie dla psychoterapeuty.
Znajdź w podanych fragmentach transkrypcji miejsca, w których pojawił się
temat z pytania, i przytocz je.

ZASADY:
- Każda sekcja MUSI zawierać co najmniej jeden cytat.
- Cytat kopiuj DOSŁOWNIE, znak w znak, z fragmentu. Nie parafrazuj.
- segment_id i session_id przepisz dokładnie z nagłówka fragmentu.
- NIE interpretuj, NIE wyciągaj wniosków o kliencie. Pokazujesz, gdzie coś padło.`,

	guardrail.A3Format: `Ujmij podany materiał w formę dokumentu, o którą prosi terapeuta.
Nie dodawaj treści, której nie ma w materiale. Cytaty kopiuj dosłownie.`,

	guardrail.A5Prep: `Przygotuj terapeutę do nadchodzącej sesji na podstawie fragmentów.

ZASADY:
- Sekcje: do czego warto wrócić, co zostało otwarte.
- Możesz zaproponować pytania (suggested_questions) — KAŻDE musi mieć co
  najmniej jeden dosłowny cytat uzasadniający.
- Propozycja pytania NIE MOŻE zawierać etykiety diagnostycznej, wzmianki o
  lekach ani oceny ryzyka.
- Nie formułuj wniosków za terapeutę.`,

	guardrail.A7Template: `Odwzoruj materiał na model/szablon, o który prosi terapeuta.
Każda kategoria musi być poparta co najmniej jednym dosłownym cytatem.
Nie wypełniaj kategorii, dla której nie ma materiału — pomiń ją.`,

	guardrail.A8Concept: `Jesteś partnerem w gabinecie dla psychoterapeuty.
Zaproponuj konceptualizację przypadku jako HIPOTEZY do rozważenia.

ZASADY:
- Każda hipoteza MUSI mieć co najmniej jeden dosłowny cytat z fragmentów.
- Formułuj warunkowo: "może", "jedną z możliwości jest", "wygląda, jakby".
- NIE nazywaj jednostek chorobowych i NIE stwierdzaj, że klient je ma.
- NIE wspominaj o lekach. NIE oceniaj ryzyka.
- To materiał do weryfikacji przez terapeutę, nie rozstrzygnięcie.
- Zwięźle: każda hipoteza to tytuł i 3-6 zdań, nie esej.`,

	guardrail.A9Progress: `Oceń zmianę w czasie na podstawie fragmentów i danych.

ZASADY:
- Każda obserwacja MUSI mieć co najmniej jeden dosłowny cytat.
- Wszystko, co dotyczy przyszłości, formułuj WARUNKOWO.
- Pole caveats jest obowiązkowe: wypisz ograniczenia tego wnioskowania.
- NIE diagnozuj, NIE wspominaj o lekach, NIE oceniaj ryzyka.
- Zwięźle: każda obserwacja to 3-6 zdań.`,

	guardrail.A10Intervention: `Zaproponuj kierunki pracy do rozważenia przez terapeutę.

ZASADY:
- Każda propozycja MUSI mieć co najmniej jeden dosłowny cytat uzasadniający.
- Formułuj jako propozycje, nie zalecenia.
- NIE proponuj farmakoterapii. NIE oceniaj ryzyka. NIE diagnozuj.
- Decyzja należy do terapeuty.
- Zwięźle: każda propozycja to 3-6 zdań.`,
}

// executeGrounded handles every intent that works from client material.
func (s Service) executeGrounded(ctx context.Context, t Turn, d guardrail.Decision, history []HistoryTurn) (*Answer, []ModelCost, guardrail.Verdict, int, error) {
	schema, ok := guardrail.SchemaFor(d.Intent)
	if !ok {
		return nil, nil, guardrail.Verdict{}, 0, fmt.Errorf("chat: no schema for intent %s", d.Intent)
	}
	sysPrompt, ok := groundedSystemPrompts[d.Intent]
	if !ok {
		return nil, nil, guardrail.Verdict{}, 0, fmt.Errorf("chat: no prompt for intent %s", d.Intent)
	}

	// Reguly cytowania doklejane KODEM, nie w literalach promptow: musza
	// obowiazywac kazda intencje uziemiona bez wyjatku, a incydent 19:28
	// (A10, blok 'fabricated') pokazal skutek luki — transkrypcja byla
	// angielska, pytanie polskie, i model przetlumaczyl/wygladzil cytat.
	// Deterministyczny weryfikator slusznie to odrzucil; tu usuwamy
	// POKUSE, nie kontrole.
	sysPrompt += quoteRules

	// Soczewka modalnosci: wymieniona w pytaniu wygrywa z prowadzona w
	// kartotece (terapeuta PPT moze prosic o ujecie CBT). Prompt intencji
	// stoi PIERWSZY i definiuje zadanie oraz zasady; soczewka tylko
	// jezyk i porzadek analizy.
	if lens, ok := s.resolveLens(ctx, t, d.Intent); ok {
		sysPrompt = sysPrompt + "\n\n" + lens.Render()
	}

	// Candidate sessions. RAG preselection applies to the intents whose
	// questions are thematic; for the rest, recency is the better prior
	// and costs no embedding call.
	var filter map[uuid.UUID]bool
	var ragHits int
	var costs []ModelCost
	if usesRAGPreselection(d.Intent) {
		f, hits, embedCost := s.preselect(ctx, t, searchQueryOrQuestion(t, history))
		filter, ragHits = f, hits
		if embedCost.Model != "" {
			costs = append(costs, embedCost)
		}
	}

	segments, err := s.Retriever.LoadSegments(ctx, t.PatientFileID, filter)
	if err != nil {
		return nil, costs, guardrail.Verdict{}, ragHits, err
	}

	// A question made entirely of function and meta words has nothing to
	// search for. Say so instead of matching noise: a query of pure
	// stopwords lands on whatever segment is shortest, and the answer
	// reads as a confident finding about an arbitrary fragment. That is
	// what produced "Wzmianki o 'ten Janko'" on 2026-08-20 — a real,
	// verifier-approved quote answering a question that asked nothing.
	//
	// This is most likely right after a refusal, where the offered
	// alternative prefills "…na ten temat" but no topic travels with it:
	// the chat holds no conversation memory, so "this topic" refers to
	// nothing the server can see.
	// Pytanie bez wlasnych terminow — na przyklad "Pokaz cytaty na ten
	// temat" po odmowie. Temat dziedziczony z ostatniego pytania, ktore
	// go mialo; brak tej ciaglosci wyprodukowal 20.08.2026 sekcje
	// "Wzmianki o 'ten Janko'".
	searchQuery := t.Question
	if len(SearchableTerms(searchQuery)) == 0 {
		if inherited, ok := InheritedTopic(history); ok {
			searchQuery = inherited
		} else {
			return topiclessAnswer(costs, ragHits)
		}
	}

	// Narrow to the segments that actually relate to the question, so
	// the model's context is evidence rather than a transcript dump.
	relevant := SearchQuotes(segments, searchQuery, 40)
	if len(relevant) == 0 {
		relevant = segments
	}

	context := s.Retriever.FormatContext(relevant)
	if strings.TrimSpace(context) == "" {
		return &Answer{Sections: []Section{{
			Title: "Brak materiału",
			Body:  "Nie znalazłem w transkrypcjach fragmentów, na których mógłbym oprzeć odpowiedź.",
			Kind:  "summary",
		}}}, costs, guardrail.Verdict{}, ragHits, nil
	}

	user := "PYTANIE TERAPEUTY:\n" + t.Question + "\n\nFRAGMENTY TRANSKRYPCJI:\n" + context
	if needsDigests(d.Intent) {
		if digests, err := s.Retriever.ReportDigests(ctx, t.PatientFileID, 0); err == nil && len(digests) > 0 {
			var b strings.Builder
			for _, dg := range digests {
				fmt.Fprintf(&b, "- %s: %s — %s\n", dg.SessionAt.Format("2006-01-02"), dg.Title, dg.SummaryShort)
			}
			user += "\n\nSKRÓTY RAPORTÓW (kontekst, NIE cytuj ich jako transkrypcji):\n" + b.String()
		}
	}

	resp, err := s.LLM.Generate(ctx, GenerateRequest{
		Model: GeneratorModel, SystemPrompt: sysPrompt, UserContent: user,
		ResponseSchema: schema, Temperature: 0.3, MaxTokens: maxGenerationTokens,
	})
	costs = append(costs, ModelCost{Model: GeneratorModel,
		InputTokens: resp.Usage.InputTokens, OutputTokens: resp.Usage.OutputTokens})
	if err != nil {
		return nil, costs, guardrail.Verdict{}, ragHits, err
	}

	// Obciecie przy MaxTokens = niedomkniety JSON. Jedno ponowienie z
	// wiekszym budzetem: rzadka, duza odpowiedz ma byc wolniejsza, a nie
	// zablokowana. 20.08 dwie tury na produkcji poszly kodem 'schema'
	// wlasnie dlatego, ze tego ponowienia nie bylo.
	if resp.Truncated {
		slog.WarnContext(ctx, "chat.generation_truncated_retry",
			"intent", string(d.Intent), "max_tokens", maxGenerationTokens)
		retry, rerr := s.LLM.Generate(ctx, GenerateRequest{
			Model: GeneratorModel, SystemPrompt: sysPrompt, UserContent: user,
			ResponseSchema: schema, Temperature: 0.3, MaxTokens: retryGenerationTokens,
		})
		costs = append(costs, ModelCost{Model: GeneratorModel,
			InputTokens: retry.Usage.InputTokens, OutputTokens: retry.Usage.OutputTokens})
		if rerr == nil {
			if retry.Truncated {
				// Odpowiedz nie miesci sie nawet w podwojonym budzecie —
				// to sygnal o ROZMIARZE tresci, nie o infrastrukturze.
				// 20.08 19:01: nieograniczone body razy 5 hipotez.
				slog.WarnContext(ctx, "chat.generation_truncated_twice",
					"intent", string(d.Intent), "retry_max_tokens", retryGenerationTokens)
			}
			resp = retry
		}
	}

	m, err := decodeModelAnswer(resp.Text)
	if err != nil {
		// Niedekodowalna odpowiedz nie moze trafic do terapeuty — ale
		// odmowa "nic" tez nie musi. ADR: verifier_block -> zastapienie
		// wersja ekstraktywna albo odmowa. Zrodlowe fragmenty JUZ mamy.
		slog.WarnContext(ctx, "chat.verifier_block",
			"intent", string(d.Intent), "reason", guardrail.BlockSchema,
			"detail", "model output did not decode")
		return extractiveFallback(relevant),
			costs, guardrail.Verdict{Blocked: true, Reason: guardrail.BlockSchema}, ragHits, nil
	}

	segMap := SegmentMap(relevant)
	answer, units := assemble(d.Intent, m, relevant)

	// Walidacja serwerowa PO odpowiedzi modelu (ADR 4.3): odpowiedz
	// uziemiona bez ani jednej jednostki jest niepoprawna, chocby JSON
	// byl skladny — "{}" dekoduje sie bez bledu i bez tej bramki
	// wyszedlby pusty dymek udajacy odpowiedz.
	if len(units) == 0 {
		slog.WarnContext(ctx, "chat.verifier_block",
			"intent", string(d.Intent), "reason", guardrail.BlockSchema,
			"detail", "decoded answer carries no units")
		return extractiveFallback(relevant), costs,
			guardrail.Verdict{Blocked: true, Reason: guardrail.BlockSchema}, ragHits, nil
	}

	v := guardrail.Verifier{Caller: modelCaller{s.LLM}, Model: GeneratorModel}
	verdict := v.Verify(ctx, d.Intent, units, segMap)
	if verdict.Cost.Model != "" {
		costs = append(costs, ModelCost{Model: verdict.Cost.Model,
			InputTokens: verdict.Cost.InputTokens, OutputTokens: verdict.Cost.OutputTokens})
	}
	if verdict.Blocked {
		// Detail jest strukturalny (indeksy, identyfikatory segmentow,
		// kod) — zero tresci klinicznej, a bez tego logu diagnoza bloku
		// na produkcji wymagala dedukcji z samej latencji.
		slog.WarnContext(ctx, "chat.verifier_block",
			"intent", string(d.Intent), "reason", verdict.Reason, "detail", verdict.Detail)

		// Samonaprawa: blad DOSLOWNOSCI cytatu (tlumaczenie, wygladzenie
		// zajakniec) to jedyna klasa bledu, ktora model umie naprawic
		// mechanicznie — dostaje wlasna odpowiedz i polecenie skopiowania
		// cytatow 1:1, reszta tresci bez zmian. Jedna proba; po niej
		// werdykt liczy sie od nowa, wiec gwarancja deterministyczna nie
		// slabnie ani o wlos. Bledy tresciowe (diagnoza itd.) NIE sa
		// naprawiane — tam blokada jest wlasnie celem.
		if verdict.Reason == guardrail.BlockFabricated || verdict.Reason == guardrail.BlockUngrounded {
			slog.InfoContext(ctx, "chat.quote_repair_attempt", "intent", string(d.Intent))
			repair, rerr := s.LLM.Generate(ctx, GenerateRequest{
				Model: GeneratorModel, SystemPrompt: sysPrompt,
				UserContent: user + "\n\nPOPRZEDNIA ODPOWIEDZ (do naprawy):\n" + resp.Text +
					"\n\nNAPRAW WYLACZNIE CYTATY: skopiuj kazdy doslownie z fragmentow " +
					"powyzej, w oryginalnym jezyku, znak w znak. Tresci hipotez nie zmieniaj.",
				ResponseSchema: schema, Temperature: 0, MaxTokens: retryGenerationTokens,
			})
			costs = append(costs, ModelCost{Model: GeneratorModel,
				InputTokens: repair.Usage.InputTokens, OutputTokens: repair.Usage.OutputTokens})
			if rerr == nil {
				if m2, derr := decodeModelAnswer(repair.Text); derr == nil {
					answer2, units2 := assemble(d.Intent, m2, relevant)
					if len(units2) > 0 {
						verdict2 := v.Verify(ctx, d.Intent, units2, segMap)
						if verdict2.Cost.Model != "" {
							costs = append(costs, ModelCost{Model: verdict2.Cost.Model,
								InputTokens: verdict2.Cost.InputTokens, OutputTokens: verdict2.Cost.OutputTokens})
						}
						if !verdict2.Blocked {
							slog.InfoContext(ctx, "chat.quote_repair_succeeded", "intent", string(d.Intent))
							appendUserOnlyFields(d.Intent, answer2)
							return answer2, costs, verdict2, ragHits, nil
						}
						slog.WarnContext(ctx, "chat.quote_repair_failed",
							"intent", string(d.Intent), "reason", verdict2.Reason)
					}
				}
			}
		}
		return extractiveFallback(relevant), costs, verdict, ragHits, nil
	}

	// User-only fields are appended HERE, by the server, after
	// validation. They were absent from the schema the model saw, which
	// is why the model cannot have filled them.
	appendUserOnlyFields(d.Intent, answer)
	return answer, costs, verdict, ragHits, nil
}

// usesRAGPreselection reports whether an intent's questions are thematic
// enough for a vector search over rag_memories to beat recency.
func usesRAGPreselection(i guardrail.Intent) bool {
	switch i {
	case guardrail.A8Concept, guardrail.A1Search, guardrail.A10Intervention:
		return true
	}
	return false
}

// needsDigests reports whether report summaries add useful context.
func needsDigests(i guardrail.Intent) bool {
	switch i {
	case guardrail.A8Concept, guardrail.A9Progress, guardrail.A10Intervention:
		return true
	}
	return false
}

// assemble converts the model's JSON into the served answer plus the
// units the verifier checks. Both come from the same source so the
// verifier cannot be checking something other than what will be shown.
func assemble(intent guardrail.Intent, m modelAnswer, segs []Segment) (*Answer, []guardrail.Unit) {
	byID := map[string]Segment{}
	for _, s := range segs {
		if s.ID != uuid.Nil {
			byID[s.ID.String()] = s
		}
	}
	resolve := func(refs []guardrail.QuoteRef) []Quote {
		out := make([]Quote, 0, len(refs))
		for _, r := range refs {
			q := Quote{SessionID: r.SessionID, SegmentID: r.SegmentID, Text: r.Text}
			// Metadata comes from the database, never from the model.
			if seg, ok := byID[r.SegmentID]; ok {
				q.Speaker = seg.Speaker
				q.TsStartMs = seg.TsStartMs
				q.TsEndMs = seg.TsEndMs
				q.SessionAt = seg.SessionAt
				q.SessionID = seg.SessionID.String()
			}
			out = append(out, q)
		}
		return out
	}

	a := &Answer{}
	var units []guardrail.Unit
	grounded := guardrail.RequiresGrounding(intent)

	for _, sec := range m.Sections {
		a.Sections = append(a.Sections, Section{
			Title: sec.Title, Body: sec.Body, Quotes: resolve(sec.Quotes), Kind: "extract",
		})
		units = append(units, guardrail.Unit{
			Kind: "section", Text: sec.Title + "\n" + sec.Body,
			Quotes: sec.Quotes, MustBeGrounded: grounded,
		})
	}
	for _, h := range m.Hypotheses {
		a.Sections = append(a.Sections, Section{
			Title: h.Title, Body: h.Body, Quotes: resolve(h.Quotes), Kind: "hypothesis",
		})
		units = append(units, guardrail.Unit{
			Kind: "hypothesis", Text: h.Title + "\n" + h.Body,
			Quotes: h.Quotes, MustBeGrounded: true,
		})
	}
	if len(m.Caveats) > 0 {
		a.Sections = append(a.Sections, Section{
			Title: "Ograniczenia", Body: "- " + strings.Join(m.Caveats, "\n- "), Kind: "summary",
		})
	}
	for _, sq := range m.SuggestedQuestions {
		a.SuggestedQuestions = append(a.SuggestedQuestions, SuggestedQuestion{
			Question: sq.Question, Quotes: resolve(sq.Quotes),
		})
		units = append(units, guardrail.Unit{
			Kind: "suggested_question", Text: sq.Question,
			Quotes: sq.Quotes, MustBeGrounded: true,
		})
	}
	return a, units
}

// userOnlyTitles are the display titles for the therapist-owned fields.
var userOnlyTitles = map[string]string{
	"conclusion":     "Twój wniosek",
	"decision":       "Twoja decyzja",
	"open_questions": "Twoje pytania",
}

// appendUserOnlyFields adds the empty, therapist-owned sections.
func appendUserOnlyFields(intent guardrail.Intent, a *Answer) {
	for _, field := range guardrail.UserOnlyFields[intent] {
		title := userOnlyTitles[field]
		if title == "" {
			title = field
		}
		a.Sections = append(a.Sections, Section{
			Title: title, Body: "", Kind: "user_only", UserAuthored: true,
		})
	}
}

// preselect narrows candidate sessions using rag_memories.
//
// Best-effort by design: an embedding failure falls back to recency
// rather than failing the turn. RAG here decides WHICH sessions to read,
// and reading the most recent ones is a reasonable answer to that
// question when the vector path is unavailable.
func (s Service) preselect(ctx context.Context, t Turn, query string) (map[uuid.UUID]bool, int, ModelCost) {
	vec, usage, err := s.LLM.Embed(ctx, query)
	cost := ModelCost{Model: EmbeddingModel, InputTokens: usage.InputTokens}
	if err != nil {
		return nil, 0, ModelCost{}
	}
	ids, err := s.Retriever.CandidateSessions(ctx, t.PatientFileID, vec)
	if err != nil || len(ids) == 0 {
		return nil, 0, cost
	}
	filter := make(map[uuid.UUID]bool, len(ids))
	for _, id := range ids {
		filter[id] = true
	}
	return filter, len(ids), cost
}

// retryGenerationTokens to budzet drugiej proby po obcieciu. Wiekszosc
// odpowiedzi miesci sie w maxGenerationTokens i placi nizsza latencje;
// rzadka duza dostaje drugi, wolniejszy przebieg zamiast blokady.
const retryGenerationTokens int32 = 4096

// extractiveFallback buduje odpowiedz z samego materialu zrodlowego —
// realizacja wprost zapisu ADR o zastapieniu zablokowanej tresci wersja
// ekstraktywna. Terapeuta widzi cytaty, na ktorych analiza miala sie
// oprzec, zamiast sciany "nie pokaze".
//
// Cytaty pochodza z segmentow, ktore SAME sa zrodlem — uziemienie jest
// tozsamosciowe, wiec zaden weryfikator nie jest tu potrzebny.
func extractiveFallback(relevant []Segment) *Answer {
	if len(relevant) == 0 {
		return nil // nie ma na co spasc — wolajacy odmowi
	}
	const maxFallbackQuotes = 4
	quotes := make([]Quote, 0, maxFallbackQuotes)
	for _, seg := range relevant {
		if seg.ID == uuid.Nil {
			continue
		}
		quotes = append(quotes, Quote{
			SessionID: seg.SessionID.String(),
			SegmentID: seg.ID.String(),
			Text:      seg.Text,
			Speaker:   seg.Speaker,
			TsStartMs: seg.TsStartMs,
			TsEndMs:   seg.TsEndMs,
			SessionAt: seg.SessionAt,
		})
		if len(quotes) == maxFallbackQuotes {
			break
		}
	}
	if len(quotes) == 0 {
		return nil
	}
	return &Answer{Sections: []Section{{
		Title: "Materiał źródłowy",
		Body: "Pełna analiza nie przeszła kontroli jakości i nie została pokazana. " +
			"Poniżej fragmenty sesji, na których miała się opierać — możesz " +
			"zadać pytanie ponownie lub inaczej.",
		Quotes: quotes,
		Kind:   "extract",
	}}}
}

// topiclessAnswer odpowiada na pytanie, ktore nie niesie tematu i nie ma
// skad go odziedziczyc — czyli pierwsza ture rozmowy zlozona wylacznie
// ze slow o samej prosbie.
//
// Prosba o doprecyzowanie bije wyszukiwanie na szumie: zapytanie z
// samych stopwordow trafia w najkrotszy segment, a odpowiedz czyta sie
// jak pewne ustalenie o kliencie.
func topiclessAnswer(costs []ModelCost, ragHits int) (*Answer, []ModelCost, guardrail.Verdict, int, error) {
	return &Answer{Sections: []Section{{
		Title: "Doprecyzuj pytanie",
		Body: "Nie wiem, czego szukać — w pytaniu nie ma tematu, " +
			"tylko słowa opisujące samą prośbę. Napisz, o czym mam " +
			"poszukać fragmentów (np. „o pracy”, „o relacji z matką”).",
		Kind: "summary",
	}}}, costs, guardrail.Verdict{}, ragHits, nil
}

// searchQueryOrQuestion zwraca tekst, ktorym warto odpytac RAG.
//
// Osobna funkcja, bo preselekcja RAG dzieje sie PRZED pobraniem
// segmentow, a wiec przed miejscem, w ktorym liczone jest searchQuery.
func searchQueryOrQuestion(t Turn, history []HistoryTurn) string {
	if len(SearchableTerms(t.Question)) > 0 {
		return t.Question
	}
	if inherited, ok := InheritedTopic(history); ok {
		return inherited
	}
	return t.Question
}
