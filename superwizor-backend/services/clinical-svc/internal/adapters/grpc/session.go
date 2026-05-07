package grpc

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
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
		Id:              s.ID.String(),
		TherapistId:     s.TherapistID.String(),
		PatientFileId:   s.PatientFileID.String(),
		SessionDate:     s.SessionDate.Time.Format("2006-01-02"),
		SessionNumber:   s.SessionNumber,
		ContactForm:     string(s.ContactForm),
		Status:          string(s.Status),
		CreatedAt:       timestamppb.New(s.CreatedAt),
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
	
	return resp
}
