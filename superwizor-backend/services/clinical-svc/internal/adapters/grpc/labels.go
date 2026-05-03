package grpc

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

func (s *Server) UpdateSpeakerLabels(ctx context.Context, req *clinicalv1.UpdateSpeakerLabelsRequest) (*clinicalv1.UpdateSpeakerLabelsResponse, error) {
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	if len(req.LabelMapping) == 0 {
		return nil, status.Error(codes.InvalidArgument, "label_mapping required")
	}

	// Walidacja: każdy label musi być niepusty, max 50 znaków, brak whitespace-only
	for tag, label := range req.LabelMapping {
		trimmed := strings.TrimSpace(label)
		if trimmed == "" {
			return nil, status.Errorf(codes.InvalidArgument, "label for speaker_tag %s cannot be empty", tag)
		}
		if len(trimmed) > 50 {
			return nil, status.Errorf(codes.InvalidArgument, "label for speaker_tag %s exceeds 50 chars", tag)
		}
	}

	tx, err := s.dbPool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	defer tx.Rollback(ctx)

	qtx := s.queries.WithTx(tx)

	// 1. Get latest transcript dla sesji
	transcript, err := qtx.GetTranscriptForRebuild(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "no transcript found for session")
	}

	// 2. Load wszystkie segmenty
	segments, err := qtx.ListSegmentsForRebuild(ctx, transcript.TranscriptID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// 3. Build new blob z aktualizowanymi labels
	type BlobLine struct {
		SpeakerTag   int32   `json:"speaker_tag"`
		SpeakerLabel string  `json:"speaker_label"`
		Text         string  `json:"text"`
		StartMS      int64   `json:"start_ms"`
		EndMS        int64   `json:"end_ms"`
		Confidence   float32 `json:"confidence"`
	}

	blobLines := make([]BlobLine, 0, len(segments))
	for _, seg := range segments {
		// Decrypt segment text (placeholder w Faza 2; KMS w Faza 3)
		segText := strings.TrimPrefix(string(seg.TextCiphertext), "ENCRYPT_PLACEHOLDER:")

		// Apply nowy label (jeśli w mapping; inaczej zostaw obecny)
		newLabel, hasUpdate := req.LabelMapping[fmt.Sprintf("%d", seg.SpeakerTag)]
		if !hasUpdate {
			// Zachowaj poprzedni label z DB — nie wszystkie speakers muszą być w mapping
			row := tx.QueryRow(ctx,
				"SELECT speaker_label FROM transcript_segments WHERE transcript_id = $1 AND speaker_tag = $2 LIMIT 1",
				transcript.TranscriptID, seg.SpeakerTag)
			row.Scan(&newLabel)
		}

		blobLines = append(blobLines, BlobLine{
			SpeakerTag:   seg.SpeakerTag,
			SpeakerLabel: newLabel,
			Text:         segText,
			StartMS:      int64(seg.StartOffsetMs),
			EndMS:        int64(seg.EndOffsetMs),
			Confidence:   ptrFloat32(seg.Confidence),
		})
	}

	blobJSON, _ := json.Marshal(blobLines)

	// PRODUCTION: encrypt z Cloud KMS
	newCiphertext := []byte("ENCRYPT_PLACEHOLDER:" + string(blobJSON))
	newDEK := []byte("DEK_PLACEHOLDER")

	// 4. Update transcripts (rebuild blob)
	if err := qtx.UpdateTranscriptBlob(ctx, db.UpdateTranscriptBlobParams{
		ID:                     transcript.TranscriptID,
		TranscriptCiphertext:   newCiphertext,
		TranscriptEncryptedDek: newDEK,
	}); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// 5. Update transcript_segments.speaker_label per tag w mapping
	for tagStr, newLabel := range req.LabelMapping {
		var tag int32
		fmt.Sscanf(tagStr, "%d", &tag)

		if err := qtx.UpdateSegmentLabel(ctx, db.UpdateSegmentLabelParams{
			TranscriptID: transcript.TranscriptID,
			SpeakerTag:   tag,
			SpeakerLabel: strings.TrimSpace(newLabel),
		}); err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
	}

	// 6. Update sessions.speaker_label_mapping
	mappingJSON, _ := json.Marshal(req.LabelMapping)
	if err := qtx.UpdateSessionLabelMapping(ctx, db.UpdateSessionLabelMappingParams{
		ID:                  sessionID,
		SpeakerLabelMapping: mappingJSON,
	}); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// 7. Audit
	auditMeta, _ := json.Marshal(map[string]any{
		"transcript_id": transcript.TranscriptID.String(),
		"label_changes": req.LabelMapping,
	})
	_ = qtx.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		Action:       "session.update_speaker_labels",
		ResourceType: "session",
		ResourceID:   pgtype.UUID{Bytes: sessionID, Valid: true},
		Metadata:     auditMeta,
	})

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &clinicalv1.UpdateSpeakerLabelsResponse{
		SessionId:       sessionID.String(),
		TranscriptId:    transcript.TranscriptID.String(),
		SegmentsUpdated: int32(len(req.LabelMapping)),
		BlobRebuilt:     true,
	}, nil
}

func ptrFloat32(p pgtype.Numeric) float32 {
	if !p.Valid {
		return 0
	}
	f, _ := p.Float64Value()
	return float32(f.Float64)
}
