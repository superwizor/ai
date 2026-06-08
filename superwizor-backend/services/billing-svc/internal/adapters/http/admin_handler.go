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
	mux.HandleFunc("POST /admin/email-drip", h.handleEmailDrip)
	mux.HandleFunc("POST /admin/renewal-reminders", h.handleRenewalReminders)
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
	expiredBeta := 0
	for _, s := range subs {
		// BETA plan guard: max 2 periods (2 × 30 days). Count existing
		// usage_counters for this subscription — if ≥2, cancel instead
		// of renewing. The counter count == number of completed periods.
		periodCount, err := h.countPeriods(ctx, s.ID)
		if err != nil {
			h.logger.ErrorContext(ctx, "manual renewal: count periods failed",
				"sub_id", s.ID, "error", err)
			continue
		}

		// Check if this is a BETA plan by looking at the provider_subscription_id
		// prefix (set during provisionPlanOrgAndSub as "beta-<orgID>").
		isBeta := h.isBetaSubscription(ctx, s.ID)
		if isBeta && periodCount >= 2 {
			// Beta expired — downgrade to CANCELED
			if err := h.cancelSubscription(ctx, s.ID); err != nil {
				h.logger.ErrorContext(ctx, "manual renewal: beta cancel failed",
					"sub_id", s.ID, "error", err)
			} else {
				expiredBeta++
				h.logger.InfoContext(ctx, "cron: beta subscription expired after 2 periods",
					"sub_id", s.ID, "org_id", s.OrganizationID, "periods_used", periodCount)
			}
			continue
		}

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
		"expired_beta", expiredBeta,
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

// ─── Beta-specific helpers ────────────────────────────────────

// countPeriods returns the number of usage_counter rows for a subscription.
// Each row represents one billing period (30 days).
func (h *AdminHandler) countPeriods(ctx context.Context, subID uuid.UUID) (int, error) {
	var count int
	err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM usage_counters WHERE subscription_id = $1`, subID,
	).Scan(&count)
	return count, err
}

// isBetaSubscription checks if the subscription belongs to a BETA plan
// by looking at the plan tier (via JOIN).
func (h *AdminHandler) isBetaSubscription(ctx context.Context, subID uuid.UUID) bool {
	var tier string
	err := h.pool.QueryRow(ctx,
		`SELECT p.tier FROM subscriptions s
		 JOIN subscription_plans p ON p.id = s.plan_id
		 WHERE s.id = $1`, subID,
	).Scan(&tier)
	return err == nil && tier == "BETA"
}

// cancelSubscription sets a subscription status to CANCELED.
func (h *AdminHandler) cancelSubscription(ctx context.Context, subID uuid.UUID) error {
	_, err := h.pool.Exec(ctx,
		`UPDATE subscriptions SET status = 'CANCELED', updated_at = now() WHERE id = $1`, subID,
	)
	return err
}

// ---------- email-drip ----------

type emailDripResponse struct {
	TrialExhausted int `json:"trial_exhausted"`
	FollowUp1      int `json:"followup_1"`
	FollowUp2      int `json:"followup_2"`
	BetaExpiry     int `json:"beta_expiry"`
	Message        string `json:"message"`
}

// handleEmailDrip — daily cron (09:00 CET) for lifecycle email drip campaign.
//
// Queries:
//   1. Trial exhausted: TRIALING subs where tokens_used >= tokens_per_period
//      AND no "trial_exhausted" email sent yet (tracked via email_drip_log).
//   2. Follow-up 1: 3 days after trial_exhausted email was sent, no followup_1 sent.
//   3. Follow-up 2: 7 days after trial_exhausted email was sent, no followup_2 sent.
//   4. Beta expiry: BETA subs with period_end within 3 days, no alert sent.
//
// Each match inserts a row into email_drip_log (idempotent: UNIQUE on
// (user_id, template_name, subscription_id)) and publishes to
// notification-svc for actual delivery.
//
// NOTE: email_drip_log table must be created via migration before this
// handler is useful. Until then, this endpoint identifies candidates
// and logs them for manual follow-up.
func (h *AdminHandler) handleEmailDrip(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	h.logger.InfoContext(ctx, "cron: email-drip started")

	result := emailDripResponse{Message: "ok"}

	// --- 1. Trial exhausted ---
	rows1, err := h.pool.Query(ctx, `
		SELECT u.id, u.email, u.first_name, s.id AS sub_id
		FROM subscriptions s
		JOIN subscription_plans p ON p.id = s.plan_id
		JOIN organizations o ON o.id = s.organization_id
		JOIN users u ON u.organization_id = o.id
		JOIN usage_counters uc ON uc.subscription_id = s.id
		  AND uc.period_start = s.current_period_start
		WHERE p.tier = 'TRIAL'
		  AND s.status IN ('ACTIVE', 'TRIALING')
		  AND uc.tokens_used >= p.tokens_per_period
		  AND NOT EXISTS (
		    SELECT 1 FROM email_drip_log edl
		    WHERE edl.user_id = u.id
		      AND edl.template_name = 'trial_exhausted'
		      AND edl.subscription_id = s.id
		  )
		LIMIT 100
	`)
	if err != nil {
		h.logger.WarnContext(ctx, "email-drip: trial_exhausted query failed (table may not exist yet)", "error", err)
	} else {
		defer rows1.Close()
		for rows1.Next() {
			var userID, email, firstName string
			var subID uuid.UUID
			if err := rows1.Scan(&userID, &email, &firstName, &subID); err != nil {
				h.logger.ErrorContext(ctx, "email-drip: scan trial_exhausted", "error", err)
				continue
			}
			h.logger.InfoContext(ctx, "email-drip: trial_exhausted candidate",
				"user_id", userID, "email", email, "sub_id", subID)
			// TODO: publish to notification-svc Pub/Sub topic
			// TODO: INSERT INTO email_drip_log (user_id, template_name, subscription_id)
			result.TrialExhausted++
		}
	}

	// --- 2. Follow-up 1 (3 days after trial_exhausted) ---
	rows2, err := h.pool.Query(ctx, `
		SELECT edl.user_id, u.email, u.first_name, edl.subscription_id
		FROM email_drip_log edl
		JOIN users u ON u.id::text = edl.user_id
		WHERE edl.template_name = 'trial_exhausted'
		  AND edl.sent_at < now() - interval '3 days'
		  AND NOT EXISTS (
		    SELECT 1 FROM email_drip_log edl2
		    WHERE edl2.user_id = edl.user_id
		      AND edl2.template_name = 'followup_1'
		      AND edl2.subscription_id = edl.subscription_id
		  )
		LIMIT 100
	`)
	if err != nil {
		h.logger.WarnContext(ctx, "email-drip: followup_1 query failed", "error", err)
	} else {
		defer rows2.Close()
		for rows2.Next() {
			var userID, email, firstName string
			var subID uuid.UUID
			if err := rows2.Scan(&userID, &email, &firstName, &subID); err != nil {
				continue
			}
			h.logger.InfoContext(ctx, "email-drip: followup_1 candidate",
				"user_id", userID, "email", email)
			result.FollowUp1++
		}
	}

	// --- 3. Follow-up 2 (7 days after trial_exhausted) ---
	rows3, err := h.pool.Query(ctx, `
		SELECT edl.user_id, u.email, u.first_name, edl.subscription_id
		FROM email_drip_log edl
		JOIN users u ON u.id::text = edl.user_id
		WHERE edl.template_name = 'trial_exhausted'
		  AND edl.sent_at < now() - interval '7 days'
		  AND NOT EXISTS (
		    SELECT 1 FROM email_drip_log edl2
		    WHERE edl2.user_id = edl.user_id
		      AND edl2.template_name = 'followup_2'
		      AND edl2.subscription_id = edl.subscription_id
		  )
		LIMIT 100
	`)
	if err != nil {
		h.logger.WarnContext(ctx, "email-drip: followup_2 query failed", "error", err)
	} else {
		defer rows3.Close()
		for rows3.Next() {
			var userID, email, firstName string
			var subID uuid.UUID
			if err := rows3.Scan(&userID, &email, &firstName, &subID); err != nil {
				continue
			}
			h.logger.InfoContext(ctx, "email-drip: followup_2 candidate",
				"user_id", userID, "email", email)
			result.FollowUp2++
		}
	}

	// --- 4. Beta expiry alert (3 days before period_end) ---
	rows4, err := h.pool.Query(ctx, `
		SELECT u.id, u.email, u.first_name, u.last_name,
		       o.display_name AS org_name, s.id AS sub_id,
		       s.current_period_end,
		       uc.tokens_used, p.tokens_per_period
		FROM subscriptions s
		JOIN subscription_plans p ON p.id = s.plan_id
		JOIN organizations o ON o.id = s.organization_id
		JOIN users u ON u.organization_id = o.id
		LEFT JOIN usage_counters uc ON uc.subscription_id = s.id
		  AND uc.period_start = s.current_period_start
		WHERE p.tier = 'BETA'
		  AND s.status IN ('ACTIVE', 'TRIALING')
		  AND s.current_period_end BETWEEN now() AND now() + interval '3 days'
		  AND NOT EXISTS (
		    SELECT 1 FROM email_drip_log edl
		    WHERE edl.user_id = u.id::text
		      AND edl.template_name = 'beta_expiry_alert'
		      AND edl.subscription_id = s.id
		  )
		LIMIT 50
	`)
	if err != nil {
		h.logger.WarnContext(ctx, "email-drip: beta_expiry query failed", "error", err)
	} else {
		defer rows4.Close()
		for rows4.Next() {
			var userID, email, firstName, lastName, orgName string
			var subID uuid.UUID
			var periodEnd time.Time
			var tokensUsed, tokensPerPeriod int32
			if err := rows4.Scan(&userID, &email, &firstName, &lastName, &orgName, &subID, &periodEnd, &tokensUsed, &tokensPerPeriod); err != nil {
				continue
			}
			h.logger.InfoContext(ctx, "email-drip: beta_expiry_alert candidate",
				"user", fmt.Sprintf("%s %s", firstName, lastName),
				"email", email, "org", orgName,
				"period_end", periodEnd.Format("2006-01-02"))
			result.BetaExpiry++
		}
	}

	h.logger.InfoContext(ctx, "cron: email-drip done",
		"trial_exhausted", result.TrialExhausted,
		"followup_1", result.FollowUp1,
		"followup_2", result.FollowUp2,
		"beta_expiry", result.BetaExpiry)

	writeJSON(w, http.StatusOK, result)
}

// ---------- renewal-reminders ----------

type renewalReminderResponse struct {
	ReminderCount int    `json:"reminder_count"`
	Message       string `json:"message"`
}

// handleRenewalReminders — daily cron: find ACTIVE paid subs with period_end
// within 3 days and send renewal_reminder email (once per period).
func (h *AdminHandler) handleRenewalReminders(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	h.logger.InfoContext(ctx, "cron: renewal-reminders started")

	rows, err := h.pool.Query(ctx, `
		SELECT u.id, u.email, u.first_name,
		       p.display_name AS plan_name, p.tokens_per_period,
		       s.current_period_end, s.id AS sub_id
		FROM subscriptions s
		JOIN subscription_plans p ON p.id = s.plan_id
		JOIN organizations o ON o.id = s.organization_id
		JOIN users u ON u.organization_id = o.id
		WHERE s.status = 'ACTIVE'
		  AND s.provider = 'STRIPE'
		  AND s.current_period_end BETWEEN now() AND now() + interval '3 days'
		  AND NOT EXISTS (
		    SELECT 1 FROM email_drip_log edl
		    WHERE edl.user_id = u.id::text
		      AND edl.template_name = 'renewal_reminder'
		      AND edl.subscription_id = s.id
		  )
		LIMIT 100
	`)
	if err != nil {
		h.logger.WarnContext(ctx, "renewal-reminders: query failed", "error", err)
		writeJSON(w, http.StatusOK, renewalReminderResponse{Message: "query_failed"})
		return
	}
	defer rows.Close()

	count := 0
	for rows.Next() {
		var userID, email, firstName, planName string
		var tokensPerPeriod int32
		var periodEnd time.Time
		var subID uuid.UUID
		if err := rows.Scan(&userID, &email, &firstName, &planName, &tokensPerPeriod, &periodEnd, &subID); err != nil {
			continue
		}
		h.logger.InfoContext(ctx, "renewal-reminder candidate",
			"user_id", userID, "email", email, "plan", planName,
			"period_end", periodEnd.Format("2006-01-02"))
		count++
	}

	h.logger.InfoContext(ctx, "cron: renewal-reminders done", "count", count)
	writeJSON(w, http.StatusOK, renewalReminderResponse{
		ReminderCount: count,
		Message:       "ok",
	})
}

