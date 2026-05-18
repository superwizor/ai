package grpc

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/firebase"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/domain"
)

type Server struct {
	identityv1.UnimplementedIdentityServiceServer
	queries *db.Queries
	auth    *firebase.AuthClient
	version string
}

func NewServer(queries *db.Queries, auth *firebase.AuthClient, version string) *Server {
	return &Server{queries: queries, auth: auth, version: version}
}

func (s *Server) HealthCheck(ctx context.Context, _ *emptypb.Empty) (*identityv1.HealthCheckResponse, error) {
	return &identityv1.HealthCheckResponse{
		Status:  "OK",
		Version: s.version,
	}, nil
}

func (s *Server) ValidateToken(ctx context.Context, req *identityv1.ValidateTokenRequest) (*identityv1.UserContext, error) {
	if req.FirebaseIdToken == "" {
		return nil, status.Error(codes.InvalidArgument, "firebase_id_token is required")
	}

	firebaseUID, _, err := s.auth.VerifyToken(ctx, req.FirebaseIdToken)
	if err != nil {
		if errors.Is(err, domain.ErrTokenExpired) {
			return nil, status.Error(codes.Unauthenticated, "token expired")
		}
		return nil, status.Error(codes.Unauthenticated, "invalid token")
	}

	user, err := s.queries.GetUserByFirebaseUID(ctx, &firebaseUID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not registered")
	}

	// Per migration 000013, users.firebase_uid and users.email are
	// nullable for patient rows (which don't authenticate). Therapist
	// rows still have both populated — the partial CHECK constraint
	// enforces that — but the Go types are *string so we dereference
	// defensively. Empty strings on the wire are fine; clients already
	// treat them as "unset" for the same reason patient_users don't
	// have these fields surfaced in the patient app.
	resp := &identityv1.UserContext{
		UserId:      user.ID.String(),
		FirebaseUid: derefString(user.FirebaseUid),
		Role:        toProtoRole(user.Role),
		Email:       derefString(user.Email),
	}
	if user.OrganizationID.Valid {
		resp.OrganizationId = uuid.UUID(user.OrganizationID.Bytes).String()
	}
	return resp, nil
}

func (s *Server) GetUser(ctx context.Context, req *identityv1.GetUserRequest) (*identityv1.User, error) {
	id, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	user, err := s.queries.GetUserByID(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	return toProtoUser(user), nil
}

func (s *Server) GetUserByFirebaseUID(ctx context.Context, req *identityv1.GetUserByFirebaseUIDRequest) (*identityv1.User, error) {
	if req.FirebaseUid == "" {
		return nil, status.Error(codes.InvalidArgument, "firebase_uid is required")
	}
	user, err := s.queries.GetUserByFirebaseUID(ctx, &req.FirebaseUid)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	return toProtoUser(user), nil
}

func (s *Server) CreateUser(ctx context.Context, req *identityv1.CreateUserRequest) (*identityv1.User, error) {
	// Walidacja
	if req.FirebaseUid == "" || req.Email == "" {
		return nil, status.Error(codes.InvalidArgument, "firebase_uid and email required")
	}

	if !req.HasAcceptedTos {
		return nil, status.Error(codes.FailedPrecondition, "must accept ToS")
	}

	dbRole := db.UserRole("THERAPIST")
	if req.Role == identityv1.UserRole_USER_ROLE_PATIENT {
		dbRole = db.UserRole("PATIENT")
	}

	// Therapist creation path requires both fields per the partial
	// CHECK on users (migration 000013). Patient rows go through
	// clinical-svc.CreatePatientUser, which leaves these NULL — not
	// this RPC.
	user, err := s.queries.CreateUser(ctx, db.CreateUserParams{
		Role:           dbRole,
		FirebaseUid:    &req.FirebaseUid,
		Email:          &req.Email,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		UiLanguage:     req.UiLanguage,
		Timezone:       req.Timezone,
		HasAcceptedTos: req.HasAcceptedTos,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return toProtoUser(user), nil
}

func (s *Server) UpdateProfile(ctx context.Context, req *identityv1.UpdateProfileRequest) (*identityv1.User, error) {
	id, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	user, err := s.queries.UpdateProfile(ctx, db.UpdateProfileParams{
		ID:                id,
		FirstName:         &req.FirstName,
		LastName:          &req.LastName,
		ProfessionalTitle: &req.ProfessionalTitle,
		CredentialsNumber: &req.CredentialsNumber,
		Biography:         &req.Biography,
		PhoneNumber:       &req.PhoneNumber,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return toProtoUser(user), nil
}

func (s *Server) CheckPermission(ctx context.Context, req *identityv1.CheckPermissionRequest) (*identityv1.PermissionDecision, error) {
	// Faza 1: tylko basic checks
	// Faza 2 doda full RBAC z conditions
	if req.UserId == "" || req.ResourceType == "" || req.Action == "" {
		return nil, status.Error(codes.InvalidArgument, "missing required fields")
	}

	// W Fazie 1: tylko właściciel ma dostęp do swoich rzeczy
	// Detail logic jest po stronie clinical-svc --- identity-svc tylko zwraca user info

	return &identityv1.PermissionDecision{
		Allowed: true,
		Reason:  "ok",
	}, nil
}

// Helpers

func toProtoRole(r db.UserRole) identityv1.UserRole {
	switch r {
	case "THERAPIST":
		return identityv1.UserRole_USER_ROLE_THERAPIST
	case "PATIENT":
		return identityv1.UserRole_USER_ROLE_PATIENT
	}
	return identityv1.UserRole_USER_ROLE_UNSPECIFIED
}

// derefString safely dereferences a *string column (nullable after
// migration 000013 for patient rows). Returns "" when nil so wire
// messages never carry phantom values.
func derefString(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func toProtoUser(u db.User) *identityv1.User {
	resp := &identityv1.User{
		Id:              u.ID.String(),
		Role:            toProtoRole(u.Role),
		FirebaseUid:     derefString(u.FirebaseUid),
		Email:           derefString(u.Email),
		IsEmailVerified: u.IsEmailVerified,
		FirstName:       u.FirstName,
		LastName:        u.LastName,
		UiLanguage:      u.UiLanguage,
		Timezone:        u.Timezone,
		HasAcceptedTos:  u.HasAcceptedTos,
		CreatedAt:       timestamppb.New(u.CreatedAt),
	}
	if u.OrganizationID.Valid {
		resp.OrganizationId = uuid.UUID(u.OrganizationID.Bytes).String()
	}
	if u.PhoneNumber != nil {
		resp.PhoneNumber = *u.PhoneNumber
	}
	if u.ProfessionalTitle != nil {
		resp.ProfessionalTitle = *u.ProfessionalTitle
	}
	if u.CredentialsNumber != nil {
		resp.CredentialsNumber = *u.CredentialsNumber
	}
	if u.Biography != nil {
		resp.Biography = *u.Biography
	}
	if u.AvatarUrl != nil {
		resp.AvatarUrl = *u.AvatarUrl
	}
	if u.DefaultModalityID.Valid {
		resp.DefaultModalityId = uuid.UUID(u.DefaultModalityID.Bytes).String()
	}
	if u.BillingAddressID.Valid {
		resp.BillingAddressId = uuid.UUID(u.BillingAddressID.Bytes).String()
	}
	resp.HasMarketingConsent = u.HasMarketingConsent
	return resp
}
