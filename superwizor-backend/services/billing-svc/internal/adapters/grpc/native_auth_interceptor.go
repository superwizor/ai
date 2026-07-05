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

// Native-gRPC auth for billing-svc (security #2 / #9).
//
// billing-svc runs with the Cloud Run `allUsers` invoker, and its native
// gRPC path (`application/grpc` → gs.ServeHTTP) had NO interceptor — so an
// anonymous internet caller could invoke Admin* RPCs with a forged
// `x-superwizor-role: SUPERWIZOR_ADMIN` header (resolveAdminCaller trusts
// metadata). The Connect path is guarded; the native path was not.
//
// Who actually calls billing over native gRPC: only backend services
// (clinical-svc, ingestion-svc, stt-worker) invoking the quota ledger +
// GetSubscription, authenticated by a Google OIDC id-token. Browsers use
// Connect. So the policy is:
//   - health / reflection            → pass.
//   - quota RPCs + GetSubscription    → strip forged identity metadata;
//     require an allow-listed OIDC caller **when configured**.
//   - everything else (Admin*, org-admin browser RPCs) → REJECT — they have
//     no native caller, which is what closes the escalation hole.

// idTokenValidator matches idtoken.Validate so tests inject a fake (same
// pattern as the HTTP scheduler auth).
type idTokenValidator func(ctx context.Context, token, audience string) (*idtoken.Payload, error)

// nativeAnonymousMethods run with no auth on the native path.
var nativeAnonymousMethods = map[string]struct{}{
	"/grpc.health.v1.Health/Check":                                  {},
	"/grpc.health.v1.Health/Watch":                                  {},
	"/grpc.reflection.v1.ServerReflection/ServerReflectionInfo":     {},
	"/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo": {},
}

// nativeInternalMethods are the ONLY BillingService RPCs a backend service
// legitimately calls over native gRPC. Everything not here (all Admin*,
// GetMyOrgSeatUsage, ListInvoices, AdminListPlans, AdminGetOrgSeatUsage) is
// browser-only via Connect and is rejected on the native path.
var nativeInternalMethods = map[string]struct{}{
	"/billing.v1.BillingService/CheckQuota":      {},
	"/billing.v1.BillingService/ReserveCredit":   {},
	"/billing.v1.BillingService/CommitUsage":     {},
	"/billing.v1.BillingService/ReleaseCredit":   {},
	"/billing.v1.BillingService/IncrementUsage":  {},
	"/billing.v1.BillingService/GetSubscription": {},
}

// NativeAuthInterceptor guards the native gRPC path (see file header).
//
// audience = billing-svc's own Cloud Run URL (what internal callers mint as
// the OIDC `aud`); allowedSAs = caller service-account emails. When BOTH are
// configured, the quota RPCs require a valid, allow-listed OIDC token. When
// they are UNSET (not yet wired in terraform) the quota RPCs still run — but
// with client-supplied `x-superwizor-*` metadata stripped — so this is safe
// to deploy ahead of the infra change without breaking the pipeline, while
// the Admin* rejection (the Critical) takes effect immediately regardless.
func NativeAuthInterceptor(audience string, allowedSAs map[string]struct{}, validate idTokenValidator) grpc.UnaryServerInterceptor {
	if validate == nil {
		validate = idtoken.Validate
	}
	oidcConfigured := audience != "" && len(allowedSAs) > 0
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		if _, ok := nativeAnonymousMethods[info.FullMethod]; ok {
			return handler(ctx, req)
		}
		if _, ok := nativeInternalMethods[info.FullMethod]; !ok {
			// No backend service calls this over native gRPC. Refuse — this
			// is what kills the Admin* escalation (#2).
			return nil, status.Errorf(codes.Unauthenticated,
				"%s is not callable over native gRPC", info.FullMethod)
		}

		md, _ := metadata.FromIncomingContext(ctx)
		// Always strip client-supplied trusted-identity headers so a forged
		// x-superwizor-* can never reach resolveAdminCaller / orgIDFromContext.
		clean := stripReservedMetadata(md)

		if oidcConfigured {
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
		}
		return handler(metadata.NewIncomingContext(ctx, clean), req)
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

// stripReservedMetadata returns a copy of md with every x-superwizor-* key
// removed — the native-path analogue of the connectmd strip (#9).
func stripReservedMetadata(md metadata.MD) metadata.MD {
	out := metadata.New(nil)
	for k, vv := range md {
		if strings.HasPrefix(strings.ToLower(k), "x-superwizor-") {
			continue
		}
		out.Set(k, vv...)
	}
	return out
}

// ParseAllowedSAs splits a comma-separated env value into a set of caller SA
// emails (SA emails contain no commas). Blanks are ignored.
func ParseAllowedSAs(csv string) map[string]struct{} {
	out := map[string]struct{}{}
	for _, s := range strings.Split(csv, ",") {
		if t := strings.TrimSpace(s); t != "" {
			out[t] = struct{}{}
		}
	}
	return out
}
