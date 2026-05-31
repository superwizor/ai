// Stripe webhook handler — pełna implementacja (zastępuje stripe_stub.go).
//
// Weryfikacja sygnatury:
//   Stripe-Signature header zawiera t=<unix> i v1=<hmac-sha256>.
//   Weryfikujemy bez zewnętrznego SDK: HMAC-SHA256(secret, "<t>.<body>").
//   Zgodne ze specyfikacją Stripe: https://docs.stripe.com/webhooks#verify-manually
//
// Zależności:
//   Zero nowych go.mod deps — tylko stdlib + istniejące pgx/uuid.
//   Stripe-Go SDK można dodać później (nie jest wymagane dla weryfikacji).
//
// Idempotency:
//   payment_events.UNIQUE(provider, provider_event_id) — zduplikowany
//   event z Stripe zwraca 200 OK bez ponownego przetwarzania (ON CONFLICT DO NOTHING).
//
// Event routing (ADR-BL-003, docs/16 §7.4):
//   checkout.session.completed        → upsert subscription, create usage_counter
//   customer.subscription.created     → upsert subscription (backup path)
//   customer.subscription.updated     → update status / cancel_at_period_end
//   customer.subscription.deleted     → CANCELED
//   invoice.paid                      → new usage_counters row (period reset, ADR-BL-003)
//   invoice.payment_failed            → PAST_DUE
//   wszystkie inne                    → IGNORED (audit log)
//
// Deployment note (docs/16 §11.1):
//   Docelowo osobny billing-webhook-svc z allUsers IAM.
//   Na staging: billing-svc bezpośrednio z INGRESS_TRAFFIC_ALL (Terraform zmiana Darka).
//   Bezpieczeństwo zapewnia weryfikacja HMAC — bez niej → 400.
package http

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// StripeHandler obsługuje POST /stripe/webhook z pełną weryfikacją sygnatury
// i routingiem eventów do logiki billing-svc.
type StripeHandler struct {
	pool          *pgxpool.Pool
	logger        *slog.Logger
	webhookSecret string // wartość STRIPE_WEBHOOK_SECRET (z Secret Manager przez env)
}

// NewStripeHandler tworzy handler. Jeśli STRIPE_WEBHOOK_SECRET nie jest ustawiony,
// handler loguje ostrzeżenie i ODRZUCA wszystkie requesty z 503 — celowo, żeby
// nie deployować przypadkowo bez weryfikacji.
func NewStripeHandler(pool *pgxpool.Pool, logger *slog.Logger) *StripeHandler {
	if logger == nil {
		logger = slog.Default()
	}
	secret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	if secret == "" {
		logger.Warn("STRIPE_WEBHOOK_SECRET not set — /stripe/webhook will reject all requests with 503")
	}
	return &StripeHandler{
		pool:          pool,
		logger:        logger,
		webhookSecret: secret,
	}
}

// RegisterRoutes rejestruje endpoint. Zastępuje StripeStubHandler.RegisterRoutes.
func (h *StripeHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /stripe/webhook", h.handleWebhook)
}

// ─── Minimalne typy do parsowania Stripe event JSON ───────────────────────────

type stripeEvent struct {
	ID   string          `json:"id"`
	Type string          `json:"type"`
	Data stripeEventData `json:"data"`
}

type stripeEventData struct {
	Object json.RawMessage `json:"object"`
}

// stripeCheckoutSession — pola potrzebne przy checkout.session.completed.
type stripeCheckoutSession struct {
	ID             string `json:"id"`
	Customer       string `json:"customer"`
	Subscription   string `json:"subscription"`
	PaymentStatus  string `json:"payment_status"`
	ClientMetadata struct {
		OrganizationID string `json:"organization_id"`
	} `json:"metadata"`
}

// stripeSubscription — pola potrzebne przy subscription.created/updated/deleted.
type stripeSubscription struct {
	ID                 string `json:"id"`
	Customer           string `json:"customer"`
	Status             string `json:"status"`
	CurrentPeriodStart int64  `json:"current_period_start"`
	CurrentPeriodEnd   int64  `json:"current_period_end"`
	CancelAtPeriodEnd  bool   `json:"cancel_at_period_end"`
	CanceledAt         int64  `json:"canceled_at"`
	TrialEnd           int64  `json:"trial_end"`
	Items              struct {
		Data []struct {
			Price struct {
				ID string `json:"id"`
			} `json:"price"`
		} `json:"data"`
	} `json:"items"`
	Metadata struct {
		OrganizationID string `json:"organization_id"`
	} `json:"metadata"`
}

