package grpc

// Admin-side therapist ↔ organization membership (docs/43 §5).
//
// The manager-facing path is InviteTherapist → AcceptInvitation, which
// CREATES the account. It cannot serve an account that already exists:
// users.email is globally UNIQUE, so a second invitation for the same
// address can never be accepted. These two RPCs are the admin escape
// hatch for that case — they move an EXISTING account between orgs and
// keep the seat ledger honest while doing it.
//
// Invariants mirrored from the invite path (invitations.go):
//   • users.organization_id is the single source of membership; a
//     therapist belongs to at most one org, so "assign" is a MOVE when
//     the account already sits somewhere else.
//   • seat_assignments is the occupancy ledger. A seat is taken under a
//     FOR UPDATE lock on the allocation row and released on the way out
//     — RemoveTherapist's habit of leaking the seat is NOT copied here.
//   • Every mutation needs reason >= 10 chars and lands in audit_events.

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

func (s *Server) AdminAssignTherapistToOrg(
	ctx context.Context,
	req *identityv1.AdminAssignTherapistToOrgRequest,
) (*identityv1.AdminAssignTherapistToOrgResponse, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" {
		return nil, status.Error(codes.InvalidArgument, "email is required")
	}

	if _, err := s.queries.GetOrganizationByID(ctx, orgID); err != nil {
		return nil, status.Error(codes.NotFound, "organization not found")
	}

	user, err := s.queries.GetUserByEmail(ctx, &email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Deliberately NOT an invitation: this RPC only ever attaches
			// accounts that already exist. Inviting a brand-new therapist
			// stays with the org manager (InviteTherapist).
			return nil, status.Error(codes.NotFound, "USER_NOT_FOUND")
		}
		return nil, status.Errorf(codes.Internal, "lookup user: %v", err)
	}
	if user.Role != db.UserRoleTHERAPIST {
		return nil, status.Error(codes.FailedPrecondition, "USER_NOT_THERAPIST")
	}

	currentOrg := uuid.Nil
	if user.OrganizationID.Valid {
		currentOrg = uuid.UUID(user.OrganizationID.Bytes)
	}
	if currentOrg == orgID {
		return nil, status.Error(codes.FailedPrecondition, "ALREADY_IN_ORGANIZATION")
	}

	// A move drags the therapist's future sessions to the new org while
	// the billing history stays behind. Never do that silently — hand the
	// admin the numbers and make them ask again.
	if currentOrg != uuid.Nil && !req.ConfirmTransfer {
		warning, err := s.therapistTransferWarning(ctx, user.ID, currentOrg)
		if err != nil {
			return nil, err
		}
		return &identityv1.AdminAssignTherapistToOrgResponse{
			Status:          identityv1.AdminAssignTherapistStatus_ADMIN_ASSIGN_THERAPIST_STATUS_TRANSFER_CONFIRMATION_REQUIRED,
			TransferWarning: warning,
		}, nil
	}

	allocationID, err := s.resolveSeatAllocation(ctx, orgID, req.SeatAllocationId)
	if err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	if allocationID != uuid.Nil {
		alloc, err := qtx.GetSeatAllocationForUpdate(ctx, allocationID)
		if err != nil {
			return nil, status.Error(codes.NotFound, "seat allocation not found")
		}
		if alloc.OrganizationID != orgID {
			return nil, status.Error(codes.NotFound, "seat allocation not found")
		}
		if err := checkSeatAvailable(ctx, qtx, alloc); err != nil {
			return nil, err
		}
	}

	// Release the seat held in the previous org before taking a new one:
	// uq_one_active_seat_per_user allows exactly one open row per user.
	if err := qtx.CloseActiveSeatAssignmentForUser(ctx, user.ID); err != nil {
		return nil, status.Errorf(codes.Internal, "close previous seat: %v", err)
	}
	if err := qtx.LinkUserToOrganization(ctx, db.LinkUserToOrganizationParams{
		ID:             user.ID,
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "link user to organization: %v", err)
	}
	if allocationID != uuid.Nil {
		if _, err := qtx.CreateSeatAssignment(ctx, db.CreateSeatAssignmentParams{
			UserID:       user.ID,
			AllocationID: allocationID,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "create seat assignment: %v", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "tx commit: %v", err)
	}

	meta := map[string]any{
		"email":            email,
		"seat_allocation":  allocationID.String(),
		"confirm_transfer": req.ConfirmTransfer,
	}
	if currentOrg != uuid.Nil {
		meta["moved_from_organization_id"] = currentOrg.String()
	}
	if err := s.writeAuditEvent(ctx, caller,
		"organization.assign_therapist", "user",
		&user.ID, &orgID, req.Reason, meta,
	); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}

	updated, err := s.queries.GetUserByID(ctx, user.ID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "reload user: %v", err)
	}
	return &identityv1.AdminAssignTherapistToOrgResponse{
		Status:    identityv1.AdminAssignTherapistStatus_ADMIN_ASSIGN_THERAPIST_STATUS_ASSIGNED,
		Therapist: toProtoUser(updated),
	}, nil
}

