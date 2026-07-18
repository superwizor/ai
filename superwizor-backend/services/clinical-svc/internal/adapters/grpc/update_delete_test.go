package grpc

// Extensive tests for the Update/Delete handler surface. Covers:
//   - UpdatePatientFile
//   - UpdatePatientUser
//   - DeletePatientUser    (RODO-style cascade + Pub/Sub fan-out)
//   - DeletePatientFile    (tx-coordinated hard delete + Pub/Sub fan-out)
//   - UpdateSession        (rename)
//   - DeleteSession        (hard delete + Pub/Sub)
//
// Each handler gets:
//   - input validation cases (bad UUIDs, missing auth ctx)
//   - authz cases (wrong therapist returns 404, not 403, to avoid
//     ID enumeration leaks)
//   - DB-error cases per query the handler calls (Internal mapping,
//     unique-violation → AlreadyExists where relevant)
//   - happy-path with full proto-shape assertion
//   - Pub/Sub fan-out assertions (one publish per session id, failure
//     in publisher does not unwind the DB delete, nil publisher is
//     accepted)
//
// Tests use testdoubles_test.go: fakeQuerier (embeds nil db.Querier so
// unset methods panic loudly), fakeTxOpener, fakePublisher.

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// ---------- shared helpers ----------

// ctxWithUser injects the therapist-id string the auth interceptor
// would have set. All authenticated handlers read ctx.Value(UserIDKey).
func ctxWithUser(t *testing.T, id uuid.UUID) context.Context {
	t.Helper()
	return context.WithValue(context.Background(), UserIDKey, id.String())
}

// newTestServer wires a Server with the given Querier/TxOpener/Publisher.
// identity + crypto stay nil — none of the Update/Delete handlers under
// test touch them.
func newTestServer(q db.Querier, tx TxOpener, pub SessionEventPublisher) *Server {
	return NewServerWithDeps(q, tx, nil, nil, nil, pub, "test-1.0", nil)
}

// codeOf extracts the gRPC code from an error. Returns codes.OK for nil.
func codeOf(err error) codes.Code {
	if err == nil {
		return codes.OK
	}
	if st, ok := status.FromError(err); ok {
		return st.Code()
	}
	return codes.Unknown
}

// uniqueViolation returns a pgconn.PgError that isUniqueViolation() should
// classify as 23505. Lives here so the test doesn't depend on production
// query layer producing real PG errors.
func uniqueViolation() error {
	return &pgconn.PgError{Code: pgerrcode.UniqueViolation, Message: "duplicate key value violates unique constraint"}
}

// patientFileFixture — minimal PatientFile row with the given id +
// therapist + patient (nil patient means PatientID.Valid = false, used
// to test the "patient already wiped" branch).
func patientFileFixture(id, therapist uuid.UUID, patient *uuid.UUID) db.PatientFile {
	pf := db.PatientFile{ID: id, TherapistID: therapist, ProcessType: db.ProcessType("INDIVIDUAL")}
	if patient != nil {
		pf.PatientID = pgtype.UUID{Bytes: *patient, Valid: true}
	}
	return pf
}

// withUserRowFixture — non-empty row for refetch assertions.
// consent_given_at is set to a fixed timestamp so tests can prove the
// mapper emits it (vs. leaving the proto field zero). This mirrors the
// real shape clinical-svc returns once 000005's CASE-based insert has
// run with has_recording_consent=true.
func withUserRowFixture(id, therapist uuid.UUID, patient *uuid.UUID) db.GetPatientFileWithUserRow {
	row := db.GetPatientFileWithUserRow{
		ID:                  id,
		TherapistID:         therapist,
		WorkingAlias:        "alias-after-update",
		ProcessType:         db.ProcessType("INDIVIDUAL"),
		HasRecordingConsent: true,
		ConsentGivenAt:      pgtype.Timestamptz{Time: fixedConsentTime, Valid: true},
		ModalityCode:        "CBT",
	}
	if patient != nil {
		row.PatientID = pgtype.UUID{Bytes: *patient, Valid: true}
		lang := "pl"
		row.PatientLanguageCode = &lang
	}
	return row
}

// fixedConsentTime — deterministic timestamp used by withUserRowFixture
// so assertions can compare exact-equal without timing flake. Year is
// far enough in the past that it's obviously test data if it leaks.
var fixedConsentTime = time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)

// =================================================================
//   UpdatePatientFile
// =================================================================

func TestUpdatePatientFile_InvalidPatientFileID(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdatePatientFile(context.Background(), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId: "not-a-uuid",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v (err=%v)", got, err)
	}
}

