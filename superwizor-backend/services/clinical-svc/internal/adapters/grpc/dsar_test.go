package grpc

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

func newDSARTestServer(q db.Querier, tx TxOpener, crypto cryptobox.CryptoBox, pub SessionEventPublisher) *Server {
	return NewServerWithDeps(q, tx, nil, nil, crypto, pub, "test-1.0", nil)
}

// =================================================================
//   ExportPatientData
// =================================================================

func TestExportPatientData_MissingAuth(t *testing.T) {
	srv := newDSARTestServer(&fakeQuerier{}, nil, nil, nil)
	_, err := srv.ExportPatientData(context.Background(), &clinicalv1.ExportPatientDataRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v (err=%v)", got, err)
	}
}

func TestExportPatientData_InvalidPatientFileID(t *testing.T) {
	therapist := uuid.New()
	srv := newDSARTestServer(&fakeQuerier{}, nil, nil, nil)
	_, err := srv.ExportPatientData(ctxWithUser(t, therapist), &clinicalv1.ExportPatientDataRequest{
		PatientFileId: "not-a-uuid",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v (err=%v)", got, err)
	}
}

func TestExportPatientData_NotFound(t *testing.T) {
	therapist := uuid.New()
	q := &fakeQuerier{
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return db.GetPatientFileWithUserRow{}, pgx.ErrNoRows
		},
	}
	srv := newDSARTestServer(q, nil, nil, nil)
	_, err := srv.ExportPatientData(ctxWithUser(t, therapist), &clinicalv1.ExportPatientDataRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v (err=%v)", got, err)
	}
}

func TestExportPatientData_WrongTherapist(t *testing.T) {
	therapist := uuid.New()
	wrongTherapist := uuid.New()
	pfID := uuid.New()
	q := &fakeQuerier{
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			return db.GetPatientFileWithUserRow{
				ID:          pfID,
				TherapistID: wrongTherapist,
			}, nil
		},
	}
	srv := newDSARTestServer(q, nil, nil, nil)
	_, err := srv.ExportPatientData(ctxWithUser(t, therapist), &clinicalv1.ExportPatientDataRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v (err=%v)", got, err)
	}
}

