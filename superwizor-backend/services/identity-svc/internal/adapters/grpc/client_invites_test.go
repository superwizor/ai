package grpc

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// clientInviteFakeQuerier — nil-embed fake for the docs/39 client
// invitation surface.
type clientInviteFakeQuerier struct {
	db.Querier
	getUserByFirebaseUIDFn func(ctx context.Context, uid *string) (db.User, error)
	getUserByIDFn          func(ctx context.Context, id uuid.UUID) (db.User, error)
	getUserByEmailFn       func(ctx context.Context, email *string) (db.User, error)
	getPFForInviteFn       func(ctx context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error)
	setPFEmailFn           func(ctx context.Context, arg db.SetPatientFileEmailParams) error
	createInvitationFn     func(ctx context.Context, arg db.CreateInvitationParams) (db.Invitation, error)
	getPendingByFileFn     func(ctx context.Context, pf pgtype.UUID) (db.Invitation, error)

	createInvitationCalls []db.CreateInvitationParams
}

func (f *clientInviteFakeQuerier) GetUserByFirebaseUID(ctx context.Context, uid *string) (db.User, error) {
	return f.getUserByFirebaseUIDFn(ctx, uid)
}
func (f *clientInviteFakeQuerier) GetUserByID(ctx context.Context, id uuid.UUID) (db.User, error) {
	return f.getUserByIDFn(ctx, id)
}
func (f *clientInviteFakeQuerier) GetUserByEmail(ctx context.Context, email *string) (db.User, error) {
	if f.getUserByEmailFn != nil {
		return f.getUserByEmailFn(ctx, email)
	}
	return db.User{}, pgx.ErrNoRows
}
func (f *clientInviteFakeQuerier) GetPatientFileForInvite(ctx context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error) {
	return f.getPFForInviteFn(ctx, id)
}
func (f *clientInviteFakeQuerier) SetPatientFileEmail(ctx context.Context, arg db.SetPatientFileEmailParams) error {
	if f.setPFEmailFn != nil {
		return f.setPFEmailFn(ctx, arg)
	}
	return nil
}
func (f *clientInviteFakeQuerier) CreateInvitation(ctx context.Context, arg db.CreateInvitationParams) (db.Invitation, error) {
	f.createInvitationCalls = append(f.createInvitationCalls, arg)
	return f.createInvitationFn(ctx, arg)
}
func (f *clientInviteFakeQuerier) GetPendingPatientInvitationByFile(ctx context.Context, pf pgtype.UUID) (db.Invitation, error) {
	if f.getPendingByFileFn != nil {
		return f.getPendingByFileFn(ctx, pf)
	}
	return db.Invitation{}, pgx.ErrNoRows
}

func newInviteServer(q db.Querier, fbUID string) *Server {
	s := NewServer(nil, q, &mockTokenVerifier{uid: fbUID}, "test", nil)
	return s
}

func therapistRow(id, org uuid.UUID) db.User {
	return db.User{
		ID:             id,
		Role:           "THERAPIST",
		OrganizationID: pgtype.UUID{Bytes: org, Valid: true},
		IsActive:       true,
		FirstName:      "Tomasz",
	}
}

func TestInviteClient_OwnerHappyPath_BindsKartotekaAndRole(t *testing.T) {
	therapist := uuid.New()
	org := uuid.New()
	pfID := uuid.New()
	email := "klient@example.com"

	q := &clientInviteFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return therapistRow(therapist, org), nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return therapistRow(therapist, org), nil
		},
		getPFForInviteFn: func(_ context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error) {
			return db.GetPatientFileForInviteRow{
				ID:           id,
				TherapistID:  therapist,
				PatientEmail: &email,
			}, nil
		},
		createInvitationFn: func(_ context.Context, arg db.CreateInvitationParams) (db.Invitation, error) {
			return db.Invitation{
				ID: uuid.New(), OrganizationID: arg.OrganizationID,
				InvitedByUser: arg.InvitedByUser, Email: arg.Email,
				ExpiresAt: arg.ExpiresAt, InvitedRole: arg.InvitedRole,
				PatientFileID: arg.PatientFileID, CreatedAt: time.Now(),
			}, nil
		},
	}
	s := newInviteServer(q, "fb-therapist")

	inv, err := s.InviteClient(authedCtx(), &identityv1.InviteClientRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if inv.InvitedRole != identityv1.UserRole_USER_ROLE_PATIENT {
		t.Errorf("invited_role = %v, want PATIENT", inv.InvitedRole)
	}
	got := q.createInvitationCalls[0]
	if !got.PatientFileID.Valid || uuid.UUID(got.PatientFileID.Bytes) != pfID {
		t.Errorf("invitation must be kartoteka-bound, got %v", got.PatientFileID)
	}
	if got.Email != email {
		t.Errorf("email from kartoteka expected, got %q", got.Email)
	}
}

func TestInviteClient_ForeignTherapist_IsNotFound(t *testing.T) {
	owner := uuid.New()
	caller := uuid.New()
	org := uuid.New()

	q := &clientInviteFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return therapistRow(caller, org), nil
		},
		getPFForInviteFn: func(_ context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error) {
			return db.GetPatientFileForInviteRow{ID: id, TherapistID: owner}, nil
		},
	}
	s := newInviteServer(q, "fb-foreign")

	_, err := s.InviteClient(authedCtx(), &identityv1.InviteClientRequest{
		PatientFileId: uuid.NewString(),
	})
	if status.Code(err) != codes.NotFound {
		t.Fatalf("foreign kartoteka must be NotFound, got %v", err)
	}
}