func TestUpdatePatientFile_UniqueViolationMapsToAlreadyExists(t *testing.T) {
	id := uuid.New()
	therapistID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, pid uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(pid, therapistID, nil), nil
		},
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			return db.PatientFile{}, uniqueViolation()
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientFile(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId: id.String(),
		WorkingAlias:  "alias-taken",
	})
	if got := codeOf(err); got != codes.AlreadyExists {
		t.Fatalf("want AlreadyExists, got %v (err=%v)", got, err)
	}
	if !strings.Contains(err.Error(), "alias-taken") {
		t.Errorf("want error to mention the conflicting alias, got %q", err.Error())
	}
}

func TestUpdatePatientFile_GenericDBErrorMapsToInternal(t *testing.T) {
	therapistID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, pid uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(pid, therapistID, nil), nil
		},
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			return db.PatientFile{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientFile(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestUpdatePatientFile_RefetchFailureIsInternal(t *testing.T) {
	id := uuid.New()
	therapistID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, pid uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(pid, therapistID, nil), nil
		},
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			return db.PatientFile{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, _ uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return db.GetPatientFileWithUserRow{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientFile(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId: id.String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestUpdatePatientFile_HappyPath(t *testing.T) {
	pfID := uuid.New()
	therapistID := uuid.New()
	patientID := uuid.New()

	var receivedParams db.UpdatePatientFileParams
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			receivedParams = arg
			return db.PatientFile{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return withUserRowFixture(id, therapistID, &patientID), nil
		},
	}
	srv := newTestServer(q, nil, nil)

	resp, err := srv.UpdatePatientFile(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId:         pfID.String(),
		WorkingAlias:          "Marcus",
		InitialComplaint:      "anxiety",
		PrivateTherapistNotes: "ok",
		IsProcessClosed:       true,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Id != pfID.String() {
		t.Errorf("id: want %s, got %s", pfID, resp.Id)
	}
	if resp.ModalityCode != "CBT" {
		t.Errorf("modality_code: want CBT (from JOIN), got %q", resp.ModalityCode)
	}
	if resp.ConsentGivenAt == nil {
		t.Errorf("consent_given_at must be emitted when the JOINed row has Valid=true")
	} else if !resp.ConsentGivenAt.AsTime().Equal(fixedConsentTime) {
		t.Errorf("consent_given_at: want %v, got %v", fixedConsentTime, resp.ConsentGivenAt.AsTime())
	}
	if !resp.HasRecordingConsent {
		t.Errorf("has_recording_consent must come through as true")
	}
	//nolint:staticcheck // SA1019: deliberate — this guard asserts the deprecated field stays empty (docs/43 §4)
	if resp.PatientFirstName != "" {
		t.Errorf("deprecated patient_first_name must stay empty (docs/43 §4), got %q", resp.PatientFirstName) //nolint:staticcheck // SA1019: see guard above
	}
	if resp.WorkingAlias != "alias-after-update" {
		t.Errorf("working_alias: want alias-after-update (from refetch), got %q", resp.WorkingAlias)
	}
	if receivedParams.IsProcessClosed != true {
		t.Errorf("is_process_closed must propagate; got %v", receivedParams.IsProcessClosed)
	}
	if receivedParams.Column2 != "Marcus" || receivedParams.Column3 != "anxiety" || receivedParams.Column4 != "ok" {
		t.Errorf("update params didn't propagate request strings; got %+v", receivedParams)
	}
}

// Patient_file with consent=false stored at insert time → mapper must
// leave the proto consent_given_at field nil rather than emitting a
// zero-time. Mirrors what happens for a kartoteka created with
// has_recording_consent=false (or a legacy row predating the CASE-fix).
func TestUpdatePatientFile_NoConsentLeavesTimestampNil(t *testing.T) {
	pfID := uuid.New()
	therapistID := uuid.New()

	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			return db.PatientFile{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			row := withUserRowFixture(id, therapistID, nil)
			// Override the fixture defaults — no consent given.
			row.HasRecordingConsent = false
			row.ConsentGivenAt = pgtype.Timestamptz{Valid: false}
			return row, nil
		},
	}
	srv := newTestServer(q, nil, nil)
	resp, err := srv.UpdatePatientFile(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.HasRecordingConsent {
		t.Errorf("has_recording_consent must reflect the row (false); got true")
	}
	if resp.ConsentGivenAt != nil {
		t.Errorf("consent_given_at must stay nil when the DB row is NULL; got %v", resp.ConsentGivenAt.AsTime())
	}
}

// =================================================================
//   UpdatePatientUser
// =================================================================

func TestUpdatePatientUser_MissingAuthCtx(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdatePatientUser(context.Background(), &clinicalv1.UpdatePatientUserRequest{})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", got)
	}
}

func TestUpdatePatientUser_InvalidTherapistIDInCtx(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "not-a-uuid")
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdatePatientUser(ctx, &clinicalv1.UpdatePatientUserRequest{})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestUpdatePatientUser_InvalidPatientFileID(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, uuid.New()), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: "garbage",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestUpdatePatientUser_NotFound(t *testing.T) {
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, uuid.New()), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v", got)
	}
}

// Wrong therapist must NOT leak ownership info — returns same NotFound
// code as "actually missing" so callers can't enumerate kartoteka IDs.
func TestUpdatePatientUser_WrongTherapistReturnsNotFound(t *testing.T) {
	requesterID := uuid.New()
	ownerID := uuid.New()
	pfID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, ownerID, nil), nil
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, requesterID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound (leak protection), got %v", got)
	}
}

