package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// Authz matrix for the docs/39 client panel — written against the
// no-enumeration-oracle contract: every mismatch is NotFound, never
// PermissionDenied (except a plain wrong ROLE, which is a category
// error, not an object probe).

func clientCtx(userID uuid.UUID) context.Context {
	ctx := context.WithValue(context.Background(), UserIDKey, userID.String())
	ctx = context.WithValue(ctx, UserRoleKey, "PATIENT")
	return ctx
}

func therapistCtxWithID(userID uuid.UUID) context.Context {
	ctx := context.WithValue(context.Background(), UserIDKey, userID.String())
	ctx = context.WithValue(ctx, UserRoleKey, "THERAPIST")
	return ctx
}

// clientPanelFake extends the shared fakeQuerier with the docs/39
// query surface.
type clientPanelFake struct {
	fakeQuerier
	clientKartotekiFn      func(ctx context.Context, pid pgtype.UUID) ([]db.ClientListKartotekiRow, error)
	clientSharedSessionsFn func(ctx context.Context, pf uuid.UUID) ([]db.ClientListSharedSessionsRow, error)
	clientGetSessionFn     func(ctx context.Context, id uuid.UUID) (db.ClientGetSharedSessionRow, error)
	clientVisibleNotesFn   func(ctx context.Context, pf uuid.UUID) ([]db.PatientNote, error)
	createClientNoteFn     func(ctx context.Context, arg db.CreateClientNoteParams) (db.PatientNote, error)
	markNoteReadClientFn   func(ctx context.Context, id uuid.UUID) error
	getPatientNoteFn       func(ctx context.Context, id uuid.UUID) (db.PatientNote, error)
	setSessionSharedFn     func(ctx context.Context, arg db.SetSessionSharedWithClientParams) (db.SetSessionSharedWithClientRow, error)
	setNoteSharedFn        func(ctx context.Context, arg db.SetNoteSharedWithClientParams) (db.SetNoteSharedWithClientRow, error)

	setSessionSharedCalls []db.SetSessionSharedWithClientParams
}

// PR9 notification lookups — default to "no recipient" so the
// best-effort notify path is a silent no-op in unit tests.
func (f *clientPanelFake) GetPatientUserEmailForFile(ctx context.Context, id uuid.UUID) (db.GetPatientUserEmailForFileRow, error) {
	return db.GetPatientUserEmailForFileRow{}, pgx.ErrNoRows
}
func (f *clientPanelFake) GetUserEmailForNotify(ctx context.Context, id uuid.UUID) (db.GetUserEmailForNotifyRow, error) {
	return db.GetUserEmailForNotifyRow{}, pgx.ErrNoRows
}

func (f *clientPanelFake) ClientListKartoteki(ctx context.Context, pid pgtype.UUID) ([]db.ClientListKartotekiRow, error) {
	return f.clientKartotekiFn(ctx, pid)
}
func (f *clientPanelFake) ClientListSharedSessions(ctx context.Context, pf uuid.UUID) ([]db.ClientListSharedSessionsRow, error) {
	return f.clientSharedSessionsFn(ctx, pf)
}
func (f *clientPanelFake) ClientGetSharedSession(ctx context.Context, id uuid.UUID) (db.ClientGetSharedSessionRow, error) {
	return f.clientGetSessionFn(ctx, id)
}
func (f *clientPanelFake) ClientListVisibleNotes(ctx context.Context, pf uuid.UUID) ([]db.PatientNote, error) {
	return f.clientVisibleNotesFn(ctx, pf)
}
func (f *clientPanelFake) CreateClientNote(ctx context.Context, arg db.CreateClientNoteParams) (db.PatientNote, error) {
	return f.createClientNoteFn(ctx, arg)
}
func (f *clientPanelFake) MarkNoteReadByClient(ctx context.Context, id uuid.UUID) error {
	if f.markNoteReadClientFn != nil {
		return f.markNoteReadClientFn(ctx, id)
	}
	return nil
}
func (f *clientPanelFake) GetPatientNote(ctx context.Context, id uuid.UUID) (db.PatientNote, error) {
	return f.getPatientNoteFn(ctx, id)
}
func (f *clientPanelFake) SetSessionSharedWithClient(ctx context.Context, arg db.SetSessionSharedWithClientParams) (db.SetSessionSharedWithClientRow, error) {
	f.setSessionSharedCalls = append(f.setSessionSharedCalls, arg)
	if f.setSessionSharedFn != nil {
		return f.setSessionSharedFn(ctx, arg)
	}
	return db.SetSessionSharedWithClientRow{ID: arg.ID}, nil
}
func (f *clientPanelFake) SetNoteSharedWithClient(ctx context.Context, arg db.SetNoteSharedWithClientParams) (db.SetNoteSharedWithClientRow, error) {
	if f.setNoteSharedFn != nil {
		return f.setNoteSharedFn(ctx, arg)
	}
	return db.SetNoteSharedWithClientRow{ID: arg.ID}, nil
}

