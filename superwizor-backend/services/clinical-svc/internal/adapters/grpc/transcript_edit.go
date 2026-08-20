package grpc

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/grouping"
)

func (s *Server) EditTranscriptSegment(ctx context.Context, req *clinicalv1.EditTranscriptSegmentRequest) (*clinicalv1.EditTranscriptSegmentResponse, error) {
	slog.Info("EditTranscriptSegment: request received", "sessionId", req.SessionId, "startOffsetMs", req.StartOffsetMs, "newSpeakerTag", req.NewSpeakerTag)

	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	slog.Info("EditTranscriptSegment: beginning transaction")
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	defer func() { _ = tx.Rollback(ctx) }()

	qtx := tx.Queries()

	// 1. Get latest transcript
	slog.Info("EditTranscriptSegment: fetching transcript for rebuild")
	transcript, err := qtx.GetTranscriptForRebuild(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "no transcript found for session")
	}

	// Fetch full transcript with ciphertext
	slog.Info("EditTranscriptSegment: fetching full transcript ciphertext")
	fullTranscript, err := qtx.GetTranscriptBySession(ctx, sessionID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "transcript not found: %v", err)
	}

	// Decrypt blob
	slog.Info("EditTranscriptSegment: decrypting canonical transcript ciphertext")
	blobJSON, err := s.crypto.Decrypt(ctx, fullTranscript.TranscriptCiphertext, fullTranscript.TranscriptEncryptedDek)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to decrypt transcript: %v", err)
	}
	slog.Info("EditTranscriptSegment: decryption successful")

	var lines []transcriptBlobLine
	if err := json.Unmarshal(blobJSON, &lines); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to unmarshal transcript: %v", err)
	}

	// 2. Fetch session to get label mapping
	sess, err := qtx.GetSession(ctx, sessionID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "session not found: %v", err)
	}
	var speakerLabelMapping map[string]string
	if len(sess.SpeakerLabelMapping) > 0 {
		_ = json.Unmarshal(sess.SpeakerLabelMapping, &speakerLabelMapping)
	}
	if speakerLabelMapping == nil {
		speakerLabelMapping = make(map[string]string)
	}

	// Find and edit target line
	found := false
	var firstIdx, lastIdx int
	for i, line := range lines {
		if int64(line.StartMS) == req.StartOffsetMs {
			found = true
			firstIdx = i

			// Scan contiguous segments with same speaker tag to find turn boundary
			targetTag := line.SpeakerTag
			var targetTagVal int32
			if targetTag != nil {
				targetTagVal = *targetTag
			}

			lastIdx = i
			for j := i + 1; j < len(lines); j++ {
				tag := lines[j].SpeakerTag
				var tagVal int32
				if tag != nil {
					tagVal = *tag
				}
				if tagVal == targetTagVal {
					lastIdx = j
				} else {
					break
				}
			}
			break
		}
	}

	if !found {
		return nil, status.Errorf(codes.NotFound, "segment with start_offset_ms %d not found", req.StartOffsetMs)
	}

	// Update the first segment of the turn with the edited text and new duration
	if req.NewText != "" {
		lines[firstIdx].Text = req.NewText
		lines[firstIdx].WordCount = len(strings.Fields(req.NewText))
	}
	lines[firstIdx].EndMS = lines[lastIdx].EndMS // Extend end offset to the end of the entire turn

	if req.NewSpeakerTag != 0 {
		tag := req.NewSpeakerTag
		lines[firstIdx].SpeakerTag = &tag
		label := speakerLabelMapping[fmt.Sprintf("%d", tag)]
		if label == "" {
			label = fmt.Sprintf("Osoba %d", tag)
		}
		lines[firstIdx].SpeakerLabel = &label
	}

	// Remove other segments that were merged into this one
	var updatedLines []transcriptBlobLine
	updatedLines = append(updatedLines, lines[:firstIdx+1]...)
	updatedLines = append(updatedLines, lines[lastIdx+1:]...)

	// Re-index chunk indices
	for i := range updatedLines {
		updatedLines[i].ChunkIdx = i
	}

	// Encrypt text for the single merged segment
	textBytes := []byte(updatedLines[firstIdx].Text)
	ciphertext, dek, err := s.crypto.Encrypt(ctx, textBytes)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to encrypt segment text: %v", err)
	}

	var tagVal int32
	if updatedLines[firstIdx].SpeakerTag != nil {
		tagVal = *updatedLines[firstIdx].SpeakerTag
	}
	var labelVal string
	if updatedLines[firstIdx].SpeakerLabel != nil {
		labelVal = *updatedLines[firstIdx].SpeakerLabel
	}

	if tx.Raw() != nil {
		// Delete all segments that were in the original turn range
		_, err = tx.Raw().Exec(ctx,
			"DELETE FROM transcript_segments WHERE transcript_id = $1 AND start_offset_ms >= $2 AND start_offset_ms <= $3",
			transcript.TranscriptID, lines[firstIdx].StartMS, lines[lastIdx].EndMS)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to delete old segments: %v", err)
		}

		// Insert the new single merged segment
		_, err = tx.Raw().Exec(ctx,
			`INSERT INTO transcript_segments 
			 (transcript_id, speaker_tag, speaker_label, start_offset_ms, end_offset_ms, text_ciphertext, text_encrypted_dek, text_word_count, confidence) 
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			transcript.TranscriptID, tagVal, labelVal, updatedLines[firstIdx].StartMS, updatedLines[firstIdx].EndMS, ciphertext, dek, updatedLines[firstIdx].WordCount, updatedLines[firstIdx].Confidence,
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to insert merged segment: %v", err)
		}
	}

	// Re-encrypt blob
	newBlobJSON, _ := json.Marshal(updatedLines)
	newCiphertext, newDEK, err := s.crypto.Encrypt(ctx, newBlobJSON)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to encrypt transcript: %v", err)
	}

	// Update in transcripts table
	if err := qtx.UpdateTranscriptBlob(ctx, db.UpdateTranscriptBlobParams{
		ID:                     transcript.TranscriptID,
		TranscriptCiphertext:   newCiphertext,
		TranscriptEncryptedDek: newDEK,
	}); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	slog.Info("EditTranscriptSegment: committing transaction")
	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	slog.Info("EditTranscriptSegment: transaction committed successfully")

	// Rebuild proto transcript response
	slog.Info("EditTranscriptSegment: rebuilding response proto")
	protoTranscript, err := s.getProtoTranscript(ctx, transcript.TranscriptID, req.SessionId)
	if err != nil {
		return nil, err
	}
	slog.Info("EditTranscriptSegment: response rebuilt, returning")

	return &clinicalv1.EditTranscriptSegmentResponse{
		SessionId:  req.SessionId,
		Transcript: protoTranscript,
	}, nil
}

func (s *Server) SplitTranscriptSegment(ctx context.Context, req *clinicalv1.SplitTranscriptSegmentRequest) (*clinicalv1.SplitTranscriptSegmentResponse, error) {
	slog.Info("SplitTranscriptSegment: request received", "sessionId", req.SessionId, "startOffsetMs", req.StartOffsetMs, "splitWordIndex", req.SplitWordIndex, "secondPartSpeakerTag", req.SecondPartSpeakerTag)

	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	slog.Info("SplitTranscriptSegment: beginning transaction")
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	defer func() { _ = tx.Rollback(ctx) }()

	qtx := tx.Queries()

	// 1. Get latest transcript
	slog.Info("SplitTranscriptSegment: fetching transcript for rebuild")
	transcript, err := qtx.GetTranscriptForRebuild(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "no transcript found for session")
	}

	// Fetch full transcript with ciphertext
	slog.Info("SplitTranscriptSegment: fetching full transcript ciphertext")
	fullTranscript, err := qtx.GetTranscriptBySession(ctx, sessionID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "transcript not found: %v", err)
	}

	// Decrypt blob
	slog.Info("SplitTranscriptSegment: decrypting canonical transcript ciphertext")
	blobJSON, err := s.crypto.Decrypt(ctx, fullTranscript.TranscriptCiphertext, fullTranscript.TranscriptEncryptedDek)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to decrypt transcript: %v", err)
	}
	slog.Info("SplitTranscriptSegment: decryption successful")

	var lines []transcriptBlobLine
	if err := json.Unmarshal(blobJSON, &lines); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to unmarshal transcript: %v", err)
	}

	// Fetch session to get label mapping
	sess, err := qtx.GetSession(ctx, sessionID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "session not found: %v", err)
	}
	var speakerLabelMapping map[string]string
	if len(sess.SpeakerLabelMapping) > 0 {
		_ = json.Unmarshal(sess.SpeakerLabelMapping, &speakerLabelMapping)
	}
	if speakerLabelMapping == nil {
		speakerLabelMapping = make(map[string]string)
	}

	// Find target first segment of the turn
	foundIdx := -1
	for i, line := range lines {
		if int64(line.StartMS) == req.StartOffsetMs {
			foundIdx = i
			break
		}
	}

	if foundIdx == -1 {
		return nil, status.Errorf(codes.NotFound, "segment with start_offset_ms %d not found", req.StartOffsetMs)
	}

	// Scan contiguous segments with the same speaker tag to find turn boundary
	targetTag := lines[foundIdx].SpeakerTag
	var targetTagVal int32
	if targetTag != nil {
		targetTagVal = *targetTag
	}

	lastIdx := foundIdx
	for j := foundIdx + 1; j < len(lines); j++ {
		tag := lines[j].SpeakerTag
		var tagVal int32
		if tag != nil {
			tagVal = *tag
		}
		if tagVal == targetTagVal {
			lastIdx = j
		} else {
			break
		}
	}

	// Merge all words of this turn
	var turnWords []string
	for idx := foundIdx; idx <= lastIdx; idx++ {
		turnWords = append(turnWords, strings.Fields(lines[idx].Text)...)
	}

	if len(turnWords) < 2 {
		return nil, status.Error(codes.InvalidArgument, "cannot split a segment with less than 2 words")
	}
	if req.SplitWordIndex <= 0 || int(req.SplitWordIndex) >= len(turnWords) {
		return nil, status.Errorf(codes.InvalidArgument, "invalid split_word_index %d (must be between 1 and %d)", req.SplitWordIndex, len(turnWords)-1)
	}

	// Calculate split timestamp across the entire turn duration
	splitIndex := int(req.SplitWordIndex)
	duration := lines[lastIdx].EndMS - lines[foundIdx].StartMS
	splitOffset := int64(float64(duration) * (float64(splitIndex) / float64(len(turnWords))))
	splitTime := lines[foundIdx].StartMS + splitOffset

	// Part 1
	part1Text := strings.Join(turnWords[:splitIndex], " ")
	part1SpeakerTag := lines[foundIdx].SpeakerTag
	if req.FirstPartSpeakerTag != 0 {
		tag := req.FirstPartSpeakerTag
		part1SpeakerTag = &tag
	}
	var part1SpeakerLabel *string
	if part1SpeakerTag != nil {
		lbl := speakerLabelMapping[fmt.Sprintf("%d", *part1SpeakerTag)]
		if lbl == "" {
			lbl = fmt.Sprintf("Osoba %d", *part1SpeakerTag)
		}
		part1SpeakerLabel = &lbl
	}

	part1Line := transcriptBlobLine{
		ChunkIdx:     lines[foundIdx].ChunkIdx,
		Text:         part1Text,
		StartMS:      lines[foundIdx].StartMS,
		EndMS:        splitTime,
		WordCount:    splitIndex,
		Confidence:   lines[foundIdx].Confidence,
		SpeakerTag:   part1SpeakerTag,
		SpeakerLabel: part1SpeakerLabel,
	}

	// Part 2
	part2Text := strings.Join(turnWords[splitIndex:], " ")
	part2SpeakerTag := lines[foundIdx].SpeakerTag
	if req.SecondPartSpeakerTag != 0 {
		tag := req.SecondPartSpeakerTag
		part2SpeakerTag = &tag
	}
	var part2SpeakerLabel *string
	if part2SpeakerTag != nil {
		lbl := speakerLabelMapping[fmt.Sprintf("%d", *part2SpeakerTag)]
		if lbl == "" {
			lbl = fmt.Sprintf("Osoba %d", *part2SpeakerTag)
		}
		part2SpeakerLabel = &lbl
	}

	part2Line := transcriptBlobLine{
		ChunkIdx:     lines[foundIdx].ChunkIdx + 1,
		Text:         part2Text,
		StartMS:      splitTime,
		EndMS:        lines[lastIdx].EndMS,
		WordCount:    len(turnWords) - splitIndex,
		Confidence:   lines[foundIdx].Confidence,
		SpeakerTag:   part2SpeakerTag,
		SpeakerLabel: part2SpeakerLabel,
	}

	// Replace the entire turn range (foundIdx to lastIdx) with these two parts
	var newLines []transcriptBlobLine
	newLines = append(newLines, lines[:foundIdx]...)
	newLines = append(newLines, part1Line, part2Line)
	newLines = append(newLines, lines[lastIdx+1:]...)

	// Re-index chunk indices
	for i := range newLines {
		newLines[i].ChunkIdx = i
	}

	// Re-encrypt blob
	newBlobJSON, _ := json.Marshal(newLines)
	newCiphertext, newDEK, err := s.crypto.Encrypt(ctx, newBlobJSON)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to encrypt transcript: %v", err)
	}

	// Update transcripts table
	if err := qtx.UpdateTranscriptBlob(ctx, db.UpdateTranscriptBlobParams{
		ID:                     transcript.TranscriptID,
		TranscriptCiphertext:   newCiphertext,
		TranscriptEncryptedDek: newDEK,
	}); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// Re-encrypt texts for the two split segments
	p1Bytes := []byte(part1Line.Text)
	p1Cipher, p1DEK, err := s.crypto.Encrypt(ctx, p1Bytes)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to encrypt part 1 text: %v", err)
	}

	p2Bytes := []byte(part2Line.Text)
	p2Cipher, p2DEK, err := s.crypto.Encrypt(ctx, p2Bytes)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to encrypt part 2 text: %v", err)
	}

	if tx.Raw() != nil {
		// Delete all segments in the original turn range
		_, err = tx.Raw().Exec(ctx,
			"DELETE FROM transcript_segments WHERE transcript_id = $1 AND start_offset_ms >= $2 AND start_offset_ms <= $3",
			transcript.TranscriptID, lines[foundIdx].StartMS, lines[lastIdx].EndMS)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to delete old segments: %v", err)
		}

		// Insert Part 1
		var tag1 int32
		if part1Line.SpeakerTag != nil {
			tag1 = *part1Line.SpeakerTag
		}
		var label1 string
		if part1Line.SpeakerLabel != nil {
			label1 = *part1Line.SpeakerLabel
		}
		_, err = tx.Raw().Exec(ctx,
			`INSERT INTO transcript_segments 
			 (transcript_id, speaker_tag, speaker_label, start_offset_ms, end_offset_ms, text_ciphertext, text_encrypted_dek, text_word_count, confidence) 
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			transcript.TranscriptID, tag1, label1, part1Line.StartMS, part1Line.EndMS, p1Cipher, p1DEK, part1Line.WordCount, part1Line.Confidence,
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to insert split segment part 1: %v", err)
		}

		// Insert Part 2
		var tag2 int32
		if part2Line.SpeakerTag != nil {
			tag2 = *part2Line.SpeakerTag
		}
		var label2 string
		if part2Line.SpeakerLabel != nil {
			label2 = *part2Line.SpeakerLabel
		}
		_, err = tx.Raw().Exec(ctx,
			`INSERT INTO transcript_segments 
			 (transcript_id, speaker_tag, speaker_label, start_offset_ms, end_offset_ms, text_ciphertext, text_encrypted_dek, text_word_count, confidence) 
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			transcript.TranscriptID, tag2, label2, part2Line.StartMS, part2Line.EndMS, p2Cipher, p2DEK, part2Line.WordCount, part2Line.Confidence,
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to insert split segment part 2: %v", err)
		}
	}

	slog.Info("SplitTranscriptSegment: committing transaction")
	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	slog.Info("SplitTranscriptSegment: transaction committed successfully")

	// Rebuild proto transcript response
	slog.Info("SplitTranscriptSegment: rebuilding response proto")
	protoTranscript, err := s.getProtoTranscript(ctx, transcript.TranscriptID, req.SessionId)
	if err != nil {
		return nil, err
	}
	slog.Info("SplitTranscriptSegment: response rebuilt, returning")

	return &clinicalv1.SplitTranscriptSegmentResponse{
		SessionId:  req.SessionId,
		Transcript: protoTranscript,
	}, nil
}

func (s *Server) getProtoTranscript(ctx context.Context, transcriptID uuid.UUID, sessionIDStr string) (*clinicalv1.Transcript, error) {
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	transcript, err := s.queries.GetTranscriptBySession(ctx, sessionID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "transcript not found: %v", err)
	}

	protoTranscript := &clinicalv1.Transcript{
		Id: transcript.ID.String(),
	}

	if segs, ok := tryCanonicalBlobSegments(ctx, s.crypto, transcript); ok {
		protoTranscript.Segments = segs
		protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
	} else {
		segs, fatalErr := loadSegmentsViaPerSegmentLoop(ctx, s.queries, s.crypto, transcript.ID, sessionIDStr)
		if fatalErr != nil {
			return nil, fatalErr
		}
		protoTranscript.Segments = segs
		protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
	}

	return protoTranscript, nil
}