// patient_id NULL means a pseudonymous kartoteka (no paired user).
// UpdatePatientUser must succeed as a no-op: since migration 000077
// there is no stored e-mail to persist (deprecated patient_email in the
// request is ignored) and the user update is skipped (no row to touch).
func TestUpdatePatientUser_NullPatientIDIsNoop(t *testing.T) {
	therapistID := uuid.New()
	pfID := uuid.New()
	userUpdated := false
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return db.GetPatientFileWithUserRow{}, nil
		},
		updatePatientUserFn: func(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error) {
			userUpdated = true
			return db.UpdatePatientUserRow{}, nil
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
		PatientEmail:  "liniana@example.com",
	})
	if err != nil {
		t.Fatalf("want success for pseudonymous kartoteka, got %v", err)
	}
	if userUpdated {
		t.Fatalf("UpdatePatientUser (language) must be skipped when patient_id is NULL")
	}
}

func TestUpdatePatientUser_DBUpdateError(t *testing.T) {
	therapistID := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		updatePatientUserFn: func(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error) {
			return db.UpdatePatientUserRow{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestUpdatePatientUser_RefetchFailure(t *testing.T) {
	therapistID := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		updatePatientUserFn: func(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error) {
			return db.UpdatePatientUserRow{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, _ uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return db.GetPatientFileWithUserRow{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestUpdatePatientUser_HappyPath(t *testing.T) {
	therapistID := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	var receivedParams db.UpdatePatientUserParams
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		updatePatientUserFn: func(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error) {
			receivedParams = arg
			return db.UpdatePatientUserRow{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return withUserRowFixture(id, therapistID, &patientID), nil
		},
	}
	srv := newTestServer(q, nil, nil)
	// FirstName/LastName are deprecated wire-compat fields (docs/43 §4):
	// an older app build sending them must succeed, the values must NOT
	// reach the users row nor come back in the response — but the edit
	// intent is NOT lost: it maps onto working_alias (legacy-compat,
	// 2026-07-18 "zapisz i nic się nie zmienia" fix).
	resp, err := srv.UpdatePatientUser(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
		FirstName:     "Anna",
		LastName:      "Nowak",
		LanguageCode:  "pl",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if receivedParams.ID != patientID {
		t.Errorf("update must target the joined patient_id, got %v want %v", receivedParams.ID, patientID)
	}
	if receivedParams.LanguageCode != "pl" {
		t.Errorf("language must propagate; got %+v", receivedParams)
	}
	if len(q.setWorkingAliasCalls) != 1 || q.setWorkingAliasCalls[0].WorkingAlias != "Anna Nowak" {
		t.Errorf("legacy names must map onto working_alias 'Anna Nowak', got %+v", q.setWorkingAliasCalls)
	}
	//nolint:staticcheck // SA1019: deliberate — this guard asserts the deprecated fields stay empty (docs/43 §4)
	if resp.PatientFirstName != "" || resp.PatientLastName != "" {
		t.Errorf("deprecated name fields must stay empty, got %q %q", //nolint:staticcheck // SA1019: see guard above
			resp.PatientFirstName, resp.PatientLastName)
	}
}

// New-style callers (post-docs/43 builds) send no names — the legacy
// alias mapping must stay inert (alias edited only via UpdatePatientFile).
func TestUpdatePatientUser_NoNamesLeavesAliasAlone(t *testing.T) {
	therapistID := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		updatePatientUserFn: func(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error) {
			return db.UpdatePatientUserRow{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return withUserRowFixture(id, therapistID, &patientID), nil
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
		LanguageCode:  "en",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(q.setWorkingAliasCalls) != 0 {
		t.Errorf("no names in request → SetWorkingAlias must not run, got %+v", q.setWorkingAliasCalls)
	}
}

// Legacy alias edit hitting ux_patient_files_therapist_alias must map
// to AlreadyExists so the old UI shows "alias taken", not a 500.
func TestUpdatePatientUser_LegacyAliasCollision(t *testing.T) {
	therapistID := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		setWorkingAliasFn: func(ctx context.Context, arg db.SetWorkingAliasParams) error {
			return &pgconn.PgError{Code: pgerrcode.UniqueViolation, ConstraintName: "ux_patient_files_therapist_alias"}
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdatePatientUser(ctxWithUser(t, therapistID), &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: pfID.String(),
		FirstName:     "Anna",
		LastName:      "Nowak",
	})
	if got := codeOf(err); got != codes.AlreadyExists {
		t.Fatalf("want AlreadyExists on alias collision, got %v (err=%v)", got, err)
	}
}

// =================================================================
//   DeletePatientUser
// =================================================================

func TestDeletePatientUser_MissingAuth(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.DeletePatientUser(context.Background(), &clinicalv1.DeletePatientUserRequest{})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", got)
	}
}

func TestDeletePatientUser_InvalidTherapistIDInCtx(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "not-a-uuid")
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.DeletePatientUser(ctx, &clinicalv1.DeletePatientUserRequest{})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestDeletePatientUser_InvalidPatientFileID(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.DeletePatientUser(ctxWithUser(t, uuid.New()), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: "junk",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestDeletePatientUser_NotFound(t *testing.T) {
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.DeletePatientUser(ctxWithUser(t, uuid.New()), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v", got)
	}
}

func TestDeletePatientUser_WrongTherapistReturnsNotFound(t *testing.T) {
	requesterID := uuid.New()
	ownerID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, ownerID, nil), nil
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.DeletePatientUser(ctxWithUser(t, requesterID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound (leak protection), got %v", got)
	}
}

// Kartoteka with no patient_id (already wiped) → no-op success.
// DeletePatientUser handler must NOT call the DELETE query at all in
// this branch, otherwise it'd try to delete uuid.Nil.
func TestDeletePatientUser_NoPatientIsNoOpSuccess(t *testing.T) {
	therapistID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
		// listSessionIDsForPatientFn intentionally nil — must not be called.
		// deletePatientUserFn intentionally nil — must not be called.
	}
	pub := &fakePublisher{}
	srv := newTestServer(q, nil, pub)
	_, err := srv.DeletePatientUser(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("expected no-op success, got %v", err)
	}
	if len(q.deletePatientUserCalls) != 0 {
		t.Errorf("must not call DeletePatientUser when patient_id is NULL; got %d calls", len(q.deletePatientUserCalls))
	}
	if len(pub.calls) != 0 {
		t.Errorf("must not publish events when no patient existed; got %d", len(pub.calls))
	}
}

func TestDeletePatientUser_ListSessionsErrorIsInternal(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		listSessionIDsForPatientFn: func(ctx context.Context, _ pgtype.UUID) ([]uuid.UUID, error) {
			return nil, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.DeletePatientUser(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestDeletePatientUser_DeleteErrorIsInternal(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		listSessionIDsForPatientFn: func(ctx context.Context, _ pgtype.UUID) ([]uuid.UUID, error) {
			return nil, nil
		},
		deletePatientUserFn: func(ctx context.Context, _ uuid.UUID) (int64, error) {
			return 0, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.DeletePatientUser(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

// Happy path: 2 sessions live under this patient → after the cascade
// fires, the handler must publish exactly 2 session.deleted events,
// in some order. Each carries the right session_id + therapist_id.
func TestDeletePatientUser_HappyPathPublishesAllSessions(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	pfID := uuid.New()
	sess1, sess2 := uuid.New(), uuid.New()

	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		listSessionIDsForPatientFn: func(ctx context.Context, pid pgtype.UUID) ([]uuid.UUID, error) {
			// Verify the handler is asking about the right patient.
			if !pid.Valid || uuid.UUID(pid.Bytes) != patientID {
				t.Errorf("list called with wrong patient_id")
			}
			return []uuid.UUID{sess1, sess2}, nil
		},
		deletePatientUserFn: func(ctx context.Context, id uuid.UUID) (int64, error) {
			if id != patientID {
				t.Errorf("delete called with wrong id: %v want %v", id, patientID)
			}
			return 1, nil
		},
	}
	pub := &fakePublisher{}
	srv := newTestServer(q, nil, pub)
	_, err := srv.DeletePatientUser(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pub.calls) != 2 {
		t.Fatalf("want 2 published events, got %d", len(pub.calls))
	}
	got := map[string]bool{}
	for _, c := range pub.calls {
		got[c.sessionID] = true
		if c.therapistID != therapistID.String() {
			t.Errorf("publish therapist_id wrong: %v", c.therapistID)
		}
	}
	if !got[sess1.String()] || !got[sess2.String()] {
		t.Errorf("missing one of the expected session ids; got %+v", pub.calls)
	}
}

// Pub/Sub failure must NOT unwind the DELETE — DB is authoritative.
// Two sessions, both publishes fail → handler still returns OK.
func TestDeletePatientUser_PublishErrorDoesNotFailHandler(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		listSessionIDsForPatientFn: func(ctx context.Context, _ pgtype.UUID) ([]uuid.UUID, error) {
			return []uuid.UUID{uuid.New(), uuid.New()}, nil
		},
		deletePatientUserFn: func(ctx context.Context, _ uuid.UUID) (int64, error) { return 1, nil },
	}
	pub := &fakePublisher{publishErr: errSentinel}
	srv := newTestServer(q, nil, pub)
	_, err := srv.DeletePatientUser(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("publish failure must not surface as handler error; got %v", err)
	}
	if len(pub.calls) != 2 {
		t.Errorf("handler must attempt every publish despite earlier failures; got %d", len(pub.calls))
	}
}

// Nil publisher (local dev w/o Pub/Sub creds) must not crash.
func TestDeletePatientUser_NilPublisherIsAllowed(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
		listSessionIDsForPatientFn: func(ctx context.Context, _ pgtype.UUID) ([]uuid.UUID, error) {
			return []uuid.UUID{uuid.New()}, nil
		},
		deletePatientUserFn: func(ctx context.Context, _ uuid.UUID) (int64, error) { return 1, nil },
	}
	srv := newTestServer(q, nil, nil) // pub == nil
	_, err := srv.DeletePatientUser(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientUserRequest{
		PatientFileId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("nil publisher must be tolerated, got %v", err)
	}
}

// =================================================================
//   DeletePatientFile
// =================================================================

func TestDeletePatientFile_MissingAuth(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, &fakeTxOpener{}, nil)
	_, err := srv.DeletePatientFile(context.Background(), &clinicalv1.DeletePatientFileRequest{})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", got)
	}
}

func TestDeletePatientFile_InvalidTherapistIDInCtx(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "not-a-uuid")
	srv := newTestServer(&fakeQuerier{}, &fakeTxOpener{}, nil)
	_, err := srv.DeletePatientFile(ctx, &clinicalv1.DeletePatientFileRequest{})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestDeletePatientFile_InvalidPatientFileID(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, &fakeTxOpener{}, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, uuid.New()), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: "x",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestDeletePatientFile_ListSessionIDsErrorIsInternal(t *testing.T) {
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) {
			return nil, errSentinel
		},
	}
	srv := newTestServer(q, &fakeTxOpener{}, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, uuid.New()), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestDeletePatientFile_GetNotFound(t *testing.T) {
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, _ uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{}, errSentinel
		},
	}
	srv := newTestServer(q, &fakeTxOpener{}, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, uuid.New()), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v", got)
	}
}

func TestDeletePatientFile_WrongTherapistReturnsNotFound(t *testing.T) {
	requester := uuid.New()
	owner := uuid.New()
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, owner, nil), nil
		},
	}
	srv := newTestServer(q, &fakeTxOpener{}, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, requester), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v", got)
	}
}

func TestDeletePatientFile_TxBeginError(t *testing.T) {
	therapistID := uuid.New()
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
	}
	tx := &fakeTxOpener{beginErr: errSentinel}
	srv := newTestServer(q, tx, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

func TestDeletePatientFile_HardDeleteErrorIsInternal(t *testing.T) {
	therapistID := uuid.New()
	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 0, errSentinel
		},
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
	}
	tx := &fakeTxOpener{q: txQ}
	srv := newTestServer(q, tx, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
	if tx.commitCalls != 0 {
		t.Errorf("must NOT commit when HardDelete failed; commit called %d times", tx.commitCalls)
	}
	if tx.rollbackCalls == 0 {
		t.Errorf("deferred rollback must fire on error path")
	}
}

// HardDeletePatientFile returning 0 rows means "no row matched the
// (id, therapist_id) predicate" — translate to NotFound (vs Internal).
func TestDeletePatientFile_ZeroRowsIsNotFound(t *testing.T) {
	therapistID := uuid.New()
	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 0, nil
		},
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
	}
	srv := newTestServer(q, &fakeTxOpener{q: txQ}, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound on 0-rows, got %v", got)
	}
}

func TestDeletePatientFile_PairedUserDeleteErrorIsInternal(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 1, nil
		},
		deletePatientUserFn: func(ctx context.Context, _ uuid.UUID) (int64, error) {
			return 0, errSentinel
		},
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
	}
	tx := &fakeTxOpener{q: txQ}
	srv := newTestServer(q, tx, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
	if tx.commitCalls != 0 {
		t.Errorf("tx must NOT commit when user delete failed")
	}
}

func TestDeletePatientFile_CommitErrorIsInternal(t *testing.T) {
	therapistID := uuid.New()
	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 1, nil
		},
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
	}
	tx := &fakeTxOpener{q: txQ, commitErr: errSentinel}
	srv := newTestServer(q, tx, nil)
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