func newClientPanelServer(q db.Querier) *Server {
	return NewServerWithDeps(q, nil, nil, nil, cryptobox.NewMockBox(), nil, "test-1.0", nil)
}

// ── role + self-access gates ────────────────────────────────────────

func TestClientRPCs_TherapistRole_IsDenied(t *testing.T) {
	s := newClientPanelServer(&clientPanelFake{})
	_, err := s.ClientGetMyOverview(therapistCtxWithID(uuid.New()), &emptypb.Empty{})
	if codeOf(err) != codes.PermissionDenied {
		t.Fatalf("therapist calling client RPC must be PermissionDenied, got %v", err)
	}
}

func TestClientListSessions_ForeignKartoteka_IsNotFound(t *testing.T) {
	caller := uuid.New()
	otherPatient := uuid.New()
	pfID := uuid.New()

	q := &clientPanelFake{}
	q.getPatientFileFn = func(_ context.Context, id uuid.UUID) (db.PatientFile, error) {
		return db.PatientFile{ID: id, TherapistID: uuid.New(),
			PatientID: pgtype.UUID{Bytes: otherPatient, Valid: true}}, nil
	}
	s := newClientPanelServer(q)

	_, err := s.ClientListSessions(clientCtx(caller), &clinicalv1.ClientListSessionsRequest{
		PatientFileId: pfID.String(),
	})
	if codeOf(err) != codes.NotFound {
		t.Fatalf("foreign kartoteka must be NotFound, got %v", err)
	}
}

func TestClientListSessions_OwnKartoteka_ReturnsSharedOnly(t *testing.T) {
	caller := uuid.New()
	pfID := uuid.New()

	q := &clientPanelFake{
		clientSharedSessionsFn: func(_ context.Context, pf uuid.UUID) ([]db.ClientListSharedSessionsRow, error) {
			return []db.ClientListSharedSessionsRow{{
				ID:                 uuid.New(),
				SessionDate:        pgtype.Date{Time: time.Now(), Valid: true},
				SessionNumber:      3,
				SharedWithClientAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
				HasTranscript:      true,
			}}, nil
		},
	}
	q.getPatientFileFn = func(_ context.Context, id uuid.UUID) (db.PatientFile, error) {
		return db.PatientFile{ID: id, TherapistID: uuid.New(),
			PatientID: pgtype.UUID{Bytes: caller, Valid: true}}, nil
	}
	s := newClientPanelServer(q)

	resp, err := s.ClientListSessions(clientCtx(caller), &clinicalv1.ClientListSessionsRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Sessions) != 1 || !resp.Sessions[0].HasTranscript {
		t.Errorf("expected the shared session row, got %+v", resp.Sessions)
	}
}

// ── transcript triple-gate ──────────────────────────────────────────

func TestClientGetTranscript_UnsharedSession_IsNotFound(t *testing.T) {
	caller := uuid.New()

	q := &clientPanelFake{
		clientGetSessionFn: func(_ context.Context, id uuid.UUID) (db.ClientGetSharedSessionRow, error) {
			return db.ClientGetSharedSessionRow{
				ID:        id,
				PatientID: pgtype.UUID{Bytes: caller, Valid: true},
				// shared_with_client_at NOT set
			}, nil
		},
	}
	s := newClientPanelServer(q)

	_, err := s.ClientGetTranscript(clientCtx(caller), &clinicalv1.ClientGetTranscriptRequest{
		SessionId: uuid.NewString(),
	})
	if codeOf(err) != codes.NotFound {
		t.Fatalf("unshared session must be invisible (NotFound), got %v", err)
	}
}

func TestClientGetTranscript_ForeignPatient_IsNotFound(t *testing.T) {
	caller := uuid.New()
	otherPatient := uuid.New()

	q := &clientPanelFake{
		clientGetSessionFn: func(_ context.Context, id uuid.UUID) (db.ClientGetSharedSessionRow, error) {
			return db.ClientGetSharedSessionRow{
				ID:                 id,
				PatientID:          pgtype.UUID{Bytes: otherPatient, Valid: true},
				SharedWithClientAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
			}, nil
		},
	}
	s := newClientPanelServer(q)

	_, err := s.ClientGetTranscript(clientCtx(caller), &clinicalv1.ClientGetTranscriptRequest{
		SessionId: uuid.NewString(),
	})
	if codeOf(err) != codes.NotFound {
		t.Fatalf("another patient's session must be NotFound, got %v", err)
	}
}

