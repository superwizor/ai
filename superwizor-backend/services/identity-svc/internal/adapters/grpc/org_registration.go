package grpc

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// RegisterOrganization is the public self-serve endpoint for clinic
// founders. Creates organisation + headquarters address + a single
// ORG_ADMIN user + Trial subscription in one PG tx.
//
// Auth: the caller has signed in to Firebase Auth first
// (`createUserWithEmailAndPassword` or one of the social OAuth flows).
// They send the resulting ID token in the Authorization header. We
// verify the token, derive firebase_uid from the verified claims, and
// (defensively) assert that it matches req.firebase_uid in the payload.
// The payload's firebase_uid is convenience — the auth metadata is the
// real source.
//
// Single-role MVP (docs/18 R4): the founder becomes role=ORG_ADMIN
// only. To also record sessions they invite themselves under a second
// email via the standard InviteTherapist flow.
//
// Idempotency: if a user with the same firebase_uid already exists,
// returns the existing org + user (treats the call as a no-op replay).
// This means a client can safely retry on a network blip during the
// tx without producing a duplicate org.
func (s *Server) RegisterOrganization(ctx context.Context, req *identityv1.RegisterOrganizationRequest) (*identityv1.RegisterOrganizationResponse, error) {
	if err := validateRegisterOrgRequest(req); err != nil {
		return nil, err
	}

	// Verify the Firebase token from gRPC metadata. Public endpoint
	// but the client MUST have authenticated to Firebase first.
	verifiedUID, err := s.verifyFirebaseTokenFromContext(ctx)
	if err != nil {
		return nil, err
	}
	if verifiedUID != req.FirebaseUid {
		return nil, status.Error(codes.InvalidArgument,
			"firebase_uid in payload does not match the authenticated token")
	}

	// Idempotency replay: if this firebase_uid already has a user row,
	// short-circuit and return their org. Caller can safely retry.
	existing, err := s.queries.GetUserByFirebaseUID(ctx, &verifiedUID)
	if err == nil {
		return s.assembleExistingOrgRegistration(ctx, existing)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "lookup existing user: %v", err)
	}

	// Fresh registration — single tx so any failure rolls back the
	// whole org + user + subscription + counter.
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := s.queries.WithTx(tx)

	// 1. Headquarters address (org's billing address comes later as
	//    a separate edit; HQ is the only address required at signup).
	addrParams, err := buildCreateAddressParams(req.HeadquartersAddress)
	if err != nil {
		return nil, err
	}
	addr, err := qtx.CreateAddress(ctx, addrParams)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create address: %v", err)
	}

	// 2. Organisation. type defaults to SOLO when the payload
	//    UNSPECIFIED — typical for the /register/therapist path
	//    which doesn't surface type-picking UI. The dedicated
	//    /register/organization (clinic) page sends CLINIC.
	orgParams := db.CreateOrganizationParams{
		LegalName:               req.LegalName,
		Type:                    fromProtoOrgType(req.Type),
		HeadquartersAddressID:   pgtype.UUID{Bytes: addr.ID, Valid: true},
	}
	if req.TaxId != "" {
		orgParams.TaxID = &req.TaxId
	}
	if req.VatIdEu != "" {
		orgParams.VatIDEu = &req.VatIdEu
	}
	org, err := qtx.CreateOrganization(ctx, orgParams)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create organization: %v", err)
	}

	// 3. Founder user — role=ORG_ADMIN only (no THERAPIST per docs/18 R4).
	userParams := db.CreateUserParams{
		Role:           db.UserRoleORGADMIN,
		FirebaseUid:    &verifiedUID,
		Email:          &req.Email,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		UiLanguage:     defaultStr(req.UiLanguage, "pl"),
		Timezone:       defaultStr(req.Timezone, "Europe/Warsaw"),
		HasAcceptedTos: req.HasAcceptedTos,
	}
	user, err := qtx.CreateUser(ctx, userParams)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create user: %v", err)
	}
	if err := qtx.LinkUserToOrganization(ctx, db.LinkUserToOrganizationParams{
		ID:             user.ID,
		OrganizationID: pgtype.UUID{Bytes: org.ID, Valid: true},
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "link user→org: %v", err)
	}
	user.OrganizationID = pgtype.UUID{Bytes: org.ID, Valid: true}

	// 4. Phone + marketing consent — these aren't in CreateUserParams
	//    but we want them set at registration time. Quick UPDATE
	//    inside the same tx.
	if req.PhoneNumber != "" || req.HasMarketingConsent {
		updParams := db.UpdateProfileParams{ID: user.ID}
		if req.PhoneNumber != "" {
			updParams.PhoneNumber = &req.PhoneNumber
		}
		if req.HasMarketingConsent {
			t := true
			updParams.HasMarketingConsent = &t
		}
		if updatedUser, err := qtx.UpdateProfile(ctx, updParams); err == nil {
			user = updatedUser
		}
		// Best-effort — failure here is non-fatal (we have the row).
	}

	// 5. Stamp the org's primary_admin_user_id.
	if err := qtx.SetOrganizationPrimaryAdmin(ctx, db.SetOrganizationPrimaryAdminParams{
		ID:                 org.ID,
		PrimaryAdminUserID: pgtype.UUID{Bytes: user.ID, Valid: true},
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "set primary admin: %v", err)
	}
	org.PrimaryAdminUserID = pgtype.UUID{Bytes: user.ID, Valid: true}

	// 6. Trial subscription + usage_counter — reuses the same raw-SQL
	//    inserts as the existing provisionTrialOrgAndSub helper
	//    (subscriptions + usage_counters tables belong to billing-svc
	//    semantically, but live in the same PG instance).
	if err := s.seedTrialForOrg(ctx, tx, org.ID); err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	return &identityv1.RegisterOrganizationResponse{
		User:         toProtoUser(user),
		Organization: toProtoOrganization(org, &addr, false),
	}, nil
}

