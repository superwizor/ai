// Package http — endpointy HTTP obok gRPC servera billing-svc.
//
// Cele:
//   - /admin/reservation-expiry — cron co 5 min: EXPIRED stale reservations.
//   - /admin/manual-period-renewal — cron daily: rolluje okres dla MANUAL subs.
//   - /admin/safety-check — cron weekly: alert jeśli są subscriptions bez counter.
//   - /stripe/webhook — STUB (slice 2 da real implementację).
//
// Auth: Cloud Scheduler woła te endpointy z OIDC tokenem podpisanym przez
// dedykowane SA. Cloud Run frontend waliduje token automatycznie (IAM
// roles/run.invoker na konkretne SA). Aplikacja TYLKO sanity-checkuje
// Header X-Goog-Scheduler-Source (opcjonalne) i loguje invoker.
package http

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// AdminHandler — wrapuje pgxpool + bezpośrednio woła sqlc.
// Brak interfejsów: te endpointy są internal admin, testowane integration
// (testcontainers) a nie unit. Brak złożonej logiki domeny, tylko DB ops.
type AdminHandler struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

func NewAdminHandler(pool *pgxpool.Pool, logger *slog.Logger) *AdminHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &AdminHandler{pool: pool, logger: logger}
}

// RegisterRoutes — wpina endpointy w mux. Wywoływany z cmd/server/main.go.
func (h *AdminHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /admin/reservation-expiry", h.handleReservationExpiry)
	mux.HandleFunc("POST /admin/manual-period-renewal", h.handleManualPeriodRenewal)
	mux.HandleFunc("POST /admin/safety-check", h.handleSafetyCheck)
}

// ---------- reservation-expiry ----------

type reservationExpiryResponse struct {
	ExpiredCount int    `json:"expired_count"`
	Message      string `json:"message"`
}

// handleReservationExpiry — cron co 5 min:
//  1. UPDATE pending_reservations SET status='EXPIRED' WHERE status='ACTIVE' AND expires_at < now() RETURNING (sub_id, tokens_reserved).
//  2. Per unique sub_id: UPDATE usage_counters SET tokens_reserved -= sum.
//
// Idempotent: re-run nic nie psuje (nie ma żadnych już aktywnych z expired).
func (h *AdminHandler) handleReservationExpiry(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	h.logger.InfoContext(ctx, "cron: reservation-expiry started")

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "tx begin", err)
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := db.New(tx)

	expired, err := q.MarkExpiredReservations(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "mark expired", err)
		return
	}

	// Agreguj tokens_reserved per subscription_id (pojedyncze sub może mieć
	// wiele expired reservations — chcemy 1 UPDATE counter zamiast N).
	tokensBySub := map[uuid.UUID]int32{}
	for _, e := range expired {
		tokensBySub[e.SubscriptionID] += e.TokensReserved
	}

	for subID, tokens := range tokensBySub {
		// Acquire advisory lock żeby nie kolidować z równoległym
		// ReserveCredit/CommitUsage.
		if err := q.AcquireSubscriptionLock(ctx, subID.String()); err != nil {
			writeError(w, http.StatusInternalServerError, "acquire lock", err)
			return
		}
		counter, err := q.LockActiveCounter(ctx, subID)
		if err != nil {
			if !errIsNoRows(err) {
				writeError(w, http.StatusInternalServerError, "lock counter", err)
				return
			}
			// Brak active counter — możliwe jeśli okres się skończył między
			// utworzeniem rezerwacji a expiry. Idemy dalej; reservation jest
			// już EXPIRED w DB.
			continue
		}
		if err := q.ReleaseReservedTokens(ctx, db.ReleaseReservedTokensParams{
			ID:             counter.ID,
			TokensReserved: tokens,
		}); err != nil {
			writeError(w, http.StatusInternalServerError, "release reserved", err)
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		writeError(w, http.StatusInternalServerError, "tx commit", err)
		return
	}

	h.logger.InfoContext(ctx, "cron: reservation-expiry done",
		"expired_count", len(expired),
		"subscriptions_touched", len(tokensBySub))

	writeJSON(w, http.StatusOK, reservationExpiryResponse{
		ExpiredCount: len(expired),
		Message:      "ok",
	})
}

// ---------- manual-period-renewal ----------

type manualRenewalResponse struct {
	RenewedCount int    `json:"renewed_count"`
	Message      string `json:"message"`
}

