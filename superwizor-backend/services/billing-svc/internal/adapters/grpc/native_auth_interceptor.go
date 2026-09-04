package grpc

import (
	"context"
	"strings"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// Native-gRPC auth for billing-svc (security #2 / #9).
//
// billing-svc runs with the Cloud Run `allUsers` invoker, and its native
// gRPC path (`application/grpc` → gs.ServeHTTP) had NO interceptor — so an
// anonymous internet caller could invoke Admin* RPCs with a forged
// `x-superwizor-role: SUPERWIZOR_ADMIN` header (resolveAdminCaller trusts
// metadata). The Connect path is guarded; the native path was not.
//
// Trzy klasy wywołujących, trzy różne reguły:
//
//   - health / reflection            → przepuszczamy bez uwierzytelnienia.
//   - RPC kolejki tokenów + GetSubscription → wołane przez usługi zaplecza
//     (clinical-svc, ingestion-svc, stt-worker) z tokenem OIDC Google.
//     Zdejmujemy podrobioną tożsamość; przy skonfigurowanym OIDC wymagamy
//     wywołującego z allowlisty.
//   - RPC sklepowe (docs/70 §7.2) → wołane przez APLIKACJĘ MOBILNĄ z
//     tokenem Firebase. Tożsamość rozstrzyga identity-svc, dokładnie tak
//     jak na ścieżce Connect. Bez identity-svc odrzucamy (fail-closed).
//   - reszta (Admin*, RPC panelu organizacji) → ODRZUCAMY. Nie mają
//     natywnego wywołującego, i to zamyka dziurę eskalacyjną.
//
// ─── Dlaczego RPC sklepowe musiały tu trafić (2026-09-04) ────────────────
//
// Aplikacja na iOS i Androidzie rozmawia z billing-svc po NATYWNYM gRPC
// (`GrpcOrGrpcWebClientChannel` schodzi do gRPC-Web wyłącznie na webie).
// Przeglądarka używa Connecta i działała, więc paywall wyglądał na
// sprawny w testach webowych — a na telefonie każdy sklepowy RPC wracał
// jako `Unauthenticated: … is not callable over native gRPC`. Aplikacja
// tłumaczy każdy błąd na „brak commerce", więc ekran wyboru planu
// pokazywał „Zakupy chwilowo niedostępne" i nie było widać, że to awaria,
// a nie wyłączona sprzedaż. Zgłoszone z produkcji 04.09.2026 na buildzie
// 1.0.9+59; potwierdzone gołym żądaniem HTTP/2 do Cloud Runa.

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

// nativeUserMethods to RPC sklepowe wołane przez aplikację mobilną w
// imieniu ZALOGOWANEGO użytkownika (token Firebase, nie OIDC usługi).
// Świadomie wąska lista: wpuszczamy dokładnie te cztery, bo dokładnie te
// cztery wywołuje `StorePurchaseService`.
var nativeUserMethods = map[string]struct{}{
	"/billing.v1.BillingService/GetBillingSurface":     {},
	"/billing.v1.BillingService/BeginStorePurchase":    {},
	"/billing.v1.BillingService/VerifyStorePurchase":   {},
	"/billing.v1.BillingService/RestoreStorePurchases": {},
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
//
// identityClient uwierzytelnia RPC sklepowe tokenem Firebase. Gdy jest
// nilem (identity-svc niepodpięty), te RPC są odrzucane — nigdy nie
// wpuszczamy ich na podstawie metadanych, które klient może podrobić.
func NativeAuthInterceptor(
	audience string,
	allowedSAs map[string]struct{},
	validate idTokenValidator,
	identityClient identityv1.IdentityServiceClient,
) grpc.UnaryServerInterceptor {
	if validate == nil {
		validate = idtoken.Validate
	}
	oidcConfigured := audience != "" && len(allowedSAs) > 0
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		if _, ok := nativeAnonymousMethods[info.FullMethod]; ok {
			return handler(ctx, req)
		}

		md, _ := metadata.FromIncomingContext(ctx)
		// Always strip client-supplied trusted-identity headers so a forged
		// x-superwizor-* can never reach resolveAdminCaller / orgIDFromContext.
		clean := stripReservedMetadata(md)

		if _, ok := nativeUserMethods[info.FullMethod]; ok {
			next, err := authenticateStoreCaller(ctx, md, clean, identityClient)
			if err != nil {
				return nil, err
			}
			return handler(next, req)
		}

		if _, ok := nativeInternalMethods[info.FullMethod]; !ok {
			// No backend service calls this over native gRPC. Refuse — this
			// is what kills the Admin* escalation (#2).
			return nil, status.Errorf(codes.Unauthenticated,
				"%s is not callable over native gRPC", info.FullMethod)
		}

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

// authenticateStoreCaller zamienia token Firebase na zaufaną tożsamość w
// metadanych — natywny odpowiednik ConnectAuthInterceptor. Zwraca kontekst
// z DOPISANYMI x-superwizor-*, budowany na oczyszczonych metadanych, żeby
// wartość podana przez klienta nie mogła przebić tej z identity-svc.
func authenticateStoreCaller(
	ctx context.Context,
	md, clean metadata.MD,
	identityClient identityv1.IdentityServiceClient,
) (context.Context, error) {
	if identityClient == nil {
		// Bez identity-svc nie ma jak sprawdzić tokena. Odmawiamy —
		// wpuszczenie na podstawie samych metadanych oddałoby cudzą
		// organizację każdemu, kto wpisze jej UUID (ta sama zasada, co
		// FailClosedConnectInterceptor).
		return nil, status.Error(codes.Unauthenticated,
			"store RPCs unavailable: identity-svc not wired")
	}
	auths := md.Get("authorization")
	if len(auths) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization header")
	}
	res, err := identityClient.ValidateToken(ctx, &identityv1.ValidateTokenRequest{
		FirebaseIdToken: strings.TrimPrefix(auths[0], "Bearer "),
	})
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "invalid token: %v", err)
	}
	out := clean.Copy()
	out.Set("x-superwizor-role", protoRoleName(res.Role))
	if res.UserId != "" {
		out.Set("x-superwizor-user-id", res.UserId)
	}
	if res.OrganizationId != "" {
		out.Set("x-superwizor-organization-id", res.OrganizationId)
	}
	return metadata.NewIncomingContext(ctx, out), nil
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
