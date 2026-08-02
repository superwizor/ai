package grpc

// Bramki zakresu dla SetManagerTherapistSeat. Wszystko, co tu sprawdzamy,
// wypada ZANIM handler dotknie s.pool — tak samo jak w
// admin_org_therapists_test.go, więc testy chodzą bez Postgresa.
// Ścieżkę zapisu (blokada alokacji, zajęcie miejsca) pokrywa E2E na
// stagingu.

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

func TestSetManagerTherapistSeat_TargetMustBeManager(t *testing.T) {
	org := uuid.New()

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(org),
				IsActive:       true,
			}, nil
		},
		// Cel jest TERAPEUTĄ — ma własną ścieżkę (zaproszenie +
		// SetTherapistStatus). Ten RPC nie może być jej obejściem.
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           db.UserRoleTHERAPIST,
				OrganizationID: pgOrgUUID(org),
				IsActive:       true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: "fb-admin"}}

	_, err := s.SetManagerTherapistSeat(authedCtx(), &identityv1.SetManagerTherapistSeatRequest{
		UserId:       uuid.New().String(),
		Practicing:   true,
		AllocationId: uuid.New().String(),
	})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("kod = %v, oczekiwano FailedPrecondition (cel nie jest menedżerem)", grpcCode(err))
	}
}

func TestSetManagerTherapistSeat_CrossOrgIsDenied(t *testing.T) {
	callerOrg, otherOrg := uuid.New(), uuid.New()

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(callerOrg),
				IsActive:       true,
			}, nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(otherOrg),
				IsActive:       true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: "fb-admin"}}

	_, err := s.SetManagerTherapistSeat(authedCtx(), &identityv1.SetManagerTherapistSeatRequest{
		UserId:       uuid.New().String(),
		Practicing:   true,
		AllocationId: uuid.New().String(),
	})
	if grpcCode(err) != codes.PermissionDenied {
		t.Fatalf("kod = %v, oczekiwano PermissionDenied (menedżer z innej organizacji)", grpcCode(err))
	}
}

// Nadanie miejsca bez wskazania planu nie może przejść jako "gdziekolwiek".
func TestSetManagerTherapistSeat_PracticingRequiresAllocation(t *testing.T) {
	org := uuid.New()

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(org),
				IsActive:       true,
			}, nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(org),
				IsActive:       true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: "fb-admin"}}

	_, err := s.SetManagerTherapistSeat(authedCtx(), &identityv1.SetManagerTherapistSeatRequest{
		UserId:       uuid.New().String(),
		Practicing:   true,
		AllocationId: "", // brak planu
	})
	if grpcCode(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument (brak allocation_id)", grpcCode(err))
	}
}

// Wywołujący musi być menedżerem — zwykły terapeuta nie rozdaje miejsc.
func TestSetManagerTherapistSeat_CallerMustBeOrgAdmin(t *testing.T) {
	org := uuid.New()

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleTHERAPIST,
				OrganizationID: pgOrgUUID(org),
				IsActive:       true,
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: "fb-therapist"}}

	_, err := s.SetManagerTherapistSeat(authedCtx(), &identityv1.SetManagerTherapistSeatRequest{
		UserId:       uuid.New().String(),
		Practicing:   true,
		AllocationId: uuid.New().String(),
	})
	if grpcCode(err) == codes.OK {
		t.Fatal("terapeuta nie może nadawać miejsc menedżerom")
	}
}

// Miejsce dla wyłączonego konta to ten sam wyciek, przed którym broni
// SetMyOrgManagerStatus — tylko wejściem od drugiej strony: opłacone
// miejsce zajęte przez konto, które i tak dostanie ACCOUNT_DEACTIVATED.
func TestSetManagerTherapistSeat_InactiveManagerCannotTakeSeat(t *testing.T) {
	org := uuid.New()

	q := &orgFakeQuerier{
		getUserByFirebaseUIDFn: func(_ context.Context, _ *string) (db.User, error) {
			return db.User{
				ID:             uuid.New(),
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(org),
				IsActive:       true,
			}, nil
		},
		getUserByIDFn: func(_ context.Context, id uuid.UUID) (db.User, error) {
			return db.User{
				ID:             id,
				Role:           db.UserRoleORGADMIN,
				OrganizationID: pgOrgUUID(org),
				IsActive:       false, // konto wyłączone
			}, nil
		},
	}
	s := &Server{queries: q, auth: &mockTokenVerifier{uid: "fb-admin"}}

	_, err := s.SetManagerTherapistSeat(authedCtx(), &identityv1.SetManagerTherapistSeatRequest{
		UserId:       uuid.New().String(),
		Practicing:   true,
		AllocationId: uuid.New().String(),
	})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("kod = %v, oczekiwano FailedPrecondition (MANAGER_INACTIVE)", grpcCode(err))
	}
}

// pgOrgUUID skraca powtarzalne opakowanie organization_id.
func pgOrgUUID(id uuid.UUID) pgtype.UUID { return pgtype.UUID{Bytes: id, Valid: true} }
