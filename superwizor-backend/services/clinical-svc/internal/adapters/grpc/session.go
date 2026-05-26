package grpc

import (
	"context"
	"encoding/json"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/grouping"
)

func (s *Server) ListSessions(ctx context.Context, req *clinicalv1.ListSessionsRequest) (*clinicalv1.ListSessionsResponse, error) {
	patientFileID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	sessions, err := s.queries.ListSessionsByPatient(ctx, patientFileID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	resp := &clinicalv1.ListSessionsResponse{}
	for _, sess := range sessions {
		resp.Sessions = append(resp.Sessions, toProtoSession(sess))
	}
	return resp, nil
}

func (s *Server) GetSessionDetails(ctx context.Context, req *clinicalv1.GetSessionDetailsRequest) (*clinicalv1.GetSessionDetailsResponse, error) {
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	session, err := s.queries.GetSession(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "session not found")
	}

	resp := &clinicalv1.GetSessionDetailsResponse{
		Session: toProtoSession(session),
	}

	// 1. Fetch transcript if any
	transcript, err := s.queries.GetTranscriptBySession(ctx, sessionID)
	if err == nil {
		protoTranscript := &clinicalv1.Transcript{
			Id: transcript.ID.String(),
		}

		// Prefer canonical blob path: 1 KMS decrypt instead of N (per-segment).
		// Per ADR-IMPL-006, `transcripts.transcript_ciphertext` is the
		// source of truth; per-segment rows are derived and kept in sync
		// by UpdateSpeakerLabels (see labels.go). Long sessions (e.g.
		// Marcin's 107-min audio = 1182 segments) blew through the gRPC
		// 30s deadline on the old per-segment loop because each call to
		// Cloud KMS adds ~80-200ms of network — 1182 of those serially
		// is multiple minutes. The canonical blob path collapses that
		// to a single KMS round-trip + one local AES-GCM decrypt.
		segs, err := loadCanonicalTranscriptSegments(ctx, s.crypto, transcript)
		switch {
		case err == nil && len(segs) > 0:
			protoTranscript.Segments = segs
			protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
		default:
			if err != nil {
				slog.Warn("canonical transcript blob decrypt/parse failed — falling back to per-segment",
					"session_id", req.SessionId,
					"transcript_id", transcript.ID.String(),
					"error", err)
			}
			// Fallback: per-segment loop. Kept for safety net (and
			// historic blobs that may not exist yet, though all
			// stt-worker writes since 2026 include the blob).
			protoTranscript.Segments, protoTranscript.Turns = decryptPerSegmentFallback(
				ctx, s.queries, s.crypto, transcript.ID, req.SessionId,
			)
			if len(protoTranscript.Segments) == 0 {
				// Loud fail — see comment on the old code path.
				return nil, status.Error(codes.Internal,
					"transcript present but no segments could be decrypted; check clinical-svc KMS config")
			}
		}
		resp.Transcript = protoTranscript
	}

	// 3. Fetch reports
	reports, err := s.queries.ListReportsBySession(ctx, sessionID)
	if err == nil {
		var reportDecryptErrs int
		for _, rep := range reports {
			title := ""
			if rep.Title != nil {
				title = *rep.Title
			}
			summary := ""
			if rep.SummaryShort != nil {
				summary = *rep.SummaryShort
			}
			sentiment := ""
			if rep.SentimentLabel != nil {
				sentiment = *rep.SentimentLabel
			}
			risk := ""
			if rep.RiskLevel != nil {
				risk = *rep.RiskLevel
			}

			// Decrypt report. Errors here are the same KMS-misconfig
			// signal as for transcript segments above — log + count, then
			// fail the response loudly if EVERY report failed (see end of
			// loop). One failed report among many is still surfaced as an
			// error log but doesn't fail the whole response.
			contentBytes, err := s.crypto.Decrypt(ctx, rep.ReportCiphertext, rep.ReportEncryptedDek)
			if err != nil {
				reportDecryptErrs++
				slog.Error("decrypt report",
					"session_id", req.SessionId,
					"report_id", rep.ID.String(),
					"error", err)
				continue
			}
			content := string(contentBytes)

			resp.Reports = append(resp.Reports, &clinicalv1.Report{
				Id:             rep.ID.String(),
				Title:          title,
				SummaryShort:   summary,
				Content:        content,
				SentimentLabel: sentiment,
				RiskLevel:      risk,
			})
		}
		// Same KMS-misconfig guard as for transcript segments: if reports
		// existed in the DB but every single decrypt failed, returning
		// an empty Reports slice misleads callers into thinking the AI
		// pipeline never ran. Fail loud instead.
		if len(reports) > 0 && len(resp.Reports) == 0 {
			slog.Error("all reports failed to decrypt — likely KMS misconfig",
				"session_id", req.SessionId,
				"report_count", len(reports),
				"decrypt_errors", reportDecryptErrs)
			return nil, status.Error(codes.Internal,
				"reports present but none could be decrypted; check clinical-svc KMS config")
		}
	}

	return resp, nil
}

