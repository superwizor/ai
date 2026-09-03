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

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// Testy samodzielnego usunięcia konta (docs/70 R9, Apple 5.1.1(v)).

type deleteFakeQuerier struct {
	db.Querier

	caller       db.User
	storeSub     *db.GetActiveStoreSubscriptionForOrgRow
	softDeleted  []uuid.UUID
	auditActions []string
}

func (f *deleteFakeQuerier) GetUserByFirebaseUID(context.Context, *string) (db.User, error) {
	return f.caller, nil
}

func (f *deleteFakeQuerier) GetActiveStoreSubscriptionForOrg(context.Context, uuid.UUID) (db.GetActiveStoreSubscriptionForOrgRow, error) {
	if f.storeSub == nil {
		return db.GetActiveStoreSubscriptionForOrgRow{}, pgx.ErrNoRows
	}
	return *f.storeSub, nil
}

func (f *deleteFakeQuerier) SoftDeleteUser(_ context.Context, id uuid.UUID) error {
	f.softDeleted = append(f.softDeleted, id)
	return nil
}

func (f *deleteFakeQuerier) CreateAuditEvent(_ context.Context, arg db.CreateAuditEventParams) (db.AuditEvent, error) {
	f.auditActions = append(f.auditActions, arg.Action)
	return db.AuditEvent{}, nil
}

func therapistCaller(role db.UserRole) (db.User, uuid.UUID, uuid.UUID) {
	userID := uuid.New()
	orgID := uuid.New()
	uid := "fb-therapist"
	return db.User{
		ID:             userID,
		FirebaseUid:    &uid,
		Role:           role,
		IsActive:       true,
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
	}, userID, orgID
}

func newDeleteServer(t *testing.T, role db.UserRole, storeSub *db.GetActiveStoreSubscriptionForOrgRow) (*Server, *deleteFakeQuerier, uuid.UUID) {
	t.Helper()
	caller, userID, _ := therapistCaller(role)
	q := &deleteFakeQuerier{caller: caller, storeSub: storeSub}
	return &Server{
		queries: q,
		auth:    &mockTokenVerifier{uid: "fb-therapist"},
	}, q, userID
}

func TestDeleteMyAccount_RequiresConfirmation(t *testing.T) {
	// Usunięcie konta jest nieodwracalne z punktu widzenia użytkownika —
	// samo tapnięcie nie może wystarczyć.
	s, q, _ := newDeleteServer(t, db.UserRoleTHERAPIST, nil)
	for _, bad := range []string{"", "tak", "usuń", "DELET"} {
		_, err := s.DeleteMyAccount(authedCtx(), &identityv1.DeleteMyAccountRequest{Confirmation: bad})
		if grpcCode(err) != codes.InvalidArgument {
			t.Fatalf("potwierdzenie %q: kod = %v, chciano InvalidArgument", bad, grpcCode(err))
		}
	}
	if len(q.softDeleted) != 0 {
		t.Fatal("konto zostało usunięte mimo braku potwierdzenia")
	}
}

func TestDeleteMyAccount_AcceptsBothConfirmationWords(t *testing.T) {
	for _, word := range []string{"USUWAM", "usuwam", " Delete "} {
		s, q, userID := newDeleteServer(t, db.UserRoleTHERAPIST, nil)
		if _, err := s.DeleteMyAccount(authedCtx(), &identityv1.DeleteMyAccountRequest{
			Confirmation: word,
		}); err != nil {
			t.Fatalf("potwierdzenie %q: %v", word, err)
		}
		if len(q.softDeleted) != 1 || q.softDeleted[0] != userID {
			t.Fatalf("potwierdzenie %q: soft delete = %v", word, q.softDeleted)
		}
	}
}

