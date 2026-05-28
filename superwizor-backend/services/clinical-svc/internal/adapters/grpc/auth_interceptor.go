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

const UserIDKey contextKey = "user_id"

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
			return next(newCtx, req)
		}
	}
}