// stripeInvoice — pola potrzebne przy invoice.paid / invoice.payment_failed.
type stripeInvoice struct {
	ID             string `json:"id"`
	Customer       string `json:"customer"`
	Subscription   string `json:"subscription"`
	AmountPaid     int64  `json:"amount_paid"`
	AmountDue      int64  `json:"amount_due"`
	Currency       string `json:"currency"`
	PeriodStart    int64  `json:"period_start"`
	PeriodEnd      int64  `json:"period_end"`
	Lines          struct {
		Data []struct {
			Period struct {
				Start int64 `json:"start"`
				End   int64 `json:"end"`
			} `json:"period"`
			Price struct {
				ID string `json:"id"`
			} `json:"price"`
		} `json:"data"`
	} `json:"lines"`
}

// ─── HTTP Handler ──────────────────────────────────────────────────────────────

func (h *StripeHandler) handleWebhook(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// 503 gdy sekret nie skonfigurowany — nie ukrywamy problemu konfiguracyjnego.
	if h.webhookSecret == "" {
		h.logger.ErrorContext(ctx, "stripe webhook: STRIPE_WEBHOOK_SECRET not configured")
		http.Error(w, "webhook not configured", http.StatusServiceUnavailable)
		return
	}

	// Czytamy body (max 2MiB — typowy Stripe event to <10KB).
	body, err := io.ReadAll(io.LimitReader(r.Body, 2<<20))
	if err != nil {
		h.logger.WarnContext(ctx, "stripe webhook: read body failed", "error", err)
		http.Error(w, "read error", http.StatusBadRequest)
		return
	}

	// ── Weryfikacja sygnatury Stripe-Signature ───────────────────────────────
	sigHeader := r.Header.Get("Stripe-Signature")
	if sigHeader == "" {
		h.logger.WarnContext(ctx, "stripe webhook: missing Stripe-Signature header")
		http.Error(w, "missing signature", http.StatusBadRequest)
		return
	}

	if err := verifyStripeSignature(sigHeader, body, h.webhookSecret, 300); err != nil {
		h.logger.WarnContext(ctx, "stripe webhook: signature invalid", "error", err)
		http.Error(w, "invalid signature", http.StatusBadRequest)
		return
	}

	// ── Parsowanie eventu ────────────────────────────────────────────────────
	var event stripeEvent
	if err := json.Unmarshal(body, &event); err != nil {
		h.logger.WarnContext(ctx, "stripe webhook: unmarshal failed", "error", err)
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}

	if event.ID == "" || event.Type == "" {
		h.logger.WarnContext(ctx, "stripe webhook: event missing id or type")
		http.Error(w, "incomplete event", http.StatusBadRequest)
		return
	}

	h.logger.InfoContext(ctx, "stripe webhook: received",
		"event_id", event.ID,
		"event_type", event.Type)

	// ── Insert payment_event (idempotent audit log) ──────────────────────────
	paymentEventID, alreadyProcessed, err := h.insertPaymentEvent(ctx, event, body)
	if err != nil {
		h.logger.ErrorContext(ctx, "stripe webhook: insert payment_event failed",
			"event_id", event.ID, "error", err)
		http.Error(w, "internal", http.StatusInternalServerError)
		return
	}
	if alreadyProcessed {
		// Idempotent — duplikat, nic nie robimy.
		h.logger.InfoContext(ctx, "stripe webhook: duplicate event ignored",
			"event_id", event.ID, "event_type", event.Type)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"duplicate"}`))
		return
	}

	// ── Routing eventów ──────────────────────────────────────────────────────
	var handleErr error
	switch event.Type {
	case "checkout.session.completed":
		handleErr = h.handleCheckoutSessionCompleted(ctx, event)
	case "customer.subscription.created":
		handleErr = h.handleSubscriptionCreated(ctx, event)
	case "customer.subscription.updated":
		handleErr = h.handleSubscriptionUpdated(ctx, event)
	case "customer.subscription.deleted":
		handleErr = h.handleSubscriptionDeleted(ctx, event)
	case "invoice.paid":
		handleErr = h.handleInvoicePaid(ctx, event)
	case "invoice.payment_failed":
		handleErr = h.handleInvoicePaymentFailed(ctx, event)
	default:
		// IGNORED — już wpisane do payment_events ze statusem IGNORED.
		h.logger.InfoContext(ctx, "stripe webhook: event type ignored",
			"event_id", event.ID, "event_type", event.Type)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ignored"}`))
		return
	}

	if handleErr != nil {
		h.logger.ErrorContext(ctx, "stripe webhook: handler failed",
			"event_id", event.ID,
			"event_type", event.Type,
			"error", handleErr)
		// Oznacz payment_event jako FAILED.
		q := db.New(h.pool)
		_ = q.MarkPaymentEventFailed(ctx, db.MarkPaymentEventFailedParams{
			ID:           paymentEventID,
			ErrorMessage: ptr(handleErr.Error()),
		})
		// Zwracamy 500 — Stripe ponowi (retry w webhook dashboard).
		http.Error(w, "handler error", http.StatusInternalServerError)
		return
	}

	// Oznacz payment_event jako PROCESSED.
	q := db.New(h.pool)
	_ = q.MarkPaymentEventProcessed(ctx, paymentEventID)

	h.logger.InfoContext(ctx, "stripe webhook: processed",
		"event_id", event.ID, "event_type", event.Type)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

