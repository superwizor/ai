package chat

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/appconfig"
	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// Service runs one chat turn end to end.
//
// The pipeline order is fixed and is itself a safety property:
//
//  1. kill switch      — cheapest possible refusal
//  2. quota reserve    — before any model call, so refusing is free
//  3. classify         — one model call
//  4. route            — the decision table
//  5. retrieve         — only what this intent is allowed to see
//  6. generate         — constrained by the intent's schema
//  7. verify           — deterministic, then LLM
//  8. commit + log     — real cost, evidence row
//
// Steps 1 and 2 are before step 3 on purpose: a disabled chat and an
// exhausted budget must both cost zero model calls.
type Service struct {
	LLM       LLM
	Retriever Retriever
	Quota     Quota
	Config    *appconfig.Reader
	Decisions DecisionLog
	// History to pamiec rozmowy. nil = kazda tura jest samotna.
	History HistoryStore
	// Telemetry receives the section 7.1 events. nil disables them.
	Telemetry Tracker
	Now       func() time.Time
}

// DecisionLog persists the MDR evidence row. An interface so a turn is
// testable without a database and so a logging failure can be handled
// explicitly rather than by an ignored error.
type DecisionLog interface {
	Record(ctx context.Context, d DecisionRecord) error
}

// DecisionRecord mirrors guardrail_decisions. It holds no conversation
// content — see migration 000085.
type DecisionRecord struct {
	ChatSessionHash         string
	Intent                  string
	RiskFlag                bool
	ConfidenceBucket        string
	Decision                string
	EffectiveIntent         string
	DecisionReason          string
	VerifierResult          string
	BlockReason             string
	GroundingQuoteCount     int
	ClassifierPromptVersion string
	VerifierPromptVersion   string
	ClassifierModel         string
	GeneratorModel          string
	ChatMode                string
	Platform                string
	CostMicroUSD            int64
	LatencyMs               int
}

// Turn is one request.
type Turn struct {
	TherapistID    uuid.UUID
	OrganizationID uuid.UUID
	PatientFileID  uuid.UUID
	ConversationID uuid.UUID
	Question       string
	Platform       string
	// StarterID is set when the therapist tapped a curated starter.
	StarterID string
	// StarterEdited is true when they changed its text before sending.
	StarterEdited bool
}

// Outcome is what the handler renders.
type Outcome struct {
	Kind    OutcomeKind
	Answer  *Answer
	Refusal *Refusal
	Meta    Meta
}

type OutcomeKind int

const (
	OutcomeAnswered OutcomeKind = iota
	OutcomeDegraded
	OutcomeRefused
	OutcomeVerifierBlocked
	OutcomeUnavailable
)

// Answer is the served response.
type Answer struct {
	Sections           []Section
	SuggestedQuestions []SuggestedQuestion
}

// Section is one rendered block.
type Section struct {
	Title        string
	Body         string
	Quotes       []Quote
	Kind         string // "extract"|"summary"|"stats"|"hypothesis"|"user_only"
	UserAuthored bool
}

// Quote is a resolved citation: the model supplied the pointer, the
// server filled in the metadata from the database.
type Quote struct {
	SessionID string
	SegmentID string
	Text      string
	Speaker   string
	TsStartMs int32
	TsEndMs   int32
	SessionAt time.Time
}

type SuggestedQuestion struct {
	Question string
	Quotes   []Quote
}

// Refusal is a constructive refusal.
type Refusal struct {
	MessageKey            string
	Alternatives          []guardrail.Alternative
	ShowCrisisInformation bool
}

// Meta is observability, not content.
type Meta struct {
	Intent           guardrail.Intent
	ConfidenceBucket string
	DegradeReason    string
	CostMicroUSD     int64
	QuotaRemaining   int64
	RagHitsUsed      int
	LatencyMs        int
	QuotaWarning     bool
}

// ErrChatDisabled reports that the kill switch is engaged.
var ErrChatDisabled = errors.New("chat: disabled")

