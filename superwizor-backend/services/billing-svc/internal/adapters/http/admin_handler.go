// Package http — endpointy HTTP obok gRPC servera billing-svc.
//
// Cele:
//   - /admin/reservation-expiry — cron co 5 min: EXPIRED stale reservations.
//   - /admin/manual-period-renewal — cron daily: rolluje okres dla MANUAL subs.
//   - /admin/safety-check — cron weekly: alert jeśli są subscriptions bez counter.
//   - /stripe/webhook — STUB (slice 2 da real implementację).
//
// Auth: Cloud Scheduler woła te endpointy z OIDC tokenem podpisanym przez
// dedykowane SA. Cloud Run frontend NIE waliduje tokenu (billing-svc ma
// allUsers invoker dla browser-facing GetSubscription), więc walidacja
// dzieje się w aplikacji — SchedulerAuthMiddleware (scheduler_auth.go)
// sprawdza Google ID token + email SA na każdym cron route.
package http

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sort"
	"strconv"
	"strings"
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
//
// billing-svc is publicly invokable (allUsers invoker), so route-level
// auth is the only gate. The browser-facing CRM list goes through the
// SUPERWIZOR_ADMIN Firebase-token middleware; the five cron endpoints go
// through the Google OIDC middleware (schedAuth) that validates the
// Cloud Scheduler SA's ID token in-process — Cloud Run IAM never checks
// it here. See scheduler_auth.go for the 2026-06-10 exposure writeup.
func (h *AdminHandler) RegisterRoutes(mux *http.ServeMux, auth *AdminAuthMiddleware, schedAuth *SchedulerAuthMiddleware) {
	mux.HandleFunc("POST /admin/reservation-expiry", schedAuth.Require(h.handleReservationExpiry))
	mux.HandleFunc("POST /admin/manual-period-renewal", schedAuth.Require(h.handleManualPeriodRenewal))
	mux.HandleFunc("POST /admin/safety-check", schedAuth.Require(h.handleSafetyCheck))
	mux.HandleFunc("POST /admin/email-drip", schedAuth.Require(h.handleEmailDrip))
	mux.HandleFunc("POST /admin/renewal-reminders", schedAuth.Require(h.handleRenewalReminders))
	mux.HandleFunc("GET /admin/crm/subscribers", auth.Require(h.handleCRMSubscribers))
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
	// nil err is legal (validation / auth failures have no wrapped
	// error) — several CRM call sites pass nil; err.Error() on nil
	// panicked the whole handler before 2026-06-10.
	details := ""
	if err != nil {
		details = err.Error()
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"error":   msg,
		"details": details,
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

// ---------- CRM subscribers ----------

// CRMSubscriber — enriched user + subscription view for Marcin's CRM panel.
type CRMSubscriber struct {
	UserID            string  `json:"user_id"`
	FirstName         string  `json:"first_name"`
	LastName          string  `json:"last_name"`
	Email             string  `json:"email"`
	Phone             string  `json:"phone"`
	ProfessionalTitle string  `json:"professional_title"`
	CreatedAt         string  `json:"created_at"`
	// Subscription
	SubscriptionID    string  `json:"subscription_id"`
	PlanTier          string  `json:"plan_tier"`
	PlanDisplayName   string  `json:"plan_display_name"`
	SubStatus         string  `json:"sub_status"`
	Provider          string  `json:"provider"`
	PeriodStart       string  `json:"period_start"`
	PeriodEnd         string  `json:"period_end"`
	DaysUntilRenewal  int     `json:"days_until_renewal"`
	// Usage
	TokensLimit       int32   `json:"tokens_limit"`
	TokensUsed        int32   `json:"tokens_used"`
	TokensRemaining   int32   `json:"tokens_remaining"`
	UsagePct          float64 `json:"usage_pct"`
	// Sessions (all-time from sessions table)
	TotalSessions     int32   `json:"total_sessions"`
	// Last activity
	LastSessionAt     string  `json:"last_session_at"`
	// Urgency flags
	CreditAlert       string  `json:"credit_alert"` // "critical" (≤1), "warning" (≤3), "low" (≤5), ""
	ExpiryAlert       string  `json:"expiry_alert"` // "imminent" (≤3d), "soon" (≤7d), ""
	UrgencyScore      int     `json:"urgency_score"` // higher = more urgent (for sorting)
	// Organization
	OrgID             string  `json:"org_id"`
	OrgName           string  `json:"org_name"`
}

// CRMGlobalStats — aggregate stats across the entire subscriber base (unfiltered).
type CRMGlobalStats struct {
	Total    int `json:"total"`
	Critical int `json:"critical"`
	Warning  int `json:"warning"`
	Expiring int `json:"expiring"`
	Churned  int `json:"churned"`
}

type crmResponse struct {
	Subscribers []CRMSubscriber `json:"subscribers"`
	Total       int             `json:"total"`
	TotalAll    int             `json:"total_all"`
	Page        int             `json:"page"`
	PerPage     int             `json:"per_page"`
	GlobalStats CRMGlobalStats  `json:"global_stats"`
	Message     string          `json:"message"`
}

// handleCRMSubscribers — GET /admin/crm/subscribers
//
// Returns enriched subscriber data for Marcin's CRM panel. Supports:
//
//	?tier=BETA|TRIAL|SOLO|PRO|CLINIC — filter by plan tier
//	?status=ACTIVE|CANCELED|TRIALING — filter by sub status
//	?alert=critical|warning — filter only users needing attention
//
// Sorted by urgency score by default (most critical first).
func (h *AdminHandler) handleCRMSubscribers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	h.logger.InfoContext(ctx, "crm: subscribers list requested")

	tierFilter := r.URL.Query().Get("tier")
	statusFilter := r.URL.Query().Get("status")
	alertFilter := r.URL.Query().Get("alert")
	searchFilter := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("search")))

	// Pagination params
	page := 1
	perPage := 25
	if p := r.URL.Query().Get("page"); p != "" {
		if v, err := strconv.Atoi(p); err == nil && v > 0 {
			page = v
		}
	}
	if pp := r.URL.Query().Get("per_page"); pp != "" {
		if v, err := strconv.Atoi(pp); err == nil && v > 0 && v <= 100 {
			perPage = v
		}
	}

	// ── Global stats (unfiltered, for KPI chips) ──
	var globalStats CRMGlobalStats
	_ = h.pool.QueryRow(ctx, `
		SELECT
			COUNT(*) AS total,
			COUNT(*) FILTER (WHERE GREATEST(0, COALESCE(uc.tokens_limit, p.tokens_per_period, 0) - COALESCE(uc.tokens_used, 0)) <= 1 AND COALESCE(uc.tokens_limit, p.tokens_per_period, 0) > 0) AS critical,
			COUNT(*) FILTER (WHERE GREATEST(0, COALESCE(uc.tokens_limit, p.tokens_per_period, 0) - COALESCE(uc.tokens_used, 0)) BETWEEN 2 AND 3 AND COALESCE(uc.tokens_limit, p.tokens_per_period, 0) > 0) AS warning,
			COUNT(*) FILTER (WHERE COALESCE(EXTRACT(DAY FROM s.current_period_end - now())::int, 999) <= 3) AS expiring,
			COUNT(*) FILTER (WHERE s.status = 'CANCELED') AS churned
		FROM subscriptions s
		JOIN subscription_plans p ON p.id = s.plan_id
		JOIN organizations o ON o.id = s.organization_id
		JOIN users u ON u.organization_id = o.id
		LEFT JOIN usage_counters uc ON uc.subscription_id = s.id
			AND uc.period_start = s.current_period_start
		LEFT JOIN crm_excluded_users ex ON ex.user_id = u.id
		WHERE s.status IN ('ACTIVE', 'TRIALING', 'PAST_DUE', 'CANCELED')
		  AND ex.user_id IS NULL
		  AND u.email NOT LIKE '%@example.com'
		  AND u.email NOT LIKE '%@superwizor.test'
		  AND u.email NOT LIKE '%@test.pl'
	`).Scan(&globalStats.Total, &globalStats.Critical, &globalStats.Warning, &globalStats.Expiring, &globalStats.Churned)

	// ── Main subscriber query (with last_session_at + fixed days_until_renewal) ──
	rows, err := h.pool.Query(ctx, `
		SELECT
			u.id AS user_id,
			COALESCE(u.first_name, '') AS first_name,
			COALESCE(u.last_name, '') AS last_name,
			COALESCE(u.email, '') AS email,
			COALESCE(u.phone_number, '') AS phone,
			COALESCE(u.professional_title, '') AS professional_title,
			u.created_at AS user_created_at,

			s.id AS sub_id,
			COALESCE(p.tier::text, '') AS plan_tier,
			COALESCE(p.display_name, p.tier::text) AS plan_display_name,
			COALESCE(s.status::text, '') AS sub_status,
			COALESCE(s.provider::text, '') AS provider,
			s.current_period_start,
			s.current_period_end,
			COALESCE(EXTRACT(DAY FROM s.current_period_end - now())::int, 0) AS days_until_renewal,

			COALESCE(uc.tokens_limit, p.tokens_per_period, 0) AS tokens_limit,
			COALESCE(uc.tokens_used, 0) AS tokens_used,
			GREATEST(0, COALESCE(uc.tokens_limit, p.tokens_per_period, 0) - COALESCE(uc.tokens_used, 0)) AS tokens_remaining,

			COALESCE(sess_count.cnt, 0) AS total_sessions,
			last_sess.last_session_at,

			o.id AS org_id,
			COALESCE(o.legal_name, '') AS org_name
		FROM subscriptions s
		JOIN subscription_plans p ON p.id = s.plan_id
		JOIN organizations o ON o.id = s.organization_id
		JOIN users u ON u.organization_id = o.id
		LEFT JOIN usage_counters uc ON uc.subscription_id = s.id
			AND uc.period_start = s.current_period_start
		LEFT JOIN LATERAL (
			SELECT COUNT(*)::int AS cnt
			FROM sessions sess
			WHERE sess.therapist_id = u.id
		) sess_count ON true
		LEFT JOIN LATERAL (
			SELECT MAX(created_at) AS last_session_at
			FROM sessions sess2
			WHERE sess2.therapist_id = u.id
		) last_sess ON true
		LEFT JOIN crm_excluded_users ex ON ex.user_id = u.id
		WHERE s.status IN ('ACTIVE', 'TRIALING', 'PAST_DUE', 'CANCELED')
		  AND ex.user_id IS NULL
		  AND u.email NOT LIKE '%@example.com'
		  AND u.email NOT LIKE '%@superwizor.test'
		  AND u.email NOT LIKE '%@test.pl'
		ORDER BY s.current_period_end ASC
		LIMIT 500
	`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "crm query", err)
		return
	}
	defer rows.Close()

	var allSubscribers []CRMSubscriber
	for rows.Next() {
		var sub CRMSubscriber
		var periodStart, periodEnd, userCreated time.Time
		var lastSessionAt *time.Time
		var daysUntilRenewal int
		var tokensLimit, tokensUsed, tokensRemaining, totalSessions int32

		if err := rows.Scan(
			&sub.UserID, &sub.FirstName, &sub.LastName, &sub.Email, &sub.Phone,
			&sub.ProfessionalTitle, &userCreated,
			&sub.SubscriptionID, &sub.PlanTier, &sub.PlanDisplayName,
			&sub.SubStatus, &sub.Provider,
			&periodStart, &periodEnd, &daysUntilRenewal,
			&tokensLimit, &tokensUsed, &tokensRemaining,
			&totalSessions,
			&lastSessionAt,
			&sub.OrgID, &sub.OrgName,
		); err != nil {
			h.logger.ErrorContext(ctx, "crm: scan row", "error", err)
			continue
		}

		sub.CreatedAt = userCreated.Format("2006-01-02")
		sub.PeriodStart = periodStart.Format("2006-01-02")
		if !periodEnd.IsZero() && periodEnd.Year() > 2000 {
			sub.PeriodEnd = periodEnd.Format("2006-01-02")
			sub.DaysUntilRenewal = daysUntilRenewal
		}
		if lastSessionAt != nil && !lastSessionAt.IsZero() {
			sub.LastSessionAt = lastSessionAt.Format("2006-01-02")
		}
		sub.TokensLimit = tokensLimit
		sub.TokensUsed = tokensUsed
		sub.TokensRemaining = tokensRemaining
		sub.TotalSessions = totalSessions
		if tokensLimit > 0 {
			sub.UsagePct = float64(tokensUsed) / float64(tokensLimit) * 100
		}

		// Credit alerts
		urgency := 0
		switch {
		case tokensRemaining <= 1 && tokensLimit > 0:
			sub.CreditAlert = "critical"
			urgency += 30
		case tokensRemaining <= 3 && tokensLimit > 0:
			sub.CreditAlert = "warning"
			urgency += 20
		case tokensRemaining <= 5 && tokensLimit > 0:
			sub.CreditAlert = "low"
			urgency += 10
		}

		// Expiry alerts — only for valid period_end
		if sub.PeriodEnd != "" {
			switch {
			case daysUntilRenewal <= 3:
				sub.ExpiryAlert = "imminent"
				urgency += 15
			case daysUntilRenewal <= 7:
				sub.ExpiryAlert = "soon"
				urgency += 5
			}
		}

		// Boost urgency for churned users
		if sub.SubStatus == "CANCELED" {
			urgency += 25
		}
		sub.UrgencyScore = urgency

		// Apply filters
		if tierFilter != "" && sub.PlanTier != tierFilter {
			continue
		}
		if statusFilter != "" && sub.SubStatus != statusFilter {
			continue
		}
		if alertFilter == "critical" && sub.CreditAlert != "critical" {
			continue
		}
		if alertFilter == "warning" && sub.CreditAlert != "critical" && sub.CreditAlert != "warning" {
			continue
		}

		// Server-side text search (P2.4 fix — search must run before
		// pagination so totalFiltered reflects the real count)
		if searchFilter != "" {
			nameMatch := strings.Contains(strings.ToLower(sub.FirstName), searchFilter) ||
				strings.Contains(strings.ToLower(sub.LastName), searchFilter) ||
				strings.Contains(strings.ToLower(sub.Email), searchFilter) ||
				strings.Contains(strings.ToLower(sub.OrgName), searchFilter) ||
				strings.Contains(strings.ToLower(sub.Phone), searchFilter)
			if !nameMatch {
				continue
			}
		}

		allSubscribers = append(allSubscribers, sub)
	}

	// Sort by urgency score (highest first)
	sort.Slice(allSubscribers, func(i, j int) bool {
		return allSubscribers[i].UrgencyScore > allSubscribers[j].UrgencyScore
	})

	// Paginate
	totalFiltered := len(allSubscribers)
	start := (page - 1) * perPage
	if start > totalFiltered {
		start = totalFiltered
	}
	end := start + perPage
	if end > totalFiltered {
		end = totalFiltered
	}
	pageSubscribers := allSubscribers[start:end]

	writeJSON(w, http.StatusOK, crmResponse{
		Subscribers: pageSubscribers,
		Total:       totalFiltered,
		TotalAll:    globalStats.Total,
		Page:        page,
		PerPage:     perPage,
		GlobalStats: globalStats,
		Message:     "ok",
	})
}