// handleManualPeriodRenewal — cron daily o 00:05 UTC dla MANUAL provider subs.
//
// Per spec §9.2: Stripe-driven subs są renewed przez webhook (invoice.paid).
// MANUAL subscriptions (kliniki enterprise rozliczane fakturą poza Stripe)
// nie mają takiego signaliu — cron ten odgrywa rolę webhooka.
//
// Period rolluje się o pełne 30 dni (interval '1 month' w SQL daje miesięczne
// terminy zgodne z calendar months; tu w aplikacji używamy fixed 30d żeby
// uniknąć niedeterminizmu lutowego).
//
// Idempotent: jeśli usage_counters UNIQUE constraint zatrzyma drugi insert,
// błąd jest ignorowany i sub kontynuuje.
func (h *AdminHandler) handleManualPeriodRenewal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	h.logger.InfoContext(ctx, "cron: manual-period-renewal started")

	q := db.New(h.pool)
	subs, err := q.ListExpiredManualSubscriptions(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list expired subs", err)
		return
	}

	renewedCount := 0
	for _, s := range subs {
		newStart := s.CurrentPeriodEnd
		newEnd := newStart.Add(30 * 24 * time.Hour)

		if err := h.renewOneSubscription(ctx, s.ID, newStart, newEnd, s.TokensPerPeriod); err != nil {
			// Loguj per sub ale nie przerywaj — jeden zepsuty sub nie powinien
			// zablokować renewal pozostałych.
			h.logger.ErrorContext(ctx, "manual renewal: per-sub failed",
				"sub_id", s.ID,
				"error", err)
			continue
		}
		renewedCount++
	}

	h.logger.InfoContext(ctx, "cron: manual-period-renewal done",
		"renewed_count", renewedCount,
		"candidates", len(subs))

	writeJSON(w, http.StatusOK, manualRenewalResponse{
		RenewedCount: renewedCount,
		Message:      "ok",
	})
}

func (h *AdminHandler) renewOneSubscription(ctx context.Context, subID uuid.UUID, newStart, newEnd time.Time, tokensPerPeriod int32) error {
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("tx begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := db.New(tx)

	if err := q.AcquireSubscriptionLock(ctx, subID.String()); err != nil {
		return fmt.Errorf("acquire lock: %w", err)
	}

	if err := q.ShiftSubscriptionPeriod(ctx, db.ShiftSubscriptionPeriodParams{
		ID:                 subID,
		CurrentPeriodStart: newStart,
		CurrentPeriodEnd:   newEnd,
	}); err != nil {
		return fmt.Errorf("shift period: %w", err)
	}

	if _, err := q.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
		SubscriptionID: subID,
		PeriodStart:    newStart,
		PeriodEnd:      newEnd,
		TokensLimit:    tokensPerPeriod,
	}); err != nil {
		return fmt.Errorf("create counter: %w", err)
	}

	return tx.Commit(ctx)
}

// ---------- safety-check ----------

type safetyCheckResponse struct {
	MissingCounterSubs []uuid.UUID `json:"missing_counter_subs"`
	HealedCount        int         `json:"healed_count"`
	Message            string      `json:"message"`
}

// handleSafetyCheck — weekly job. Znajduje ACTIVE/TRIALING subs bez aktywnego
// counter (oznaka stuck'a po webhookach / failed cronów) i auto-heal'uje je
// tworząc counter dla bieżącego okresu (kopiując period_start/end z subscription).
//
// Loguje listę naprawionych subs — alert w Cloud Monitoring odpala się gdy
// MissingCounterSubs > 0 (oznaka że gdzieś jest bug w renewal flow).
func (h *AdminHandler) handleSafetyCheck(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	h.logger.InfoContext(ctx, "cron: safety-check started")

	q := db.New(h.pool)
	missing, err := q.ListSubscriptionsMissingCounter(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list missing", err)
		return
	}

	healed := 0
	missingIDs := make([]uuid.UUID, 0, len(missing))
	for _, m := range missing {
		missingIDs = append(missingIDs, m.ID)
		if _, err := q.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
			SubscriptionID: m.ID,
			PeriodStart:    m.CurrentPeriodStart,
			PeriodEnd:      m.CurrentPeriodEnd,
			TokensLimit:    m.TokensPerPeriod,
		}); err != nil {
			h.logger.ErrorContext(ctx, "safety-check: heal failed",
				"sub_id", m.ID,
				"error", err)
			continue
		}
		healed++
	}

	if len(missingIDs) > 0 {
		h.logger.WarnContext(ctx, "cron: safety-check found missing counters",
			"missing_count", len(missingIDs),
			"healed_count", healed)
	}

	writeJSON(w, http.StatusOK, safetyCheckResponse{
		MissingCounterSubs: missingIDs,
		HealedCount:        healed,
		Message:            "ok",
	})
}

// ---------- helpers ----------

func writeJSON(w http.ResponseWriter, code int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, code int, msg string, err error) {
	slog.Error("admin handler error", "msg", msg, "error", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"error":   msg,
		"details": err.Error(),
	})
}

func errIsNoRows(err error) bool {
	return err == pgx.ErrNoRows
}
