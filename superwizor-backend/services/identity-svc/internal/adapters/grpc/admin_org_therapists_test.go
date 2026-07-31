package grpc

// Guard-rail tests for the admin assign/unassign therapist RPCs.
//
// Everything asserted here returns BEFORE the handler touches s.pool, so
// the tests run without Postgres — same nil-embed fake-Querier trick as
// team_status_test.go. The write paths (seat lock, LinkUserToOrganization,
// the transfer-warning aggregate) need a real DB and are covered by the
// staging E2E, not here.

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// assignFakeQuerier adds the lookups the assign/unassign handlers need on
// top of the org fake: by-email resolution and the org existence check.
type assignFakeQuerier struct {
	orgFakeQuerier
	getUserByEmailFn func(ctx context.Context, email *string) (db.User, error)
	getOrgByIDFn     func(ctx context.Context, id uuid.UUID) (db.Organization, error)
}

func (f *assignFakeQuerier) GetUserByEmail(ctx context.Context, email *string) (db.User, error) {
	return f.getUserByEmailFn(ctx, email)
}

func (f *assignFakeQuerier) GetOrganizationByID(ctx context.Context, id uuid.UUID) (db.Organization, error) {
	if f.getOrgByIDFn != nil {
		return f.getOrgByIDFn(ctx, id)
	}
	return db.Organization{ID: id, LegalName: "Test Org"}, nil
}

// adminCallerFake returns a fake whose caller is a SUPERWIZOR_ADMIN.
func adminCallerFake(target db.User, lookupErr error) *assignFakeQuerier {
	f := &assignFakeQuerier{}
	f.getUserByFirebaseUIDFn = func(_ context.Context, _ *string) (db.User, error) {
		return db.User{
			ID:       uuid.New(),
			Role:     db.UserRoleSUPERWIZORADMIN,
			IsActive: true,
		}, nil
	}
	f.getUserByIDFn = func(_ context.Context, id uuid.UUID) (db.User, error) {
		if lookupErr != nil {
			return db.User{}, lookupErr
		}
		out := target
		out.ID = id
		return out, nil
	}
	f.getUserByEmailFn = func(_ context.Context, _ *string) (db.User, error) {
		return target, lookupErr
	}
	return f
}

const validReason = "przeniesienie terapeuty na prośbę organizacji"

// grpcMessage is the message counterpart of team_status_test.go's grpcCode.
func grpcMessage(err error) string { return status.Convert(err).Message() }

func TestAdminAssignTherapist_ShortReason_IsInvalidArgument(t *testing.T) {
	s := &Server{
		queries: adminCallerFake(db.User{}, nil),
		auth:    &mockTokenVerifier{uid: "fb-admin"},
	}

	_, err := s.AdminAssignTherapistToOrg(authedCtx(), &identityv1.AdminAssignTherapistToOrgRequest{
		OrganizationId: uuid.New().String(),
		Email:          "t@example.com",
		Reason:         "krótki",
	})
	if grpcCode(err) != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument for a short reason, got %v (err=%v)", grpcCode(err), err)
	}
}

func TestAdminAssignTherapist_UnknownEmail_IsNotFound(t *testing.T) {
	s := &Server{
		queries: adminCallerFake(db.User{}, pgx.ErrNoRows),
		auth:    &mockTokenVerifier{uid: "fb-admin"},
	}

	_, err := s.AdminAssignTherapistToOrg(authedCtx(), &identityv1.AdminAssignTherapistToOrgRequest{
		OrganizationId: uuid.New().String(),
		Email:          "nieznany@example.com",
		Reason:         validReason,
	})
	if grpcCode(err) != codes.NotFound {
		t.Fatalf("want NotFound for an unknown e-mail, got %v (err=%v)", grpcCode(err), err)
	}
	// The UI keys its copy off this code — an invitation is NOT sent.
	if msg := grpcMessage(err); !strings.Contains(msg, "USER_NOT_FOUND") {
		t.Errorf("want USER_NOT_FOUND in the message, got %q", msg)
	}
}

func TestAdminAssignTherapist_NonTherapist_IsFailedPrecondition(t *testing.T) {
	s := &Server{
		queries: adminCallerFake(db.User{
			ID:   uuid.New(),
			Role: db.UserRoleORGADMIN,
		}, nil),
		auth: &mockTokenVerifier{uid: "fb-admin"},
	}

	_, err := s.AdminAssignTherapistToOrg(authedCtx(), &identityv1.AdminAssignTherapistToOrgRequest{
		OrganizationId: uuid.New().String(),
		Email:          "manager@example.com",
		Reason:         validReason,
	})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("want FailedPrecondition for a non-therapist, got %v (err=%v)", grpcCode(err), err)
	}
}

func TestAdminAssignTherapist_AlreadyInThatOrg_IsFailedPrecondition(t *testing.T) {
	org := uuid.New()
	s := &Server{
		queries: adminCallerFake(db.User{
			ID:             uuid.New(),
			Role:           db.UserRoleTHERAPIST,
			OrganizationID: pgtype.UUID{Bytes: org, Valid: true},
		}, nil),
		auth: &mockTokenVerifier{uid: "fb-admin"},
	}

	_, err := s.AdminAssignTherapistToOrg(authedCtx(), &identityv1.AdminAssignTherapistToOrgRequest{
		OrganizationId: org.String(),
		Email:          "t@example.com",
		Reason:         validReason,
	})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("want FailedPrecondition when already a member, got %v (err=%v)", grpcCode(err), err)
	}
	if msg := grpcMessage(err); !strings.Contains(msg, "ALREADY_IN_ORGANIZATION") {
		t.Errorf("want ALREADY_IN_ORGANIZATION, got %q", msg)
	}
}

func TestAdminUnassignTherapist_ForeignOrg_IsFailedPrecondition(t *testing.T) {
	orgA, orgB := uuid.New(), uuid.New()
	s := &Server{
		queries: adminCallerFake(db.User{
			Role:           db.UserRoleTHERAPIST,
			OrganizationID: pgtype.UUID{Bytes: orgA, Valid: true},
		}, nil),
		auth: &mockTokenVerifier{uid: "fb-admin"},
	}

	// Admin asks to detach the therapist from an org they don't belong to.
	_, err := s.AdminUnassignTherapistFromOrg(authedCtx(), &identityv1.AdminUnassignTherapistFromOrgRequest{
		OrganizationId: orgB.String(),
		UserId:         uuid.New().String(),
		Reason:         validReason,
	})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("want FailedPrecondition for a foreign org, got %v (err=%v)", grpcCode(err), err)
	}
	if msg := grpcMessage(err); !strings.Contains(msg, "USER_NOT_IN_ORGANIZATION") {
		t.Errorf("want USER_NOT_IN_ORGANIZATION, got %q", msg)
	}
}