func (s Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Ask runs one turn.
func (s Service) Ask(ctx context.Context, t Turn) (Outcome, error) {
	started := s.now()
	var costs []ModelCost

	// ── 1. Kill switch ────────────────────────────────────────────
	if !s.Config.ChatEnabled(ctx, t.OrganizationID) {
		return Outcome{Kind: OutcomeUnavailable}, ErrChatDisabled
	}
	mode := guardrail.Mode(s.Config.ChatMode(ctx, t.OrganizationID))
	tau := s.Config.Float64(ctx, appconfig.KeyAIChatClassifierTau, t.OrganizationID)
	limit := s.Config.Int64(ctx, appconfig.KeyAIChatQuotaMicroUSD, t.OrganizationID)

	// ── 2. Quota, before the classifier ───────────────────────────
	reservation, quotaErr := s.Quota.Reserve(ctx, t.TherapistID, limit)
	exhausted := errors.Is(quotaErr, ErrQuotaExhausted)
	if quotaErr != nil && !exhausted {
		return Outcome{}, quotaErr
	}
	// Any exit from here on must close the reservation.
	committed := false
	defer func() {
		if !committed && reservation != nil {
			_ = s.Quota.Release(context.WithoutCancel(ctx), reservation)
		}
	}()

	// ── 3. Classify ───────────────────────────────────────────────
	//
	// Historia wczytywana PRZED klasyfikacja, bo to klasyfikator jej
	// potrzebuje: bez niej "na ten temat" nie ma do czego sie odniesc.
	// Generator jej nie zobaczy — patrz history.go.
	history := s.History.Load(ctx, t.ConversationID)

	classification, classifyCost, err := s.classify(ctx, t, history)
	if err != nil {
		return Outcome{}, err
	}
	if classifyCost.Model != "" {
		costs = append(costs, ModelCost{Model: classifyCost.Model,
			InputTokens: classifyCost.InputTokens, OutputTokens: classifyCost.OutputTokens})
	}

	// ── 4. Route ──────────────────────────────────────────────────
	decision := guardrail.Router{Tau: tau, Mode: mode, QuotaExhausted: exhausted}.Route(classification)

	rec := DecisionRecord{
		ChatSessionHash:         hashConversation(t.ConversationID),
		Intent:                  string(decision.OriginalIntent),
		RiskFlag:                classification.RiskFlag,
		ConfidenceBucket:        decision.ConfidenceBucket,
		Decision:                decision.Action.String(),
		EffectiveIntent:         string(decision.Intent),
		DecisionReason:          decision.Reason,
		VerifierResult:          "skipped",
		ClassifierPromptVersion: guardrail.ClassifierPromptVersion,
		ClassifierModel:         ClassifierModel,
		ChatMode:                string(mode),
		Platform:                t.Platform,
	}

	finish := func(out Outcome) (Outcome, error) {
		actual, err := s.Quota.Commit(context.WithoutCancel(ctx), reservation, costs)
		if err != nil {
			slog.ErrorContext(ctx, "chat.quota_commit_failed", "error", err)
		}
		committed = true

		out.Meta.CostMicroUSD = actual
		out.Meta.LatencyMs = int(s.now().Sub(started).Milliseconds())
		if reservation != nil {
			out.Meta.QuotaRemaining = reservation.State.LimitMicroUSD - reservation.State.UsedMicroUSD - actual
			out.Meta.QuotaWarning = reservation.State.ShouldWarn
			if reservation.State.ShouldWarn {
				_ = s.Quota.MarkWarned(context.WithoutCancel(ctx), reservation)
			}
		}
		rec.CostMicroUSD = actual
		rec.LatencyMs = out.Meta.LatencyMs
		if s.Telemetry != nil {
			for _, ev := range telemetryFor(t, out, rec) {
				s.Telemetry.Track(context.WithoutCancel(ctx), ev)
			}
		}
		// Zapis rozmowy. Best-effort: tura juz zostala obsluzona, a
		// utrata ciaglosci jest mniej dotkliwa niz odmowa odpowiedzi,
		// ktora sie udala.
		if err := s.History.Save(context.WithoutCancel(ctx), t, out, rec,
			Usage{InputTokens: totalIn(costs), OutputTokens: totalOut(costs)}); err != nil {
			slog.ErrorContext(ctx, "chat.history_save_failed", "error", err)
		}
		if s.Decisions != nil {
			if err := s.Decisions.Record(context.WithoutCancel(ctx), rec); err != nil {
				// The evidence row is the MDR article 94 artefact. Losing
				// one is a real gap, so it is logged loudly — but it does
				// not fail a turn that was already served correctly.
				slog.ErrorContext(ctx, "chat.decision_log_failed", "error", err)
			}
		}
		return out, nil
	}

	if decision.Action == guardrail.ActionRefuse {
		return finish(Outcome{
			Kind: OutcomeRefused,
			Refusal: &Refusal{
				MessageKey:            refusalKey(decision),
				Alternatives:          decision.Alternatives,
				ShowCrisisInformation: decision.ShowCrisisInformation,
			},
			Meta: Meta{Intent: decision.OriginalIntent, ConfidenceBucket: decision.ConfidenceBucket,
				DegradeReason: decision.Reason},
		})
	}

	// ── 5-7. Retrieve, generate, verify ───────────────────────────
	answer, execCosts, verdict, ragHits, err := s.execute(ctx, t, decision, history)
	costs = append(costs, execCosts...)
	if err != nil {
		return Outcome{}, err
	}

	rec.VerifierResult = "pass"
	rec.GroundingQuoteCount = countQuotes(answer)
	rec.VerifierPromptVersion = guardrail.VerifierPromptVersion
	rec.GeneratorModel = GeneratorModel

	if verdict.Blocked {
		rec.VerifierResult = "block"
		rec.BlockReason = verdict.Reason

		// ADR: verifier_block -> zastapienie wersja ekstraktywna ALBO
		// odmowa. Gdy executor mial na co spasc (material zrodlowy),
		// terapeuta dostaje go jako odpowiedz zdegradowana; log dowodowy
		// dalej niesie block + powod, wiec pomiar progu 8.3 (3%) nie
		// traci ani jednego zdarzenia.
		if answer != nil {
			rec.GroundingQuoteCount = countQuotes(answer)
			return finish(Outcome{
				Kind:   OutcomeDegraded,
				Answer: answer,
				Meta: Meta{Intent: decision.Intent, ConfidenceBucket: decision.ConfidenceBucket,
					DegradeReason: "verifier_block", RagHitsUsed: ragHits},
			})
		}
		return finish(Outcome{
			Kind:    OutcomeVerifierBlocked,
			Refusal: &Refusal{MessageKey: "chat.refusal.verifier_blocked"},
			Meta: Meta{Intent: decision.Intent, ConfidenceBucket: decision.ConfidenceBucket,
				DegradeReason: "verifier_block", RagHitsUsed: ragHits},
		})
	}

	kind := OutcomeAnswered
	if decision.Action == guardrail.ActionDegrade {
		kind = OutcomeDegraded
	}
	return finish(Outcome{
		Kind:   kind,
		Answer: answer,
		Meta: Meta{Intent: decision.Intent, ConfidenceBucket: decision.ConfidenceBucket,
			DegradeReason: decision.Reason, RagHitsUsed: ragHits},
	})
}

// classify labels the question, or skips the call for an unedited
// starter.
//
// An unedited starter has a known intent from the registry and curated
// wording, so re-classifying it spends a model call to re-derive a
// constant. An EDITED starter is classified like any other text: the
// moment a therapist changes the words, the registry no longer describes
// what was asked.
func (s Service) classify(ctx context.Context, t Turn, history []HistoryTurn) (guardrail.Classification, guardrail.Cost, error) {
	if t.StarterID != "" && !t.StarterEdited {
		if st, ok := StarterByID(t.StarterID); ok {
			return guardrail.Classification{Intent: st.Intent, Confidence: 1.0, RiskFlag: false},
				guardrail.Cost{}, nil
		}
	}
	c := guardrail.LLMClassifier{Caller: modelCaller{s.LLM}, Model: ClassifierModel}

	// Pytanie z historia przed nim. Klasyfikator zwraca zamknieta
	// etykiete i liczbe, wiec nie ma pola, przez ktore historia moglaby
	// wyciec do terapeuty — a bez niej odniesienia sa nierozwiazywalne.
	question := t.Question
	if ctxBlock := FormatForClassifier(history); ctxBlock != "" {
		question = ctxBlock + "\nPYTANIE BIEZACE:\n" + t.Question
	}
	return c.Classify(ctx, question)
}

// modelCaller adapts LLM to guardrail.ModelCaller.
type modelCaller struct{ llm LLM }

func (m modelCaller) CallJSON(ctx context.Context, model, sys, user string, schema map[string]any, temp float32) (string, guardrail.Cost, error) {
	resp, err := m.llm.Generate(ctx, GenerateRequest{
		Model: model, SystemPrompt: sys, UserContent: user,
		ResponseSchema: schema, Temperature: temp, MaxTokens: 2048,
	})
	return resp.Text, guardrail.Cost{
		Model: model, InputTokens: resp.Usage.InputTokens, OutputTokens: resp.Usage.OutputTokens,
	}, err
}

func refusalKey(d guardrail.Decision) string {
	switch d.Reason {
	case guardrail.ReasonRiskFlag:
		return "chat.refusal.risk"
	case guardrail.ReasonOutOfScope:
		return "chat.refusal.out_of_scope"
	case guardrail.ReasonUnknownIntent:
		return "chat.refusal.unclear"
	}
	switch d.OriginalIntent {
	case guardrail.P1Diag:
		return "chat.refusal.diagnosis"
	case guardrail.P2Med:
		return "chat.refusal.medication"
	}
	return "chat.refusal.generic"
}

// hashConversation derives the evidence log's grouping key. SHA-256 of
// the conversation UUID: it groups a conversation's turns without giving
// the log a join path back to patient material.
func hashConversation(id uuid.UUID) string {
	sum := sha256.Sum256([]byte(id.String()))
	return hex.EncodeToString(sum[:])
}

func countQuotes(a *Answer) int {
	if a == nil {
		return 0
	}
	n := 0
	for _, s := range a.Sections {
		n += len(s.Quotes)
	}
	for _, q := range a.SuggestedQuestions {
		n += len(q.Quotes)
	}
	return n
}

// parseModelAnswer decodes the model's JSON into the internal shape.
type modelAnswer struct {
	Sections []struct {
		Title  string               `json:"title"`
		Body   string               `json:"body"`
		Quotes []guardrail.QuoteRef `json:"quotes"`
	} `json:"sections"`
	Hypotheses []struct {
		Title  string               `json:"title"`
		Body   string               `json:"body"`
		Quotes []guardrail.QuoteRef `json:"quotes"`
	} `json:"hypotheses"`
	Caveats            []string `json:"caveats"`
	SuggestedQuestions []struct {
		Question string               `json:"question"`
		Quotes   []guardrail.QuoteRef `json:"quotes"`
	} `json:"suggested_questions"`
}

func decodeModelAnswer(raw string) (modelAnswer, error) {
	var m modelAnswer
	clean := strings.TrimSpace(raw)
	clean = strings.TrimPrefix(clean, "```json")
	clean = strings.TrimPrefix(clean, "```")
	clean = strings.TrimSuffix(clean, "```")
	if err := json.Unmarshal([]byte(clean), &m); err != nil {
		return m, fmt.Errorf("chat: decode model answer: %w", err)
	}
	return m, nil
}

func totalIn(costs []ModelCost) int64 {
	var n int64
	for _, c := range costs {
		n += c.InputTokens
	}
	return n
}

func totalOut(costs []ModelCost) int64 {
	var n int64
	for _, c := range costs {
		n += c.OutputTokens
	}
	return n
}
