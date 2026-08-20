package grpc

import (
	"context"
	"strings"

	"connectrpc.com/connect"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

type contextKey string

const (
	UserIDKey         contextKey = "user_id"
	UserRoleKey       contextKey = "user_role"
	OrganizationIDKey contextKey = "organization_id"
	// PlatformKey carries the x-client-platform header ("web"|"ios"
	// |"android") for chat telemetry. Every custom gRPC metadata key
	// needs a matching CORS allowlist entry in pkg/cors — see the
	// x-client-platform incident of 2026-07-24.
	PlatformKey contextKey = "client_platform"
)

// protoRoleName mirrors billing-svc's helper: turn the proto UserRole
// enum into the bare-string form ("THERAPIST", "ORG_ADMIN",
// "SUPERWIZOR_ADMIN", "PATIENT") that handler-level role gates compare
// against. Keep in lockstep with billing-svc/internal/adapters/grpc/
// auth_interceptor.go::protoRoleName.
func protoRoleName(r identityv1.UserRole) string {
	switch r {
	case identityv1.UserRole_USER_ROLE_THERAPIST:
		return "THERAPIST"
	case identityv1.UserRole_USER_ROLE_PATIENT:
		return "PATIENT"
	case identityv1.UserRole_USER_ROLE_ORG_ADMIN:
		return "ORG_ADMIN"
	case identityv1.UserRole_USER_ROLE_SUPERWIZOR_ADMIN:
		return "SUPERWIZOR_ADMIN"
	}
	return ""
}

// Pre-auth allowlist. Methods on this list run without any token
// validation:
//   - HealthCheck: liveness probe.
//   - ListModalities: public catalogue (3 supported modalities at
//     MVP, all is_supported=true rows). The marketing-site
//     registration page renders the modality dropdown BEFORE the
//     user has a Firebase token — without this allowlist the form
//     can't load. Data is non-sensitive (id + system_code + EN
//     display_name + supported flag). Do not add anything that
//     reads per-user data to this map.
//
// Shared between the gRPC and Connect interceptors so the same set
// of methods stays anonymous over either transport.
var anonymousMethods = map[string]struct{}{
	"/clinical.v1.ClinicalService/HealthCheck":    {},
	"/clinical.v1.ClinicalService/ListModalities": {},
}

// UnaryAuthInterceptor checks the authorization token and validates it
// via IdentityService. Runs on the native-gRPC path only (iOS, server-
// to-server). Browser callers travel through the Connect handler and
// pick up ConnectAuthInterceptor below.
func UnaryAuthInterceptor(identityClient identityv1.IdentityServiceClient) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		if _, ok := anonymousMethods[info.FullMethod]; ok {
			return handler(ctx, req)
		}

		md, ok := metadata.FromIncomingContext(ctx)
		if !ok {
			return nil, status.Error(codes.Unauthenticated, "missing metadata")
		}

		auths := md.Get("authorization")
		if len(auths) == 0 {
			return nil, status.Error(codes.Unauthenticated, "missing authorization header")
		}

		tokenStr := strings.TrimPrefix(auths[0], "Bearer ")

		res, err := identityClient.ValidateToken(ctx, &identityv1.ValidateTokenRequest{
			FirebaseIdToken: tokenStr,
		})
		if err != nil {
			return nil, status.Errorf(codes.Unauthenticated, "invalid token: %v", err)
		}

		newCtx := context.WithValue(ctx, UserIDKey, res.UserId)
		newCtx = context.WithValue(newCtx, UserRoleKey, protoRoleName(res.Role))
		newCtx = context.WithValue(newCtx, OrganizationIDKey, res.OrganizationId)
		newCtx = context.WithValue(newCtx, PlatformKey, platformFromMD(md))
		return handler(newCtx, req)
	}
}

// ConnectAuthInterceptor mirrors UnaryAuthInterceptor for the Connect
// handler chain — Connect-RPC (marketing-site browser) and gRPC-Web
// (Flutter web) requests land here instead of on the gRPC server. The
// interceptor runs AFTER connectmd.HeadersToGRPCMetadata, so the
// Authorization header is already present in the request's HTTP
// headers; we read it via req.Header() rather than from gRPC metadata
// to keep this transport-agnostic.
//
// Without this, every Flutter-web RPC that depends on
// `ctx.Value(UserIDKey)` (ListPatientFiles, CreatePatientFile, etc.)
// returns "missing user ID in context" — the 2026-05-28 regression
// surfaced after we routed gRPC-Web to the Connect handler to fix the
// 415 mismatch.
func ConnectAuthInterceptor(identityClient identityv1.IdentityServiceClient) connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			if _, ok := anonymousMethods[req.Spec().Procedure]; ok {
				return next(ctx, req)
			}

			auth := req.Header().Get("Authorization")
			if auth == "" {
				return nil, connect.NewError(connect.CodeUnauthenticated,
					status.Error(codes.Unauthenticated, "missing authorization header"))
			}
			tokenStr := strings.TrimPrefix(auth, "Bearer ")

			res, err := identityClient.ValidateToken(ctx, &identityv1.ValidateTokenRequest{
				FirebaseIdToken: tokenStr,
			})
			if err != nil {
				return nil, connect.NewError(connect.CodeUnauthenticated,
					status.Errorf(codes.Unauthenticated, "invalid token: %v", err))
			}

			newCtx := context.WithValue(ctx, UserIDKey, res.UserId)
			newCtx = context.WithValue(newCtx, UserRoleKey, protoRoleName(res.Role))
			newCtx = context.WithValue(newCtx, OrganizationIDKey, res.OrganizationId)
			newCtx = context.WithValue(newCtx, PlatformKey, normalizePlatform(req.Header().Get("X-Client-Platform")))
			return next(newCtx, req)
		}
	}
}

// platformFromMD reads the client platform marker from gRPC metadata.
func platformFromMD(md metadata.MD) string {
	vals := md.Get("x-client-platform")
	if len(vals) == 0 {
		return ""
	}
	return normalizePlatform(vals[0])
}

// normalizePlatform maps a client-supplied platform marker onto the
// closed set the platform records.
//
// Unknown values become "" rather than passing through. The value lands
// in telemetry and in guardrail_decisions, and an unbounded string from a
// client would be a free-text field in a table that is specified to have
// none.
func normalizePlatform(raw string) string {
	switch p := strings.ToLower(strings.TrimSpace(raw)); p {
	case "web", "ios", "android":
		return p
	}
	return ""
}