func (s *Server) AdminUnassignTherapistFromOrg(
	ctx context.Context,
	req *identityv1.AdminUnassignTherapistFromOrgRequest,
) (*emptypb.Empty, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	userID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}

	user, err := s.queries.GetUserByID(ctx, userID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if !user.OrganizationID.Valid || uuid.UUID(user.OrganizationID.Bytes) != orgID {
		return nil, status.Error(codes.FailedPrecondition, "USER_NOT_IN_ORGANIZATION")
	}
	if user.Role != db.UserRoleTHERAPIST {
		return nil, status.Error(codes.FailedPrecondition, "USER_NOT_THERAPIST")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	if err := qtx.CloseActiveSeatAssignmentForUser(ctx, userID); err != nil {
		return nil, status.Errorf(codes.Internal, "close seat: %v", err)
	}
	// No sqlc query unlinks a user (the invite path only ever links), and
	// LinkUserToOrganization takes a non-nullable org. Raw UPDATE, same
	// guard as the sqlc original: never resurrect a deleted row.
	if _, err := tx.Exec(ctx,
		`UPDATE users SET organization_id = NULL
		  WHERE id = $1 AND deleted_at IS NULL`, userID,
	); err != nil {
		return nil, status.Errorf(codes.Internal, "unlink user: %v", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "tx commit: %v", err)
	}

	if err := s.writeAuditEvent(ctx, caller,
		"organization.unassign_therapist", "user",
		&userID, &orgID, req.Reason,
		map[string]any{"email": user.Email},
	); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// therapistTransferWarning gathers what a move would cost, so the admin
// confirms with the numbers in front of them rather than blind.
//
// sessions and usage_events belong to clinical-svc and billing-svc
// respectively, but live in the same PG instance; this is a read-only
// aggregate for an admin-only screen. Same-instance precedent:
// AdminSetOrganizationStatus writes subscriptions directly (admin.go).
func (s *Server) therapistTransferWarning(
	ctx context.Context,
	userID, currentOrg uuid.UUID,
) (*identityv1.TherapistTransferWarning, error) {
	out := &identityv1.TherapistTransferWarning{
		CurrentOrganizationId: currentOrg.String(),
	}

	if org, err := s.queries.GetOrganizationByID(ctx, currentOrg); err == nil {
		out.CurrentOrganizationName = org.LegalName
	}

	var (
		total     int64
		billable  int64
		tokens    int64
		lastAt    pgtype.Timestamptz
		holdsSeat bool
	)
	if err := s.pool.QueryRow(ctx,
		`SELECT COUNT(*)                                  AS total,
		        COUNT(ue.session_id)                      AS billable,
		        COALESCE(SUM(ue.tokens_consumed), 0)::bigint AS tokens,
		        MAX(s.created_at)                         AS last_at
		   FROM sessions s
		   LEFT JOIN usage_events ue ON ue.session_id = s.id
		  WHERE s.therapist_id = $1`, userID,
	).Scan(&total, &billable, &tokens, &lastAt); err != nil {
		return nil, status.Errorf(codes.Internal, "session stats: %v", err)
	}
	if err := s.pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM seat_assignments
		                 WHERE user_id = $1 AND unassigned_at IS NULL)`, userID,
	).Scan(&holdsSeat); err != nil {
		return nil, status.Errorf(codes.Internal, "seat lookup: %v", err)
	}

	out.TotalSessions = int32(total)
	out.BillableSessions = int32(billable)
	out.TokensConsumed = int32(tokens)
	out.HoldsActiveSeat = holdsSeat
	if lastAt.Valid {
		out.LastSessionAt = timestamppb.New(lastAt.Time)
	}
	return out, nil
}

// resolveSeatAllocation picks the allocation the therapist should occupy.
// Explicit id wins. Otherwise: exactly one allocation is unambiguous, no
// allocations means the org simply doesn't track seats (the
// allocation-less invite path does the same), and several allocations
// need the caller to say which plan they mean.
func (s *Server) resolveSeatAllocation(
	ctx context.Context,
	orgID uuid.UUID,
	explicit string,
) (uuid.UUID, error) {
	if strings.TrimSpace(explicit) != "" {
		id, err := uuid.Parse(explicit)
		if err != nil {
			return uuid.Nil, status.Error(codes.InvalidArgument, "invalid seat_allocation_id")
		}
		return id, nil
	}

	rows, err := s.pool.Query(ctx,
		`SELECT id FROM org_seat_allocations WHERE organization_id = $1`, orgID)
	if err != nil {
		return uuid.Nil, status.Errorf(codes.Internal, "list seat allocations: %v", err)
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return uuid.Nil, status.Errorf(codes.Internal, "scan seat allocation: %v", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return uuid.Nil, status.Errorf(codes.Internal, "list seat allocations: %v", err)
	}

	switch len(ids) {
	case 0:
		return uuid.Nil, nil
	case 1:
		return ids[0], nil
	default:
		return uuid.Nil, status.Error(codes.InvalidArgument,
			"SEAT_ALLOCATION_REQUIRED")
	}
}