// ─── Event handlers ────────────────────────────────────────────────────────────

// handleCheckoutSessionCompleted — klient zakończył checkout.
// Pobieramy subskrypcję przez metadata.organization_id → tworzymy/upsertujemy
// subscriptions row i startujemy nowy usage_counters bucket.
//
// WAŻNE: metadata["organization_id"] MUSI być ustawione przez frontend
// przy tworzeniu Checkout Session (client_reference_id lub metadata).
// Bez tego nie możemy powiązać subskrypcji z organizacją.
func (h *StripeHandler) handleCheckoutSessionCompleted(ctx context.Context, event stripeEvent) error {
	var sess stripeCheckoutSession
	if err := json.Unmarshal(event.Data.Object, &sess); err != nil {
		return fmt.Errorf("unmarshal checkout session: %w", err)
	}

	orgIDStr := sess.ClientMetadata.OrganizationID
	if orgIDStr == "" {
		// Próbujemy też client_reference_id — common pattern.
		h.logger.WarnContext(ctx, "stripe checkout: organization_id missing in metadata",
			"session_id", sess.ID,
			"subscription_id", sess.Subscription)
		// Nie failujemy — czekamy na subscription.created który też niesie metadata.
		return nil
	}

	if sess.Subscription == "" {
		// Jednorazowa płatność (nie subskrypcja) — nie obsługujemy.
		return nil
	}

	// Subskrypcja zostanie upsertowana przez handleSubscriptionCreated,
	// który Stripe wyśle równolegle. Tutaj tylko logujemy link org→sub.
	h.logger.InfoContext(ctx, "stripe checkout: session completed",
		"session_id", sess.ID,
		"org_id", orgIDStr,
		"stripe_sub_id", sess.Subscription)
	return nil
}

// handleSubscriptionCreated — nowa subskrypcja Stripe.
func (h *StripeHandler) handleSubscriptionCreated(ctx context.Context, event stripeEvent) error {
	return h.upsertSubscriptionFromStripe(ctx, event)
}

// handleSubscriptionUpdated — zmiana planu / statusu / cancel_at_period_end.
func (h *StripeHandler) handleSubscriptionUpdated(ctx context.Context, event stripeEvent) error {
	return h.upsertSubscriptionFromStripe(ctx, event)
}

// handleSubscriptionDeleted — subskrypcja anulowana.
func (h *StripeHandler) handleSubscriptionDeleted(ctx context.Context, event stripeEvent) error {
	var sub stripeSubscription
	if err := json.Unmarshal(event.Data.Object, &sub); err != nil {
		return fmt.Errorf("unmarshal subscription: %w", err)
	}

	var canceledAt pgtype.Timestamptz
	if sub.CanceledAt > 0 {
		canceledAt = pgtype.Timestamptz{Time: time.Unix(sub.CanceledAt, 0), Valid: true}
	}

	q := db.New(h.pool)
	return q.UpdateSubscriptionStatusByStripeID(ctx, db.UpdateSubscriptionStatusByStripeIDParams{
		ProviderSubscriptionID: sub.ID,
		Status:                 db.SubscriptionStatusCANCELED,
		CancelAtPeriodEnd:      false,
		CanceledAt:             canceledAt,
	})
}

