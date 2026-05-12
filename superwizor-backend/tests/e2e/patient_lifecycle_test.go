//go:build e2e
// +build e2e

package e2e_test

// End-to-end tests for the patient lifecycle CRUD paths in clinical-svc.
// Distinct from TestFullSession_HappyPath: this file does NOT touch the
// STT/LLM pipeline (no audio upload, no Gemini call) so it runs in
// seconds and isolates the create/update/delete RPC surface from the
// expensive ingestion plumbing.
//
// Covers the gaps the happy path doesn't:
//   1. CreatePatientFile with the new patient_first_name / last_name /
//      language_code fields, asserting they round-trip through GetPatientFile
//      and ListPatientFiles.
//   2. UpdatePatientUser editing those fields (RPC added in c74fa9d).
//   3. DeletePatientFile produces NotFound on subsequent reads
//      (RODO right-to-erasure on a single kartoteka).
//   4. DeletePatientUser produces NotFound on subsequent reads AND
//      cascades through every kartoteka (RODO erasure on the patient axis,
//      added in 3fd4f20).
//
// Run with the same setup as TestFullSession_HappyPath:
//   gcloud auth application-default login    # one-time, for Firebase Admin
//   cd tests
//   go test -tags=e2e -timeout=5m -v ./e2e/... -run TestPatientLifecycle

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// lifecycleSetup wires a fresh Firebase user → therapist record →
// authenticated gRPC clients in one go. Returns helpers + cleanup
// (registered via t.Cleanup) so each subtest gets a clean tenant.
//
// We re-use the helpers from full_session_test.go (loadConfig,
// mintFirebaseSession, dial) so the wiring is identical to the happy
// path — same auth interceptor, same Firebase mint flow, same URL
// discovery. The only difference: no audio.
type lifecycleEnv struct {
	t         *testing.T
	ctx       context.Context
	cfg       config
	therapist *identityv1.User
	clinical  clinicalv1.ClinicalServiceClient
	runID     int64
}

func setupLifecycleEnv(t *testing.T) *lifecycleEnv {
	t.Helper()
	cfg := loadConfig(t)
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_lifecycle_%d", runID)
	firebaseEmail := fmt.Sprintf("e2e+lifecycle_%d@superwizor.test", runID)

	// Reuse cached pre-minted token from env if present (CI path);
	// otherwise mint a fresh Firebase user via Admin SDK.
	idToken := cfg.preMintedToken
	if idToken == "" {
		fbSession, err := mintFirebaseSession(context.Background(),
			cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, err, "Firebase token minting")
		t.Cleanup(func() {
			if err := fbSession.cleanup(); err != nil {
				t.Logf("⚠ Firebase user cleanup failed for %s: %v", firebaseUID, err)
			}
		})
		idToken = fbSession.IDToken
	}

	identityConn := dial(t, cfg.identityURL, idToken)
	t.Cleanup(func() { identityConn.Close() })
	clinicalConn := dial(t, cfg.clinicalURL, idToken)
	t.Cleanup(func() { clinicalConn.Close() })

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)

	// Test-level context with a 3-minute budget. The lifecycle RPCs are
	// all sub-second; 3 minutes covers worst-case cold-starts + retries.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	t.Cleanup(cancel)

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "Lifecycle",
		LastName:       "Therapist",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser (therapist)")
	require.NotEmpty(t, therapist.Id)

	return &lifecycleEnv{
		t:         t,
		ctx:       ctx,
		cfg:       cfg,
		therapist: therapist,
		clinical:  clinicalClient,
		runID:     runID,
	}
}

// createTestPatient is a small helper that creates a patient_file
// with the new patient_user fields populated, and returns the proto
// so the test can assert on round-tripped values. Caller is responsible
// for cleanup (most tests delete deliberately as part of the test
// scenario).
func (e *lifecycleEnv) createTestPatient(suffix string) *clinicalv1.PatientFile {
	e.t.Helper()
	pf, err := e.clinical.CreatePatientFile(e.ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId:         e.therapist.Id,
		ModalityCode:        "CBT",
		WorkingAlias:        fmt.Sprintf("Lifecycle Alias %d-%s", e.runID, suffix),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "e2e lifecycle complaint",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-lifecycle-%d-%s", e.runID, suffix),
		PatientFirstName:    "Anna",
		PatientLastName:     "Nowak",
		PatientLanguageCode: "pl",
	})
	require.NoError(e.t, err, "CreatePatientFile")
	require.NotEmpty(e.t, pf.Id)
	return pf
}

