// Package grpc holds the notification-svc gRPC server (Cloud Run).
//
// Three RPCs are user-facing:
//   - RegisterFCMToken — Flutter calls on login + token refresh.
//   - RemoveFCMToken   — Flutter calls on logout.
//   - GetUnreadCount   — diagnostic; Flutter normally uses Firestore listener.
//
// Plus HealthCheck for liveness probes. Authentication: every request
// (except HealthCheck) must carry a Firebase ID token in the
// "authorization: Bearer ..." metadata header. We verify the token locally
// using the Firebase Admin Auth SDK (no extra hop to identity-svc — we
// already pull in the Admin SDK for FCM, and the verification is offline
// after the first key fetch).
package grpc

import (
	"context"
	"errors"
	"log/slog"
	"strings"

	fbauth "firebase.google.com/go/v4/auth"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	pgstore "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/postgres"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/email"
)

type Server struct {
	notificationv1.UnimplementedNotificationServiceServer
	store   *pgstore.Store
	auth    *fbauth.Client
	emailer email.Sender // nil-safe; nil falls through to NoopSender at call site
	version string
}

func NewServer(store *pgstore.Store, auth *fbauth.Client, version string) *Server {
	return &Server{store: store, auth: auth, version: version, emailer: email.NewMockSender()}
}

// WithEmailer overrides the email Sender. Production wiring (cmd/server/
// main.go) calls this with a ResendSender; tests use a MockSender;
// local dev when RESEND_API_KEY is unset stays on the default
// MockSender from NewServer.
func (s *Server) WithEmailer(sender email.Sender) *Server { s.emailer = sender; return s }

// HealthCheck — unauthenticated. Cloud Run health probes hit this.
func (s *Server) HealthCheck(_ context.Context, _ *emptypb.Empty) (*notificationv1.HealthCheckResponse, error) {
	return &notificationv1.HealthCheckResponse{Ok: true, Version: s.version}, nil
}

// RegisterFCMToken upserts a token for the authenticated user. Idempotent —
// re-registering an existing (user, token) pair returns AlreadyRegistered=true.
func (s *Server) RegisterFCMToken(
	ctx context.Context, req *notificationv1.RegisterFCMTokenRequest,
) (*notificationv1.RegisterFCMTokenResponse, error) {
	user, err := s.authenticate(ctx)
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(req.GetToken()) == "" {
		return nil, status.Error(codes.InvalidArgument, "token is required")
	}

	res, err := s.store.UpsertFCMToken(ctx, pgstore.UpsertFCMTokenParams{
		UserID:      user.ID,
		Token:       req.GetToken(),
		Platform:    platformToColumnValue(req.GetPlatform()),
		AppVersion:  req.GetAppVersion(),
		DeviceModel: req.GetDeviceModel(),
		Locale:      req.GetLocale(),
	})
	if err != nil {
		slog.Error("upsert fcm token", "user_id", user.ID, "error", err)
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &notificationv1.RegisterFCMTokenResponse{
		TokenId:           res.ID.String(),
		AlreadyRegistered: !res.WasNew,
	}, nil
}

// RemoveFCMToken soft-deletes the token. Idempotent: removing an already-
// invalidated or unknown token still returns OK.
func (s *Server) RemoveFCMToken(
	ctx context.Context, req *notificationv1.RemoveFCMTokenRequest,
) (*emptypb.Empty, error) {
	user, err := s.authenticate(ctx)
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(req.GetToken()) == "" {
		return nil, status.Error(codes.InvalidArgument, "token is required")
	}
	if err := s.store.RemoveFCMTokenByValue(ctx, user.ID, req.GetToken()); err != nil {
		slog.Error("remove fcm token", "user_id", user.ID, "error", err)
		return nil, status.Error(codes.Internal, err.Error())
	}
	return &emptypb.Empty{}, nil
}

// GetUnreadCount returns a coarse audit count. Note: per architecture §6,
// Flutter normally counts via the Firestore listener; this RPC exists as a
// fallback / diagnostic.
func (s *Server) GetUnreadCount(
	ctx context.Context, _ *emptypb.Empty,
) (*notificationv1.GetUnreadCountResponse, error) {
	user, err := s.authenticate(ctx)
	if err != nil {
		return nil, err
	}
	n, err := s.store.GetUnreadNotificationCount(ctx, user.ID)
	if err != nil {
		slog.Error("get unread count", "user_id", user.ID, "error", err)
		return nil, status.Error(codes.Internal, err.Error())
	}
	// int64 → int32: counts above 2^31 are not realistic for one user; cap
	// just in case so we never panic on overflow.
	if n > 1<<30 {
		n = 1 << 30
	}
	return &notificationv1.GetUnreadCountResponse{Count: int32(n)}, nil
}

// authenticate verifies the Firebase ID token from gRPC metadata and
// resolves it to a users row. Returns Unauthenticated if anything is amiss.
//
// We verify locally rather than delegating to identity-svc because:
//   - The Admin SDK is already imported (for FCM messaging).
//   - VerifyIDToken caches Google's signing keys; the typical hot-path
//     verification is sub-millisecond and offline.
//   - One fewer service-to-service hop on the token-registration path
//     (which is the most frequent RPC for this service).
func (s *Server) authenticate(ctx context.Context) (*pgstore.User, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}
	auths := md.Get("authorization")
	if len(auths) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization header")
	}
	tokenStr := strings.TrimPrefix(auths[0], "Bearer ")
	tokenStr = strings.TrimSpace(tokenStr)
	if tokenStr == "" {
		return nil, status.Error(codes.Unauthenticated, "empty bearer token")
	}

	if s.auth == nil {
		// Dev/test: caller provided an unverified UID via header.
		// Production paths always have s.auth != nil; we exit early here
		// instead of silently accepting unsigned tokens.
		return nil, status.Error(codes.Unauthenticated, "auth client not configured")
	}

	tok, err := s.auth.VerifyIDToken(ctx, tokenStr)
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "invalid id token: %v", err)
	}

	user, err := s.store.LookupUserByFirebaseUID(ctx, tok.UID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Verified Firebase identity, but not registered in users
			// table — typical right after Firebase signup but before
			// identity-svc.RegisterUser. UNAUTHENTICATED matches the
			// architecture pattern (clinical-svc behaves the same).
			return nil, status.Error(codes.Unauthenticated, "user not registered")
		}
		slog.Error("lookup user by firebase uid", "fb_uid", tok.UID, "error", err)
		return nil, status.Error(codes.Internal, "user lookup failed")
	}
	return user, nil
}

// platformToColumnValue normalises the proto enum to the lowercase string
// the fcm_tokens.platform column stores ("ios" / "android" / "web").
func platformToColumnValue(p notificationv1.Platform) string {
	switch p {
	case notificationv1.Platform_PLATFORM_IOS:
		return "ios"
	case notificationv1.Platform_PLATFORM_ANDROID:
		return "android"
	case notificationv1.Platform_PLATFORM_WEB:
		return "web"
	default:
		// Better to record an explicit "unknown" than to silently coerce
		// to ios — makes orphaned rows easy to spot in audits.
		return "unknown"
	}
}