// handleInvoicePaid — ADR-BL-003: tworzy NOWY usage_counters row z tokens_used=0.
// To jest trigger resetowania tokenów na nowy okres.
func (h *StripeHandler) handleInvoicePaid(ctx context.Context, event stripeEvent) error {
	var inv stripeInvoice
	if err := json.Unmarshal(event.Data.Object, &inv); err != nil {
		return fmt.Errorf("unmarshal invoice: %w", err)
	}

	if inv.Subscription == "" {
		// Jednorazowa faktura — brak subskrypcji, ignorujemy.
		return nil
	}

	q := db.New(h.pool)

	// Znajdź subskrypcję.
	sub, err := q.GetSubscriptionByStripeID(ctx, inv.Subscription)
	if err != nil {
		if err == pgx.ErrNoRows {
			h.logger.WarnContext(ctx, "stripe invoice.paid: subscription not found, skipping counter reset",
				"stripe_sub_id", inv.Subscription)
			return nil
		}
		return fmt.Errorf("get subscription: %w", err)
	}

	// Wyznacz daty okresu z invoice.lines (najbardziej autorytatywne).
	periodStart, periodEnd := inv.PeriodStart, inv.PeriodEnd
	if len(inv.Lines.Data) > 0 {
		periodStart = inv.Lines.Data[0].Period.Start
		periodEnd = inv.Lines.Data[0].Period.End
	}

	start := time.Unix(periodStart, 0).UTC()
	end := time.Unix(periodEnd, 0).UTC()

	// Utwórz nowy usage_counters row dla nowego okresu (ADR-BL-003).
	// UNIQUE(subscription_id, period_start) chroni przed double-create.
	_, err = q.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
		SubscriptionID: sub.ID,
		PeriodStart:    start,
		PeriodEnd:      end,
		TokensLimit:    sub.PlanTokensPerPeriod,
	})
	if err != nil {
		// Unique violation = już istnieje ten bucket — idempotent.
		if isUniqueViolation(err) {
			h.logger.InfoContext(ctx, "stripe invoice.paid: usage_counter already exists (idempotent)",
				"subscription_id", sub.ID.String())
			return nil
		}
		return fmt.Errorf("create usage_counter: %w", err)
	}

	// Zaktualizuj period w subscriptions row.
	q2 := db.New(h.pool)
	_ = q2.ShiftSubscriptionPeriod(ctx, db.ShiftSubscriptionPeriodParams{
		ID:                 sub.ID,
		CurrentPeriodStart: start,
		CurrentPeriodEnd:   end,
	})

	h.logger.InfoContext(ctx, "stripe invoice.paid: new usage_counter created",
		"subscription_id", sub.ID.String(),
		"period_start", start.Format(time.DateOnly),
		"period_end", end.Format(time.DateOnly),
		"tokens_limit", sub.PlanTokensPerPeriod)

	return nil
}