// =================================================================
//   TestPatientLifecycle_CreateAndRead — verifies the new user fields
//   added in c74fa9d (patient_first_name, last_name, language_code)
//   AND the modality_code JOIN fix from 662b9db survive a Create → Get
//   → List round-trip against real clinical-svc.
// =================================================================
func TestPatientLifecycle_CreateAndRead(t *testing.T) {
	env := setupLifecycleEnv(t)

	t.Log("\n═══ Step 1: CreatePatientFile with patient_user fields ═══")
	created := env.createTestPatient("create-read")
	t.Cleanup(func() {
		// Best-effort hard delete to keep the test DB clean. Errors here
		// don't fail the test — they only mean we leaked a row in staging.
		bgCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		_, _ = env.clinical.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{
			PatientFileId: created.Id,
		})
	})

	// The Create response carries the new fields directly (no JOIN needed —
	// the handler emits them from the inputs it just inserted).
	assert.Equal(t, "Anna", created.PatientFirstName, "patient_first_name from Create")
	assert.Equal(t, "Nowak", created.PatientLastName, "patient_last_name from Create")
	assert.Equal(t, "pl", created.PatientLanguageCode, "patient_language_code from Create")
	assert.Equal(t, "CBT", created.ModalityCode, "modality_code from Create")
	t.Logf("✓ Create response shape OK (id=%s)", created.Id)

	// Get goes through the With-User JOIN path — proves the JOIN actually
	// resolves the patient_id to the right users row.
	t.Log("\n═══ Step 2: GetPatientFile returns the joined fields ═══")
	got, err := env.clinical.GetPatientFile(env.ctx, &clinicalv1.GetPatientFileRequest{
		PatientFileId: created.Id,
	})
	require.NoError(t, err, "GetPatientFile")
	assert.Equal(t, created.Id, got.Id)
	assert.Equal(t, "Anna", got.PatientFirstName, "GetPatientFile must JOIN patient_user")
	assert.Equal(t, "Nowak", got.PatientLastName)
	assert.Equal(t, "pl", got.PatientLanguageCode)
	assert.Equal(t, "CBT", got.ModalityCode, "GetPatientFile must JOIN modalities (Faza 2 fix)")
	t.Logf("✓ Get response carries JOINed user + modality fields")

	// List should also hit the With-User JOIN path. The test therapist
	// owns exactly one kartoteka so this is a deterministic check.
	t.Log("\n═══ Step 3: ListPatientFiles returns the same fields ═══")
	listed, err := env.clinical.ListPatientFiles(env.ctx, &clinicalv1.ListPatientFilesRequest{
		TherapistId: env.therapist.Id,
		PageSize:    10,
	})
	require.NoError(t, err, "ListPatientFiles")

	var match *clinicalv1.PatientFile
	for _, pf := range listed.PatientFiles {
		if pf.Id == created.Id {
			match = pf
			break
		}
	}
	require.NotNil(t, match, "created kartoteka must appear in List response (got %d total)", len(listed.PatientFiles))
	assert.Equal(t, "Anna", match.PatientFirstName, "List must JOIN patient_user")
	assert.Equal(t, "CBT", match.ModalityCode, "List must JOIN modalities")
	t.Logf("✓ List returns same shape (%d kartoteki total)", len(listed.PatientFiles))
}

// =================================================================
//   TestPatientLifecycle_UpdatePatientUser — exercises the new RPC
//   added in c74fa9d. Empty fields mean "leave alone"; concrete values
//   replace.
// =================================================================
func TestPatientLifecycle_UpdatePatientUser(t *testing.T) {
	env := setupLifecycleEnv(t)
	created := env.createTestPatient("update-user")
	t.Cleanup(func() {
		bgCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		_, _ = env.clinical.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{
			PatientFileId: created.Id,
		})
	})

	t.Log("\n═══ UpdatePatientUser: replace first_name and language ═══")
	updated, err := env.clinical.UpdatePatientUser(env.ctx, &clinicalv1.UpdatePatientUserRequest{
		PatientFileId: created.Id,
		FirstName:     "Katarzyna", // replace
		LastName:      "",          // leave alone (server NULLIF)
		LanguageCode:  "en",        // replace
	})
	require.NoError(t, err, "UpdatePatientUser")
	assert.Equal(t, "Katarzyna", updated.PatientFirstName, "first_name should be updated")
	assert.Equal(t, "Nowak", updated.PatientLastName, "last_name should be untouched")
	assert.Equal(t, "en", updated.PatientLanguageCode, "language_code should be updated")
	assert.Equal(t, "CBT", updated.ModalityCode, "modality_code stays immutable post-create")
	t.Logf("✓ Update returned refreshed PatientFile with new fields")

	// Re-Get to confirm the DB row actually changed (not just the response).
	got, err := env.clinical.GetPatientFile(env.ctx, &clinicalv1.GetPatientFileRequest{
		PatientFileId: created.Id,
	})
	require.NoError(t, err, "GetPatientFile (post-update)")
	assert.Equal(t, "Katarzyna", got.PatientFirstName, "post-update Get reads the new value")
	assert.Equal(t, "en", got.PatientLanguageCode)
}