// validateRegisterOrgRequest enforces the docs/18 §13.3 form contract
// at the wire layer. We're lenient on optional fields (vat_id_eu,
// region) but strict on what the table CHECKs require.
func validateRegisterOrgRequest(req *identityv1.RegisterOrganizationRequest) error {
	if req == nil {
		return status.Error(codes.InvalidArgument, "request is nil")
	}
	if req.FirebaseUid == "" {
		return status.Error(codes.InvalidArgument, "firebase_uid required")
	}
	if req.Email == "" {
		return status.Error(codes.InvalidArgument, "email required")
	}
	if req.FirstName == "" || req.LastName == "" {
		return status.Error(codes.InvalidArgument, "first_name and last_name required")
	}
	if req.LegalName == "" {
		return status.Error(codes.InvalidArgument, "legal_name required")
	}
	if !req.HasAcceptedTos {
		return status.Error(codes.FailedPrecondition, "must accept ToS")
	}
	if req.HeadquartersAddress == nil {
		return status.Error(codes.InvalidArgument, "headquarters_address required")
	}
	return nil
}

// buildCreateAddressParams mirrors upsertAddress's create branch but
// returns the sqlc params struct so we can call it inside a tx via qtx.
func buildCreateAddressParams(addr *identityv1.Address) (db.CreateAddressParams, error) {
	if addr == nil {
		return db.CreateAddressParams{}, status.Error(codes.InvalidArgument, "address required")
	}
	if len(addr.CountryCode) != 2 {
		return db.CreateAddressParams{}, status.Error(codes.InvalidArgument, "country_code must be ISO alpha-2")
	}
	if addr.City == "" || addr.PostalCode == "" || addr.StreetLine == "" || addr.BuildingNumber == "" {
		return db.CreateAddressParams{}, status.Error(codes.InvalidArgument,
			"address fields required: city, postal_code, street_line, building_number")
	}
	params := db.CreateAddressParams{
		CountryCode:    addr.CountryCode,
		City:           addr.City,
		PostalCode:     addr.PostalCode,
		StreetLine:     addr.StreetLine,
		BuildingNumber: addr.BuildingNumber,
	}
	if addr.Region != "" {
		params.Region = &addr.Region
	}
	if addr.UnitNumber != "" {
		params.UnitNumber = &addr.UnitNumber
	}
	if addr.Directions != "" {
		params.Directions = &addr.Directions
	}
	return params, nil
}

