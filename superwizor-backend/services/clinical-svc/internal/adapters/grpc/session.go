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
		
		// 2. Fetch transcript segments
		segments, err := s.queries.ListTranscriptSegments(ctx, transcript.ID)
		if err == nil {
			var segDecryptErrs int
			for _, seg := range segments {
				textBytes, err := s.crypto.Decrypt(ctx, seg.TextCiphertext, seg.TextEncryptedDek)
				if err != nil {
					// Log loudly — silently dropping segments was the bug
					// behind "GetSessionDetails returns empty data" when
					// KMS_KEY_URI was missing and cryptobox fell back to
					// MockBox. The handler still returns a partial response
					// rather than failing — caller can compare segment
					// count to transcript_segments table to detect drift.
					segDecryptErrs++
					slog.Error("decrypt transcript segment",
						"session_id", req.SessionId,
						"transcript_id", transcript.ID.String(),
						"segment_id", seg.ID.String(),
						"error", err)
					continue
				}
				text := string(textBytes)
				
				var conf float32
				if seg.Confidence.Valid {
				    c, _ := seg.Confidence.Float64Value()
				    conf = float32(c.Float64)
				}
				protoTranscript.Segments = append(protoTranscript.Segments, &clinicalv1.TranscriptSegment{
					SpeakerTag:    seg.SpeakerTag,
					SpeakerLabel:  seg.SpeakerLabel,
					StartOffsetMs: seg.StartOffsetMs,
					EndOffsetMs:   seg.EndOffsetMs,
					Text:          text,
					Confidence:    conf,
				})
			}
			// If we couldn't decrypt ANY segment but had segments, that's
			// almost certainly a KMS misconfig (missing KMS_KEY_URI env
			// var, missing roles/cloudkms.cryptoKeyEncrypterDecrypter on
			// the runtime SA). Fail loud rather than return an empty
			// transcript that callers will report as an empty session.
			if len(segments) > 0 && len(protoTranscript.Segments) == 0 {
				slog.Error("all transcript segments failed to decrypt — likely KMS misconfig",
					"session_id", req.SessionId,
					"transcript_id", transcript.ID.String(),
					"segment_count", len(segments),
					"decrypt_errors", segDecryptErrs)
				return nil, status.Error(codes.Internal,
					"transcript present but no segments could be decrypted; check clinical-svc KMS config")
			}
			// Derive speaker-grouped view from the (decrypted) segments.
			// Read-only views in Flutter bind to Turns; the per-chunk
			// Segments slice stays for the speaker-label edit UI.
			// O(n) over segments; trivial vs the decrypt loop above.
			protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(protoTranscript.Segments)
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
