package grpc

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// SetTherapistStatus is the reversible activation toggle (docs/38 §4).
// ORG_ADMIN only; target must be a THERAPIST in the caller's org.
//
// Deactivate (is_active=false): closes the therapist's open seat
// assignment (frees the seat for someone else) and flips users.is_active
// — from the next token validation on, the therapist gets
// PermissionDenied "ACCOUNT_DEACTIVATED". Clinical data stays untouched;
// RemoveTherapist (soft-delete) remains the RODO path.
//
// Reactivate (is_active=true): re-occupies a seat in the therapist's
// most recent allocation. FailedPrecondition "SEATS_EXHAUSTED" when that
// allocation is full. A therapist who never had a seat (org without
// allocations) just flips back on.
func (s *Server) SetTherapistStatus(ctx context.Context, req *identityv1.SetTherapistStatusRequest) (*identityv1.User, error) {
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

	// Scope check mirrors RemoveTherapist: target must be a THERAPIST in
	// the caller's org; anything else is NotFound/FailedPrecondition.
	target, err := s.queries.GetUserByID(ctx, userID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if !target.OrganizationID.Valid || uuid.UUID(target.OrganizationID.Bytes) != *caller.organizationID {
		return nil, status.Error(codes.PermissionDenied, "user is not in your organization")
	}
	if target.Role != "THERAPIST" {
		return nil, status.Error(codes.FailedPrecondition, "can only toggle THERAPIST accounts")
	}
	if target.IsActive == req.IsActive {
		return toProtoUser(target), nil // idempotent no-op
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	if req.IsActive {
		// Reactivation: re-occupy a seat in the most recent allocation,
		// subject to the free-seat check under the allocation row lock.
		last, err := qtx.GetLatestSeatAssignmentForUser(ctx, userID)
		switch {
		case err == nil:
			alloc, err := qtx.GetSeatAllocationForUpdate(ctx, last.AllocationID)
			if err != nil {
				return nil, status.Errorf(codes.Internal, "load allocation: %v", err)
			}
			if err := checkSeatAvailable(ctx, qtx, alloc); err != nil {
				return nil, err
			}
			if _, err := qtx.CreateSeatAssignment(ctx, db.CreateSeatAssignmentParams{
				UserID:       userID,
				AllocationID: alloc.ID,
			}); err != nil {
				return nil, status.Errorf(codes.Internal, "create seat assignment: %v", err)
			}
		case errors.Is(err, pgx.ErrNoRows):
			// Never had a seat (org without allocations) — just flip on.
		default:
			return nil, status.Errorf(codes.Internal, "lookup seat assignment: %v", err)
		}
	} else {
		// Deactivation frees the seat. Idempotent if no open assignment.
		if err := qtx.CloseActiveSeatAssignmentForUser(ctx, userID); err != nil {
			return nil, status.Errorf(codes.Internal, "close seat assignment: %v", err)
		}
	}

	updated, err := qtx.SetUserActiveStatus(ctx, db.SetUserActiveStatusParams{
		ID:       userID,
		IsActive: req.IsActive,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "set active status: %v", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	return toProtoUser(updated), nil
}

// checkSeatAvailable enforces the occupancy formula (docs/38 §3):
//
//	active seat_assignments + pending unexpired invitations < seats
//
// Callers MUST hold the allocation row lock (GetSeatAllocationForUpdate)
// in the same tx so the check-then-insert is race-free. Returns
// FailedPrecondition "SEATS_EXHAUSTED" — the same contract the web-app
// and Flutter surface as "brak wolnych miejsc w planie".
func checkSeatAvailable(ctx context.Context, q db.Querier, alloc db.OrgSeatAllocation) error {
	assigned, err := q.CountActiveSeatAssignments(ctx, alloc.ID)
	if err != nil {
		return status.Errorf(codes.Internal, "count seat assignments: %v", err)
	}
	pending, err := q.CountPendingInvitationsForAllocation(ctx, pgtype.UUID{Bytes: alloc.ID, Valid: true})
	if err != nil {
		return status.Errorf(codes.Internal, "count pending invitations: %v", err)
	}
	if assigned+pending >= int64(alloc.Seats) {
		return status.Errorf(codes.FailedPrecondition,
			"SEATS_EXHAUSTED: %d/%d seats in use (including pending invitations)",
			assigned+pending, alloc.Seats)
	}
	return nil
}

// checkSeatAvailableExcluding — same as checkSeatAvailable, but ignores
// one specific PENDING invitation. Used by the re-invite path: the
// refreshed row's old reservation dissolves in the same UPDATE, so it
// must not count against the target allocation (which may be the very
// allocation it currently holds).
func checkSeatAvailableExcluding(ctx context.Context, q db.Querier, alloc db.OrgSeatAllocation, excludeInvitationID uuid.UUID) error {
	assigned, err := q.CountActiveSeatAssignments(ctx, alloc.ID)
	if err != nil {
		return status.Errorf(codes.Internal, "count seat assignments: %v", err)
	}
	pending, err := q.CountPendingInvitationsForAllocationExcluding(ctx, db.CountPendingInvitationsForAllocationExcludingParams{
		AllocationID: pgtype.UUID{Bytes: alloc.ID, Valid: true},
		ID:           excludeInvitationID,
	})
	if err != nil {
		return status.Errorf(codes.Internal, "count pending invitations: %v", err)
	}
	if assigned+pending >= int64(alloc.Seats) {
		return status.Errorf(codes.FailedPrecondition,
			"SEATS_EXHAUSTED: %d/%d seats in use (including pending invitations)",
			assigned+pending, alloc.Seats)
	}
	return nil
}
