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
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/domain"
)

// TokenVerifier abstracts Firebase Auth token verification so
// production uses the real firebase.AuthClient and tests can inject
// a mock. The concrete *firebase.AuthClient already satisfies this.
type TokenVerifier interface {
	VerifyToken(ctx context.Context, idToken string) (uid string, claims map[string]any, err error)
	CustomToken(ctx context.Context, uid string) (string, error)
	UserExistsByEmail(ctx context.Context, email string) (bool, error)
}

type Server struct {
	identityv1.UnimplementedIdentityServiceServer
	queries  db.Querier
	pool     *pgxpool.Pool
	auth     TokenVerifier
	version  string
	emailer  InvitationEmailer
	collector *analytics.Collector
	// acceptURLBase is the public origin that hosts the accept-invite
	// page (e.g. https://app.superwizor.ai). Combined with the token
	// to form the link sent to invitees.
	acceptURLBase string
}

func NewServer(pool *pgxpool.Pool, queries db.Querier, auth TokenVerifier, version string, collector *analytics.Collector) *Server {
	return &Server{
		pool:          pool,
		queries:       queries,
		auth:          auth,
		version:       version,
		emailer:       NoopEmailSender{},
		collector:     collector,
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

	firebaseUID, claims, err := s.auth.VerifyToken(ctx, req.FirebaseIdToken)
	if err != nil {
		if errors.Is(err, domain.ErrTokenExpired) {
			return nil, status.Error(codes.Unauthenticated, "token expired")
		}
		return nil, status.Error(codes.Unauthenticated, "invalid token")
	}

	user, err := s.queries.GetUserByFirebaseUID(ctx, &firebaseUID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Auto-link by email — ONLY when Firebase confirms the email
			// is verified. Without this guard an attacker could register a
			// Firebase account with the victim's email (without verifying
			// it), call ValidateToken, and hijack the existing PG user row.
			emailVerified, _ := claims["email_verified"].(bool)
			if emailVal, ok := claims["email"].(string); ok && emailVal != "" && emailVerified {
				emailLC := strings.ToLower(strings.TrimSpace(emailVal))
				existingUser, errEmail := s.queries.GetUserByEmail(ctx, &emailLC)
				if errEmail == nil {
					// Update their firebase_uid to link the accounts
					_, errUpdate := s.pool.Exec(ctx,
						`UPDATE users SET firebase_uid = $1 WHERE id = $2 AND deleted_at IS NULL`,
						firebaseUID, existingUser.ID,
					)
					if errUpdate == nil {
						slog.InfoContext(ctx, "auto-linked user on the fly", "email", emailLC, "firebase_uid", firebaseUID, "user_id", existingUser.ID)
						user = existingUser
						user.FirebaseUid = &firebaseUID
						err = nil // clear error to proceed returning user context
					} else {
						slog.ErrorContext(ctx, "failed to auto-link user", "error", errUpdate, "email", emailLC)
					}
				}
			}
		}
		if err != nil {
			return nil, status.Error(codes.NotFound, "user not registered")
		}
	}

	// Synchronize email from Firebase claims if it differs from the database email
	if emailVal, ok := claims["email"].(string); ok && emailVal != "" {
		emailLC := strings.ToLower(strings.TrimSpace(emailVal))
		currentEmail := strings.ToLower(strings.TrimSpace(derefString(user.Email)))
		if emailLC != currentEmail {
			_, errUpdate := s.pool.Exec(ctx,
				`UPDATE users SET email = $1 WHERE id = $2 AND deleted_at IS NULL`,
				emailLC, user.ID,
			)
			if errUpdate == nil {
				slog.InfoContext(ctx, "synced user email from firebase claims on the fly",
					"old_email", currentEmail, "new_email", emailLC, "user_id", user.ID)
				user.Email = &emailLC
			} else {
				slog.ErrorContext(ctx, "failed to sync user email", "error", errUpdate, "user_id", user.ID)
			}
		}
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

func (s *Server) CheckEmailExists(ctx context.Context, req *identityv1.CheckEmailExistsRequest) (*identityv1.CheckEmailExistsResponse, error) {
	if req.Email == "" {
		return nil, status.Error(codes.InvalidArgument, "email is required")
	}

	emailLC := strings.ToLower(strings.TrimSpace(req.Email))
	_, err := s.queries.GetUserByEmail(ctx, &emailLC)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &identityv1.CheckEmailExistsResponse{Exists: false, IsPendingDeletion: false}, nil
		}
		return nil, status.Errorf(codes.Internal, "database query failed: %v", err)
	}

	// Email exists in database. Check if user exists in Firebase Auth.
	existsInAuth, err := s.auth.UserExistsByEmail(ctx, emailLC)
	if err != nil {
		slog.Error("failed to check user in firebase auth", "email", emailLC, "err", err)
		return &identityv1.CheckEmailExistsResponse{Exists: true, IsPendingDeletion: false}, nil
	}

	return &identityv1.CheckEmailExistsResponse{
		Exists:            true,
		IsPendingDeletion: !existsInAuth,
	}, nil
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
	qtx := db.New(tx)

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

	// Auto-provision a subscription for every new THERAPIST.
	// initial_plan_tier selects BETA vs TRIAL. Paid plans go through
	// Stripe Checkout (separate flow) — the user starts with a Trial
	// and the Stripe webhook upgrades them.
	if dbRole == "THERAPIST" {
		planTier := strings.ToUpper(req.InitialPlanTier)
		if planTier == "BETA" {
			if err := s.provisionPlanOrgAndSub(ctx, tx, &user, req, "BETA"); err != nil {
				return nil, err
			}
		} else {
			if err := s.provisionTrialOrgAndSub(ctx, tx, &user, req); err != nil {
				return nil, err
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Wyciągnięcie auth_provider do celów analitycznych (zdarzenie therapist.registered)
	authProvider := "password" // domyślny fallback
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		auths := md.Get("authorization")
		if len(auths) > 0 {
			token := auths[0]
			if len(token) > 7 && (strings.HasPrefix(token, "Bearer ") || strings.HasPrefix(token, "bearer ")) {
				token = token[7:]
			}
			_, claims, errVerify := s.auth.VerifyToken(ctx, token)
			if errVerify == nil {
				if fb, ok := claims["firebase"].(map[string]any); ok {
					if prov, ok := fb["sign_in_provider"].(string); ok {
						authProvider = prov
					}
				}
				if authProvider == "" {
					if prov, ok := claims["sign_in_provider"].(string); ok {
						authProvider = prov
					}
				}
			}
		}
	}

	if dbRole == "THERAPIST" && s.collector != nil {
		orgIDPtr := func() *uuid.UUID {
			if user.OrganizationID.Valid {
				id := uuid.UUID(user.OrganizationID.Bytes)
				return &id
			}
			return nil
		}()
		s.collector.Track(ctx, analytics.Event{
			Name:           "therapist.registered",
			TherapistID:    &user.ID,
			OrganizationID: orgIDPtr,
			Properties: map[string]any{
				"auth_provider": authProvider,
			},
			Source: "server",
		})
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
	orgName := displayName + " - Praktyka"

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
	// current_period_end = NOW() + 30 days — trial hard limit per business rules.
	// After 30 days the cron won't find a renewal candidate (trial plan has
	// max 1 period implied) and unused sessions simply expire.
	var subID uuid.UUID
	var periodStart, periodEnd pgtype.Timestamptz
	if err := tx.QueryRow(ctx,
		`INSERT INTO subscriptions (
		     organization_id, plan_id, provider, provider_subscription_id,
		     status, current_period_start, current_period_end
		 ) VALUES (
		     $1, $2, 'MANUAL', $3,
		     'TRIALING', NOW(), NOW() + INTERVAL '30 days'
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

// provisionPlanOrgAndSub creates a SOLO org and provisions a
// subscription with the specified plan tier. Currently used for BETA
// signups. Unlike provisionTrialOrgAndSub, the period is 30 days
// (not 100 years) so the cron-based auto-renewal can work.
func (s *Server) provisionPlanOrgAndSub(ctx context.Context, tx pgx.Tx, user *db.User, req *identityv1.CreateUserRequest, tier string) error {
	displayName := strings.TrimSpace(req.FirstName + " " + req.LastName)
	if displayName == "" {
		displayName = strings.TrimSpace(req.Email)
		if at := strings.IndexByte(displayName, '@'); at > 0 {
			displayName = displayName[:at]
		}
	}
	orgName := displayName + " - Praktyka"

	var orgID uuid.UUID
	if err := tx.QueryRow(ctx,
		`INSERT INTO organizations (legal_name, type)
		 VALUES ($1, 'SOLO')
		 RETURNING id`,
		orgName,
	).Scan(&orgID); err != nil {
		slog.ErrorContext(ctx, "provisionPlan: create org", "error", err, "name", orgName, "tier", tier)
		return status.Errorf(codes.Internal, "create org: %v", err)
	}

	if err := tx.QueryRow(ctx,
		`UPDATE users SET organization_id = $1 WHERE id = $2 RETURNING organization_id`,
		orgID, user.ID,
	).Scan(&user.OrganizationID); err != nil {
		slog.ErrorContext(ctx, "provisionPlan: link user to org", "error", err, "tier", tier)
		return status.Errorf(codes.Internal, "link org: %v", err)
	}

	var planID uuid.UUID
	var tokensPerPeriod int32
	if err := tx.QueryRow(ctx,
		`SELECT id, tokens_per_period FROM subscription_plans
		 WHERE tier = $1 AND cycle = 'MONTHLY' AND is_active = TRUE
		 LIMIT 1`, tier,
	).Scan(&planID, &tokensPerPeriod); err != nil {
		slog.ErrorContext(ctx, "provisionPlan: lookup plan", "error", err, "tier", tier)
		return status.Errorf(codes.Internal, "lookup %s plan: %v", tier, err)
	}

	// BETA gets a real 30-day period (auto-renewal cron handles the
	// second month). TRIAL keeps 100 years per provisionTrialOrgAndSub.
	periodInterval := "30 days"

	var subID uuid.UUID
	var periodStart, periodEnd pgtype.Timestamptz
	if err := tx.QueryRow(ctx,
		`INSERT INTO subscriptions (
		     organization_id, plan_id, provider, provider_subscription_id,
		     status, current_period_start, current_period_end
		 ) VALUES (
		     $1, $2, 'MANUAL', $3,
		     'TRIALING', NOW(), NOW() + $4::INTERVAL
		 )
		 RETURNING id, current_period_start, current_period_end`,
		orgID, planID, strings.ToLower(tier)+"-"+orgID.String(), periodInterval,
	).Scan(&subID, &periodStart, &periodEnd); err != nil {
		slog.ErrorContext(ctx, "provisionPlan: create subscription", "error", err, "tier", tier)
		return status.Errorf(codes.Internal, "create subscription: %v", err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO usage_counters (
		     subscription_id, period_start, period_end, tokens_limit
		 ) VALUES ($1, $2, $3, $4)`,
		subID, periodStart, periodEnd, tokensPerPeriod,
	); err != nil {
		slog.ErrorContext(ctx, "provisionPlan: create counter", "error", err, "tier", tier)
		return status.Errorf(codes.Internal, "create counter: %v", err)
	}

	slog.InfoContext(ctx, "provisionPlan: subscription seeded",
		"user_id", user.ID, "org_id", orgID, "subscription_id", subID,
		"tier", tier, "tokens_per_period", tokensPerPeriod, "org_name", orgName)
	return nil
}

// UpdateProfile moved to profile.go with the docs/18 D2 contract
// (selective UPDATE; empty-string-on-legacy-fields = "don't change").

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
	case db.UserRoleORGADMIN:
		return identityv1.UserRole_USER_ROLE_ORG_ADMIN
	case db.UserRoleSUPERWIZORADMIN:
		return identityv1.UserRole_USER_ROLE_SUPERWIZOR_ADMIN
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