func TestDeleteMyAccount_DisablesFirebaseAndAudits(t *testing.T) {
	// Sam soft-delete nie unieważnia wydanego tokena — bez wyłączenia
	// konta w Firebase użytkownik logowałby się dalej aż do wygaśnięcia.
	s, q, _ := newDeleteServer(t, db.UserRoleTHERAPIST, nil)
	verifier := s.auth.(*mockTokenVerifier)

	if _, err := s.DeleteMyAccount(authedCtx(), &identityv1.DeleteMyAccountRequest{
		Confirmation: "USUWAM",
		Reason:       "za drogo",
	}); err != nil {
		t.Fatalf("DeleteMyAccount: %v", err)
	}
	if !verifier.disabledUIDs["fb-therapist"] {
		t.Error("konto Firebase nie zostało wyłączone")
	}
	if len(q.auditActions) != 1 || q.auditActions[0] != "identity.account_self_deleted" {
		t.Errorf("ślad audytu = %v", q.auditActions)
	}
}

func TestDeleteMyAccount_BlocksOnActiveStoreSubscription(t *testing.T) {
	// docs/70 E5: subskrypcji ze sklepu nie umiemy anulować. Ciche
	// skasowanie konta zostawiłoby użytkownika z comiesięczną opłatą za
	// usługę, do której stracił dostęp.
	sub := &db.GetActiveStoreSubscriptionForOrgRow{
		Provider:         "APPLE_IAP",
		CurrentPeriodEnd: time.Now().Add(20 * 24 * time.Hour),
	}
	s, q, _ := newDeleteServer(t, db.UserRoleTHERAPIST, sub)

	_, err := s.DeleteMyAccount(authedCtx(), &identityv1.DeleteMyAccountRequest{Confirmation: "USUWAM"})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("kod = %v, chciano FailedPrecondition", grpcCode(err))
	}
	if !strings.Contains(grpcMessage(err), "STORE_SUBSCRIPTION_ACTIVE") {
		t.Errorf("komunikat = %q — aplikacja dopasowuje po tym kodzie", grpcMessage(err))
	}
	if !strings.Contains(grpcMessage(err), "App Store") {
		t.Errorf("komunikat powinien nazwać sklep: %q", grpcMessage(err))
	}
	if len(q.softDeleted) != 0 {
		t.Fatal("konto usunięte mimo aktywnej subskrypcji ze sklepu")
	}
}

func TestDeleteMyAccount_ProceedsWhenSubscriptionAcknowledged(t *testing.T) {
	sub := &db.GetActiveStoreSubscriptionForOrgRow{Provider: "GOOGLE_IAP"}
	s, q, userID := newDeleteServer(t, db.UserRoleTHERAPIST, sub)

	if _, err := s.DeleteMyAccount(authedCtx(), &identityv1.DeleteMyAccountRequest{
		Confirmation:             "USUWAM",
		AcknowledgedSubscription: true,
	}); err != nil {
		t.Fatalf("DeleteMyAccount: %v", err)
	}
	if len(q.softDeleted) != 1 || q.softDeleted[0] != userID {
		t.Fatalf("soft delete = %v", q.softDeleted)
	}
}

func TestDeleteMyAccount_OrgAdminCannotSelfDelete(t *testing.T) {
	// Manager kliniki zostawiłby organizację bez właściciela — takim
	// wnioskiem zajmuje się administrator platformy.
	s, q, _ := newDeleteServer(t, db.UserRoleORGADMIN, nil)
	_, err := s.DeleteMyAccount(authedCtx(), &identityv1.DeleteMyAccountRequest{Confirmation: "USUWAM"})
	if grpcCode(err) != codes.FailedPrecondition {
		t.Fatalf("kod = %v, chciano FailedPrecondition", grpcCode(err))
	}
	if !strings.Contains(grpcMessage(err), "ORG_ADMIN_CANNOT_SELF_DELETE") {
		t.Errorf("komunikat = %q", grpcMessage(err))
	}
	if len(q.softDeleted) != 0 {
		t.Fatal("konto ORG_ADMIN zostało usunięte")
	}
}
