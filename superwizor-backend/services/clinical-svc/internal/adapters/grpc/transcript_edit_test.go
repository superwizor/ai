package grpc

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

func TestEditTranscriptSegment_Success(t *testing.T) {
	sessionID := uuid.New()
	transcriptID := uuid.New()
	crypto := cryptobox.NewMockBox()
	ctx := context.WithValue(context.Background(), UserIDKey, uuid.New().String())

	// Create initial transcript blob JSON
	tag := int32(1)
	label := "Osoba 1"
	initialLines := []transcriptBlobLine{
		{
			ChunkIdx:     0,
			Text:         "Dzień dobry, dzisiaj słońce świeci.",
			StartMS:      1000,
			EndMS:        5000,
			WordCount:    5,
			Confidence:   0.9,
			SpeakerTag:   &tag,
			SpeakerLabel: &label,
		},
	}
	initialJSON, _ := json.Marshal(initialLines)
	ciphertext, dek, _ := crypto.Encrypt(ctx, initialJSON)

	var savedCiphertext []byte
	q := &fakeQuerier{
		getTranscriptForRebuildFn: func(ctx context.Context, sid uuid.UUID) (db.GetTranscriptForRebuildRow, error) {
			return db.GetTranscriptForRebuildRow{
				TranscriptID: transcriptID,
				SessionID:    sessionID,
				LanguageCode: "pl",
			}, nil
		},
		getTranscriptBySessionFn: func(ctx context.Context, sid uuid.UUID) (db.Transcript, error) {
			return db.Transcript{
				ID:                     transcriptID,
				SessionID:              sessionID,
				TranscriptCiphertext:   ciphertext,
				TranscriptEncryptedDek: dek,
			}, nil
		},
		getSessionFn: func(ctx context.Context, sid uuid.UUID) (db.Session, error) {
			return db.Session{
				ID:                  sessionID,
				SpeakerLabelMapping: []byte(`{"1":"Darek"}`),
			}, nil
		},
		updateTranscriptBlobFn: func(ctx context.Context, arg db.UpdateTranscriptBlobParams) error {
			savedCiphertext = arg.TranscriptCiphertext
			return nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := &Server{queries: q, tx: opener, crypto: crypto}

	req := &clinicalv1.EditTranscriptSegmentRequest{
		SessionId:      sessionID.String(),
		StartOffsetMs:  1000,
		NewText:        "Dzień dobry, dzisiaj deszcz pada.",
		NewSpeakerTag:  2,
	}

	resp, err := s.EditTranscriptSegment(ctx, req)
	if err != nil {
		t.Fatalf("EditTranscriptSegment failed: %v", err)
	}

	if resp.SessionId != sessionID.String() {
		t.Errorf("expected session_id %s, got %s", sessionID.String(), resp.SessionId)
	}

	// Decrypt the saved blob to check the changes
	savedJSON, err := crypto.Decrypt(ctx, savedCiphertext, dek)
	if err != nil {
		t.Fatalf("failed to decrypt saved ciphertext: %v", err)
	}

	var savedLines []transcriptBlobLine
	_ = json.Unmarshal(savedJSON, &savedLines)

	if len(savedLines) != 1 {
		t.Fatalf("expected 1 segment line, got %d", len(savedLines))
	}

	line := savedLines[0]
	if line.Text != "Dzień dobry, dzisiaj deszcz pada." {
		t.Errorf("expected text 'Dzień dobry, dzisiaj deszcz pada.', got %q", line.Text)
	}
	if line.WordCount != 5 {
		t.Errorf("expected word count 5, got %d", line.WordCount)
	}
	if *line.SpeakerTag != 2 {
		t.Errorf("expected speaker tag 2, got %d", *line.SpeakerTag)
	}
	if *line.SpeakerLabel != "Osoba 2" { // No mapping for 2, falls back to default Osoba 2
		t.Errorf("expected speaker label 'Osoba 2', got %q", *line.SpeakerLabel)
	}
}

func TestSplitTranscriptSegment_Success(t *testing.T) {
	sessionID := uuid.New()
	transcriptID := uuid.New()
	crypto := cryptobox.NewMockBox()
	ctx := context.WithValue(context.Background(), UserIDKey, uuid.New().String())

	// Create initial transcript blob JSON with one line containing 4 words
	tag := int32(1)
	label := "Osoba 1"
	initialLines := []transcriptBlobLine{
		{
			ChunkIdx:     0,
			Text:         "Jeden dwa trzy cztery",
			StartMS:      1000,
			EndMS:        5000, // Duration = 4000ms
			WordCount:    4,
			Confidence:   0.85,
			SpeakerTag:   &tag,
			SpeakerLabel: &label,
		},
	}
	initialJSON, _ := json.Marshal(initialLines)
	ciphertext, dek, _ := crypto.Encrypt(ctx, initialJSON)

	var savedCiphertext []byte
	q := &fakeQuerier{
		getTranscriptForRebuildFn: func(ctx context.Context, sid uuid.UUID) (db.GetTranscriptForRebuildRow, error) {
			return db.GetTranscriptForRebuildRow{
				TranscriptID: transcriptID,
				SessionID:    sessionID,
				LanguageCode: "pl",
			}, nil
		},
		getTranscriptBySessionFn: func(ctx context.Context, sid uuid.UUID) (db.Transcript, error) {
			// Second call in getProtoTranscript will see the updated ciphertext
			currCiphertext := ciphertext
			if savedCiphertext != nil {
				currCiphertext = savedCiphertext
			}
			return db.Transcript{
				ID:                     transcriptID,
				SessionID:              sessionID,
				TranscriptCiphertext:   currCiphertext,
				TranscriptEncryptedDek: dek,
			}, nil
		},
		getSessionFn: func(ctx context.Context, sid uuid.UUID) (db.Session, error) {
			return db.Session{
				ID:                  sessionID,
				SpeakerLabelMapping: []byte(`{"1":"Darek","2":"Pacjent"}`),
			}, nil
		},
		updateTranscriptBlobFn: func(ctx context.Context, arg db.UpdateTranscriptBlobParams) error {
			savedCiphertext = arg.TranscriptCiphertext
			return nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := &Server{queries: q, tx: opener, crypto: crypto}

	// Split at index 2 ("trzy"), so part 1 is "Jeden dwa" and part 2 is "trzy cztery"
	req := &clinicalv1.SplitTranscriptSegmentRequest{
		SessionId:             sessionID.String(),
		StartOffsetMs:         1000,
		SplitWordIndex:        2,
		SecondPartSpeakerTag:  2,
	}

	resp, err := s.SplitTranscriptSegment(ctx, req)
	if err != nil {
		t.Fatalf("SplitTranscriptSegment failed: %v", err)
	}

	// Decrypt the saved blob to check the changes
	savedJSON, err := crypto.Decrypt(ctx, savedCiphertext, dek)
	if err != nil {
		t.Fatalf("failed to decrypt saved ciphertext: %v", err)
	}

	var savedLines []transcriptBlobLine
	_ = json.Unmarshal(savedJSON, &savedLines)

	if len(savedLines) != 2 {
		t.Fatalf("expected 2 segment lines, got %d", len(savedLines))
	}

	p1 := savedLines[0]
	if p1.Text != "Jeden dwa" {
		t.Errorf("expected part 1 text 'Jeden dwa', got %q", p1.Text)
	}
	if p1.StartMS != 1000 || p1.EndMS != 3000 { // 1000 + 4000*(2/4) = 3000
		t.Errorf("expected part 1 interval [1000, 3000], got [%d, %d]", p1.StartMS, p1.EndMS)
	}
	if *p1.SpeakerTag != 1 {
		t.Errorf("expected part 1 tag 1, got %d", *p1.SpeakerTag)
	}

	p2 := savedLines[1]
	if p2.Text != "trzy cztery" {
		t.Errorf("expected part 2 text 'trzy cztery', got %q", p2.Text)
	}
	if p2.StartMS != 3000 || p2.EndMS != 5000 {
		t.Errorf("expected part 2 interval [3000, 5000], got [%d, %d]", p2.StartMS, p2.EndMS)
	}
	if *p2.SpeakerTag != 2 {
		t.Errorf("expected part 2 tag 2, got %d", *p2.SpeakerTag)
	}
	if *p2.SpeakerLabel != "Pacjent" { // Speaker tag 2 resolved to "Pacjent" via mapping
		t.Errorf("expected part 2 label 'Pacjent', got %q", *p2.SpeakerLabel)
	}

	// Verify the rebuilt response has correct turns
	if len(resp.Transcript.Turns) != 2 {
		t.Errorf("expected 2 turns in proto response, got %d", len(resp.Transcript.Turns))
	}
}

func TestSplitTranscriptSegment_Validation(t *testing.T) {
	sessionID := uuid.New()
	transcriptID := uuid.New()
	crypto := cryptobox.NewMockBox()
	ctx := context.WithValue(context.Background(), UserIDKey, uuid.New().String())

	tag := int32(1)
	label := "Osoba 1"
	initialLines := []transcriptBlobLine{
		{
			ChunkIdx:     0,
			Text:         "Jeden", // Only 1 word
			StartMS:      1000,
			EndMS:        5000,
			WordCount:    1,
			Confidence:   0.85,
			SpeakerTag:   &tag,
			SpeakerLabel: &label,
		},
	}
	initialJSON, _ := json.Marshal(initialLines)
	ciphertext, dek, _ := crypto.Encrypt(ctx, initialJSON)

	q := &fakeQuerier{
		getTranscriptForRebuildFn: func(ctx context.Context, sid uuid.UUID) (db.GetTranscriptForRebuildRow, error) {
			return db.GetTranscriptForRebuildRow{
				TranscriptID: transcriptID,
				SessionID:    sessionID,
			}, nil
		},
		getTranscriptBySessionFn: func(ctx context.Context, sid uuid.UUID) (db.Transcript, error) {
			return db.Transcript{
				ID:                     transcriptID,
				SessionID:              sessionID,
				TranscriptCiphertext:   ciphertext,
				TranscriptEncryptedDek: dek,
			}, nil
		},
		getSessionFn: func(ctx context.Context, sid uuid.UUID) (db.Session, error) {
			return db.Session{ID: sessionID}, nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := &Server{queries: q, tx: opener, crypto: crypto}

	req := &clinicalv1.SplitTranscriptSegmentRequest{
		SessionId:      sessionID.String(),
		StartOffsetMs:  1000,
		SplitWordIndex: 1,
	}

	_, err := s.SplitTranscriptSegment(ctx, req)
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("expected InvalidArgument error for 1 word split, got code %v: %v", status.Code(err), err)
	}
}