func TestExportPatientData_HappyPath(t *testing.T) {
	therapist := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	noteID := uuid.New()
	sessID := uuid.New()
	transcriptID := uuid.New()
	reportID := uuid.New()

	crypto := cryptobox.NewMockBox()
	ctx := ctxWithUser(t, therapist)

	// Encrypt test note values
	noteTitleCt, noteTitleDek, _ := crypto.Encrypt(ctx, []byte("Decrypted Title"))
	noteTextCt, noteTextDek, _ := crypto.Encrypt(ctx, []byte("Decrypted Text"))

	// Encrypt report value
	reportCt, reportDek, _ := crypto.Encrypt(ctx, []byte("Decrypted Report Content"))

	// Create canonical transcript JSON
	tag := int32(1)
	label := "Osoba 1"
	lines := []transcriptBlobLine{
		{
			ChunkIdx:     0,
			Text:         "Dzień dobry",
			StartMS:      100,
			EndMS:        2000,
			WordCount:    2,
			Confidence:   0.95,
			SpeakerTag:   &tag,
			SpeakerLabel: &label,
		},
	}
	linesJSON, _ := json.Marshal(lines)
	transcriptCt, transcriptDek, _ := crypto.Encrypt(ctx, linesJSON)

	q := &fakeQuerier{
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			lang := "pl"
			return db.GetPatientFileWithUserRow{
				ID:                  pfID,
				TherapistID:         therapist,
				WorkingAlias:        "alias-test",
				ProcessType:         db.ProcessTypeINDIVIDUAL,
				HasRecordingConsent: true,
				ConsentGivenAt:      pgtype.Timestamptz{Time: time.Now(), Valid: true},
				ModalityCode:        "CBT",
				PatientID:           pgtype.UUID{Bytes: patientID, Valid: true},
				PatientLanguageCode: &lang,
			}, nil
		},
		getPatientNotesForExportFn: func(ctx context.Context, patientFileID uuid.UUID) ([]db.PatientNote, error) {
			return []db.PatientNote{
				{
					ID:                noteID,
					PatientFileID:     pfID,
					Kind:              "FREE_NOTE",
					TitleCiphertext:   noteTitleCt,
					TitleEncryptedDek: noteTitleDek,
					TextCiphertext:    noteTextCt,
					TextEncryptedDek:  noteTextDek,
					CreatedAt:         time.Now(),
					SentToPatientAt:   pgtype.Timestamptz{Time: time.Now(), Valid: true},
					SentToEmail:       derefStringPtr("jan@example.com"),
				},
			}, nil
		},
		getSessionsForExportFn: func(ctx context.Context, patientFileID uuid.UUID) ([]db.Session, error) {
			name := "Sesja 1"
			durSecs := int32(120)
			return []db.Session{
				{
					ID:              sessID,
					PatientFileID:   pfID,
					TherapistID:     therapist,
					Name:            &name,
					SessionDate:     pgtype.Date{Time: time.Now(), Valid: true},
					SessionNumber:   1,
					Status:          db.SessionStatusCOMPLETED,
					DurationSeconds: &durSecs,
					CreatedAt:       time.Now(),
				},
			}, nil
		},
		getTranscriptBySessionFn: func(ctx context.Context, sessionID uuid.UUID) (db.Transcript, error) {
			return db.Transcript{
				ID:                     transcriptID,
				SessionID:              sessID,
				TranscriptCiphertext:   transcriptCt,
				TranscriptEncryptedDek: transcriptDek,
				CreatedAt:              time.Now(),
			}, nil
		},
		listReportsBySessionFn: func(ctx context.Context, sessionID uuid.UUID) ([]db.Report, error) {
			title := "Report Title"
			sumShort := "Short Summary"
			sentLabel := "neutral"
			riskLevel := "low"
			return []db.Report{
				{
					ID:                 reportID,
					SessionID:          sessID,
					Title:              &title,
					SummaryShort:       &sumShort,
					ReportCiphertext:   reportCt,
					ReportEncryptedDek: reportDek,
					SentimentLabel:     &sentLabel,
					RiskLevel:          &riskLevel,
					CreatedAt:          time.Now(),
				},
			}, nil
		},
	}

	srv := newDSARTestServer(q, nil, crypto, nil)
	resp, err := srv.ExportPatientData(ctx, &clinicalv1.ExportPatientDataRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("ExportPatientData happy path error: %v", err)
	}

	// Verify Patient File mapping
	if resp.PatientFile.Id != pfID.String() {
		t.Errorf("expected patient file ID %s, got %s", pfID, resp.PatientFile.Id)
	}
	// docs/43 §4: the export identifies the kartoteka by its alias only;
	// deprecated name fields must stay empty.
	if resp.PatientFile.WorkingAlias != "alias-test" {
		t.Errorf("expected WorkingAlias alias-test, got %s", resp.PatientFile.WorkingAlias)
	}
	if resp.PatientFile.PatientFirstName != "" {
		t.Errorf("deprecated PatientFirstName must be empty, got %s", resp.PatientFile.PatientFirstName)
	}

	// Verify Note mapping & decryption
	if len(resp.Notes) != 1 {
		t.Fatalf("expected 1 note, got %d", len(resp.Notes))
	}
	if resp.Notes[0].Title != "Decrypted Title" {
		t.Errorf("expected Title 'Decrypted Title', got %q", resp.Notes[0].Title)
	}
	if resp.Notes[0].Text != "Decrypted Text" {
		t.Errorf("expected Text 'Decrypted Text', got %q", resp.Notes[0].Text)
	}

	// Verify Session mapping & decryption
	if len(resp.Sessions) != 1 {
		t.Fatalf("expected 1 session, got %d", len(resp.Sessions))
	}
	if resp.Sessions[0].Transcript == nil {
		t.Fatalf("expected transcript to be decrypted and parsed, got nil")
	}
	if len(resp.Sessions[0].Transcript.Segments) != 1 {
		t.Fatalf("expected 1 transcript segment, got %d", len(resp.Sessions[0].Transcript.Segments))
	}
	if resp.Sessions[0].Transcript.Segments[0].Text != "Dzień dobry" {
		t.Errorf("expected segment text 'Dzień dobry', got %q", resp.Sessions[0].Transcript.Segments[0].Text)
	}

	// Verify Report mapping & decryption
	if len(resp.Sessions[0].Reports) != 1 {
		t.Fatalf("expected 1 report, got %d", len(resp.Sessions[0].Reports))
	}
	if resp.Sessions[0].Reports[0].Content != "Decrypted Report Content" {
		t.Errorf("expected report content 'Decrypted Report Content', got %q", resp.Sessions[0].Reports[0].Content)
	}
}

