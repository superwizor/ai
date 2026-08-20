// Package svcauth provides server-to-server authentication for the gRPC
// methods that one backend service exposes to another inside the
// Superwizor monorepo.
//
// Why it exists: every public Cloud Run service runs with the `allUsers`
// invoker (browsers + Flutter Web call them directly), so Cloud Run IAM is
// NOT an auth gate. Internal-only RPCs — billing's quota ledger, the
// notification email senders — were therefore reachable by anyone on the
// internet. The callers already mint a Google OIDC ID token
// (`idtoken.NewTokenSource(audience = callee URL)`); this package validates
// that token at the callee and asserts the caller is one of our own service
// accounts.
//
// The strong, un-forgeable gate is the verified `email` claim: an attacker
// cannot obtain a Google-signed token whose email is e.g.
// `clinical-svc@<project>.iam.gserviceaccount.com` without controlling that
// service account. Audience is checked too when configured, as
// defense-in-depth against cross-service token replay — but it is optional
// because a single Cloud Run service can be reached under more than one URL
// form and the SA gate already restricts callers to our own infrastructure.
//
// See docs/security/SECURITY_REMEDIATION_PLAN.md §3-§4. The HTTP equivalent
// (Cloud Scheduler cron OIDC) lives in billing-svc's scheduler_auth.go; this
// is the gRPC-metadata flavour, generalized so billing-svc and
// notification-svc share one implementation.
package svcauth

import (
	"context"
	"log/slog"
	"strings"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// Policy is the auth requirement applied to a single gRPC method on a
// service's native-gRPC (application/grpc) path.
type Policy int

const (
	// PolicyDeny rejects the method on this transport. Used for admin RPCs
	// that must only be reachable via the browser Connect path with a
	// Firebase token — never as a raw server-to-server gRPC call (closes the
	// `x-superwizor-role`-spoofing privilege escalation).
	PolicyDeny Policy = iota
	// PolicyOIDCInternal requires a Google OIDC ID token minted by one of the
	// allowlisted service accounts.
	PolicyOIDCInternal
	// PolicyPassthrough runs the handler without interceptor-level auth — the
	// handler authenticates itself (e.g. notification-svc FCM RPCs call their
	// own authenticate()) or the method is non-sensitive.
	PolicyPassthrough
)

// validateFunc matches idtoken.Validate so tests can inject a fake.
type validateFunc func(ctx context.Context, token, audience string) (*idtoken.Payload, error)

// OIDCValidator validates a Google-signed OIDC ID token taken from gRPC
// metadata and asserts the caller is one of our own service accounts.
//
// Fail-closed: when no SA allowlist is configured, Check denies everything.
type OIDCValidator struct {
	allowedSAs       map[string]struct{} // verified `email` claim must be in this set (mandatory)
	allowedAudiences map[string]struct{} // optional: if non-empty, `aud` must be in this set
	validate         validateFunc        // idtoken.Validate; swappable in tests
}

// NewOIDCValidator builds a validator. allowedSAs is the mandatory gate
// (caller service-account emails). allowedAudiences is optional
// defense-in-depth (the callee's Cloud Run URL(s)); pass nil/empty to skip
// the audience check and rely on the SA gate alone.
func NewOIDCValidator(allowedSAs, allowedAudiences []string) *OIDCValidator {
	return &OIDCValidator{
		allowedSAs:       toLowerSet(allowedSAs),
		allowedAudiences: toSet(allowedAudiences),
		validate:         idtoken.Validate,
	}
}

// Configured reports whether the mandatory SA allowlist is set.
func (v *OIDCValidator) Configured() bool { return len(v.allowedSAs) > 0 }

// Check validates the OIDC token in ctx's gRPC metadata. Returns a gRPC
// status error (Unauthenticated / PermissionDenied) on any failure.
func (v *OIDCValidator) Check(ctx context.Context) error {
	if !v.Configured() {
		// Misconfiguration must not become an open door.
		return status.Error(codes.Unauthenticated, "internal auth not configured")
	}
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return status.Error(codes.Unauthenticated, "missing metadata")
	}
	auths := md.Get("authorization")
	if len(auths) == 0 {
		return status.Error(codes.Unauthenticated, "missing authorization")
	}
	token := strings.TrimPrefix(auths[0], "Bearer ")

	// audience "" => idtoken validates signature/expiry/issuer but skips the
	// aud claim; we check aud ourselves against the allowlist so multiple
	// Cloud Run URL forms for the same service all pass.
	payload, err := v.validate(ctx, token, "")
	if err != nil {
		return status.Errorf(codes.Unauthenticated, "invalid oidc token: %v", err)
	}
	email, _ := payload.Claims["email"].(string)
	verified, _ := payload.Claims["email_verified"].(bool)
	if !verified || !inLowerSet(v.allowedSAs, email) {
		return status.Errorf(codes.PermissionDenied, "caller %q is not an allowed service account", email)
	}
	if len(v.allowedAudiences) > 0 {
		if _, ok := v.allowedAudiences[payload.Audience]; !ok {
			return status.Errorf(codes.PermissionDenied, "token audience %q not allowed", payload.Audience)
		}
	}
	return nil
}