func TestInviteClient_NoEmailAnywhere_IsFailedPrecondition(t *testing.T) {
	therapist := uuid.New()
	org := uuid.New()

	q := &clientInviteFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return therapistRow(therapist, org), nil
		},
		getPFForInviteFn: func(_ context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error) {
			return db.GetPatientFileForInviteRow{ID: id, TherapistID: therapist}, nil
		},
	}
	s := newInviteServer(q, "fb-therapist")

	_, err := s.InviteClient(authedCtx(), &identityv1.InviteClientRequest{
		PatientFileId: uuid.NewString(),
	})
	if status.Code(err) != codes.FailedPrecondition ||
		!strings.Contains(status.Convert(err).Message(), "CLIENT_EMAIL_MISSING") {
		t.Fatalf("want CLIENT_EMAIL_MISSING FailedPrecondition, got %v", err)
	}
}

func TestInviteClient_EmailOwnedByTherapist_IsFailedPrecondition(t *testing.T) {
	therapist := uuid.New()
	org := uuid.New()

	q := &clientInviteFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return therapistRow(therapist, org), nil
		},
		getPFForInviteFn: func(_ context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error) {
			return db.GetPatientFileForInviteRow{ID: id, TherapistID: therapist}, nil
		},
		getUserByEmailFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{ID: uuid.New(), Role: "THERAPIST"}, nil
		},
	}
	s := newInviteServer(q, "fb-therapist")

	_, err := s.InviteClient(authedCtx(), &identityv1.InviteClientRequest{
		PatientFileId: uuid.NewString(),
		Email:         "kolega@clinic.pl",
	})
	if status.Code(err) != codes.FailedPrecondition ||
		!strings.Contains(status.Convert(err).Message(), "CLIENT_EMAIL_TAKEN") {
		t.Fatalf("want CLIENT_EMAIL_TAKEN, got %v", err)
	}
}

func TestGetClientInviteStatus_States(t *testing.T) {
	therapist := uuid.New()
	org := uuid.New()
	patient := uuid.New()
	fb := "fb-patient"
	email := "klient@example.com"

	base := func(pf db.GetPatientFileForInviteRow, patientUser *db.User, pending *db.Invitation) *Server {
		q := &clientInviteFakeQuerier{
			getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
				return therapistRow(therapist, org), nil
			},
			getPFForInviteFn: func(_ context.Context, id uuid.UUID) (db.GetPatientFileForInviteRow, error) {
				pf.ID = id
				return pf, nil
			},
			getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
				if patientUser != nil && id == patientUser.ID {
					return *patientUser, nil
				}
				return therapistRow(therapist, org), nil
			},
		}
		if pending != nil {
			q.getPendingByFileFn = func(_ context.Context, _ pgtype.UUID) (db.Invitation, error) {
				return *pending, nil
			}
		}
		return newInviteServer(q, "fb-therapist")
	}

	// NONE — nothing yet.
	s := base(db.GetPatientFileForInviteRow{TherapistID: therapist}, nil, nil)
	st, err := s.GetClientInviteStatus(authedCtx(), &identityv1.GetClientInviteStatusRequest{PatientFileId: uuid.NewString()})
	if err != nil || st.Status != "NONE" {
		t.Fatalf("want NONE, got %v err=%v", st.GetStatus(), err)
	}

	// PENDING — unexpired invitation.
	inv := db.Invitation{Email: email, ExpiresAt: time.Now().Add(24 * time.Hour), InvitedRole: "PATIENT"}
	s = base(db.GetPatientFileForInviteRow{TherapistID: therapist}, nil, &inv)
	st, err = s.GetClientInviteStatus(authedCtx(), &identityv1.GetClientInviteStatusRequest{PatientFileId: uuid.NewString()})
	if err != nil || st.Status != "PENDING" || st.Email != email {
		t.Fatalf("want PENDING/%s, got %v/%v err=%v", email, st.GetStatus(), st.GetEmail(), err)
	}

	// ACTIVE — patient user with firebase_uid.
	pu := db.User{ID: patient, Role: "PATIENT", FirebaseUid: &fb, Email: &email, IsActive: true}
	s = base(db.GetPatientFileForInviteRow{TherapistID: therapist, PatientID: pgtype.UUID{Bytes: patient, Valid: true}}, &pu, nil)
	st, err = s.GetClientInviteStatus(authedCtx(), &identityv1.GetClientInviteStatusRequest{PatientFileId: uuid.NewString()})
	if err != nil || st.Status != "ACTIVE" {
		t.Fatalf("want ACTIVE, got %v err=%v", st.GetStatus(), err)
	}

	// INACTIVE — activated then deactivated.
	pu.IsActive = false
	s = base(db.GetPatientFileForInviteRow{TherapistID: therapist, PatientID: pgtype.UUID{Bytes: patient, Valid: true}}, &pu, nil)
	st, err = s.GetClientInviteStatus(authedCtx(), &identityv1.GetClientInviteStatusRequest{PatientFileId: uuid.NewString()})
	if err != nil || st.Status != "INACTIVE" {
		t.Fatalf("want INACTIVE, got %v err=%v", st.GetStatus(), err)
	}
}