func TestClientGetTranscript_SharedOwned_NoTranscriptYet_ReturnsSessionOnly(t *testing.T) {
	caller := uuid.New()

	q := &clientPanelFake{
		clientGetSessionFn: func(_ context.Context, id uuid.UUID) (db.ClientGetSharedSessionRow, error) {
			return db.ClientGetSharedSessionRow{
				ID:                 id,
				SessionDate:        pgtype.Date{Time: time.Now(), Valid: true},
				PatientID:          pgtype.UUID{Bytes: caller, Valid: true},
				SharedWithClientAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
			}, nil
		},
	}
	q.getTranscriptBySessionFn = func(_ context.Context, _ uuid.UUID) (db.Transcript, error) {
		return db.Transcript{}, pgx.ErrNoRows
	}
	s := newClientPanelServer(q)

	resp, err := s.ClientGetTranscript(clientCtx(caller), &clinicalv1.ClientGetTranscriptRequest{
		SessionId: uuid.NewString(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Session == nil || resp.Transcript != nil {
		t.Errorf("want session metadata without transcript, got %+v", resp)
	}
}

// ── client notes ────────────────────────────────────────────────────

func TestClientCreateNote_EncryptsAndTargetsTherapist(t *testing.T) {
	caller := uuid.New()
	therapist := uuid.New()
	pfID := uuid.New()

	q := &clientPanelFake{
		createClientNoteFn: func(_ context.Context, arg db.CreateClientNoteParams) (db.PatientNote, error) {
			if arg.TherapistID != therapist {
				t.Errorf("note counterparty = %s, want kartoteka owner %s", arg.TherapistID, therapist)
			}
			if len(arg.TitleCiphertext) == 0 || len(arg.TextCiphertext) == 0 {
				t.Errorf("note must be stored encrypted")
			}
			return db.PatientNote{
				ID: uuid.New(), PatientFileID: arg.PatientFileID,
				TherapistID: arg.TherapistID, Kind: "CLIENT_NOTE",
				AuthorRole:        "PATIENT",
				TitleCiphertext:   arg.TitleCiphertext,
				TitleEncryptedDek: arg.TitleEncryptedDek,
				TextCiphertext:    arg.TextCiphertext,
				TextEncryptedDek:  arg.TextEncryptedDek,
				CreatedAt:         time.Now(),
			}, nil
		},
	}
	q.getPatientFileFn = func(_ context.Context, id uuid.UUID) (db.PatientFile, error) {
		return db.PatientFile{ID: id, TherapistID: therapist,
			PatientID: pgtype.UUID{Bytes: caller, Valid: true}}, nil
	}
	s := newClientPanelServer(q)

	note, err := s.ClientCreateNote(clientCtx(caller), &clinicalv1.ClientCreateNoteRequest{
		PatientFileId: pfID.String(),
		Title:         "Moje przemyślenia",
		Text:          "Po sesji czuję się lepiej.",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if note.Kind != "CLIENT_NOTE" || note.AuthorRole != "PATIENT" {
		t.Errorf("kind/author = %s/%s, want CLIENT_NOTE/PATIENT", note.Kind, note.AuthorRole)
	}
	if note.Title != "Moje przemyślenia" {
		t.Errorf("round-trip title mismatch: %q", note.Title)
	}
}

// ── therapist sharing toggles ───────────────────────────────────────

func TestShareSessionWithClient_ForeignTherapist_IsNotFound(t *testing.T) {
	owner := uuid.New()
	q := &clientPanelFake{}
	q.getSessionFn = func(_ context.Context, id uuid.UUID) (db.Session, error) {
		return db.Session{ID: id, TherapistID: owner}, nil
	}
	s := newClientPanelServer(q)

	_, err := s.ShareSessionWithClient(therapistCtxWithID(uuid.New()), &clinicalv1.ShareSessionWithClientRequest{
		SessionId: uuid.NewString(), Shared: true,
	})
	if codeOf(err) != codes.NotFound {
		t.Fatalf("foreign session share must be NotFound, got %v", err)
	}
}

func TestShareSessionWithClient_Owner_TogglesMarker(t *testing.T) {
	owner := uuid.New()
	q := &clientPanelFake{}
	q.getSessionFn = func(_ context.Context, id uuid.UUID) (db.Session, error) {
		return db.Session{ID: id, TherapistID: owner}, nil
	}
	s := newClientPanelServer(q)

	if _, err := s.ShareSessionWithClient(therapistCtxWithID(owner), &clinicalv1.ShareSessionWithClientRequest{
		SessionId: uuid.NewString(), Shared: true,
	}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(q.setSessionSharedCalls) != 1 || q.setSessionSharedCalls[0].Column2 != true {
		t.Errorf("expected shared=true toggle, got %+v", q.setSessionSharedCalls)
	}
}

func TestShareNoteWithClient_ClientNote_IsFailedPrecondition(t *testing.T) {
	owner := uuid.New()
	q := &clientPanelFake{
		getPatientNoteFn: func(_ context.Context, id uuid.UUID) (db.PatientNote, error) {
			return db.PatientNote{ID: id, TherapistID: owner, Kind: "CLIENT_NOTE"}, nil
		},
	}
	s := newClientPanelServer(q)

	_, err := s.ShareNoteWithClient(therapistCtxWithID(owner), &clinicalv1.ShareNoteWithClientRequest{
		NoteId: uuid.NewString(), Shared: true,
	})
	if codeOf(err) != codes.FailedPrecondition {
		t.Fatalf("sharing a CLIENT_NOTE must be FailedPrecondition, got %v", err)
	}
}
