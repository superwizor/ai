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

const UserIDKey contextKey = "user_id"

// UnaryAuthInterceptor checks the authorization token and validates it via IdentityService
func UnaryAuthInterceptor(identityClient identityv1.IdentityServiceClient) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		// Pre-auth allowlist. Methods on this list run without any token
		// validation:
		//   - HealthCheck: liveness probe.
		//   - ListModalities: public catalogue (3 supported modalities at
		//     MVP, all is_supported=true rows). The marketing-site
		//     registration page renders the modality dropdown BEFORE the
		//     user has a Firebase token — without this allowlist the form
		//     can't load. Data is non-sensitive (id + system_code + EN
		//     display_name + supported flag). Do not add anything that
		//     reads per-user data to this switch.
		switch info.FullMethod {
		case "/clinical.v1.ClinicalService/HealthCheck",
			"/clinical.v1.ClinicalService/ListModalities":
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

		// inject user_id into context
		newCtx := context.WithValue(ctx, UserIDKey, res.UserId)
		return handler(newCtx, req)
	}
}
