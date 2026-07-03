package grpc

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// orgFakeQuerier is the nil-embed fake for the org-management tests
// (docs/38). Unset methods panic via the nil db.Querier embed — an
// unexpected query in a test is a bug in the test or the handler.
type orgFakeQuerier struct {
	db.Querier
	getUserByFirebaseUIDFn func(ctx context.Context, uid *string) (db.User, error)
	getUserByIDFn          func(ctx context.Context, id uuid.UUID) (db.User, error)
	countAssignmentsFn     func(ctx context.Context, allocationID uuid.UUID) (int64, error)
	countPendingInvitesFn  func(ctx context.Context, allocationID pgtype.UUID) (int64, error)
}

func (f *orgFakeQuerier) GetUserByFirebaseUID(ctx context.Context, uid *string) (db.User, error) {
	return f.getUserByFirebaseUIDFn(ctx, uid)
}

func (f *orgFakeQuerier) GetUserByID(ctx context.Context, id uuid.UUID) (db.User, error) {
	return f.getUserByIDFn(ctx, id)
}

func (f *orgFakeQuerier) CountActiveSeatAssignments(ctx context.Context, allocationID uuid.UUID) (int64, error) {
	return f.countAssignmentsFn(ctx, allocationID)
}

func (f *orgFakeQuerier) CountPendingInvitationsForAllocation(ctx context.Context, allocationID pgtype.UUID) (int64, error) {
	return f.countPendingInvitesFn(ctx, allocationID)
}

// authedCtx builds a ctx carrying a Bearer token so resolveCaller's
// metadata extraction succeeds; the mockTokenVerifier decides the uid.
func authedCtx() context.Context {
	md := metadata.New(map[string]string{"authorization": "Bearer test-token"})
	return metadata.NewIncomingContext(context.Background(), md)
}

func grpcCode(err error) codes.Code {
	if err == nil {
		return codes.OK
	}
	st, _ := status.FromError(err)
	return st.Code()
}

// ─── ValidateToken / resolveCaller: deactivation gate (docs/38 §4) ──

func TestValidateToken_DeactivatedAccount_IsPermissionDenied(t *testing.T) {
	fbUID := "fb-deactivated"
	email := "t@clinic.pl"
	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:          uuid.New(),
				Role:        "THERAPIST",
				FirebaseUid: &fbUID,
				Email:       &email,
				IsActive:    false, // deactivated by ORG_ADMIN
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID, claims: map[string]any{}}}

	_, err := s.ValidateToken(context.Background(), &identityv1.ValidateTokenRequest{
		FirebaseIdToken: "valid-token",
	})
	if grpcCode(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied, got %v (err=%v)", grpcCode(err), err)
	}
	if !strings.HasPrefix(status.Convert(err).Message(), "ACCOUNT_DEACTIVATED") {
		t.Errorf("client contract: message must start with ACCOUNT_DEACTIVATED, got %q",
			status.Convert(err).Message())
	}
}

func TestResolveCaller_DeactivatedAccount_IsPermissionDenied(t *testing.T) {
	fbUID := "fb-deactivated"
	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{ID: uuid.New(), Role: db.UserRoleORGADMIN, IsActive: false}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID}}

	_, err := s.resolveCaller(authedCtx())
	if grpcCode(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied for deactivated caller, got %v", grpcCode(err))
	}
}

func TestValidateToken_ActiveAccount_StillWorks(t *testing.T) {
	fbUID := "fb-active"
	email := "t@clinic.pl"
	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:          uuid.New(),
				Role:        "THERAPIST",
				FirebaseUid: &fbUID,
				Email:       &email,
				IsActive:    true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID, claims: map[string]any{}}}

	resp, err := s.ValidateToken(context.Background(), &identityv1.ValidateTokenRequest{
		FirebaseIdToken: "valid-token",
	})
	if err != nil {
		t.Fatalf("active account must validate: %v", err)
	}
	if resp.Role != identityv1.UserRole_USER_ROLE_THERAPIST {
		t.Errorf("role: want THERAPIST, got %v", resp.Role)
	}
}

// ─── SetTherapistStatus: scope + role gates ─────────────────────────

func TestSetTherapistStatus_WrongOrg_IsDenied(t *testing.T) {
	callerOrg := uuid.New()
	otherOrg := uuid.New()
	fbUID := "fb-admin"
	target := uuid.New()

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgtype.UUID{Bytes: callerOrg, Valid: true},
				IsActive:       true,
			}, nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           "THERAPIST",
				OrganizationID: pgtype.UUID{Bytes: otherOrg, Valid: true},
				IsActive:       true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID}}

	_, err := s.SetTherapistStatus(authedCtx(), &identityv1.SetTherapistStatusRequest{
		UserId: target.String(), IsActive: false,
	})
	if grpcCode(err) != codes.PermissionDenied {
		t.Fatalf("cross-org toggle must be denied, got %v (err=%v)", grpcCode(err), err)
	}
}