func toProtoSession(s db.Session) *clinicalv1.Session {
	resp := &clinicalv1.Session{
		Id:            s.ID.String(),
		TherapistId:   s.TherapistID.String(),
		PatientFileId: s.PatientFileID.String(),
		SessionDate:   s.SessionDate.Time.Format("2006-01-02"),
		SessionNumber: s.SessionNumber,
		ContactForm:   string(s.ContactForm),
		Status:        string(s.Status),
		CreatedAt:     timestamppb.New(s.CreatedAt),
	}
	if s.AudioUploadID.Valid {
		resp.AudioUploadId = uuid.UUID(s.AudioUploadID.Bytes).String()
	}
	if s.DurationSeconds != nil {
		resp.DurationSeconds = *s.DurationSeconds
	}

	// Map mapping
	if len(s.SpeakerLabelMapping) > 0 {
		var mapping map[string]string
		if err := json.Unmarshal(s.SpeakerLabelMapping, &mapping); err == nil {
			resp.SpeakerLabelMapping = mapping
		}
	}

	// Name is nullable in DB to allow backfill leniency (migration
	// 000011). Emit empty string if NULL — the Flutter side falls
	// back to "<modality> <session_number>" rendering.
	if s.Name != nil {
		resp.Name = *s.Name
	}

	return resp
}

// UpdateSession renames a single session. Currently the only mutable
// field is `name`; future patches (e.g. session_date correction) extend
// this handler.
//
// Authz: the SQL UPDATE doesn't filter by therapist_id (sqlc-generated
// UpdateSessionName returns the refreshed row by id alone), so we pre-
// fetch the session and check ownership BEFORE the update. Cheap one
// extra round-trip; clearer 403 vs 404 errors for the caller.
func (s *Server) UpdateSession(ctx context.Context, req *clinicalv1.UpdateSessionRequest) (*clinicalv1.Session, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}

	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	newName := strings.TrimSpace(req.Name)
	if newName == "" {
		return nil, status.Error(codes.InvalidArgument, "name required")
	}
	// Cap at 255 to match VARCHAR(255). Failing here gives a friendlier
	// error than PG's "value too long for type character varying(255)".
	if len(newName) > 255 {
		return nil, status.Error(codes.InvalidArgument, "name too long (max 255 chars)")
	}

	existing, err := s.queries.GetSession(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "session not found")
	}
	if existing.TherapistID != therapistID {
		// Don't leak ownership info in the error string — same code
		// path as "not found" to avoid session-ID enumeration.
		return nil, status.Error(codes.NotFound, "session not found")
	}

	updated, err := s.queries.UpdateSessionName(ctx, db.UpdateSessionNameParams{
		ID:   sessionID,
		Name: &newName,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update name: %v", err)
	}

	return toProtoSession(updated), nil
}

// DeleteSession hard-deletes a single session. Migration 000012 turned
// transcripts/reports/hitop FK constraints to CASCADE, so dependent
// rows go in the same statement.
//
// Side effect: publishes a session.deleted Pub/Sub event so
// notification-svc can wipe the Firestore session_states/{sessionId}
// doc + any inbox notifications. The Pub/Sub publish is best-effort —
// if it fails we still report the deletion as successful (the PG side
// is gone; the Firestore mirror cleanup will lag but not block).
func (s *Server) DeleteSession(ctx context.Context, req *clinicalv1.DeleteSessionRequest) (*emptypb.Empty, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}

	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	rows, err := s.queries.HardDeleteSession(ctx, db.HardDeleteSessionParams{
		ID:          sessionID,
		TherapistID: therapistID,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "delete session: %v", err)
	}
	if rows == 0 {
		// Either the session never existed or belongs to another
		// therapist. Same 404 to avoid enumeration.
		return nil, status.Error(codes.NotFound, "session not found")
	}

	// Fire-and-forget — publish the cleanup event. If pubsub is wired
	// (s.pubsub != nil), we attempt the publish; failures are logged
	// but don't unwind the PG delete. notification-svc may double-fire
	// if Pub/Sub retries deliver after PG hard-delete completes — its
	// handler is idempotent (no-op on missing Firestore doc).
	if s.pubsub != nil {
		if err := s.pubsub.PublishSessionDeleted(ctx, sessionID.String(), therapistID.String()); err != nil {
			slog.Warn("publish session.deleted failed", "session_id", sessionID, "error", err)
		}
	}

	return &emptypb.Empty{}, nil
}

