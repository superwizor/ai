// Package outbox definiuje event types + payload schemas dla outbox_events
// publikowanych przez billing-svc.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.1 (thresholds) i §3.8 (mapping).
package outbox

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

const (
	AggregateSubscription = "subscription"
	AggregateQuota        = "quota"

	EventQuotaWarning           = "quota.warning"
	EventQuotaCritical          = "quota.critical"
	EventQuotaExhausted         = "quota.exhausted"
	EventQuotaRenewed           = "subscription.period_renewed"
	EventSubscriptionCanceled   = "subscription.canceled"
	EventSubscriptionPastDue    = "subscription.payment_failed"
)

// QuotaPayload — dla quota.warning / quota.critical / quota.exhausted / quota.renewed.
// Brak PHI per ADR-IMPL-013 — tylko liczby i timestampy.
type QuotaPayload struct {
	SubscriptionID  uuid.UUID `json:"subscription_id"`
	OrganizationID  uuid.UUID `json:"organization_id"`
	PlanTier        string    `json:"plan_tier"`
	PlanCycle       string    `json:"plan_cycle"`
	TokensUsed      int32     `json:"tokens_used"`
	TokensReserved  int32     `json:"tokens_reserved"`
	TokensRemaining int32     `json:"tokens_remaining"`
	TokensLimit     int32     `json:"tokens_limit"`
	PeriodStart     time.Time `json:"period_start"`
	PeriodEnd       time.Time `json:"period_end"`
}

// Marshal — typed helper żeby konsumenci wiedzieli, czego oczekiwać.
func (p QuotaPayload) Marshal() ([]byte, error) {
	return json.Marshal(p)
}

// ---------- threshold logic ----------

// Thresholds — domyślne progi z designu §16.1. Konfigurowane przez env vars
// w czasie startu billing-svc (BILLING_WARN_REMAINING, BILLING_CRITICAL_REMAINING).
type Thresholds struct {
	Warn     int32 // domyślnie 5
	Critical int32 // domyślnie 1
}

// DefaultThresholds — fallback dla testów i lokalnego dev.
func DefaultThresholds() Thresholds {
	return Thresholds{Warn: 5, Critical: 1}
}

// QuotaEdgeEventType — zwraca event_type który powinien zostać wyemitowany
// przy przejściu z `remainingBefore` na `remainingAfter`. Pusty string ⇒
// brak edge (nie emitujemy).
//
// Edge-triggered logika (§16.1): wysyłamy notyfikację TYLKO przy
// przekroczeniu progu, nie przy każdym wartość-poniżej. Tj.:
//   - exhausted: remaining_after == 0 AND remaining_before > 0
//   - critical:  remaining_after <= Critical AND remaining_before > Critical (ale > 0)
//   - warning:   remaining_after <= Warn AND remaining_before > Warn       (ale > Critical)
//
// Pierwszeństwo: exhausted > critical > warning (jeden event per commit, nie trzy).
func (t Thresholds) QuotaEdgeEventType(remainingBefore, remainingAfter int32) string {
	if remainingAfter <= 0 && remainingBefore > 0 {
		return EventQuotaExhausted
	}
	if remainingAfter <= t.Critical && remainingBefore > t.Critical && remainingAfter > 0 {
		return EventQuotaCritical
	}
	if remainingAfter <= t.Warn && remainingBefore > t.Warn && remainingAfter > t.Critical {
		return EventQuotaWarning
	}
	return ""
}
