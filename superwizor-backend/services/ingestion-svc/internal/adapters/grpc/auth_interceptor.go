package grpc

import (
	"context"
	"strings"

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
)

// tokenValidator is the slice of identityv1.IdentityServiceClient the
// interceptor actually uses. Narrowed to an interface so the unit test
// can inject a fake without standing up a live identity-svc. The real
// generated *identityServiceClient satisfies it.
type tokenValidator interface {
	ValidateToken(ctx context.Context, in *identityv1.ValidateTokenRequest, opts ...grpc.CallOption) (*identityv1.UserContext, error)
}

// protoRoleName mirrors clinical-svc / billing-svc: turn the proto
// UserRole enum into the bare-string form ("THERAPIST", "ORG_ADMIN",
// "SUPERWIZOR_ADMIN", "PATIENT") that handler-level role gates compare
// against. Kept in lockstep with the other services' copies.
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

// anonymousMethods run without token validation. Only the gRPC health
// probe qualifies — Cloud Run hits it before any user context exists.
// Both ingestion RPCs (CreateAudioUpload/GetAudioUploadStatus) touch
// per-therapist / per-patient rows and must never be listed here.
//
// Note: this is a UnaryServerInterceptor, so streaming methods
// (reflection's ServerReflectionInfo, Health/Watch) never reach it and
// need no entry.
var anonymousMethods = map[string]struct{}{
	"/grpc.health.v1.Health/Check": {},
}

// UnaryAuthInterceptor validates the Firebase token on the Authorization
// metadata via identity-svc and injects the resolved user_id / role /
// organization_id into the request context. ingestion-svc is native
// gRPC only (iOS + Flutter-web via grpc-web both attach the Firebase
// token — see flutter-app AuthInterceptor), so a single unary
// interceptor covers every caller.
//
// SECURITY #1: before this, CreateAudioUpload trusted the client-
// supplied therapist_id and did no ownership check, so any caller could
// mint a signed upload URL against another therapist's patient file
// (IDOR → PHI write). The handlers now derive the therapist from the
// context this interceptor populates.
func UnaryAuthInterceptor(identityClient tokenValidator) grpc.UnaryServerInterceptor {
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
		return handler(newCtx, req)
	}
}

// userIDFromContext returns the authenticated caller's user id, or "" if
// the request ran without the auth interceptor. The empty case only
// happens in local INSECURE mode (IDENTITY_SVC_URL unset +
// INGESTION_ALLOW_INSECURE=1); in production the interceptor always
// populates it, so a "" here means the request never authenticated.
func userIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(UserIDKey).(string)
	return v
}
