// Cross-origin SSO between the marketing site (superwizor.web.app)
// and the Flutter web app (superwizor-app.web.app).
//
// Firebase Auth's IndexedDB is origin-scoped, so a user signed in on
// the marketing origin has no session on the Flutter origin. To hand
// off the active session we mint a short-lived Firebase custom token
// on the caller's behalf; the Flutter origin redeems it via
// signInWithCustomToken to establish its own Auth session for the
// same uid.
//
// Security: the handler never reads a uid from the request. It always
// mints for the authenticated caller (resolveCaller → firebaseUID).
// No org/role escalation surface. Custom tokens expire ~1h and are
// single-use in practice — the receiving origin signs in once, after
// which the token is spent.

package grpc

import (
	"context"
	"log/slog"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

func (s *Server) MintAppLoginToken(ctx context.Context, _ *emptypb.Empty) (*identityv1.AppLoginToken, error) {
	c, err := s.resolveCaller(ctx)
	if err != nil {
		return nil, err
	}
	if c.firebaseUID == "" {
		// resolveCaller already loaded the User row from the DB; an
		// empty firebase_uid here means the row was created without
		// one, which shouldn't happen for any normal signup path.
		// Treat as InvalidArgument so the caller surfaces the issue
		// rather than silently failing the redirect.
		return nil, status.Error(codes.FailedPrecondition,
			"caller has no firebase_uid bound to their account")
	}

	tok, err := s.auth.CustomToken(ctx, c.firebaseUID)
	if err != nil {
		slog.ErrorContext(ctx, "MintAppLoginToken: CustomToken failed",
			"user_id", c.userID.String(),
			"err", err)
		return nil, status.Error(codes.Internal, "mint custom token failed")
	}
	return &identityv1.AppLoginToken{Token: tok}, nil
}
