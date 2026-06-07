package grpc

import (
	"context"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// RecordConsent logs a user consent choice (TOS, MARKETING, RECORDING) for auditing.
func (s *Server) RecordConsent(ctx context.Context, req *identityv1.RecordConsentRequest) (*identityv1.RecordConsentResponse, error) {
	caller, err := s.resolveCaller(ctx)
	if err != nil {
		return nil, err
	}

	targetUserID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	if req.ConsentType == "" {
		return nil, status.Error(codes.InvalidArgument, "consent_type is required")
	}

	// Auth check:
	// 1. User can record consent for themselves.
	// 2. Therapist can record consent for a patient.
	// 3. Superwizor Admin can record consent for any user.
	isSelf := caller.userID == targetUserID
	isAdmin := caller.role == db.UserRoleSUPERWIZORADMIN
	isTherapistRecordingPatient := false

	if !isSelf && !isAdmin {
		// Fetch target user to check their role
		targetUser, err := s.queries.GetUserByID(ctx, targetUserID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, status.Error(codes.NotFound, "target user not found")
			}
			return nil, status.Errorf(codes.Internal, "fetch target user: %v", err)
		}

		if caller.role == db.UserRoleTHERAPIST && targetUser.Role == db.UserRolePATIENT {
			isTherapistRecordingPatient = true
		}
	}

	if !isSelf && !isAdmin && !isTherapistRecordingPatient {
		return nil, status.Error(codes.PermissionDenied, "unauthorized to record consent for this user")
	}

	// Insert into DB
	row, err := s.queries.RecordConsent(ctx, db.RecordConsentParams{
		UserID:         targetUserID,
		ConsentType:    req.ConsentType,
		Granted:        req.Granted,
		ConsentVersion: &req.ConsentVersion,
		IpAddress:      &req.IpAddress,
		UserAgent:      &req.UserAgent,
	})
	if err != nil {
		slog.ErrorContext(ctx, "failed to record consent", "error", err, "user_id", targetUserID)
		return nil, status.Errorf(codes.Internal, "failed to record consent: %v", err)
	}

	slog.InfoContext(ctx, "recorded consent choice",
		"consent_id", row.ID.String(),
		"user_id", targetUserID.String(),
		"consent_type", req.ConsentType,
		"granted", req.Granted,
		"version", req.ConsentVersion,
	)

	return &identityv1.RecordConsentResponse{
		ConsentRecordId: row.ID.String(),
		RecordedAt:      timestamppb.New(row.RecordedAt),
	}, nil
}
