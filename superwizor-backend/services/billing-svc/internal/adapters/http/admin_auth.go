// admin_auth.go — Firebase-token auth middleware for the browser-facing
// admin HTTP endpoints (/admin/crm/*).
//
// Added 2026-06-10 after the CRM endpoints were found publicly readable:
// billing-svc runs with allUsers invoker (the marketing site calls
// GetSubscription from the browser), so "Cloud Run IAM protects /admin/*"
// — the assumption the CRM handlers shipped with — was never true here.
// Every CRM route now requires a Firebase ID token that identity-svc
// resolves to role SUPERWIZOR_ADMIN, mirroring grpcadapter.
// ConnectAuthInterceptor for the Connect-RPC admin surface.
//
// FAIL-CLOSED: when identity-svc isn't wired (IDENTITY_SVC_URL unset),
// the middleware returns 503 rather than letting requests through.

package http

import (
	"log/slog"
	"net/http"
	"strings"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// AdminAuthMiddleware wraps browser-facing admin HTTP handlers with a
// Firebase-token + SUPERWIZOR_ADMIN role check.
type AdminAuthMiddleware struct {
	identity identityv1.IdentityServiceClient
	logger   *slog.Logger
}

func NewAdminAuthMiddleware(identity identityv1.IdentityServiceClient, logger *slog.Logger) *AdminAuthMiddleware {
	return &AdminAuthMiddleware{identity: identity, logger: logger}
}

// Require returns h wrapped with the auth check.
func (m *AdminAuthMiddleware) Require(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if m.identity == nil {
			// Misconfiguration must not become an open door.
			m.logger.Error("admin auth: identity-svc not wired — refusing admin HTTP request",
				"path", r.URL.Path)
			writeError(w, http.StatusServiceUnavailable, "auth backend unavailable", nil)
			return
		}
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "missing bearer token", nil)
			return
		}
		token := strings.TrimPrefix(auth, "Bearer ")

		res, err := m.identity.ValidateToken(r.Context(), &identityv1.ValidateTokenRequest{
			FirebaseIdToken: token,
		})
		if err != nil {
			writeError(w, http.StatusUnauthorized, "invalid token", nil)
			return
		}
		if res.Role != identityv1.UserRole_USER_ROLE_SUPERWIZOR_ADMIN {
			m.logger.Warn("admin auth: non-admin role rejected",
				"path", r.URL.Path, "role", res.Role.String())
			writeError(w, http.StatusForbidden, "admin role required", nil)
			return
		}
		h(w, r)
	}
}