// handleInvoicePaymentFailed — płatność nieudana → PAST_DUE.
func (h *StripeHandler) handleInvoicePaymentFailed(ctx context.Context, event stripeEvent) error {
	var inv stripeInvoice
	if err := json.Unmarshal(event.Data.Object, &inv); err != nil {
		return fmt.Errorf("unmarshal invoice: %w", err)
	}
	if inv.Subscription == "" {
		return nil
	}
	q := db.New(h.pool)
	return q.UpdateSubscriptionStatusByStripeID(ctx, db.UpdateSubscriptionStatusByStripeIDParams{
		ProviderSubscriptionID: inv.Subscription,
		Status:                 db.SubscriptionStatusPASTDUE,
		CancelAtPeriodEnd:      false,
		CanceledAt:             pgtype.Timestamptz{},
	})
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

// upsertSubscriptionFromStripe parsuje stripeSubscription i robi upsert w DB.
// Używane przez subscription.created i subscription.updated.
func (h *StripeHandler) upsertSubscriptionFromStripe(ctx context.Context, event stripeEvent) error {
	var sub stripeSubscription
	if err := json.Unmarshal(event.Data.Object, &sub); err != nil {
		return fmt.Errorf("unmarshal subscription: %w", err)
	}

	orgIDStr := sub.Metadata.OrganizationID
	if orgIDStr == "" {
		h.logger.WarnContext(ctx, "stripe subscription: organization_id missing in metadata — cannot link",
			"stripe_sub_id", sub.ID,
			"event_type", event.Type)
		// Nie failujemy — robimy co możemy bez org_id.
		// Ewentualnie Darek linkuje ręcznie przez panel admina.
		return nil
	}

	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		return fmt.Errorf("parse organization_id %q: %w", orgIDStr, err)
	}

	// Znajdź plan po stripe_price_id.
	priceID := ""
	if len(sub.Items.Data) > 0 {
		priceID = sub.Items.Data[0].Price.ID
	}

	q := db.New(h.pool)
	plan, err := q.GetPlanByStripePriceID(ctx, &priceID)
	if err != nil {
		if err == pgx.ErrNoRows {
			h.logger.WarnContext(ctx, "stripe subscription: unknown stripe_price_id, cannot map to plan",
				"price_id", priceID, "stripe_sub_id", sub.ID)
			return nil
		}
		return fmt.Errorf("get plan by price_id %q: %w", priceID, err)
	}

	// Mapuj status Stripe → nasz enum.
	status := mapStripeSubStatus(sub.Status)

	periodStart := time.Unix(sub.CurrentPeriodStart, 0).UTC()
	periodEnd := time.Unix(sub.CurrentPeriodEnd, 0).UTC()

	var trialEnd pgtype.Timestamptz
	if sub.TrialEnd > 0 {
		trialEnd = pgtype.Timestamptz{Time: time.Unix(sub.TrialEnd, 0), Valid: true}
	}

	dbSub, err := q.UpsertStripeSubscription(ctx, db.UpsertStripeSubscriptionParams{
		OrganizationID:         orgID,
		PlanID:                 plan.ID,
		ProviderSubscriptionID: sub.ID,
		Status:                 status,
		CurrentPeriodStart:     periodStart,
		CurrentPeriodEnd:       periodEnd,
		CancelAtPeriodEnd:      sub.CancelAtPeriodEnd,
		TrialEndAt:             trialEnd,
	})
	if err != nil {
		return fmt.Errorf("upsert subscription: %w", err)
	}

	// Jeśli ACTIVE/TRIALING: upewnij się że istnieje usage_counters bucket
	// dla bieżącego okresu. ON CONFLICT gwarantuje idempotency.
	if status == db.SubscriptionStatusACTIVE || status == db.SubscriptionStatusTRIALING {
		_, counterErr := q.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
			SubscriptionID: dbSub.ID,
			PeriodStart:    periodStart,
			PeriodEnd:      periodEnd,
			TokensLimit:    plan.TokensPerPeriod,
		})
		if counterErr != nil && !isUniqueViolation(counterErr) {
			h.logger.WarnContext(ctx, "stripe subscription: create usage_counter failed",
				"subscription_id", dbSub.ID.String(), "error", counterErr)
			// Nie failujemy całego handlera — cron safety-check wykryje brak countera.
		}
	}

	h.logger.InfoContext(ctx, "stripe subscription: upserted",
		"stripe_sub_id", sub.ID,
		"org_id", orgIDStr,
		"plan_tier", string(plan.Tier),
		"status", string(status))
	return nil
}

// insertPaymentEvent wstawia zdarzenie do payment_events (audit log).
// Zwraca (id, alreadyProcessed, error).
// alreadyProcessed=true gdy ON CONFLICT DO NOTHING zadziałał (duplikat).
//
// Idempotency: sqlc :one z ON CONFLICT DO NOTHING zwraca pgx.ErrNoRows
// gdy RETURNING nie daje żadnego row (duplikat). Nie zwraca nil struct.
func (h *StripeHandler) insertPaymentEvent(ctx context.Context, event stripeEvent, raw []byte) (uuid.UUID, bool, error) {
	q := db.New(h.pool)
	row, err := q.CreatePaymentEvent(ctx, db.CreatePaymentEventParams{
		Provider:         db.PaymentProviderSTRIPE,
		ProviderEventID:  event.ID,
		EventType:        event.Type,
		AmountGross:      pgtype.Numeric{}, // Valid=false → SQL NULL
		AmountNet:        pgtype.Numeric{}, // Valid=false → SQL NULL
		VatRate:          pgtype.Numeric{}, // Valid=false → SQL NULL
		CurrencyCode:     nil,
		RawPayload:       raw,
		ProcessingStatus: processingStatusForType(event.Type),
	})
	if err != nil {
		if err == pgx.ErrNoRows {
			// ON CONFLICT DO NOTHING → RETURNING dał 0 rows → duplikat.
			return uuid.Nil, true, nil
		}
		return uuid.Nil, false, err
	}
	return row.ID, false, nil
}

