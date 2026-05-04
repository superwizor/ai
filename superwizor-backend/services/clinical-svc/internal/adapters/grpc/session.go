package grpc

import (
	"context"
	"encoding/json"

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
			for _, seg := range segments {
				textBytes, err := s.crypto.Decrypt(ctx, seg.TextCiphertext, seg.TextEncryptedDek)
				if err != nil {
					continue // or return error
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
		}
		resp.Transcript = protoTranscript
	}

	// 3. Fetch reports
	reports, err := s.queries.ListReportsBySession(ctx, sessionID)
	if err == nil {
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

			// Decrypt report
			contentBytes, err := s.crypto.Decrypt(ctx, rep.ReportCiphertext, rep.ReportEncryptedDek)
			if err != nil {
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
