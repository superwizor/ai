// scheduler_auth.go — Google OIDC token auth middleware for the Cloud
// Scheduler cron endpoints (/admin/reservation-expiry, /admin/manual-period-
// renewal, /admin/safety-check, /admin/email-drip, /admin/renewal-reminders).
//
// Added 2026-06-10 as the second half of the CRM exposure fix (119afdf):
// billing-svc runs with allUsers invoker (the marketing site calls
// GetSubscription from the browser — see docs/agents/11_web_deploy_invoker_drift.md),
// so Cloud Run IAM never validated the Cloud Scheduler OIDC token and the
// cron endpoints were publicly callable. This middleware validates the
// Google-signed ID token in-process instead:
//
//  1. idtoken.Validate checks signature (Google certs), expiry, issuer,
//     and that `aud` equals the billing-svc Cloud Run URL — the audience
//     the scheduler jobs are configured to mint (infra/environments/
//     staging/billing_crons.tf).
//  2. The email claim must equal the cloud-scheduler-billing SA
//     (service-accounts.tf "Cloud Scheduler → billing-svc HTTP crons")
//     and be marked verified.
//
// FAIL-CLOSED: when audience or allowed SA email is not configured
// (SCHEDULER_OIDC_AUDIENCE / SCHEDULER_SA_EMAIL unset), requests get 503
// rather than passing through — mirrors AdminAuthMiddleware.

package http

import (
	"context"
	"log/slog"
	"net/http"
	"strings"

	"google.golang.org/api/idtoken"
)

// idTokenValidator matches idtoken.Validate so tests can inject a fake.
type idTokenValidator func(ctx context.Context, token, audience string) (*idtoken.Payload, error)

// SchedulerAuthMiddleware wraps the Cloud Scheduler cron HTTP handlers
// with a Google OIDC ID-token check.
type SchedulerAuthMiddleware struct {
	validate     idTokenValidator
	audience     string // billing-svc Cloud Run URL — the `aud` the scheduler jobs mint
	allowedEmail string // cloud-scheduler-billing@<project>.iam.gserviceaccount.com
	logger       *slog.Logger
}

func NewSchedulerAuthMiddleware(audience, allowedEmail string, logger *slog.Logger) *SchedulerAuthMiddleware {
	if logger == nil {
		logger = slog.Default()
	}
	return &SchedulerAuthMiddleware{
		validate:     idtoken.Validate,
		audience:     audience,
		allowedEmail: allowedEmail,
		logger:       logger,
	}
}

// Require returns h wrapped with the OIDC check.
func (m *SchedulerAuthMiddleware) Require(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if m.audience == "" || m.allowedEmail == "" {
			// Misconfiguration must not become an open door.
			m.logger.Error("scheduler auth: audience or SA email not configured — refusing cron request",
				"path", r.URL.Path)
			writeError(w, http.StatusServiceUnavailable, "scheduler auth not configured", nil)
			return
		}
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "missing bearer token", nil)
			return
		}
		token := strings.TrimPrefix(auth, "Bearer ")

		payload, err := m.validate(r.Context(), token, m.audience)
		if err != nil {
			m.logger.Warn("scheduler auth: token validation failed",
				"path", r.URL.Path, "error", err)
			writeError(w, http.StatusUnauthorized, "invalid token", nil)
			return
		}

		email, _ := payload.Claims["email"].(string)
		emailVerified, _ := payload.Claims["email_verified"].(bool)
		if !emailVerified || !strings.EqualFold(email, m.allowedEmail) {
			m.logger.Warn("scheduler auth: caller is not the scheduler SA",
				"path", r.URL.Path, "email", email, "email_verified", emailVerified)
			writeError(w, http.StatusForbidden, "caller not authorized", nil)
			return
		}

		h(w, r)
	}
}
