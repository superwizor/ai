// Manager (ORG_ADMIN) self-management — docs/38 PR14.
//
// An ORG_ADMIN can list the org's managers + pending manager invites,
// invite a new manager, and deactivate/reactivate OR revoke-invite an
// OTHER manager. All gated on the caller's ORG_ADMIN role with the org
// resolved from the auth context (never trusted from the request).
//
// Two hard rules (product decision 2026-07-05):
//   - A manager can never act on THEIR OWN account (no self-lockout).
//   - "Remove" is reversible deactivation for an active manager, and a
//     hard revoke for a still-pending invitation.

package grpc

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// ListMyOrgManagers returns the org's active managers (role=ORG_ADMIN) +
// pending ORG_ADMIN invitations. ORG_ADMIN only.
func (s *Server) ListMyOrgManagers(ctx context.Context, _ *emptypb.Empty) (*identityv1.ListManagersResponse, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}

	active, err := s.queries.ListManagersByOrganization(ctx,
		pgtype.UUID{Bytes: *caller.organizationID, Valid: true})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list managers: %v", err)
	}
	pending, err := s.queries.ListPendingManagerInvitationsByOrg(ctx, *caller.organizationID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list pending manager invitations: %v", err)
	}

	out := &identityv1.ListManagersResponse{
		Managers: make([]*identityv1.ManagerEntry, 0, len(active)+len(pending)),
	}
	for _, u := range active {
		out.Managers = append(out.Managers, &identityv1.ManagerEntry{User: toProtoUser(u)})
	}
	for _, inv := range pending {
		out.Managers = append(out.Managers, &identityv1.ManagerEntry{PendingInvitation: toProtoInvitation(inv)})
	}
	return out, nil
}

// InviteMyOrgManager invites a new ORG_ADMIN to the caller's org — the
// same magic-link machinery as InviteTherapist, but invited_role=ORG_ADMIN
// with NO seat allocation (managers don't occupy seats). Refresh in place
// on a same-email pending row.
func (s *Server) InviteMyOrgManager(ctx context.Context, req *identityv1.InviteMyOrgManagerRequest) (*identityv1.Invitation, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || !strings.Contains(email, "@") {
		return nil, status.Error(codes.InvalidArgument, "valid email required")
	}

	token, tokenHash, err := generateInvitationToken()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "generate token: %v", err)
	}
	expiresAt := time.Now().Add(invitationTTL)

	createParams := db.CreateInvitationParams{
		OrganizationID: *caller.organizationID,
		InvitedByUser:  caller.userID,
		Email:          email,
		TokenHash:      tokenHash,
		ExpiresAt:      expiresAt,
		InvitedRole:    db.UserRoleORGADMIN,
		// no allocation — managers don't occupy seats
	}
	if fn := strings.TrimSpace(req.FirstName); fn != "" {
		createParams.InvitedFirstName = &fn
	}
	if ln := strings.TrimSpace(req.LastName); ln != "" {
		createParams.InvitedLastName = &ln
	}

	inv, err := s.queries.CreateInvitation(ctx, createParams)
	if err != nil {
		// Same-email re-invite: refresh the existing pending row to an
		// ORG_ADMIN invite with a fresh token/expiry. ORG_ADMIN + NULL
		// allocation satisfies chk_invitations_allocation_by_role whatever
		// the prior role was.
		existing, lookupErr := s.queries.GetInvitationByOrgEmail(ctx, db.GetInvitationByOrgEmailParams{
			OrganizationID: *caller.organizationID,
			Email:          email,
		})
		if lookupErr != nil {
			return nil, status.Errorf(codes.Internal, "create invitation: %v", err)
		}
		if _, uerr := s.pool.Exec(ctx,
			`UPDATE invitations
			    SET token_hash = $2, expires_at = $3, invited_by_user = $4,
			        invited_role = 'ORG_ADMIN', allocation_id = NULL,
			        invited_first_name = $5, invited_last_name = $6,
			        created_at = now()
			  WHERE id = $1`,
			existing.ID, tokenHash, expiresAt, caller.userID,
			createParams.InvitedFirstName, createParams.InvitedLastName,
		); uerr != nil {
			return nil, status.Errorf(codes.Internal, "refresh invitation: %v", uerr)
		}
		inv = existing
		inv.TokenHash = tokenHash
		inv.ExpiresAt = expiresAt
		inv.InvitedRole = db.UserRoleORGADMIN
		inv.AllocationID = pgtype.UUID{}
		inv.InvitedFirstName = createParams.InvitedFirstName
		inv.InvitedLastName = createParams.InvitedLastName
	}

	// Best-effort email context.
	orgName := ""
	if org, oerr := s.queries.GetOrganizationByID(ctx, *caller.organizationID); oerr == nil {
		orgName = org.LegalName
	}
	inviterFirstName, locale := "", "pl"
	if u, uerr := s.queries.GetUserByID(ctx, caller.userID); uerr == nil {
		inviterFirstName = u.FirstName
		if u.UiLanguage != "" {
			locale = u.UiLanguage
		}
	}
	acceptURL := fmt.Sprintf("%s/accept-invite?token=%s",
		strings.TrimRight(s.acceptURLBase, "/"), url.QueryEscape(token))
	_ = s.emailer.SendInvitation(ctx, InvitationEmailParams{
		Recipient:        email,
		OrgName:          orgName,
		InviterFirstName: inviterFirstName,
		AcceptURL:        acceptURL,
		ExpiresAt:        expiresAt.Format(time.RFC3339),
		Locale:          locale,
		InvitedRole:      "ORG_ADMIN",
	})

	return toProtoInvitation(inv), nil
}