func TestSetTherapistStatus_NonTherapist_IsFailedPrecondition(t *testing.T) {
	org := uuid.New()
	fbUID := "fb-admin"

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgtype.UUID{Bytes: org, Valid: true},
				IsActive:       true,
			}, nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           db.UserRoleORGADMIN, // co-admin, not a therapist
				OrganizationID: pgtype.UUID{Bytes: org, Valid: true},
				IsActive:       true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID}}

	_, err := s.SetTherapistStatus(authedCtx(), &identityv1.SetTherapistStatusRequest{
		UserId: uuid.NewString(), IsActive: false,
	})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("want FailedPrecondition for non-THERAPIST target, got %v", grpcCode(err))
	}
}

func TestSetTherapistStatus_NoOpToggle_IsIdempotent(t *testing.T) {
	org := uuid.New()
	fbUID := "fb-admin"

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgtype.UUID{Bytes: org, Valid: true},
				IsActive:       true,
			}, nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           "THERAPIST",
				OrganizationID: pgtype.UUID{Bytes: org, Valid: true},
				IsActive:       true, // already active
			}, nil
		},
	}
	// pool stays nil — the no-op path must return BEFORE any tx.
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID}}

	resp, err := s.SetTherapistStatus(authedCtx(), &identityv1.SetTherapistStatusRequest{
		UserId: uuid.NewString(), IsActive: true,
	})
	if err != nil {
		t.Fatalf("no-op toggle must succeed without a tx: %v", err)
	}
	if !resp.IsActive {
		t.Errorf("response must reflect is_active=true")
	}
}

// ─── checkSeatAvailable: occupancy formula (docs/38 §3) ─────────────

func TestCheckSeatAvailable(t *testing.T) {
	alloc := db.OrgSeatAllocation{ID: uuid.New(), Seats: 3}

	tests := []struct {
		name     string
		assigned int64
		pending  int64
		wantCode codes.Code
	}{
		{"free seats", 1, 0, codes.OK},
		{"pending invites count toward occupancy", 1, 1, codes.OK},
		{"full via assignments", 3, 0, codes.FailedPrecondition},
		{"full via assignments+invites", 2, 1, codes.FailedPrecondition},
		{"overbooked defensive", 4, 2, codes.FailedPrecondition},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			q := &orgFakeQuerier{
				countAssignmentsFn: func(_ context.Context, _ uuid.UUID) (int64, error) {
					return tc.assigned, nil
				},
				countPendingInvitesFn: func(_ context.Context, _ pgtype.UUID) (int64, error) {
					return tc.pending, nil
				},
			}
			err := checkSeatAvailable(context.Background(), q, alloc)
			if grpcCode(err) != tc.wantCode {
				t.Fatalf("assigned=%d pending=%d seats=%d: want %v, got %v (err=%v)",
					tc.assigned, tc.pending, alloc.Seats, tc.wantCode, grpcCode(err), err)
			}
			if tc.wantCode == codes.FailedPrecondition &&
				!strings.HasPrefix(status.Convert(err).Message(), "SEATS_EXHAUSTED") {
				t.Errorf("client contract: message must start with SEATS_EXHAUSTED, got %q",
					status.Convert(err).Message())
			}
		})
	}
}

// ─── AdminCreateOrganization: input validation ──────────────────────

func TestNormalizeManagerEmails(t *testing.T) {
	got, err := normalizeManagerEmails([]string{" Anna@Clinic.PL ", "anna@clinic.pl", "b@c.pl", ""})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 2 || got[0] != "anna@clinic.pl" || got[1] != "b@c.pl" {
		t.Errorf("dedup+lowercase failed: %v", got)
	}

	if _, err := normalizeManagerEmails([]string{"not-an-email"}); grpcCode(err) != codes.InvalidArgument {
		t.Errorf("invalid e-mail must be InvalidArgument, got %v", err)
	}
	if _, err := normalizeManagerEmails(nil); grpcCode(err) != codes.InvalidArgument {
		t.Errorf("empty list must be InvalidArgument, got %v", err)
	}
}

func TestAdminCreateOrganization_ReasonTooShort(t *testing.T) {
	fbUID := "fb-superadmin"
	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{ID: uuid.New(), Role: db.UserRoleSUPERWIZORADMIN, IsActive: true}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID}}

	_, err := s.AdminCreateOrganization(authedCtx(), &identityv1.AdminCreateOrganizationRequest{
		LegalName:     "Klinika X",
		ManagerEmails: []string{"m@x.pl"},
		Reason:        "short",
	})
	if grpcCode(err) != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument for short reason, got %v", grpcCode(err))
	}
}

func TestAdminCreateOrganization_RequiresSuperwizorAdmin(t *testing.T) {
	fbUID := "fb-orgadmin"
	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{ID: uuid.New(), Role: db.UserRoleORGADMIN, IsActive: true}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: fbUID}}

	_, err := s.AdminCreateOrganization(authedCtx(), &identityv1.AdminCreateOrganizationRequest{
		LegalName:     "Klinika X",
		ManagerEmails: []string{"m@x.pl"},
		Reason:        "provisioning new B2B client",
	})
	if grpcCode(err) != codes.PermissionDenied {
		t.Fatalf("ORG_ADMIN must not create orgs, got %v", grpcCode(err))
	}
}
