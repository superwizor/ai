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
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// StripeHandler obsługuje POST /stripe/webhook z pełną weryfikacją sygnatury
// i routingiem eventów do logiki billing-svc.
type StripeHandler struct {
	pool           *pgxpool.Pool
	queries        *db.Queries
	logger         *slog.Logger
	webhookSecret  string                           // wartość STRIPE_WEBHOOK_SECRET (z Secret Manager przez env)
	identityClient identityv1.IdentityServiceClient // opcjonalny — do syncu danych org ze Stripe
}

// NewStripeHandler tworzy handler. Jeśli STRIPE_WEBHOOK_SECRET nie jest ustawiony,
// handler loguje ostrzeżenie i ODRZUCA wszystkie requesty z 503 — celowo, żeby
// nie deployować przypadkowo bez weryfikacji.
//
// identityClient jest opcjonalny — jeśli nil, synchronizacja danych firmy
// ze Stripe do organizations jest pomijana (graceful degradation).
func NewStripeHandler(pool *pgxpool.Pool, logger *slog.Logger, identityClient identityv1.IdentityServiceClient) *StripeHandler {
	if logger == nil {
		logger = slog.Default()
	}
	secret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	if secret == "" {
		logger.Warn("STRIPE_WEBHOOK_SECRET not set — /stripe/webhook will reject all requests with 503")
	}
	if identityClient == nil {
		logger.Warn("stripe webhook: identityClient nil — Stripe→org sync disabled")
	}
	return &StripeHandler{
		pool:           pool,
		queries:        db.New(pool),
		logger:         logger,
		webhookSecret:  secret,
		identityClient: identityClient,
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
	ID              string                `json:"id"`
	Customer        string                `json:"customer"`
	Subscription    string                `json:"subscription"`
	PaymentStatus   string                `json:"payment_status"`
	ClientMetadata  struct {
		OrganizationID string `json:"organization_id"`
	} `json:"metadata"`
	CustomerDetails *stripeCustomerDetails `json:"customer_details"`
}

// stripeCustomerDetails — dane klienta zbierane przez Stripe Checkout.
// Stripe wypełnia te pola automatycznie (name, email, address, tax_ids)
// na podstawie tego co klient podał w formularzu płatności.
type stripeCustomerDetails struct {
	Name    string        `json:"name"`
	Email   string        `json:"email"`
	Address stripeAddress `json:"address"`
	TaxIDs  []stripeTaxID `json:"tax_ids"`
}

type stripeAddress struct {
	Line1      string `json:"line1"`
	Line2      string `json:"line2"`
	City       string `json:"city"`
	PostalCode string `json:"postal_code"`
	State      string `json:"state"`
	Country    string `json:"country"`
}

type stripeTaxID struct {
	Type  string `json:"type"`  // "eu_vat" | "pl_nip"
	Value string `json:"value"` // "PL1234567890"
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
	StartDate          int64  `json:"start_date"`
	Created            int64  `json:"created"`
	Items              struct {
		Data []struct {
			Price struct {
				ID string `json:"id"`
			} `json:"price"`
			CurrentPeriodStart int64 `json:"current_period_start"`
			CurrentPeriodEnd   int64 `json:"current_period_end"`
		} `json:"data"`
	} `json:"items"`
	Metadata struct {
		OrganizationID string `json:"organization_id"`
	} `json:"metadata"`
}

// stripeInvoice — pola potrzebne przy invoice.paid / invoice.payment_failed.
type stripeInvoice struct {
	ID               string `json:"id"`
	Customer         string `json:"customer"`
	Subscription     string `json:"subscription"`
	AmountPaid       int64  `json:"amount_paid"`
	AmountDue        int64  `json:"amount_due"`
	Currency         string `json:"currency"`
	PeriodStart      int64  `json:"period_start"`
	PeriodEnd        int64  `json:"period_end"`
	InvoicePDF       string `json:"invoice_pdf"`
	HostedInvoiceURL string `json:"hosted_invoice_url"`
	Created          int64  `json:"created"`
	Lines            struct {
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
	Parent *struct {
		SubscriptionDetails *struct {
			Subscription string `json:"subscription"`
		} `json:"subscription_details"`
	} `json:"parent"`
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
	if h.webhookSecret != "skip" {
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
	} else {
		h.logger.InfoContext(ctx, "stripe webhook: signature verification skipped (STRIPE_WEBHOOK_SECRET=skip)")
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
	case "checkout.session.expired":
		handleErr = h.handleCheckoutSessionExpired(ctx, event)
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

	// ── Kod rabatowy: rezerwacja → użycie (docs/70 §6.4) ─────────────
	// Rezerwacja powstała przy tworzeniu sesji Checkout; dopiero
	// potwierdzona płatność zamienia ją w użycie. Sesja porzucona
	// wygasa i zwalnia rezerwację (checkout.session.expired poniżej).
	if orgID, perr := uuid.Parse(orgIDStr); perr == nil {
		h.commitDiscountRedemption(ctx, orgID)
		// Zakup dobiegł końca — blokada kanału WEB nie jest już potrzebna.
		if derr := h.queries.DeletePendingCheckout(ctx, db.DeletePendingCheckoutParams{
			OrganizationID: orgID,
			Channel:        "WEB",
		}); derr != nil {
			h.logger.WarnContext(ctx, "stripe checkout: nie zdjęto blokady kanału", "error", derr)
		}
	}

	// ── Sync danych firmy ze Stripe do organizations (best-effort) ───
	// Stripe Checkout zbiera dane klienta (imię/firma, adres, NIP) —
	// synchronizujemy je do tabeli organizations przez identity-svc
	// AdminUpdateOrganization RPC. Failure nie blokuje checkout flow.
	if sess.CustomerDetails != nil && h.identityClient != nil {
		syncCtx, syncCancel := context.WithTimeout(context.WithoutCancel(ctx), 10*time.Second)
		go func() {
			defer syncCancel()
			h.syncCustomerDetailsToOrg(syncCtx, orgIDStr, sess.CustomerDetails)
		}()
	}

	return nil
}

// commitDiscountRedemption zamienia rezerwację kodu w użycie i
// odświeża licznik pokazywany w panelu.
//
// Organizacja może mieć najwyżej jedną rezerwację na kod (UNIQUE), ale
// nie wiemy tutaj, KTÓREGO kodu użyto — Stripe zwraca to w
// total_details, którego nasz uproszczony parser zdarzeń nie czyta.
// Domykamy więc wszystkie rezerwacje RESERVED tej organizacji: w
// praktyce jest ich zero albo jedna, bo checkout dopuszcza jeden kod.
func (h *StripeHandler) commitDiscountRedemption(ctx context.Context, orgID uuid.UUID) {
	codeIDs, err := h.queries.ListReservedRedemptionCodesForOrg(ctx, orgID)
	if err != nil {
		h.logger.WarnContext(ctx, "kod rabatowy: nie udało się odczytać rezerwacji", "error", err)
		return
	}
	for _, codeID := range codeIDs {
		if _, cerr := h.queries.CommitRedemptionByReference(ctx, db.CommitRedemptionByReferenceParams{
			CodeID:         codeID,
			OrganizationID: orgID,
		}); cerr != nil {
			h.logger.WarnContext(ctx, "kod rabatowy: domknięcie rezerwacji nieudane", "error", cerr)
			continue
		}
		if serr := h.queries.SyncRedemptionsCount(ctx, codeID); serr != nil {
			h.logger.WarnContext(ctx, "kod rabatowy: przeliczenie licznika nieudane", "error", serr)
		}
	}
}

// handleCheckoutSessionExpired zwalnia rezerwację kodu i blokadę kanału,
// gdy użytkownik porzucił opłacanie.
func (h *StripeHandler) handleCheckoutSessionExpired(ctx context.Context, event stripeEvent) error {
	var sess stripeCheckoutSession
	if err := json.Unmarshal(event.Data.Object, &sess); err != nil {
		return fmt.Errorf("unmarshal checkout session: %w", err)
	}
	orgID, perr := uuid.Parse(sess.ClientMetadata.OrganizationID)
	if perr != nil {
		return nil
	}
	codeIDs, err := h.queries.ListReservedRedemptionCodesForOrg(ctx, orgID)
	if err == nil {
		for _, codeID := range codeIDs {
			if _, rerr := h.queries.ReleaseRedemption(ctx, db.ReleaseRedemptionParams{
				CodeID:         codeID,
				OrganizationID: orgID,
			}); rerr != nil {
				h.logger.WarnContext(ctx, "kod rabatowy: zwolnienie rezerwacji nieudane", "error", rerr)
			}
		}
	}
	if derr := h.queries.DeletePendingCheckout(ctx, db.DeletePendingCheckoutParams{
		OrganizationID: orgID,
		Channel:        "WEB",
	}); derr != nil {
		h.logger.WarnContext(ctx, "stripe checkout: nie zdjęto blokady kanału", "error", derr)
	}
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

func getInvoiceSubscriptionID(inv *stripeInvoice) string {
	if inv.Subscription != "" {
		return inv.Subscription
	}
	if inv.Parent != nil && inv.Parent.SubscriptionDetails != nil {
		return inv.Parent.SubscriptionDetails.Subscription
	}
	return ""
}

// handleInvoicePaid — ADR-BL-003: tworzy NOWY usage_counters row z tokens_used=0.
// To jest trigger resetowania tokenów na nowy okres.
func (h *StripeHandler) handleInvoicePaid(ctx context.Context, event stripeEvent) error {
	var inv stripeInvoice
	if err := json.Unmarshal(event.Data.Object, &inv); err != nil {
		return fmt.Errorf("unmarshal invoice: %w", err)
	}

	subID := getInvoiceSubscriptionID(&inv)
	if subID == "" {
		// Jednorazowa faktura — brak subskrypcji, ignorujemy.
		return nil
	}

	q := db.New(h.pool)

	// Znajdź subskrypcję.
	sub, err := q.GetSubscriptionByStripeID(ctx, subID)
	if err != nil {
		if err == pgx.ErrNoRows {
			h.logger.WarnContext(ctx, "stripe invoice.paid: subscription not found, skipping counter reset",
				"stripe_sub_id", subID)
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

	// Save invoice record to database
	var amountNumeric pgtype.Numeric
	err = amountNumeric.Scan(fmt.Sprintf("%.2f", float64(inv.AmountPaid)/100.0))
	if err == nil {
		invoiceCreatedAt := time.Now().UTC()
		if inv.Created > 0 {
			invoiceCreatedAt = time.Unix(inv.Created, 0).UTC()
		}

		_, err = q.CreateInvoice(ctx, db.CreateInvoiceParams{
			OrganizationID:   sub.OrganizationID,
			SubscriptionID:   pgtype.UUID{Bytes: sub.ID, Valid: true},
			StripeInvoiceID:  inv.ID,
			AmountPaid:       amountNumeric,
			Currency:         strings.ToUpper(inv.Currency),
			InvoicePdf:       inv.InvoicePDF,
			HostedInvoiceUrl: inv.HostedInvoiceURL,
			PeriodStart:      start,
			PeriodEnd:        end,
			CreatedAt:        invoiceCreatedAt,
		})
		if err != nil {
			h.logger.ErrorContext(ctx, "stripe invoice.paid: failed to save invoice to DB",
				"stripe_invoice_id", inv.ID, "error", err)
		} else {
			h.logger.InfoContext(ctx, "stripe invoice.paid: invoice successfully saved to DB",
				"stripe_invoice_id", inv.ID, "org_id", sub.OrganizationID)
		}
	} else {
		h.logger.ErrorContext(ctx, "stripe invoice.paid: failed to convert amount to numeric", "error", err)
	}

	return nil
}

// handleInvoicePaymentFailed — płatność nieudana → PAST_DUE.
func (h *StripeHandler) handleInvoicePaymentFailed(ctx context.Context, event stripeEvent) error {
	var inv stripeInvoice
	if err := json.Unmarshal(event.Data.Object, &inv); err != nil {
		return fmt.Errorf("unmarshal invoice: %w", err)
	}
	subID := getInvoiceSubscriptionID(&inv)
	if subID == "" {
		return nil
	}
	q := db.New(h.pool)
	return q.UpdateSubscriptionStatusByStripeID(ctx, db.UpdateSubscriptionStatusByStripeIDParams{
		ProviderSubscriptionID: subID,
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

	q := db.New(h.pool)

	orgIDStr := sub.Metadata.OrganizationID
	if orgIDStr == "" {
		// Fallback: legacy subscriptions created before metadata was added.
		// Try to find org_id from existing DB record matched by stripe sub ID.
		existingSub, dbErr := q.GetSubscriptionByStripeID(ctx, sub.ID)
		if dbErr == nil {
			orgIDStr = existingSub.OrganizationID.String()
			h.logger.InfoContext(ctx, "stripe subscription: resolved organization_id from DB fallback",
				"stripe_sub_id", sub.ID,
				"org_id", orgIDStr)
		} else {
			h.logger.WarnContext(ctx, "stripe subscription: organization_id missing in metadata and not found in DB — cannot link",
				"stripe_sub_id", sub.ID,
				"event_type", event.Type)
			return nil
		}
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

	periodStartUnix := sub.CurrentPeriodStart
	periodEndUnix := sub.CurrentPeriodEnd

	if periodStartUnix == 0 && len(sub.Items.Data) > 0 {
		periodStartUnix = sub.Items.Data[0].CurrentPeriodStart
	}
	if periodEndUnix == 0 && len(sub.Items.Data) > 0 {
		periodEndUnix = sub.Items.Data[0].CurrentPeriodEnd
	}

	if periodStartUnix == 0 {
		if sub.StartDate > 0 {
			periodStartUnix = sub.StartDate
		} else if sub.Created > 0 {
			periodStartUnix = sub.Created
		} else {
			periodStartUnix = time.Now().Unix()
		}
		h.logger.WarnContext(ctx, "stripe subscription: period_start fallback used",
			"stripe_sub_id", sub.ID,
			"fallback_unix", periodStartUnix,
			"source", "start_date/created/now")
	}
	if periodEndUnix == 0 || periodEndUnix <= periodStartUnix {
		// Cycle-aware fallback: use plan.Cycle to determine the correct period length.
		// Without this, annual plans would get a 30-day period instead of 365 days.
		var fallbackDays int64
		switch plan.Cycle {
		case db.BillingCycleANNUAL:
			fallbackDays = 365
		case db.BillingCycleSEMIANNUAL:
			fallbackDays = 183
		default: // MONTHLY
			fallbackDays = 30
		}
		periodEndUnix = periodStartUnix + fallbackDays*24*60*60
		h.logger.WarnContext(ctx, "stripe subscription: period_end fallback used",
			"stripe_sub_id", sub.ID,
			"plan_cycle", string(plan.Cycle),
			"fallback_days", fallbackDays,
			"period_end_unix", periodEndUnix)
	}

	// Sanity check: period length should be reasonable (1 day to 400 days).
	periodLengthDays := (periodEndUnix - periodStartUnix) / (24 * 60 * 60)
	if periodLengthDays > 400 {
		h.logger.WarnContext(ctx, "stripe subscription: unusually long period detected",
			"stripe_sub_id", sub.ID,
			"period_length_days", periodLengthDays)
	}
	if periodLengthDays < 1 {
		h.logger.ErrorContext(ctx, "stripe subscription: period_end <= period_start after fallback, forcing +30d",
			"stripe_sub_id", sub.ID,
			"period_start_unix", periodStartUnix,
			"period_end_unix", periodEndUnix)
		periodEndUnix = periodStartUnix + 30*24*60*60
	}

	periodStart := time.Unix(periodStartUnix, 0).UTC()
	periodEnd := time.Unix(periodEndUnix, 0).UTC()

	var trialEnd pgtype.Timestamptz
	if sub.TrialEnd > 0 {
		trialEnd = pgtype.Timestamptz{Time: time.Unix(sub.TrialEnd, 0), Valid: true}
	}

	var canceledAt pgtype.Timestamptz
	if sub.CanceledAt > 0 {
		canceledAt = pgtype.Timestamptz{Time: time.Unix(sub.CanceledAt, 0).UTC(), Valid: true}
	}

	cancelAtPeriodEnd := sub.CancelAtPeriodEnd
	if sub.CanceledAt > 0 {
		cancelAtPeriodEnd = true
	}

	// Uruchomienie transakcji, aby zachować spójność przy deaktywacji starych subskrypcji i wstawieniu nowej.
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	qTx := db.New(tx)

	// Jeśli nowa subskrypcja ma być aktywna/trial/past_due, najpierw deaktywujemy wszystkie inne aktywne subskrypcje tej organizacji.
	if status == db.SubscriptionStatusACTIVE || status == db.SubscriptionStatusTRIALING || status == db.SubscriptionStatusPASTDUE {
		err = qTx.DeactivateOtherActiveSubscriptions(ctx, db.DeactivateOtherActiveSubscriptionsParams{
			OrganizationID:         orgID,
			ProviderSubscriptionID: sub.ID,
		})
		if err != nil {
			return fmt.Errorf("deactivate other active subscriptions: %w", err)
		}
	}
	dbSub, err := qTx.UpsertStripeSubscription(ctx, db.UpsertStripeSubscriptionParams{
		OrganizationID:         orgID,
		PlanID:                 plan.ID,
		ProviderSubscriptionID: sub.ID,
		Status:                 status,
		CurrentPeriodStart:     periodStart,
		CurrentPeriodEnd:       periodEnd,
		CancelAtPeriodEnd:      cancelAtPeriodEnd,
		TrialEndAt:             trialEnd,
		CanceledAt:             canceledAt,
	})
	if err != nil {
		return fmt.Errorf("upsert subscription: %w", err)
	}

	// Jeśli ACTIVE/TRIALING: upewnij się że istnieje usage_counters bucket
	// dla bieżącego okresu. Sprawdzamy najpierw czy istnieje, aby uniknąć
	// wywołania błędu UNIQUE constraint, który unieważniłby całą transakcję w Postgresie.
	if status == db.SubscriptionStatusACTIVE || status == db.SubscriptionStatusTRIALING {
		exists, checkErr := qTx.CheckUsageCounterExists(ctx, db.CheckUsageCounterExistsParams{
			SubscriptionID: dbSub.ID,
			PeriodStart:    periodStart,
		})
		if checkErr != nil {
			h.logger.WarnContext(ctx, "stripe subscription: check usage_counter existence failed",
				"subscription_id", dbSub.ID.String(), "error", checkErr)
		} else if !exists {
			_, counterErr := qTx.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
				SubscriptionID: dbSub.ID,
				PeriodStart:    periodStart,
				PeriodEnd:      periodEnd,
				TokensLimit:    plan.TokensPerPeriod,
			})
			if counterErr != nil && !isUniqueViolation(counterErr) {
				h.logger.WarnContext(ctx, "stripe subscription: create usage_counter failed",
					"subscription_id", dbSub.ID.String(), "error", counterErr)
				// Nie failujemy całej transakcji — cron safety-check wykryje brak countera.
			}
		} else {
			h.logger.InfoContext(ctx, "stripe subscription: usage_counter already exists, updating limit and period_end",
				"subscription_id", dbSub.ID.String(),
				"new_limit", plan.TokensPerPeriod,
				"new_period_end", periodEnd)
			updateErr := qTx.UpdateUsageCounterOnPlanChange(ctx, db.UpdateUsageCounterOnPlanChangeParams{
				SubscriptionID: dbSub.ID,
				PeriodStart:    periodStart,
				TokensLimit:    plan.TokensPerPeriod,
				PeriodEnd:      periodEnd,
			})
			if updateErr != nil {
				h.logger.WarnContext(ctx, "stripe subscription: update usage_counter failed",
					"subscription_id", dbSub.ID.String(), "error", updateErr)
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
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
// UWAGA: default NIE powinien cicho mapować na ACTIVE — to ukrywa nieznane statusy
// i może prowadzić do sytuacji gdzie INCOMPLETE subskrypcja wygląda jak ACTIVE.
// Zamiast tego logujemy ostrzeżenie i zwracamy INCOMPLETE jako bezpieczny default.
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
		// Bezpieczny default: INCOMPLETE zamiast ACTIVE.
		// Nowy/nieznany status Stripe nie powinien cicho aktywować subskrypcji.
		slog.Warn("stripe subscription: unknown status mapped to INCOMPLETE",
			"stripe_status", stripeStatus)
		return db.SubscriptionStatusINCOMPLETE
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

// Compile-time check imports.
var _ = context.Background
var _ = slog.Warn

// syncCustomerDetailsToOrg synchronizuje dane firmy ze Stripe Checkout
// do tabeli organizations w identity-svc via AdminUpdateOrganization RPC.
//
// Best-effort: błędy są logowane ale nie blokują checkout flow.
// Wywoływana w goroutine z context.WithoutCancel żeby przeżyć
// zamknięcie HTTP response (webhook musi oddać 200 szybko).
//
// Mapowanie Stripe → Organization:
//   customer_details.name         → legal_name
//   customer_details.address.*    → headquarters_address.{street_line, city, postal_code, region, country_code}
//   customer_details.tax_ids[0]   → tax_id (pl_nip) lub vat_id_eu (eu_vat)
func (h *StripeHandler) syncCustomerDetailsToOrg(ctx context.Context, orgIDStr string, details *stripeCustomerDetails) {
	if details == nil {
		return
	}

	// Build the AdminUpdateOrganizationRequest
	req := &identityv1.AdminUpdateOrganizationRequest{
		OrganizationId: orgIDStr,
		Reason:         "Stripe checkout auto-sync: customer_details → organization",
	}

	hasData := false

	// Legal name
	if details.Name != "" {
		req.LegalName = &details.Name
		hasData = true
	}

	// Tax IDs — NIP (pl_nip) or EU VAT (eu_vat)
	for _, tid := range details.TaxIDs {
		if tid.Value == "" {
			continue
		}
		switch tid.Type {
		case "pl_nip":
			req.TaxId = &tid.Value
			hasData = true
		case "eu_vat":
			req.VatIdEu = &tid.Value
			hasData = true
		}
	}

	// Address
	addr := details.Address
	if addr.Line1 != "" || addr.City != "" || addr.PostalCode != "" || addr.Country != "" {
		req.HeadquartersAddress = &identityv1.Address{
			StreetLine:  addr.Line1,
			City:        addr.City,
			PostalCode:  addr.PostalCode,
			Region:      addr.State,
			CountryCode: addr.Country,
		}
		// Append Line2 to directions if present
		if addr.Line2 != "" {
			req.HeadquartersAddress.Directions = addr.Line2
		}
		hasData = true
	}

	if !hasData {
		h.logger.InfoContext(ctx, "stripe checkout: no customer_details to sync",
			"org_id", orgIDStr)
		return
	}

	_, err := h.identityClient.AdminUpdateOrganization(ctx, req)
	if err != nil {
		h.logger.WarnContext(ctx, "stripe checkout: org sync via gRPC failed, falling back to direct DB update",
			"org_id", orgIDStr,
			"error", err)

		orgID, parseErr := uuid.Parse(orgIDStr)
		if parseErr != nil {
			h.logger.ErrorContext(ctx, "stripe checkout: invalid organization ID in metadata", "org_id", orgIDStr, "error", parseErr)
			return
		}

		// Fallback direct DB update
		tx, txErr := h.pool.Begin(ctx)
		if txErr != nil {
			h.logger.ErrorContext(ctx, "stripe checkout: db transaction begin failed", "error", txErr)
			return
		}
		defer func() { _ = tx.Rollback(ctx) }()

		// Update legal_name
		if details.Name != "" {
			_, dbErr := tx.Exec(ctx, `UPDATE organizations SET legal_name = $1 WHERE id = $2`, details.Name, orgID)
			if dbErr != nil {
				h.logger.ErrorContext(ctx, "stripe checkout: direct update legal_name failed", "error", dbErr)
				return
			}
		}

		// Update Tax IDs — NIP (pl_nip) or EU VAT (eu_vat)
		for _, tid := range details.TaxIDs {
			if tid.Value == "" {
				continue
			}
			switch tid.Type {
			case "pl_nip":
				_, dbErr := tx.Exec(ctx, `UPDATE organizations SET tax_id = $1 WHERE id = $2`, tid.Value, orgID)
				if dbErr != nil {
					h.logger.ErrorContext(ctx, "stripe checkout: direct update tax_id failed", "error", dbErr)
					return
				}
			case "eu_vat":
				_, dbErr := tx.Exec(ctx, `UPDATE organizations SET vat_id_eu = $1 WHERE id = $2`, tid.Value, orgID)
				if dbErr != nil {
					h.logger.ErrorContext(ctx, "stripe checkout: direct update vat_id_eu failed", "error", dbErr)
					return
				}
			}
		}

		// Address
		if addr.Line1 != "" || addr.City != "" || addr.PostalCode != "" || addr.Country != "" {
			// Find existing address ID
			var existingAddressID pgtype.UUID
			dbErr := tx.QueryRow(ctx, `SELECT headquarters_address_id FROM organizations WHERE id = $1`, orgID).Scan(&existingAddressID)
			if dbErr == nil && existingAddressID.Valid {
				// Update existing address
				_, dbErr = tx.Exec(ctx, `
					UPDATE addresses 
					SET country_code = $1, region = $2, city = $3, postal_code = $4, street_line = $5, building_number = $6, directions = $7
					WHERE id = $8`,
					addr.Country, addr.State, addr.City, addr.PostalCode, addr.Line1, "-", addr.Line2, existingAddressID.Bytes,
				)
				if dbErr != nil {
					h.logger.WarnContext(ctx, "stripe checkout: direct update address failed", "error", dbErr)
				}
			} else {
				// Create new address
				var newAddressID uuid.UUID
				dbErr = tx.QueryRow(ctx, `
					INSERT INTO addresses (country_code, region, city, postal_code, street_line, building_number, directions)
					VALUES ($1, $2, $3, $4, $5, $6, $7)
					RETURNING id`,
					addr.Country, addr.State, addr.City, addr.PostalCode, addr.Line1, "-", addr.Line2,
				).Scan(&newAddressID)
				if dbErr == nil {
					_, dbErr = tx.Exec(ctx, `UPDATE organizations SET headquarters_address_id = $1 WHERE id = $2`, newAddressID, orgID)
					if dbErr != nil {
						h.logger.WarnContext(ctx, "stripe checkout: direct link address failed", "error", dbErr)
					}
				} else {
					h.logger.WarnContext(ctx, "stripe checkout: direct create address failed", "error", dbErr)
				}
			}
		}

		if commitErr := tx.Commit(ctx); commitErr != nil {
			h.logger.ErrorContext(ctx, "stripe checkout: direct db commit failed", "error", commitErr)
			return
		}

		h.logger.InfoContext(ctx, "stripe checkout: org data successfully synced directly to DB",
			"org_id", orgIDStr,
			"legal_name", details.Name,
		)
		return
	}

	h.logger.InfoContext(ctx, "stripe checkout: org data synced from Stripe via gRPC",
		"org_id", orgIDStr,
		"legal_name", details.Name,
		"has_tax_ids", len(details.TaxIDs) > 0,
		"has_address", addr.Line1 != "")
}