// SetMyOrgManagerStatus deactivates/reactivates ANOTHER manager
// (role=ORG_ADMIN) in the caller's org. Rejects self so a manager can't
// lock themselves out. Managers hold no seats, so there's no seat math —
// just the is_active flip.
func (s *Server) SetMyOrgManagerStatus(ctx context.Context, req *identityv1.SetMyOrgManagerStatusRequest) (*identityv1.User, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	userID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}
	if userID == caller.userID {
		return nil, status.Error(codes.FailedPrecondition, "cannot change your own manager status")
	}

	target, err := s.queries.GetUserByID(ctx, userID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if !target.OrganizationID.Valid || uuid.UUID(target.OrganizationID.Bytes) != *caller.organizationID {
		return nil, status.Error(codes.PermissionDenied, "user is not in your organization")
	}
	if target.Role != db.UserRoleORGADMIN {
		return nil, status.Error(codes.FailedPrecondition, "can only toggle ORG_ADMIN accounts")
	}
	if target.IsActive == req.IsActive {
		return toProtoUser(target), nil // idempotent no-op
	}

	updated, err := s.queries.SetUserActiveStatus(ctx, db.SetUserActiveStatusParams{
		ID:       userID,
		IsActive: req.IsActive,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "set active status: %v", err)
	}
	return toProtoUser(updated), nil
}

// RevokeMyOrgManagerInvite hard-deletes a PENDING ORG_ADMIN invitation in
// the caller's org (the invitee never accepted). The query is guarded to
// pending + ORG_ADMIN so nothing else can be removed through this path.
func (s *Server) RevokeMyOrgManagerInvite(ctx context.Context, req *identityv1.RevokeMyOrgManagerInviteRequest) (*emptypb.Empty, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	inviteID, err := uuid.Parse(req.InvitationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid invitation_id")
	}
	n, err := s.queries.RevokeManagerInvitation(ctx, db.RevokeManagerInvitationParams{
		ID:             inviteID,
		OrganizationID: *caller.organizationID,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "revoke invitation: %v", err)
	}
	if n == 0 {
		return nil, status.Error(codes.NotFound, "pending manager invitation not found")
	}
	return &emptypb.Empty{}, nil
}