// verifyFirebaseTokenFromContext extracts the Authorization header
// from gRPC metadata, strips the optional "Bearer " prefix, verifies
// the token via firebase.AuthClient, and returns the resolved
// firebase_uid.
//
// Unlike resolveCaller, this does NOT look up a user row — it's used
// by the unauthenticated RegisterOrganization + AcceptInvitation paths
// where the user row either doesn't exist yet (registration) or will
// be created in the same tx (accept).
func (s *Server) verifyFirebaseTokenFromContext(ctx context.Context) (string, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "", status.Error(codes.Unauthenticated, "no gRPC metadata")
	}
	auths := md.Get("authorization")
	if len(auths) == 0 {
		return "", status.Error(codes.Unauthenticated, "no authorization header")
	}
	token := auths[0]
	if len(token) > 7 && (strings.HasPrefix(token, "Bearer ") || strings.HasPrefix(token, "bearer ")) {
		token = token[7:]
	}
	uid, _, err := s.auth.VerifyToken(ctx, token)
	if err != nil {
		return "", status.Error(codes.Unauthenticated, "invalid Firebase token")
	}
	return uid, nil
}

// seedTrialForOrg duplicates the existing provisionTrialOrgAndSub
// helper's subscription + counter inserts, scoped to a given org id.
// We can't call provisionTrialOrgAndSub directly because that helper
// also creates the org + user — RegisterOrganization already did
// those (with the legal_name from the form, not auto-generated).
func (s *Server) seedTrialForOrg(ctx context.Context, tx pgx.Tx, orgID uuid.UUID) error {
	var planID uuid.UUID
	var tokensPerPeriod int32
	if err := tx.QueryRow(ctx,
		`SELECT id, tokens_per_period FROM subscription_plans
		 WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE
		 LIMIT 1`,
	).Scan(&planID, &tokensPerPeriod); err != nil {
		return status.Errorf(codes.Internal, "lookup trial plan: %v", err)
	}

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
		return status.Errorf(codes.Internal, "create subscription: %v", err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO usage_counters (
		     subscription_id, period_start, period_end, tokens_limit
		 ) VALUES ($1, $2, $3, $4)`,
		subID, periodStart, periodEnd, tokensPerPeriod,
	); err != nil {
		return status.Errorf(codes.Internal, "create counter: %v", err)
	}
	return nil
}

// assembleExistingOrgRegistration is the idempotency replay path —
// returns the RegisterOrganizationResponse for an already-registered
// firebase_uid. Reads the existing user + their org + HQ address and
// echoes them back.
func (s *Server) assembleExistingOrgRegistration(ctx context.Context, user db.User) (*identityv1.RegisterOrganizationResponse, error) {
	if !user.OrganizationID.Valid {
		// Edge case: a user exists but isn't attached to an org. That
		// shouldn't be possible for an ORG_ADMIN reg flow, but be
		// defensive — surface as AlreadyExists so the client redirects
		// to the regular login flow.
		return nil, status.Error(codes.AlreadyExists,
			"a user with this firebase_uid already exists but has no org")
	}
	orgID := uuid.UUID(user.OrganizationID.Bytes)
	org, err := s.queries.GetOrganizationByID(ctx, orgID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load existing org: %v", err)
	}
	var hq *db.Address
	if org.HeadquartersAddressID.Valid {
		a, err := s.queries.GetAddressByID(ctx, uuid.UUID(org.HeadquartersAddressID.Bytes))
		if err == nil {
			hq = &a
		}
	}
	return &identityv1.RegisterOrganizationResponse{
		User:         toProtoUser(user),
		Organization: toProtoOrganization(org, hq, false),
	}, nil
}

func defaultStr(v, fallback string) string {
	if strings.TrimSpace(v) == "" {
		return fallback
	}
	return v
}
