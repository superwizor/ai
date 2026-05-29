package grpc

import (
	"context"
	"strings"

	"connectrpc.com/connect"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// ConnectAuthInterceptor resolves the caller's identity from the
// Firebase token in Authorization, calls identity-svc.ValidateToken
// to look up role + user_id + organization_id, and writes them into
// the gRPC IncomingMetadata as the x-superwizor-* headers that the
// existing admin handlers (resolveAdminCaller) already read.
//
// Why this lives only on the Connect handler:
//   - Server-to-server callers (clinical-svc, ingestion-svc,
//     stt-worker) speak native gRPC on the application/grpc path
//     and already supply the x-superwizor-role header themselves.
//     They don't transit the Connect handler so this interceptor
//     never runs for them.
//   - Browser callers (marketing-site /admin/*) only have a
//     Firebase ID token; there's no upstream proxy to inject role
//     headers. Before this interceptor, AdminResetTokens /
//     AdminChangePlan came back as "x-superwizor-role missing"
//     and the frontend rendered it as "Wystąpił nieznany błąd".
//
// Anonymous allowlist: none. Every browser billing-svc RPC needs an
// authenticated caller — there's no public catalogue endpoint here.
//
// On token validation failure the interceptor returns
// connect.CodeUnauthenticated; downstream handlers never see the
// request. On success, ctx carries the metadata so resolveAdminCaller
// finds it via the existing metadata.FromIncomingContext path.
func ConnectAuthInterceptor(identityClient identityv1.IdentityServiceClient) connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
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

			// Merge the resolved identity into IncomingMetadata. The
			// HeadersToGRPCMetadata interceptor that runs before us has
			// already copied HTTP headers into the ctx, so we extend
			// rather than replace.
			md, ok := metadata.FromIncomingContext(ctx)
			if !ok {
				md = metadata.New(nil)
			} else {
				md = md.Copy()
			}
			md.Set("x-superwizor-role", protoRoleName(res.Role))
			if res.UserId != "" {
				md.Set("x-superwizor-user-id", res.UserId)
			}
			if res.OrganizationId != "" {
				md.Set("x-superwizor-organization-id", res.OrganizationId)
			}
			newCtx := metadata.NewIncomingContext(ctx, md)
			return next(newCtx, req)
		}
	}
}

// protoRoleName converts the proto UserRole enum into the bare-string
// form the billing-svc handlers compare against ("SUPERWIZOR_ADMIN",
// "ORG_ADMIN", "THERAPIST", "PATIENT"). The proto enum's String()
// returns "USER_ROLE_THERAPIST"-style names; we strip the prefix so
// the handler comparison `if c.role != "SUPERWIZOR_ADMIN"` works.
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
