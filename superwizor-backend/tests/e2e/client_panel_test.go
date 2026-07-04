//go:build e2e
// +build e2e

package e2e_test

// End-to-end test for the docs/39 client panel: invite → (simulated)
// accept → default-deny sharing → client notes round-trip → therapist
// read-back → deactivation gate. Runs against staging with real
// Firebase TEST users (never real accounts) and direct DB access for
// the two steps that can't go through RPC:
//   - accepting the invitation (the raw magic-link token exists only
//     in the e-mail; the DB stores its SHA-256), and
//   - seeding a COMPLETED session (the real path needs an audio
//     pipeline run — covered by TestFullSession_HappyPath).
//
// Everything else — invite, status, sharing toggles, the whole Client*
// family, the CLIENT_NOTE read-only guard — exercises the deployed
// services end-to-end.
//
// Run:
//   cd tests
//   DATABASE_URL=... go test -tags=e2e -timeout=8m -v ./e2e/ -run TestClientPanel

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

func TestClientPanel_FullFlow(t *testing.T) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("DATABASE_URL not set — client panel E2E needs direct DB access")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Minute)
	defer cancel()

	cfg := loadConfig(t)
	pool, err := pgxpool.New(ctx, dbURL)
	require.NoError(t, err, "connect staging DB")
	defer pool.Close()

	suffix := strings.ToLower(uuid.NewString()[:8])

	// ── 1. Therapist through the real sign-up path ──────────────────
	thSession, err := mintFirebaseSession(ctx, cfg.projectID, cfg.firebaseAPIKey,
		"e2e-cp-th-"+suffix, "e2e-cp-th-"+suffix+"@superwizor.test")
	require.NoError(t, err, "mint therapist firebase session")
	t.Cleanup(func() { _ = thSession.cleanup() })

	thIdentityConn := dial(t, cfg.identityURL, thSession.IDToken)
	defer thIdentityConn.Close()
	thIdentity := identityv1.NewIdentityServiceClient(thIdentityConn)
	thClinicalConn := dial(t, cfg.clinicalURL, thSession.IDToken)
	defer thClinicalConn.Close()
	thClinical := clinicalv1.NewClinicalServiceClient(thClinicalConn)

	therapist, err := thIdentity.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid:    thSession.UID,
		Email:          thSession.Email,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "ClientPanel",
		LastName:       "Therapist",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser (therapist)")
	therapistID := uuid.MustParse(therapist.Id)
	t.Cleanup(func() { cleanupClientPanel(t, pool, therapistID) })

	// ── 2. Kartoteka via the real RPC ────────────────────────────────
	pf, err := thClinical.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId:         therapist.Id,
		ModalityCode:        "CBT",
		WorkingAlias:        "ClientPanel E2E " + suffix,
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		HasRecordingConsent: true,
		IdempotencyKey:      "e2e-cp-" + suffix,
		PatientFirstName:    "Klient",
		PatientLastName:     "Panelowy",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err, "CreatePatientFile")
	pfID := uuid.MustParse(pf.Id)
	t.Logf("✓ therapist %s, kartoteka %s", therapistID, pfID)

	// ── 3. Invite status: NONE → InviteClient → PENDING ─────────────
	st, err := thIdentity.GetClientInviteStatus(ctx, &identityv1.GetClientInviteStatusRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err, "GetClientInviteStatus (fresh)")
	require.Equal(t, "NONE", st.Status)

	clientEmail := "e2e-cp-client-" + suffix + "@superwizor.test"
	inv, err := thIdentity.InviteClient(ctx, &identityv1.InviteClientRequest{
		PatientFileId: pf.Id,
		Email:         clientEmail,
	})
	require.NoError(t, err, "InviteClient")
	require.Equal(t, identityv1.UserRole_USER_ROLE_PATIENT, inv.InvitedRole)
	t.Logf("✓ invitation %s → %s", inv.Id, clientEmail)

	st, err = thIdentity.GetClientInviteStatus(ctx, &identityv1.GetClientInviteStatusRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	require.Equal(t, "PENDING", st.Status)
	require.Equal(t, clientEmail, st.Email)

	// Re-invite refreshes the pending invitation instead of erroring.
	_, err = thIdentity.InviteClient(ctx, &identityv1.InviteClientRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err, "re-invite (token refresh)")

	// ── 4. Simulated accept (raw token lives only in the e-mail) ────
	clSession, err := mintFirebaseSession(ctx, cfg.projectID, cfg.firebaseAPIKey,
		"e2e-cp-cl-"+suffix, clientEmail)
	require.NoError(t, err, "mint client firebase session")
	t.Cleanup(func() { _ = clSession.cleanup() })

	var clientID uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `
		INSERT INTO users (role, firebase_uid, email, first_name, last_name, has_accepted_tos)
		VALUES ('PATIENT', $1, $2, 'Klient', 'Panelowy', TRUE)
		RETURNING id`, clSession.UID, clientEmail).Scan(&clientID),
		"seed accepted client user")
	_, err = pool.Exec(ctx, `UPDATE patient_files SET patient_id = $2 WHERE id = $1`, pfID, clientID)
	require.NoError(t, err, "attach client to kartoteka")
	_, err = pool.Exec(ctx, `
		UPDATE invitations SET accepted_at = now()
		WHERE patient_file_id = $1 AND accepted_at IS NULL`, pfID)
	require.NoError(t, err, "mark invitation accepted")

	st, err = thIdentity.GetClientInviteStatus(ctx, &identityv1.GetClientInviteStatusRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	require.Equal(t, "ACTIVE", st.Status, "attached active client ⇒ ACTIVE")
	t.Logf("✓ client %s accepted (simulated), status ACTIVE", clientID)

	clClinicalConn := dial(t, cfg.clinicalURL, clSession.IDToken)
	defer clClinicalConn.Close()
	clClinical := clinicalv1.NewClinicalServiceClient(clClinicalConn)

	// ── 5. Default-deny: seeded session invisible until shared ──────
	var sessionID uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `
		INSERT INTO sessions (therapist_id, patient_file_id, session_date,
		                      session_number, duration_seconds, status)
		VALUES ($1, $2, CURRENT_DATE, 1, 3000, 'COMPLETED')
		RETURNING id`, therapistID, pfID).Scan(&sessionID), "seed COMPLETED session")

	overview, err := clClinical.ClientGetMyOverview(ctx, &emptypb.Empty{})
	require.NoError(t, err, "ClientGetMyOverview")
	require.Len(t, overview.Kartoteki, 1)
	assert.EqualValues(t, 0, overview.Kartoteki[0].SharedSessions, "nothing shared yet")

	sessions, err := clClinical.ClientListSessions(ctx, &clinicalv1.ClientListSessionsRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	require.Empty(t, sessions.Sessions, "unshared session must be invisible (D2)")

	_, err = clClinical.ClientGetTranscript(ctx, &clinicalv1.ClientGetTranscriptRequest{
		SessionId: sessionID.String(),
	})
	require.Equal(t, codes.NotFound, status.Code(err),
		"unshared transcript must be NotFound, got %v", err)

	// ── 6. Share the session → visible ──────────────────────────────
	_, err = thClinical.ShareSessionWithClient(ctx, &clinicalv1.ShareSessionWithClientRequest{
		SessionId: sessionID.String(),
		Shared:    true,
	})
	require.NoError(t, err, "ShareSessionWithClient")

	sessions, err = clClinical.ClientListSessions(ctx, &clinicalv1.ClientListSessionsRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	require.Len(t, sessions.Sessions, 1, "shared session must appear")
	assert.False(t, sessions.Sessions[0].HasTranscript, "no transcript seeded")

	tr, err := clClinical.ClientGetTranscript(ctx, &clinicalv1.ClientGetTranscriptRequest{
		SessionId: sessionID.String(),
	})
	require.NoError(t, err, "shared session readable even without transcript")
	assert.Nil(t, tr.Transcript, "transcript not seeded ⇒ empty")
	t.Log("✓ D2 default-deny + share toggle verified on the session")

	// ── 7. Therapist note: invisible → shared → read receipt ────────
	note, err := thClinical.CreatePatientNote(ctx, &clinicalv1.CreatePatientNoteRequest{
		PatientFileId: pf.Id,
		Title:         "Plan na tydzień",
		Text:          "Ćwiczenie oddechowe raz dziennie.",
	})
	require.NoError(t, err, "CreatePatientNote")

	notes, err := clClinical.ClientListNotes(ctx, &clinicalv1.ClientListNotesRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	require.Empty(t, notes.Notes, "unshared therapist note must be invisible (D2)")

	_, err = thClinical.ShareNoteWithClient(ctx, &clinicalv1.ShareNoteWithClientRequest{
		NoteId: note.Id,
		Shared: true,
	})
	require.NoError(t, err, "ShareNoteWithClient")

	notes, err = clClinical.ClientListNotes(ctx, &clinicalv1.ClientListNotesRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	require.Len(t, notes.Notes, 1)
	assert.Equal(t, "THERAPIST", notes.Notes[0].AuthorRole)
	assert.Equal(t, "Plan na tydzień", notes.Notes[0].Title, "decrypted round-trip")
	assert.False(t, notes.Notes[0].Read, "unread before ClientMarkNoteRead")

	_, err = clClinical.ClientMarkNoteRead(ctx, &clinicalv1.ClientMarkNoteReadRequest{
		NoteId: note.Id,
	})
	require.NoError(t, err, "ClientMarkNoteRead")

	// ── 8. Client note → therapist read-back + read-only guard ──────
	clientNote, err := clClinical.ClientCreateNote(ctx, &clinicalv1.ClientCreateNoteRequest{
		PatientFileId: pf.Id,
		Title:         "Moje przemyślenia",
		Text:          "Po sesji czuję się spokojniej.",
	})
	require.NoError(t, err, "ClientCreateNote")
	require.Equal(t, "CLIENT_NOTE", clientNote.Kind)

	thNotes, err := thClinical.ListPatientNotes(ctx, &clinicalv1.ListPatientNotesRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err, "therapist ListPatientNotes")
	var got *clinicalv1.PatientNote
	for _, n := range thNotes.Notes {
		if n.Id == clientNote.Id {
			got = n
		}
	}
	require.NotNil(t, got, "therapist must see the CLIENT_NOTE")
	assert.Equal(t, "PATIENT", got.AuthorRole)
	assert.Equal(t, "Moje przemyślenia", got.Title, "decrypted round-trip")
	assert.Nil(t, got.ReadByTherapistAt,
		"first listing returns the pre-mark state (edge-triggered badge)")

	// Second listing: the auto-mark from the first one is now visible.
	thNotes, err = thClinical.ListPatientNotes(ctx, &clinicalv1.ListPatientNotesRequest{
		PatientFileId: pf.Id,
	})
	require.NoError(t, err)
	for _, n := range thNotes.Notes {
		if n.Id == clientNote.Id {
			assert.NotNil(t, n.ReadByTherapistAt, "second listing shows the read mark")
		}
	}

	_, err = thClinical.UpdatePatientNote(ctx, &clinicalv1.UpdatePatientNoteRequest{
		NoteId: clientNote.Id,
		Title:  "przejęte",
		Text:   "przejęte",
	})
	require.Equal(t, codes.FailedPrecondition, status.Code(err),
		"CLIENT_NOTE must be read-only for the therapist, got %v", err)
	require.Contains(t, err.Error(), "CLIENT_NOTE_READ_ONLY")

	_, err = thClinical.ShareNoteWithClient(ctx, &clinicalv1.ShareNoteWithClientRequest{
		NoteId: clientNote.Id,
		Shared: true,
	})
	require.Equal(t, codes.FailedPrecondition, status.Code(err),
		"sharing a CLIENT_NOTE back is a category error")
	t.Log("✓ CLIENT_NOTE round-trip + read-only guard verified")

	// ── 9. No enumeration oracle + role gate ─────────────────────────
	_, err = clClinical.ClientListSessions(ctx, &clinicalv1.ClientListSessionsRequest{
		PatientFileId: uuid.NewString(), // foreign/nonexistent kartoteka
	})
	require.Equal(t, codes.NotFound, status.Code(err),
		"foreign kartoteka must be NotFound (no oracle), got %v", err)

	_, err = thClinical.ClientGetMyOverview(ctx, &emptypb.Empty{})
	require.Equal(t, codes.PermissionDenied, status.Code(err),
		"therapist calling the client family is a role error, got %v", err)

	// ── 10. Deactivation cuts the panel off ─────────────────────────
	_, err = pool.Exec(ctx, `UPDATE users SET is_active = FALSE WHERE id = $1`, clientID)
	require.NoError(t, err, "deactivate client")

	_, err = clClinical.ClientGetMyOverview(ctx, &emptypb.Empty{})
	require.Error(t, err, "deactivated client must be blocked")
	assert.Contains(t, err.Error(), "ACCOUNT_DEACTIVATED",
		"deactivation surfaces the stable prefix")
	t.Log("✓ deactivation gate verified — client panel E2E complete")
}

// cleanupClientPanel removes everything the test created, child-first.
// Keyed off the therapist because every row hangs off their kartoteki.
// Best effort — a failed cleanup logs but doesn't fail the test.
func cleanupClientPanel(t *testing.T, pool *pgxpool.Pool, therapistID uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	stmts := []string{
		`DELETE FROM patient_notes WHERE patient_file_id IN
		   (SELECT id FROM patient_files WHERE therapist_id = $1)`,
		`DELETE FROM sessions WHERE therapist_id = $1`,
		`DELETE FROM invitations WHERE patient_file_id IN
		   (SELECT id FROM patient_files WHERE therapist_id = $1)`,
		// patient_files.patient_id FK is RESTRICT — detach and delete
		// the panel user in one statement so the order can't go wrong.
		`WITH detached AS (
		   UPDATE patient_files SET patient_id = NULL
		   WHERE therapist_id = $1 AND patient_id IS NOT NULL
		   RETURNING patient_id)
		 DELETE FROM users
		 WHERE id IN (SELECT patient_id FROM detached) AND role = 'PATIENT'`,
		`DELETE FROM patient_files WHERE therapist_id = $1`,
		`DELETE FROM users WHERE id = $1`,
	}
	for _, s := range stmts {
		if _, err := pool.Exec(ctx, s, therapistID); err != nil {
			t.Logf("cleanup: %s: %v", strings.Fields(s)[2], err)
		}
	}
	fmt.Println("client-panel e2e cleanup done for therapist", therapistID)
}