// Happy path with patient_id set:
//   - HardDeletePatientFile called with (id, therapist_id) authz tuple
//   - DeletePatientUser called inside same tx with patientID
//   - tx committed
//   - one session.deleted event per pre-fetched session id
func TestDeletePatientFile_HappyPathWithPatient(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	pfID := uuid.New()
	sess1, sess2, sess3 := uuid.New(), uuid.New(), uuid.New()

	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 1, nil
		},
		deletePatientUserFn: func(ctx context.Context, id uuid.UUID) (int64, error) {
			if id != patientID {
				t.Errorf("DeletePatientUser called with wrong id: %v want %v", id, patientID)
			}
			return 1, nil
		},
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, id uuid.UUID) ([]uuid.UUID, error) {
			if id != pfID {
				t.Errorf("list called with wrong patient_file_id")
			}
			return []uuid.UUID{sess1, sess2, sess3}, nil
		},
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, &patientID), nil
		},
	}
	tx := &fakeTxOpener{q: txQ}
	pub := &fakePublisher{}
	srv := newTestServer(q, tx, pub)

	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	if tx.commitCalls != 1 {
		t.Errorf("want 1 commit, got %d", tx.commitCalls)
	}
	if len(txQ.hardDeletePatientFileArgs) != 1 {
		t.Fatalf("want 1 HardDelete call, got %d", len(txQ.hardDeletePatientFileArgs))
	}
	if txQ.hardDeletePatientFileArgs[0].TherapistID != therapistID {
		t.Errorf("HardDelete must include therapist_id as authz guard")
	}
	if len(txQ.deletePatientUserCalls) != 1 || txQ.deletePatientUserCalls[0] != patientID {
		t.Errorf("DeletePatientUser must run inside same tx for patient %v; got %+v", patientID, txQ.deletePatientUserCalls)
	}
	if len(pub.calls) != 3 {
		t.Errorf("want 3 publishes (one per session), got %d", len(pub.calls))
	}
}