// =================================================================
//   DeletePatientData
// =================================================================

func TestDeletePatientData_MissingAuth(t *testing.T) {
	srv := newDSARTestServer(&fakeQuerier{}, nil, nil, nil)
	_, err := srv.DeletePatientData(context.Background(), &clinicalv1.DeletePatientDataRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v (err=%v)", got, err)
	}
}

func TestDeletePatientData_InvalidPatientFileID(t *testing.T) {
	therapist := uuid.New()
	srv := newDSARTestServer(&fakeQuerier{}, nil, nil, nil)
	_, err := srv.DeletePatientData(ctxWithUser(t, therapist), &clinicalv1.DeletePatientDataRequest{
		PatientFileId: "not-a-uuid",
	})
	if got := codeOf(err); got != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v (err=%v)", got, err)
	}
}

func TestDeletePatientData_NotFound(t *testing.T) {
	therapist := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{}, pgx.ErrNoRows
		},
	}
	srv := newDSARTestServer(q, nil, nil, nil)
	_, err := srv.DeletePatientData(ctxWithUser(t, therapist), &clinicalv1.DeletePatientDataRequest{
		PatientFileId: uuid.New().String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v (err=%v)", got, err)
	}
}

func TestDeletePatientData_WrongTherapist(t *testing.T) {
	therapist := uuid.New()
	wrongTherapist := uuid.New()
	pfID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{
				ID:          pfID,
				TherapistID: wrongTherapist,
			}, nil
		},
	}
	srv := newDSARTestServer(q, nil, nil, nil)
	_, err := srv.DeletePatientData(ctxWithUser(t, therapist), &clinicalv1.DeletePatientDataRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.NotFound {
		t.Fatalf("want NotFound, got %v (err=%v)", got, err)
	}
}

func TestDeletePatientData_TxBeginError(t *testing.T) {
	therapist := uuid.New()
	pfID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{
				ID:          pfID,
				TherapistID: therapist,
			}, nil
		},
		listSessionIDsForPFFn: func(ctx context.Context, id uuid.UUID) ([]uuid.UUID, error) {
			return nil, nil
		},
	}
	tx := &fakeTxOpener{beginErr: errSentinel}
	srv := newDSARTestServer(q, tx, nil, nil)
	_, err := srv.DeletePatientData(ctxWithUser(t, therapist), &clinicalv1.DeletePatientDataRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v (err=%v)", got, err)
	}
}

func TestDeletePatientData_TxRollbackOnError(t *testing.T) {
	therapist := uuid.New()
	pfID := uuid.New()
	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{
				ID:          pfID,
				TherapistID: therapist,
			}, nil
		},
		listSessionIDsForPFFn: func(ctx context.Context, id uuid.UUID) ([]uuid.UUID, error) {
			return nil, nil
		},
	}

	txQ := &fakeQuerier{
		softDeleteSessionsForDSARFn: func(ctx context.Context, patientFileID uuid.UUID) error {
			return errSentinel
		},
	}

	tx := &fakeTxOpener{q: txQ}
	srv := newDSARTestServer(q, tx, nil, nil)
	_, err := srv.DeletePatientData(ctxWithUser(t, therapist), &clinicalv1.DeletePatientDataRequest{
		PatientFileId: pfID.String(),
	})
	if got := codeOf(err); got != codes.Internal {
		t.Fatalf("want Internal, got %v (err=%v)", got, err)
	}
	if tx.rollbackCalls != 1 {
		t.Errorf("expected 1 rollback call, got %d", tx.rollbackCalls)
	}
	if tx.commitCalls != 0 {
		t.Errorf("expected 0 commit calls, got %d", tx.commitCalls)
	}
}

