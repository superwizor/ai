// Stripe webhook STUB — placeholder dla slice 2.
//
// Co robi:
//   - Akceptuje POST /stripe/webhook z dowolnym body.
//   - Loguje request (bez signatury — to nie ma znaczenia bo nie weryfikujemy).
//   - Tworzy payment_events row z processing_status='IGNORED'.
//   - Zwraca 200 OK.
//
// Co NIE robi (slice 2):
//   - Walidacja Stripe-Signature.
//   - Routing event_type → handler (invoice.paid → period rollover, etc.).
//   - Emisja outbox events (subscription.created, period_renewed, etc.).
//
// Decyzja per design §11.1: w slice 2 webhook idzie do OSOBNEJ Cloud Run service
// (billing-webhook-svc, public ingress z signature validation). Tu jest stub
// wewnątrz billing-svc tylko żeby contract surface istniał i nie wracać
// 404 na test Stripe CLI w staging.
package http

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

type StripeStubHandler struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

func NewStripeStubHandler(pool *pgxpool.Pool, logger *slog.Logger) *StripeStubHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &StripeStubHandler{pool: pool, logger: logger}
}

func (h *StripeStubHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /stripe/webhook", h.handleWebhook)
}

// stripeMinimalEvent — wyciągamy tylko event ID i type. Reszta payloadu
// idzie do raw_payload JSONB.
type stripeMinimalEvent struct {
	ID   string `json:"id"`
	Type string `json:"type"`
}

func (h *StripeStubHandler) handleWebhook(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20)) // 1 MiB cap
	if err != nil {
		h.logger.WarnContext(ctx, "stripe stub: read body failed", "error", err)
		http.Error(w, "read body failed", http.StatusBadRequest)
		return
	}

	var ev stripeMinimalEvent
	if jErr := json.Unmarshal(body, &ev); jErr != nil {
		// Nie blokuj: nawet jeśli payload nie jest validnym Stripe JSON, zapiszmy go
		// jako "IGNORED" z wygenerowanym event_id, żeby zostawić ślad.
		ev.ID = "stub-unparseable-" + uuid.NewString()
		ev.Type = "unparseable"
		body = []byte(`{"_stub_note": "body was not valid JSON, original captured below"}`)
	}

	if ev.ID == "" {
		ev.ID = "stub-noid-" + uuid.NewString()
	}
	if ev.Type == "" {
		ev.Type = "unknown"
	}

	q := db.New(h.pool)
	errMsg := "STUB — not yet processed; slice 2 will route this event"
	_, err = q.CreatePaymentEventStub(ctx, db.CreatePaymentEventStubParams{
		Provider:        db.PaymentProviderSTRIPE,
		ProviderEventID: ev.ID,
		EventType:       ev.Type,
		RawPayload:      body,
		ErrorMessage:    &errMsg,
	})
	if err != nil && !isUniqueViolation(err) {
		// Unique violation = duplicate webhook → idempotent OK.
		h.logger.ErrorContext(ctx, "stripe stub: insert payment_event failed",
			"event_id", ev.ID,
			"event_type", ev.Type,
			"error", err)
		http.Error(w, "internal", http.StatusInternalServerError)
		return
	}

	h.logger.InfoContext(ctx, "stripe stub: event captured",
		"event_id", ev.ID,
		"event_type", ev.Type,
		"duplicate", isUniqueViolation(err))

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"received_stub","note":"slice 2 will route this"}`))
}

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
