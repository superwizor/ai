package grpc

import (
	"context"
	"strings"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// Internal-OIDC gate for notification-svc (SECURITY #3).
//
// notification-svc runs with the Cloud Run `allUsers` invoker and had NO
// interceptor (grpc.NewServer()), so the Send* email RPCs were an open
// relay: any internet caller could drive SendInvitationEmail /
// SendContactEmail / SendActionPlanEmail etc. → arbitrary phishing emails
// from our Resend domain + an unbounded Resend cost-bomb.
//
// Who legitimately calls Send* over gRPC: only backend services
// (identity-svc, clinical-svc, billing-svc), each dialing with a Google
// OIDC id-token whose aud = notification-svc's own URL
// (idtoken.NewTokenSource(aud = NOTIFICATION_SVC_URL)). So the policy is:
//   - Send* (internal)  → require a valid OIDC token from an allow-listed
//     caller SA (email_verified), WHEN configured.
//   - everything else   → pass through unchanged. Unlike billing-svc's
//     native path, notification-svc's gRPC server IS the path Flutter uses
//     for RegisterFCMToken / RemoveFCMToken / GetUnreadCount; those already
//     verify the Firebase token inside the handler. Health is the probe.
//
// This interceptor deliberately does NOT reject unknown methods — that
// would break the FCM/unread flow. It gates exactly the Send* relay.

// idTokenValidator matches idtoken.Validate so tests inject a fake.
type idTokenValidator func(ctx context.Context, token, audience string) (*idtoken.Payload, error)

// oidcInternalMethods are the server-to-server email RPCs. All Send*
// endpoints are internal — no browser/Flutter caller reaches any of them
// directly (SendContactEmail is relayed by billing-svc's /contact handler
// over OIDC, not called from the browser).
var oidcInternalMethods = map[string]struct{}{
	"/notification.v1.NotificationService/SendInvitationEmail":   {},
	"/notification.v1.NotificationService/SendEmailVerification": {},
	"/notification.v1.NotificationService/SendQuotaWarning":      {},
	"/notification.v1.NotificationService/SendActionPlanEmail":   {},
	"/notification.v1.NotificationService/SendContactEmail":      {},
	"/notification.v1.NotificationService/SendClientPanelEvent":  {},
}

// InternalOIDCInterceptor guards the Send* relay (see file header).
//
// audience = notification-svc's own Cloud Run URL (what internal callers
// mint as the OIDC aud); allowedSAs = caller service-account emails. When
// BOTH are configured, Send* requires a valid, allow-listed OIDC token.
// When UNSET (not yet wired in terraform) Send* still runs — so this is
// safe to deploy ahead of the infra change without breaking invites/emails
// — while the wiring lands the env vars in the same PR. Fail-closed once
// configured: a missing/invalid/wrong-caller token is rejected.
func InternalOIDCInterceptor(audience string, allowedSAs map[string]struct{}, validate idTokenValidator) grpc.UnaryServerInterceptor {
	if validate == nil {
		validate = idtoken.Validate
	}
	oidcConfigured := audience != "" && len(allowedSAs) > 0
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		if _, ok := oidcInternalMethods[info.FullMethod]; !ok {
			// FCM / unread / health — leave untouched (handler-level Firebase
			// auth / Cloud Run probe).
			return handler(ctx, req)
		}
		if !oidcConfigured {
			// Transition window: env not yet set. Don't break the email
			// pipeline; the wiring in this PR sets the vars so prod enforces.
			return handler(ctx, req)
		}

		md, _ := metadata.FromIncomingContext(ctx)
		auths := md.Get("authorization")
		if len(auths) == 0 {
			return nil, status.Error(codes.Unauthenticated, "missing authorization header")
		}
		token := strings.TrimPrefix(auths[0], "Bearer ")
		payload, err := validate(ctx, token, audience)
		if err != nil {
			return nil, status.Errorf(codes.Unauthenticated, "invalid oidc token: %v", err)
		}
		email, _ := payload.Claims["email"].(string)
		verified, _ := payload.Claims["email_verified"].(bool)
		if !verified || !saAllowed(allowedSAs, email) {
			return nil, status.Errorf(codes.PermissionDenied, "caller %q not allowed", email)
		}
		return handler(ctx, req)
	}
}

func saAllowed(allowed map[string]struct{}, email string) bool {
	for sa := range allowed {
		if strings.EqualFold(strings.TrimSpace(sa), strings.TrimSpace(email)) {
			return true
		}
	}
	return false
}

// ParseAllowedSAs splits a comma-separated env value into a set of caller SA
// emails (SA emails contain no commas). Blanks are ignored. Mirrors
// billing-svc's helper of the same name.
func ParseAllowedSAs(csv string) map[string]struct{} {
	out := map[string]struct{}{}
	for _, s := range strings.Split(csv, ",") {
		if t := strings.TrimSpace(s); t != "" {
			out[t] = struct{}{}
		}
	}
	return out
}