// InternalAuthUnaryInterceptor returns a unary interceptor that applies the
// per-method policy. Methods absent from the map are denied (fail-closed),
// except gRPC infrastructure methods (health / reflection) which always pass
// through so probes and tooling keep working.
func InternalAuthUnaryInterceptor(v *OIDCValidator, policies map[string]Policy, logger *slog.Logger) grpc.UnaryServerInterceptor {
	if logger == nil {
		logger = slog.Default()
	}
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		if isInfraMethod(info.FullMethod) {
			return handler(ctx, req)
		}
		switch policies[info.FullMethod] {
		case PolicyPassthrough:
			return handler(ctx, req)
		case PolicyOIDCInternal:
			if err := v.Check(ctx); err != nil {
				logger.WarnContext(ctx, "svcauth: internal RPC denied",
					"method", info.FullMethod, "error", err)
				return nil, err
			}
			return handler(ctx, req)
		case PolicyDeny:
			logger.WarnContext(ctx, "svcauth: method not available on native gRPC transport",
				"method", info.FullMethod)
			return nil, status.Error(codes.Unauthenticated, "method not available on this transport")
		default:
			// Unlisted service method — fail closed.
			logger.WarnContext(ctx, "svcauth: unlisted method denied (no policy)",
				"method", info.FullMethod)
			return nil, status.Error(codes.Unauthenticated, "method not permitted")
		}
	}
}

// isInfraMethod reports whether a gRPC FullMethod is a transport/infra
// method (health checks, server reflection) rather than an application RPC.
// These always pass the interceptor so Cloud Run probes and grpcurl work.
func isInfraMethod(fullMethod string) bool {
	return strings.HasPrefix(fullMethod, "/grpc.health.") ||
		strings.HasPrefix(fullMethod, "/grpc.reflection.")
}

func toSet(items []string) map[string]struct{} {
	if len(items) == 0 {
		return nil
	}
	m := make(map[string]struct{}, len(items))
	for _, it := range items {
		it = strings.TrimSpace(it)
		if it != "" {
			m[it] = struct{}{}
		}
	}
	return m
}

func toLowerSet(items []string) map[string]struct{} {
	if len(items) == 0 {
		return nil
	}
	m := make(map[string]struct{}, len(items))
	for _, it := range items {
		it = strings.ToLower(strings.TrimSpace(it))
		if it != "" {
			m[it] = struct{}{}
		}
	}
	return m
}

func inLowerSet(set map[string]struct{}, v string) bool {
	_, ok := set[strings.ToLower(strings.TrimSpace(v))]
	return ok
}