func TestDeletePatientData_HappyPath(t *testing.T) {
	therapist := uuid.New()
	pfID := uuid.New()
	patientID := uuid.New()
	sess1 := uuid.New()
	sess2 := uuid.New()
	ctx := ctxWithUser(t, therapist)

	q := &fakeQuerier{
		getPatientFileFn: func(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
			return db.PatientFile{
				ID:          pfID,
				TherapistID: therapist,
				PatientID:   pgtype.UUID{Bytes: patientID, Valid: true},
			}, nil
		},
		listSessionIDsForPFFn: func(ctx context.Context, id uuid.UUID) ([]uuid.UUID, error) {
			return []uuid.UUID{sess1, sess2}, nil
		},
		createAuditEventFn: func(ctx context.Context, arg db.CreateAuditEventParams) error {
			return nil
		},
	}

	sessionsSoftDeleted := false
	notesSoftDeleted := false
	fileSoftDeleted := false
	patientUserSoftDeleted := false

	txQ := &fakeQuerier{
		softDeleteSessionsForDSARFn: func(ctx context.Context, patientFileID uuid.UUID) error {
			if patientFileID != pfID {
				t.Errorf("softDeleteSessionsForDSAR called with wrong patientFileID")
			}
			sessionsSoftDeleted = true
			return nil
		},
		softDeletePatientNotesForDSARFn: func(ctx context.Context, patientFileID uuid.UUID) error {
			if patientFileID != pfID {
				t.Errorf("softDeletePatientNotesForDSAR called with wrong patientFileID")
			}
			notesSoftDeleted = true
			return nil
		},
		softDeletePatientFileForDSARFn: func(ctx context.Context, arg db.SoftDeletePatientFileForDSARParams) (int64, error) {
			if arg.ID != pfID || arg.TherapistID != therapist {
				t.Errorf("softDeletePatientFileForDSAR called with wrong arguments")
			}
			fileSoftDeleted = true
			return 1, nil
		},
		softDeletePatientUserForDSARFn: func(ctx context.Context, id uuid.UUID) (int64, error) {
			if id != patientID {
				t.Errorf("softDeletePatientUserForDSAR called with wrong ID: %v want %v", id, patientID)
			}
			patientUserSoftDeleted = true
			return 1, nil
		},
	}

	pub := &fakePublisher{}
	tx := &fakeTxOpener{q: txQ}
	srv := newDSARTestServer(q, tx, nil, pub)

	_, err := srv.DeletePatientData(ctx, &clinicalv1.DeletePatientDataRequest{
		PatientFileId: pfID.String(),
	})
	if err != nil {
		t.Fatalf("DeletePatientData happy path error: %v", err)
	}

	if !sessionsSoftDeleted || !notesSoftDeleted || !fileSoftDeleted || !patientUserSoftDeleted {
		t.Errorf("expected all entities to be soft-deleted: sessions=%v, notes=%v, file=%v, patientUser=%v",
			sessionsSoftDeleted, notesSoftDeleted, fileSoftDeleted, patientUserSoftDeleted)
	}

	if tx.commitCalls != 1 {
		t.Errorf("expected transaction to be committed, commitCalls = %d", tx.commitCalls)
	}

	// Verify Pub/Sub publishes for each session
	if len(pub.calls) != 2 {
		t.Errorf("expected 2 delete session publishes, got %d", len(pub.calls))
	}
}

func derefStringPtr(s string) *string {
	return &s
}
