package chat

import (
	"context"
	"fmt"
)

// PostgresDecisionLog writes the MDR article 94 evidence rows.
//
// Every field it writes is a bounded token — an intent label, a bucket, a
// reason code, a version string. Nothing derived from the conversation
// passes through here, which is what lets guardrail_decisions sit outside
// the GDPR purger for 24 months (migration 000085).
type PostgresDecisionLog struct {
	DB QuotaDB
}

const sqlInsertDecision = `
INSERT INTO guardrail_decisions (
    chat_session_hash, intent, risk_flag, confidence_bucket,
    decision, effective_intent, decision_reason,
    verifier_result, block_reason, grounding_quote_count,
    classifier_prompt_version, verifier_prompt_version,
    classifier_model, generator_model, chat_mode, platform,
    cost_micro_usd, latency_ms
) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`

func (l PostgresDecisionLog) Record(ctx context.Context, d DecisionRecord) error {
	_, err := l.DB.Exec(ctx, sqlInsertDecision,
		d.ChatSessionHash, d.Intent, d.RiskFlag, d.ConfidenceBucket,
		d.Decision, d.EffectiveIntent, d.DecisionReason,
		d.VerifierResult, d.BlockReason, d.GroundingQuoteCount,
		d.ClassifierPromptVersion, d.VerifierPromptVersion,
		d.ClassifierModel, d.GeneratorModel, d.ChatMode, d.Platform,
		d.CostMicroUSD, d.LatencyMs,
	)
	if err != nil {
		return fmt.Errorf("chat: record guardrail decision: %w", err)
	}
	return nil
}

// Telemetry event names (ADR section 7.1). Stable strings: they key the
// threshold dashboards in section 8.3, and renaming one silently empties
// whichever panel watched it.
const (
	EventQueryClassified = "ai_chat_query_classified"
	EventRefused         = "ai_chat_refused"
	EventDegraded        = "ai_chat_degraded"
	// EventClinicalGenerated fires for A5 suggested questions and for
	// A8-A10. It is the one that measures the drift the ADR names as
	// residual risk, so it carries the grounding count and the verifier
	// result rather than a bare counter.
	EventClinicalGenerated = "ai_chat_clinical_generated"
	EventVerifierBlock     = "ai_chat_verifier_block"
	EventTemplateField     = "ai_chat_template_field_filled"
	EventKillSwitchChanged = "ai_chat_kill_switch_changed"
	EventStarterUsed       = "ai_chat_starter_used"
	EventQuotaWarning      = "ai_chat_quota_warning"
	EventQuotaExhausted    = "ai_chat_quota_exhausted"
)

// TelemetryEvent is one analytics event, decoupled from pkg/analytics so
// this package stays testable without a collector.
type TelemetryEvent struct {
	Name       string
	Properties map[string]any
}

// Tracker receives telemetry. nil is a valid Service configuration.
type Tracker interface {
	Track(ctx context.Context, e TelemetryEvent)
}

// telemetryFor derives the events for one finished turn.
//
// Properties carry codes and counts only. A property holding the question
// or any part of the answer would put conversation content into the
// analytics pipeline, which has neither the retention rules nor the
// access controls for it.
func telemetryFor(t Turn, out Outcome, rec DecisionRecord) []TelemetryEvent {
	base := map[string]any{
		"intent":            rec.Intent,
		"effective_intent":  rec.EffectiveIntent,
		"confidence_bucket": rec.ConfidenceBucket,
		"platform":          rec.Platform,
		"chat_mode":         rec.ChatMode,
		"latency_ms":        rec.LatencyMs,
	}
	events := []TelemetryEvent{{Name: EventQueryClassified, Properties: copyProps(base, map[string]any{
		"risk_flag": rec.RiskFlag,
		"decision":  rec.Decision,
	})}}

	if t.StarterID != "" {
		events = append(events, TelemetryEvent{Name: EventStarterUsed, Properties: map[string]any{
			"starter_id": t.StarterID,
			"intent":     rec.Intent,
			"edited":     t.StarterEdited,
		}})
	}

	switch out.Kind {
	case OutcomeRefused:
		events = append(events, TelemetryEvent{Name: EventRefused, Properties: copyProps(base, map[string]any{
			"reason": rec.DecisionReason,
		})})
	case OutcomeDegraded:
		events = append(events, TelemetryEvent{Name: EventDegraded, Properties: copyProps(base, map[string]any{
			"reason": rec.DecisionReason,
		})})
	}

	// Zdarzenie bloku pochodzi z REKORDU, nie z rodzaju wyniku: odkad
	// blok z fallbackiem ekstraktywnym wychodzi jako odpowiedz
	// zdegradowana, kluczowanie po OutcomeVerifierBlocked gubiloby te
	// zdarzenia i prog 8.3 (3%) mierzylby fikcje.
	if rec.VerifierResult == "block" {
		events = append(events, TelemetryEvent{Name: EventVerifierBlock, Properties: copyProps(base, map[string]any{
			"block_reason":    rec.BlockReason,
			"served_fallback": out.Answer != nil,
		})})
	}

	// The generative-usage measurement. Fires whenever the served answer
	// contained model-authored clinical material.
	if out.Answer != nil && producedClinicalContent(out) {
		events = append(events, TelemetryEvent{Name: EventClinicalGenerated, Properties: copyProps(base, map[string]any{
			"grounding_quote_count":    rec.GroundingQuoteCount,
			"verifier_result":          rec.VerifierResult,
			"suggested_question_count": len(out.Answer.SuggestedQuestions),
		})})
	}

	if out.Meta.QuotaWarning {
		events = append(events, TelemetryEvent{Name: EventQuotaWarning, Properties: map[string]any{
			"remaining_micro_usd": out.Meta.QuotaRemaining,
		}})
	}
	if rec.DecisionReason == "quota" {
		events = append(events, TelemetryEvent{Name: EventQuotaExhausted, Properties: base})
	}
	return events
}

// producedClinicalContent reports whether the served answer contained
// model-authored clinical material — a hypothesis section or a suggested
// question. A stats table or a bare quote extract does not count.
func producedClinicalContent(out Outcome) bool {
	if out.Answer == nil {
		return false
	}
	if len(out.Answer.SuggestedQuestions) > 0 {
		return true
	}
	for _, s := range out.Answer.Sections {
		if s.Kind == "hypothesis" {
			return true
		}
	}
	return false
}

func copyProps(base, extra map[string]any) map[string]any {
	out := make(map[string]any, len(base)+len(extra))
	for k, v := range base {
		out[k] = v
	}
	for k, v := range extra {
		out[k] = v
	}
	return out
}
