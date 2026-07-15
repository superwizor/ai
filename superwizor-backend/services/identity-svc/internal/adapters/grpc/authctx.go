package grpc

import (
	"context"
	"errors"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// callerContext is the resolved caller identity stored on ctx via
// callerFromContext. Every authenticated handler reads it before any
// role gate; unauthenticated handlers (RegisterOrganization,
// AcceptInvitation, ValidateToken) don't.
type callerContext struct {
	userID         uuid.UUID
	firebaseUID    string
	role           db.UserRole
	organizationID *uuid.UUID // nil for orphan users (shouldn't happen post-trial-signup)
	email          string
}

type callerContextKey struct{}

func callerFromContext(ctx context.Context) (callerContext, bool) {
	c, ok := ctx.Value(callerContextKey{}).(callerContext)
	return c, ok
}

// resolveCaller is the canonical entrypoint every gated handler calls
// before doing anything else. It pulls the Firebase ID token from
// gRPC metadata, verifies it, fetches the matching User row, and
// caches the result on ctx for subsequent helpers.
//
// On any failure returns a gRPC error with the right code so handlers
// can just `return nil, err` it through.
func (s *Server) resolveCaller(ctx context.Context) (callerContext, error) {
	if c, ok := callerFromContext(ctx); ok {
		return c, nil // already resolved earlier in this RPC's lifecycle
	}

	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return callerContext{}, status.Error(codes.Unauthenticated, "no gRPC metadata")
	}
	auths := md.Get("authorization")
	if len(auths) == 0 {
		return callerContext{}, status.Error(codes.Unauthenticated, "no authorization header")
	}
	token := auths[0]
	// Strip optional "Bearer " prefix — Firebase SDK iOS sends bare token;
	// Connect-Web sends "Bearer <token>".
	if len(token) > 7 && (token[:7] == "Bearer " || token[:7] == "bearer ") {
		token = token[7:]
	}

	firebaseUID, claims, err := s.auth.VerifyToken(ctx, token)
	if err != nil {
		return callerContext{}, status.Error(codes.Unauthenticated, "invalid Firebase token")
	}

	user, err := s.queries.GetUserByFirebaseUID(ctx, &firebaseUID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return callerContext{}, status.Error(codes.NotFound, "user record not found for Firebase UID")
		}
		return callerContext{}, status.Errorf(codes.Internal, "load caller: %v", err)
	}

	// Deactivation gate (docs/38 §4) — mirrors ValidateToken so a
	// deactivated account can't reach identity-svc's own gated RPCs
	// either. Same "ACCOUNT_DEACTIVATED" contract as ValidateToken.
	if !user.IsActive {
		return callerContext{}, status.Error(codes.PermissionDenied,
			"ACCOUNT_DEACTIVATED: konto nieaktywne — skontaktuj się z administratorem organizacji")
	}

	// Self-healing sync: if email in Firebase token claims differs from PostgreSQL, update DB
	if emailVal, ok := claims["email"].(string); ok {
		tokenEmail := strings.ToLower(strings.TrimSpace(emailVal))
		dbEmail := strings.ToLower(strings.TrimSpace(derefString(user.Email)))
		if tokenEmail != "" && tokenEmail != dbEmail {
			_, errUpdate := s.queries.AdminUpdateUser(ctx, db.AdminUpdateUserParams{
				ID:    user.ID,
				Email: &tokenEmail,
			})
			if errUpdate != nil {
				slog.WarnContext(ctx, "failed to sync user email from firebase token", "error", errUpdate, "uid", firebaseUID)
			} else {
				user.Email = &tokenEmail
			}
		}
	}

	c := callerContext{
		userID:      user.ID,
		firebaseUID: derefString(user.FirebaseUid),
		role:        user.Role,
		email:       derefString(user.Email),
	}
	if user.OrganizationID.Valid {
		orgID := uuid.UUID(user.OrganizationID.Bytes)
		c.organizationID = &orgID
	}
	return c, nil
}

// requireRole resolves the caller and asserts they hold one of the
// expected roles. Returns PermissionDenied on mismatch.
func (s *Server) requireRole(ctx context.Context, expected ...db.UserRole) (callerContext, error) {
	c, err := s.resolveCaller(ctx)
	if err != nil {
		return callerContext{}, err
	}
	for _, r := range expected {
		if c.role == r {
			return c, nil
		}
	}
	return callerContext{}, status.Errorf(codes.PermissionDenied,
		"role %s not authorised for this action (need one of: %v)", c.role, expected)
}

// requireOrgAdmin is a tiny convenience over requireRole for the
// dozen-or-so org-admin endpoints.
func (s *Server) requireOrgAdmin(ctx context.Context) (callerContext, error) {
	return s.requireRole(ctx, db.UserRoleORGADMIN)
}

// requireSuperwizorAdmin gates every /admin/* RPC.
func (s *Server) requireSuperwizorAdmin(ctx context.Context) (callerContext, error) {
	return s.requireRole(ctx, db.UserRoleSUPERWIZORADMIN)
}