// Without a paired patient (e.g. kartoteka created before migration
// 000013, or after a previous DeletePatientUser orphaned it):
// HardDelete still runs, DeletePatientUser must NOT.
func TestDeletePatientFile_HappyPathNoPatient(t *testing.T) {
	therapistID := uuid.New()
	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 1, nil
		},
		// deletePatientUserFn intentionally nil — calling it would panic.
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) { return nil, nil },
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
	}
	tx := &fakeTxOpener{q: txQ}
	srv := newTestServer(q, tx, &fakePublisher{})
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	if len(txQ.deletePatientUserCalls) != 0 {
		t.Errorf("must NOT call DeletePatientUser when patient_id is NULL; got %d", len(txQ.deletePatientUserCalls))
	}
}

// Pub/Sub publish failure must not unwind the commit (commit already
// happened) — handler returns OK, every publish was at least attempted.
func TestDeletePatientFile_PublishErrorDoesNotFail(t *testing.T) {
	therapistID := uuid.New()
	txQ := &fakeQuerier{
		hardDeletePatientFileFn: func(ctx context.Context, _ db.HardDeletePatientFileParams) (int64, error) {
			return 1, nil
		},
	}
	q := &fakeQuerier{
		listSessionIDsForPFFn: func(ctx context.Context, _ uuid.UUID) ([]uuid.UUID, error) {
			return []uuid.UUID{uuid.New(), uuid.New()}, nil
		},
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return patientFileFixture(id, therapistID, nil), nil
		},
	}
	pub := &fakePublisher{publishErr: errors.New("pubsub down")}
	srv := newTestServer(q, &fakeTxOpener{q: txQ}, pub)
	_, err := srv.DeletePatientFile(ctxWithUser(t, therapistID), &clinicalv1.DeletePatientFileRequest{
		PatientFileId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("publish errors must not surface; got %v", err)
	}
	if len(pub.calls) != 2 {
		t.Errorf("handler must attempt every publish; got %d", len(pub.calls))
	}
}