// transcriptBlobLine matches the JSON shape stt-worker writes to
// transcripts.transcript_ciphertext (services/ai-pipeline-svc/cmd/
// stt-worker/main.go BlobLine + labels.go BlobLine). Kept private and
// duplicated to keep this package self-contained.
type transcriptBlobLine struct {
	ChunkIdx     int     `json:"chunk_idx"`
	Text         string  `json:"text"`
	StartMS      int64   `json:"start_ms"`
	EndMS        int64   `json:"end_ms"`
	WordCount    int     `json:"word_count"`
	Confidence   float32 `json:"confidence"`
	SpeakerTag   *int32  `json:"speaker_tag,omitempty"`
	SpeakerLabel *string `json:"speaker_label,omitempty"`
}

// cryptoBoxIface — narrow surface of cryptobox.CryptoBox used here.
// Avoids pulling the import path; tests can fake.
type cryptoBoxIface interface {
	Decrypt(ctx context.Context, ciphertext, encryptedDEK []byte) ([]byte, error)
}

// loadCanonicalTranscriptSegments decrypts the single canonical
// transcript_ciphertext blob and maps it to proto TranscriptSegment.
// Returns nil + error if blob is missing/empty or decrypt/parse fails;
// caller falls back to per-segment loop in that case.
func loadCanonicalTranscriptSegments(ctx context.Context, crypto cryptoBoxIface, transcript db.Transcript) ([]*clinicalv1.TranscriptSegment, error) {
	if len(transcript.TranscriptCiphertext) == 0 {
		return nil, nil
	}
	blobJSON, err := crypto.Decrypt(ctx, transcript.TranscriptCiphertext, transcript.TranscriptEncryptedDek)
	if err != nil {
		return nil, err
	}
	var lines []transcriptBlobLine
	if err := json.Unmarshal(blobJSON, &lines); err != nil {
		return nil, err
	}
	out := make([]*clinicalv1.TranscriptSegment, 0, len(lines))
	for _, l := range lines {
		var tag int32
		if l.SpeakerTag != nil {
			tag = *l.SpeakerTag
		}
		var label string
		if l.SpeakerLabel != nil {
			label = *l.SpeakerLabel
		}
		out = append(out, &clinicalv1.TranscriptSegment{
			SpeakerTag:    tag,
			SpeakerLabel:  label,
			StartOffsetMs: int32(l.StartMS),
			EndOffsetMs:   int32(l.EndMS),
			Text:          l.Text,
			Confidence:    l.Confidence,
		})
	}
	return out, nil
}

// decryptPerSegmentFallback is the legacy code path — kept as a safety
// net for transcripts written before the canonical blob became the
// source of truth, or for environments where the blob field is empty
// for some reason. Same N×KMS-call cost the canonical path avoids, so
// don't rely on this for long sessions.
func decryptPerSegmentFallback(ctx context.Context, queries db.Querier, crypto cryptoBoxIface, transcriptID uuid.UUID, sessionIDStr string) ([]*clinicalv1.TranscriptSegment, []*clinicalv1.SpeakerTurn) {
	segments, err := queries.ListTranscriptSegments(ctx, transcriptID)
	if err != nil {
		return nil, nil
	}
	segs := make([]*clinicalv1.TranscriptSegment, 0, len(segments))
	for _, seg := range segments {
		textBytes, derr := crypto.Decrypt(ctx, seg.TextCiphertext, seg.TextEncryptedDek)
		if derr != nil {
			slog.Error("decrypt transcript segment",
				"session_id", sessionIDStr,
				"transcript_id", transcriptID.String(),
				"segment_id", seg.ID.String(),
				"error", derr)
			continue
		}
		var conf float32
		if seg.Confidence.Valid {
			c, _ := seg.Confidence.Float64Value()
			conf = float32(c.Float64)
		}
		segs = append(segs, &clinicalv1.TranscriptSegment{
			SpeakerTag:    seg.SpeakerTag,
			SpeakerLabel:  seg.SpeakerLabel,
			StartOffsetMs: seg.StartOffsetMs,
			EndOffsetMs:   seg.EndOffsetMs,
			Text:          string(textBytes),
			Confidence:    conf,
		})
	}
	return segs, grouping.GroupSegmentsIntoTurns(segs)
}
