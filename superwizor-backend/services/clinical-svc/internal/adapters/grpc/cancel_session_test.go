package grpc

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// newCancelServer wires a Server with a fakeQuerier + fakeBilling for
// the CancelSession path. identity/crypto/pubsub stay nil — CancelSession
// touches none of them.
func newCancelServer(q db.Querier, billing *fakeBilling) *Server {
	// Pass an untyped nil when billing isn't wired, to avoid the
	// typed-nil-interface trap (a (*fakeBilling)(nil) stored in the
	// interface field would be != nil, so s.billing != nil would wrongly
	// take the release path).
	if billing == nil {
		return NewServerWithDeps(q, nil, nil, nil, nil, nil, "test-1.0")
	}
	return NewServerWithDeps(q, nil, nil, billing, nil, nil, "test-1.0")
}

func TestCancelSession_HappyPath_FlipsStatusAndReleasesCredit(t *testing.T) {
	therapist := uuid.New()
	sessionID := uuid.New()
	orgID := uuid.New()

	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapist, Status: db.SessionStatusPENDINGUPLOAD}, nil
		},
		getUserOrganizationIDFn: func(_ context.Context, _ uuid.UUID) (pgtype.UUID, error) {
			return pgtype.UUID{Bytes: orgID, Valid: true}, nil
		},
	}
	billing := &fakeBilling{}
	srv := newCancelServer(q, billing)

	_, err := srv.CancelSession(ctxWithUser(t, therapist), &clinicalv1.CancelSessionRequest{SessionId: sessionID.String()})
	if err != nil {
		t.Fatalf("CancelSession: unexpected error: %v", err)
	}

	if len(q.updateSessionStatusCalls) != 1 {
		t.Fatalf("expected 1 status update, got %d", len(q.updateSessionStatusCalls))
	}
	if got := q.updateSessionStatusCalls[0].Status; got != db.SessionStatusCANCELLEDBYUSER {
		t.Errorf("status update = %q, want CANCELLED_BY_USER", got)
	}
	if len(billing.releaseCalls) != 1 {
		t.Fatalf("expected 1 ReleaseCredit call, got %d", len(billing.releaseCalls))
	}
	rc := billing.releaseCalls[0]
	if rc.SessionId != sessionID.String() {
		t.Errorf("release session_id = %q, want %q", rc.SessionId, sessionID)
	}
	if rc.OrganizationId != orgID.String() {
		t.Errorf("release org_id = %q, want %q", rc.OrganizationId, orgID)
	}
	if rc.Reason != "USER_CANCELED" {
		t.Errorf("release reason = %q, want USER_CANCELED", rc.Reason)
	}
}

func TestCancelSession_AlreadyCancelled_IsIdempotentNoOp(t *testing.T) {
	therapist := uuid.New()
	sessionID := uuid.New()

	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapist, Status: db.SessionStatusCANCELLEDBYUSER}, nil
		},
	}
	billing := &fakeBilling{}
	srv := newCancelServer(q, billing)

	if _, err := srv.CancelSession(ctxWithUser(t, therapist), &clinicalv1.CancelSessionRequest{SessionId: sessionID.String()}); err != nil {
		t.Fatalf("expected OK on already-cancelled, got %v", err)
	}
	if len(q.updateSessionStatusCalls) != 0 {
		t.Errorf("expected no status update on idempotent cancel, got %d", len(q.updateSessionStatusCalls))
	}
	if len(billing.releaseCalls) != 0 {
		t.Errorf("expected no release on idempotent cancel, got %d", len(billing.releaseCalls))
	}
}

func TestCancelSession_Completed_IsFailedPrecondition(t *testing.T) {
	therapist := uuid.New()
	sessionID := uuid.New()

	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapist, Status: db.SessionStatusCOMPLETED}, nil
		},
	}
	srv := newCancelServer(q, &fakeBilling{})

	_, err := srv.CancelSession(ctxWithUser(t, therapist), &clinicalv1.CancelSessionRequest{SessionId: sessionID.String()})
	if codeOf(err) != codes.FailedPrecondition {
		t.Fatalf("want FailedPrecondition, got %v (err=%v)", codeOf(err), err)
	}
	if len(q.updateSessionStatusCalls) != 0 {
		t.Errorf("must not flip a completed session")
	}
}

func TestCancelSession_WrongTherapist_IsNotFound(t *testing.T) {
	owner := uuid.New()
	caller := uuid.New()
	sessionID := uuid.New()

	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: owner, Status: db.SessionStatusTRANSCRIBING}, nil
		},
	}
	srv := newCancelServer(q, &fakeBilling{})

	_, err := srv.CancelSession(ctxWithUser(t, caller), &clinicalv1.CancelSessionRequest{SessionId: sessionID.String()})
	if codeOf(err) != codes.NotFound {
		t.Fatalf("want NotFound for foreign session, got %v", codeOf(err))
	}
	if len(q.updateSessionStatusCalls) != 0 {
		t.Errorf("must not flip a foreign session")
	}
}

func TestCancelSession_MissingSession_IsNotFound(t *testing.T) {
	therapist := uuid.New()
	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, _ uuid.UUID) (db.Session, error) {
			return db.Session{}, pgx.ErrNoRows
		},
	}
	srv := newCancelServer(q, &fakeBilling{})

	_, err := srv.CancelSession(ctxWithUser(t, therapist), &clinicalv1.CancelSessionRequest{SessionId: uuid.NewString()})
	if codeOf(err) != codes.NotFound {
		t.Fatalf("want NotFound for missing session, got %v", codeOf(err))
	}
}

func TestCancelSession_ReleaseFailure_StillSucceeds(t *testing.T) {
	therapist := uuid.New()
	sessionID := uuid.New()
	orgID := uuid.New()

	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapist, Status: db.SessionStatusANALYZING}, nil
		},
		getUserOrganizationIDFn: func(_ context.Context, _ uuid.UUID) (pgtype.UUID, error) {
			return pgtype.UUID{Bytes: orgID, Valid: true}, nil
		},
	}
	billing := &fakeBilling{releaseErr: errSentinel}
	srv := newCancelServer(q, billing)

	// Release fails, but the cancel is still committed (status flipped)
	// and the RPC returns OK — the reservation TTL-expires as a backstop.
	if _, err := srv.CancelSession(ctxWithUser(t, therapist), &clinicalv1.CancelSessionRequest{SessionId: sessionID.String()}); err != nil {
		t.Fatalf("release failure must not fail the cancel, got %v", err)
	}
	if len(q.updateSessionStatusCalls) != 1 {
		t.Errorf("status must still be flipped on release failure")
	}
}

func TestCancelSession_NilBilling_FlipsStatusWithoutRelease(t *testing.T) {
	therapist := uuid.New()
	sessionID := uuid.New()

	q := &fakeQuerier{
		getSessionFn: func(_ context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapist, Status: db.SessionStatusCREATED}, nil
		},
	}
	srv := newCancelServer(q, nil) // billing not wired

	if _, err := srv.CancelSession(ctxWithUser(t, therapist), &clinicalv1.CancelSessionRequest{SessionId: sessionID.String()}); err != nil {
		t.Fatalf("unexpected error with nil billing: %v", err)
	}
	if len(q.updateSessionStatusCalls) != 1 {
		t.Errorf("status must be flipped even without billing wired")
	}
}