// =================================================================
//   TestPatientLifecycle_DeletePatientFile — single-kartoteka delete
//   (without touching the patient_user row). Verifies:
//     - DeletePatientFile returns OK (Empty)
//     - subsequent GetPatientFile returns NotFound
//     - the kartoteka no longer appears in ListPatientFiles
// =================================================================
func TestPatientLifecycle_DeletePatientFile(t *testing.T) {
	env := setupLifecycleEnv(t)
	created := env.createTestPatient("delete-pf")
	// NO t.Cleanup with DeletePatientFile — the test IS the delete.

	t.Log("\n═══ Pre-delete: confirm kartoteka exists ═══")
	_, err := env.clinical.GetPatientFile(env.ctx, &clinicalv1.GetPatientFileRequest{
		PatientFileId: created.Id,
	})
	require.NoError(t, err, "pre-delete Get must succeed")
	t.Logf("✓ kartoteka %s exists", created.Id)

	t.Log("\n═══ DeletePatientFile ═══")
	_, err = env.clinical.DeletePatientFile(env.ctx, &clinicalv1.DeletePatientFileRequest{
		PatientFileId: created.Id,
	})
	require.NoError(t, err, "DeletePatientFile")
	t.Logf("✓ DeletePatientFile returned OK")

	t.Log("\n═══ Post-delete: GetPatientFile must be NotFound ═══")
	_, err = env.clinical.GetPatientFile(env.ctx, &clinicalv1.GetPatientFileRequest{
		PatientFileId: created.Id,
	})
	require.Error(t, err, "GetPatientFile must fail after delete")
	st, ok := status.FromError(err)
	require.True(t, ok, "error must be a gRPC status")
	assert.Equal(t, codes.NotFound, st.Code(),
		"deleted kartoteka must return NotFound (RODO erasure complete)")
	t.Logf("✓ Get returns NotFound (gRPC code: %s)", st.Code())

	t.Log("\n═══ Post-delete: ListPatientFiles excludes the deleted row ═══")
	listed, err := env.clinical.ListPatientFiles(env.ctx, &clinicalv1.ListPatientFilesRequest{
		TherapistId: env.therapist.Id,
		PageSize:    10,
	})
	require.NoError(t, err, "ListPatientFiles (post-delete)")
	for _, pf := range listed.PatientFiles {
		assert.NotEqualf(t, created.Id, pf.Id,
			"deleted kartoteka must not appear in List; got %s", pf.Id)
	}
	t.Logf("✓ List excludes deleted kartoteka (%d remaining)", len(listed.PatientFiles))
}

// =================================================================
//   TestPatientLifecycle_DeletePatientUser_RODO — RODO right-to-erasure
//   on the patient axis. Added in 3fd4f20. The user-row delete CASCADEs
//   through patient_files (migration 000014) → sessions → transcripts
//   → reports.
//
//   E2E scope: this test does NOT create a session/transcript because
//   that requires the STT pipeline (covered by TestFullSession_HappyPath).
//   The cascade-through-sessions piece is unit-tested in
//   internal/adapters/grpc/update_delete_test.go::TestDeletePatientUser_*.
//   What we prove here is that the RPC works end-to-end against real
//   clinical-svc + real Postgres + real KMS, and that the kartoteka
//   becomes unreachable afterwards.
// =================================================================
func TestPatientLifecycle_DeletePatientUser_RODO(t *testing.T) {
	env := setupLifecycleEnv(t)
	created := env.createTestPatient("delete-user")
	// No t.Cleanup with DeletePatientFile — DeletePatientUser is what
	// we're testing AS the cleanup path. If it fails, the cleanup below
	// (best-effort DeletePatientFile) catches the leak.
	t.Cleanup(func() {
		bgCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		// Best-effort: if DeletePatientUser succeeded, this NotFounds (OK).
		// If DeletePatientUser failed, this rescues the row.
		_, _ = env.clinical.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{
			PatientFileId: created.Id,
		})
	})

	t.Log("\n═══ DeletePatientUser (RODO erasure on the patient axis) ═══")
	_, err := env.clinical.DeletePatientUser(env.ctx, &clinicalv1.DeletePatientUserRequest{
		PatientFileId: created.Id,
	})
	require.NoError(t, err, "DeletePatientUser")
	t.Logf("✓ DeletePatientUser returned OK (Empty)")

	t.Log("\n═══ Post-delete: GetPatientFile must be NotFound (cascade fired) ═══")
	_, err = env.clinical.GetPatientFile(env.ctx, &clinicalv1.GetPatientFileRequest{
		PatientFileId: created.Id,
	})
	require.Error(t, err, "GetPatientFile must fail after patient user delete")
	st, ok := status.FromError(err)
	require.True(t, ok, "error must be a gRPC status")
	assert.Equal(t, codes.NotFound, st.Code(),
		"DeletePatientUser must CASCADE to patient_files (migration 000014)")
	t.Logf("✓ kartoteka cascaded away (gRPC code: %s)", st.Code())

	// Sanity: the therapist's list no longer contains it.
	listed, err := env.clinical.ListPatientFiles(env.ctx, &clinicalv1.ListPatientFilesRequest{
		TherapistId: env.therapist.Id,
		PageSize:    10,
	})
	require.NoError(t, err)
	for _, pf := range listed.PatientFiles {
		assert.NotEqualf(t, created.Id, pf.Id,
			"cascaded kartoteka must not appear in List; got %s", pf.Id)
	}
	t.Logf("✓ List confirms cascade (%d kartoteki remain)", len(listed.PatientFiles))
}

