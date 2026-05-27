package grpc

import (
	"context"
	"errors"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
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
	queries  *db.Queries
	pool     *pgxpool.Pool
	auth     *firebase.AuthClient
	version  string
	emailer  InvitationEmailer
	// acceptURLBase is the public origin that hosts the accept-invite
	// page (e.g. https://app.superwizor.ai). Combined with the token
	// to form the link sent to invitees.
	acceptURLBase string
}

func NewServer(pool *pgxpool.Pool, queries *db.Queries, auth *firebase.AuthClient, version string) *Server {
	return &Server{
		pool:          pool,
		queries:       queries,
		auth:          auth,
		version:       version,
		emailer:       NoopEmailSender{},
		acceptURLBase: "https://app.superwizor.ai",
	}
}

// WithEmailer overrides the InvitationEmailer — used in commit 7 to
// wire the real Resend-backed sender, and in tests to capture sent
// emails.
func (s *Server) WithEmailer(e InvitationEmailer) *Server { s.emailer = e; return s }

// WithAcceptURLBase overrides the origin used to build invite links.
// Defaults to https://app.superwizor.ai; CI / local dev passes a
// localhost value.
func (s *Server) WithAcceptURLBase(base string) *Server { s.acceptURLBase = base; return s }

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

	// All writes happen in a single tx so a partial provisioning
	// (e.g. user row created but org/subscription failed) doesn't
	// leave the system in a half-state.
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := s.queries.WithTx(tx)

	// Therapist creation path requires both fields per the partial
	// CHECK on users (migration 000013). Patient rows go through
	// clinical-svc.CreatePatientUser, which leaves these NULL — not
	// this RPC.
	user, err := qtx.CreateUser(ctx, db.CreateUserParams{
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

	// Auto-provision a Trial subscription for every new THERAPIST.
	// CreateUserRequest has no organization_id field today, so this
	// always fires on therapist signup. Patients are skipped — their
	// quota comes from the therapist's org via patient_files.
	if dbRole == "THERAPIST" {
		if err := s.provisionTrialOrgAndSub(ctx, tx, &user, req); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	return toProtoUser(user), nil
}

// provisionTrialOrgAndSub creates a SOLO organization, links the user
// to it, and seeds a TRIAL subscription + usage_counter. Runs inside
// the caller's tx so the whole CreateUser is atomic — a failed billing
// provisioning rolls back the user row too. Mutates `user` to reflect
// the assigned organization_id so the returned proto carries it.
//
// Plan tier: TRIAL (migrations 000032 + 000033). 3 tokens, no
// auto-renewal — period_end is 100 years out so the existing
// quota-period mechanics work unchanged but the user effectively keeps
// the trial pool until they upgrade. Upgrade flow rewrites this row
// to a paid tier and resets the counter.
func (s *Server) provisionTrialOrgAndSub(ctx context.Context, tx pgx.Tx, user *db.User, req *identityv1.CreateUserRequest) error {
	// Build display name: "First Last Org". Fall back to email-local
	// if names are empty (shouldn't happen for therapists, but keeps
	// us defensive — legal_name is NOT NULL on organizations).
	displayName := strings.TrimSpace(req.FirstName + " " + req.LastName)
	if displayName == "" {
		displayName = strings.TrimSpace(req.Email)
		if at := strings.IndexByte(displayName, '@'); at > 0 {
			displayName = displayName[:at]
		}
	}
	orgName := displayName + " Org"

	// Create organization. type=SOLO since this is a single-therapist
	// trial; CLINIC plans upgrade via a different flow that switches
	// organization_type and adds licenses.
	var orgID uuid.UUID
	if err := tx.QueryRow(ctx,
		`INSERT INTO organizations (legal_name, type)
		 VALUES ($1, 'SOLO')
		 RETURNING id`,
		orgName,
	).Scan(&orgID); err != nil {
		slog.ErrorContext(ctx, "provisionTrial: create org", "error", err, "name", orgName)
		return status.Errorf(codes.Internal, "create org: %v", err)
	}

	// Link user → org. Use RETURNING so the in-memory user struct
	// reflects the new organization_id without an extra SELECT.
	if err := tx.QueryRow(ctx,
		`UPDATE users SET organization_id = $1 WHERE id = $2 RETURNING organization_id`,
		orgID, user.ID,
	).Scan(&user.OrganizationID); err != nil {
		slog.ErrorContext(ctx, "provisionTrial: link user to org", "error", err)
		return status.Errorf(codes.Internal, "link org: %v", err)
	}

	// Look up the TRIAL plan. Seeded by migration 000033.
	var planID uuid.UUID
	var tokensPerPeriod int32
	if err := tx.QueryRow(ctx,
		`SELECT id, tokens_per_period FROM subscription_plans
		 WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE
		 LIMIT 1`,
	).Scan(&planID, &tokensPerPeriod); err != nil {
		slog.ErrorContext(ctx, "provisionTrial: lookup trial plan", "error", err)
		return status.Errorf(codes.Internal, "lookup trial plan: %v", err)
	}

	// Create the subscription. provider=MANUAL (no Stripe), status=TRIALING
	// — partial unique index idx_subscriptions_one_active_per_org accepts
	// TRIALING as "active for the org" so no parallel paid sub can exist
	// alongside without upgrade-time bookkeeping.
	// current_period_end ~100 years out keeps the counter from auto-rolling.
	var subID uuid.UUID
	var periodStart, periodEnd pgtype.Timestamptz
	if err := tx.QueryRow(ctx,
		`INSERT INTO subscriptions (
		     organization_id, plan_id, provider, provider_subscription_id,
		     status, current_period_start, current_period_end
		 ) VALUES (
		     $1, $2, 'MANUAL', $3,
		     'TRIALING', NOW(), NOW() + INTERVAL '100 years'
		 )
		 RETURNING id, current_period_start, current_period_end`,
		orgID, planID, "trial-"+orgID.String(),
	).Scan(&subID, &periodStart, &periodEnd); err != nil {
		slog.ErrorContext(ctx, "provisionTrial: create subscription", "error", err)
		return status.Errorf(codes.Internal, "create subscription: %v", err)
	}

	// Create the usage counter for the trial period. tokens_limit comes
	// from the plan row so changing the trial size never requires code.
	if _, err := tx.Exec(ctx,
		`INSERT INTO usage_counters (
		     subscription_id, period_start, period_end, tokens_limit
		 ) VALUES ($1, $2, $3, $4)`,
		subID, periodStart, periodEnd, tokensPerPeriod,
	); err != nil {
		slog.ErrorContext(ctx, "provisionTrial: create counter", "error", err)
		return status.Errorf(codes.Internal, "create counter: %v", err)
	}

	slog.InfoContext(ctx, "provisionTrial: trial subscription seeded",
		"user_id", user.ID, "org_id", orgID, "subscription_id", subID,
		"tokens_per_period", tokensPerPeriod, "org_name", orgName)
	return nil
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