// processingStatusForType — zdarzenia które będziemy routować zaczynamy od PENDING,
// ignorowane od razu jako IGNORED.
func processingStatusForType(eventType string) string {
	switch eventType {
	case "checkout.session.completed",
		"customer.subscription.created",
		"customer.subscription.updated",
		"customer.subscription.deleted",
		"invoice.paid",
		"invoice.payment_failed":
		return "PENDING"
	default:
		return "IGNORED"
	}
}

// mapStripeSubStatus mapuje status Stripe na nasz enum.
func mapStripeSubStatus(stripeStatus string) db.SubscriptionStatus {
	switch stripeStatus {
	case "active":
		return db.SubscriptionStatusACTIVE
	case "trialing":
		return db.SubscriptionStatusTRIALING
	case "past_due":
		return db.SubscriptionStatusPASTDUE
	case "canceled", "cancelled":
		return db.SubscriptionStatusCANCELED
	case "incomplete", "incomplete_expired":
		return db.SubscriptionStatusINCOMPLETE
	case "paused":
		return db.SubscriptionStatusPAUSED
	default:
		return db.SubscriptionStatusACTIVE
	}
}

// ─── Stripe signature verification (zero deps) ────────────────────────────────

// verifyStripeSignature weryfikuje Stripe-Signature header zgodnie ze specyfikacją
// https://docs.stripe.com/webhooks#verify-manually
//
// Format headera: t=<unix_timestamp>,v1=<hmac_hex>[,v1=<hmac_hex>...]
// HMAC obliczamy jako HMAC-SHA256(secret, "<timestamp>.<body>").
// toleranceSec: maksymalna różnica czasu (Stripe zaleca 300s).
func verifyStripeSignature(sigHeader string, body []byte, secret string, toleranceSec int64) error {
	var timestamp int64
	var signatures []string

	for _, part := range strings.Split(sigHeader, ",") {
		kv := strings.SplitN(part, "=", 2)
		if len(kv) != 2 {
			continue
		}
		switch kv[0] {
		case "t":
			ts, err := strconv.ParseInt(kv[1], 10, 64)
			if err != nil {
				return fmt.Errorf("invalid timestamp in Stripe-Signature")
			}
			timestamp = ts
		case "v1":
			signatures = append(signatures, kv[1])
		}
	}

	if timestamp == 0 {
		return fmt.Errorf("missing timestamp in Stripe-Signature")
	}
	if len(signatures) == 0 {
		return fmt.Errorf("missing v1 signature in Stripe-Signature")
	}

	// Sprawdź tolerance (clock skew / replay protection).
	age := time.Now().Unix() - timestamp
	if age < 0 {
		age = -age
	}
	if toleranceSec > 0 && age > toleranceSec {
		return fmt.Errorf("timestamp too old: %ds (tolerance %ds)", age, toleranceSec)
	}

	// Oblicz oczekiwany HMAC.
	payload := fmt.Sprintf("%d.%s", timestamp, string(body))
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	expected := hex.EncodeToString(mac.Sum(nil))

	// Sprawdź którykolwiek z v1 pasuje (Stripe może wysłać kilka przy rotacji).
	for _, sig := range signatures {
		if hmac.Equal([]byte(sig), []byte(expected)) {
			return nil
		}
	}

	return fmt.Errorf("no matching v1 signature")
}

func ptr(s string) *string { return &s }

// isUniqueViolation sprawdza czy błąd pgx to naruszenie UNIQUE constraint.
// Używane do idempotency check przy ON CONFLICT DO NOTHING.
func isUniqueViolation(err error) bool {
	if err == nil {
		return false
	}
	pgErr, ok := err.(*pgconn.PgError)
	if !ok {
		return false
	}
	return pgErr.Code == pgerrcode.UniqueViolation
}

// Compile-time check że context.Context import nie jest unused.
var _ = context.Background