// =================================================================
//   UpdateSession
// =================================================================

func TestUpdateSession_MissingAuth(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdateSession(context.Background(), &clinicalv1.UpdateSessionRequest{})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", got)
	}
}

func TestUpdateSession_InvalidTherapistIDInCtx(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "not-a-uuid")
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdateSession(ctx, &clinicalv1.UpdateSessionRequest{Name: "x"})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestUpdateSession_InvalidSessionID(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdateSession(ctxWithUser(t, uuid.New()), &clinicalv1.UpdateSessionRequest{
		SessionId: "junk",
		Name:      "x",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestUpdateSession_EmptyNameRejected(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdateSession(ctxWithUser(t, uuid.New()), &clinicalv1.UpdateSessionRequest{
		SessionId: uuid.New().String(),
		Name:      "   ", // whitespace-only also empty after TrimSpace
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestUpdateSession_OverlongNameRejected(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.UpdateSession(ctxWithUser(t, uuid.New()), &clinicalv1.UpdateSessionRequest{
		SessionId: uuid.New().String(),
		Name:      strings.Repeat("a", 256),
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestUpdateSession_SessionNotFound(t *testing.T) {
	q := &fakeQuerier{
		getSessionFn: func(ctx context.Context, _ uuid.UUID) (db.Session, error) {
			return db.Session{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdateSession(ctxWithUser(t, uuid.New()), &clinicalv1.UpdateSessionRequest{
		SessionId: uuid.New().String(),
		Name:      "x",
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v", got)
	}
}

func TestUpdateSession_WrongTherapistReturnsNotFound(t *testing.T) {
	requester := uuid.New()
	owner := uuid.New()
	q := &fakeQuerier{
		getSessionFn: func(ctx context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: owner}, nil
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdateSession(ctxWithUser(t, requester), &clinicalv1.UpdateSessionRequest{
		SessionId: uuid.New().String(),
		Name:      "x",
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound (leak protection), got %v", got)
	}
}

func TestUpdateSession_DBUpdateErrorIsInternal(t *testing.T) {
	therapistID := uuid.New()
	q := &fakeQuerier{
		getSessionFn: func(ctx context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapistID}, nil
		},
		updateSessionNameFn: func(ctx context.Context, _ db.UpdateSessionNameParams) (db.Session, error) {
			return db.Session{}, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.UpdateSession(ctxWithUser(t, therapistID), &clinicalv1.UpdateSessionRequest{
		SessionId: uuid.New().String(),
		Name:      "x",
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

// Name must arrive at the DB trimmed.
func TestUpdateSession_HappyPathTrimsName(t *testing.T) {
	therapistID := uuid.New()
	sessionID := uuid.New()
	var receivedParams db.UpdateSessionNameParams
	q := &fakeQuerier{
		getSessionFn: func(ctx context.Context, id uuid.UUID) (db.Session, error) {
			return db.Session{ID: id, TherapistID: therapistID}, nil
		},
		updateSessionNameFn: func(ctx context.Context, arg db.UpdateSessionNameParams) (db.Session, error) {
			receivedParams = arg
			name := *arg.Name
			return db.Session{ID: arg.ID, TherapistID: therapistID, Name: &name}, nil
		},
	}
	srv := newTestServer(q, nil, nil)
	resp, err := srv.UpdateSession(ctxWithUser(t, therapistID), &clinicalv1.UpdateSessionRequest{
		SessionId: sessionID.String(),
		Name:      "  Session 7  ",
	})
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	if receivedParams.Name == nil || *receivedParams.Name != "Session 7" {
		t.Errorf("name must be TrimSpace'd before hitting DB; got %v", receivedParams.Name)
	}
	if resp.Name != "Session 7" {
		t.Errorf("response name not trimmed: %q", resp.Name)
	}
}

// =================================================================
//   DeleteSession
// =================================================================

func TestDeleteSession_MissingAuth(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.DeleteSession(context.Background(), &clinicalv1.DeleteSessionRequest{})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", got)
	}
}

func TestDeleteSession_InvalidTherapistIDInCtx(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "not-a-uuid")
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.DeleteSession(ctx, &clinicalv1.DeleteSessionRequest{})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestDeleteSession_InvalidSessionID(t *testing.T) {
	srv := newTestServer(&fakeQuerier{}, nil, nil)
	_, err := srv.DeleteSession(ctxWithUser(t, uuid.New()), &clinicalv1.DeleteSessionRequest{
		SessionId: "nope",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", got)
	}
}

func TestDeleteSession_DBErrorIsInternal(t *testing.T) {
	q := &fakeQuerier{
		hardDeleteSessionFn: func(ctx context.Context, _ db.HardDeleteSessionParams) (int64, error) {
			return 0, errSentinel
		},
	}
	srv := newTestServer(q, nil, nil)
	_, err := srv.DeleteSession(ctxWithUser(t, uuid.New()), &clinicalv1.DeleteSessionRequest{
		SessionId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v", got)
	}
}

// 0 rows affected → either the session doesn't exist or belongs to
// another therapist (auth predicate baked into HardDeleteSession WHERE
// clause). Same 404 in both cases to avoid enumeration.
func TestDeleteSession_ZeroRowsIsNotFound(t *testing.T) {
	q := &fakeQuerier{
		hardDeleteSessionFn: func(ctx context.Context, _ db.HardDeleteSessionParams) (int64, error) {
			return 0, nil
		},
	}
	pub := &fakePublisher{}
	srv := newTestServer(q, nil, pub)
	_, err := srv.DeleteSession(ctxWithUser(t, uuid.New()), &clinicalv1.DeleteSessionRequest{
		SessionId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v", got)
	}
	if len(pub.calls) != 0 {
		t.Errorf("must NOT publish session.deleted when nothing was deleted; got %d", len(pub.calls))
	}
}

func TestDeleteSession_HappyPathPublishes(t *testing.T) {
	therapistID := uuid.New()
	sessionID := uuid.New()
	var receivedParams db.HardDeleteSessionParams
	q := &fakeQuerier{
		hardDeleteSessionFn: func(ctx context.Context, arg db.HardDeleteSessionParams) (int64, error) {
			receivedParams = arg
			return 1, nil
		},
	}
	pub := &fakePublisher{}
	srv := newTestServer(q, nil, pub)
	_, err := srv.DeleteSession(ctxWithUser(t, therapistID), &clinicalv1.DeleteSessionRequest{
		SessionId: sessionID.String(),
	})
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	if receivedParams.ID != sessionID || receivedParams.TherapistID != therapistID {
		t.Errorf("HardDeleteSession args wrong: %+v", receivedParams)
	}
	if len(pub.calls) != 1 || pub.calls[0].sessionID != sessionID.String() {
		t.Errorf("want exactly 1 session.deleted publish; got %+v", pub.calls)
	}
}

func TestDeleteSession_PublishErrorDoesNotFailHandler(t *testing.T) {
	q := &fakeQuerier{
		hardDeleteSessionFn: func(ctx context.Context, _ db.HardDeleteSessionParams) (int64, error) {
			return 1, nil
		},
	}
	pub := &fakePublisher{publishErr: errSentinel}
	srv := newTestServer(q, nil, pub)
	_, err := srv.DeleteSession(ctxWithUser(t, uuid.New()), &clinicalv1.DeleteSessionRequest{
		SessionId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("publish errors must not surface as handler error; got %v", err)
	}
}

func TestDeleteSession_NilPublisherIsAllowed(t *testing.T) {
	q := &fakeQuerier{
		hardDeleteSessionFn: func(ctx context.Context, _ db.HardDeleteSessionParams) (int64, error) {
			return 1, nil
		},
	}
	srv := newTestServer(q, nil, nil) // pub == nil
	_, err := srv.DeleteSession(ctxWithUser(t, uuid.New()), &clinicalv1.DeleteSessionRequest{
		SessionId: uuid.New().String(),
	})
	if err != nil {
		t.Fatalf("nil publisher must be tolerated, got %v", err)
	}
}

// =================================================================
//   isUniqueViolation helper — proven correct for the pgerrcode path
// =================================================================

func TestIsUniqueViolation(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want bool
	}{
		{"nil", nil, false},
		{"plain", errors.New("not a pg error"), false},
		{"pg unique violation", &pgconn.PgError{Code: pgerrcode.UniqueViolation}, true},
		{"pg other code", &pgconn.PgError{Code: pgerrcode.NotNullViolation}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := isUniqueViolation(c.err); got != c.want {
				t.Errorf("want %v, got %v", c.want, got)
			}
		})
	}
}
