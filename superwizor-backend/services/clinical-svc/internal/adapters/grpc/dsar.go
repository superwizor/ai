package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/grouping"
)

// ExportPatientData exports all clinical and personal data related to a patient, decrypting KMS-encrypted columns.
func (s *Server) ExportPatientData(ctx context.Context, req *clinicalv1.ExportPatientDataRequest) (*clinicalv1.ExportPatientDataResponse, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}

	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	// Authz check: verify therapist owns the patient file
	pfJoin, err := s.queries.GetPatientFileWithUser(ctx, pfID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "patient file not found")
		}
		return nil, status.Errorf(codes.Internal, "get patient file: %v", err)
	}

	if pfJoin.TherapistID != therapistID {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	// 1. Map patient file details
	protoPF := toProtoPatientFileFromJoinRow(pfJoin, "")

	// 2. Fetch and decrypt patient notes
	notes, err := s.queries.GetPatientNotesForExport(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "fetch patient notes: %v", err)
	}

	var decryptedNotes []*clinicalv1.DecryptedPatientNote
	for _, n := range notes {
		titleBytes, err := s.crypto.Decrypt(ctx, n.TitleCiphertext, n.TitleEncryptedDek)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "decrypt note title: %v", err)
		}
		textBytes, err := s.crypto.Decrypt(ctx, n.TextCiphertext, n.TextEncryptedDek)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "decrypt note text: %v", err)
		}

		decryptedNote := &clinicalv1.DecryptedPatientNote{
			Id:        n.ID.String(),
			Kind:      n.Kind,
			Title:     string(titleBytes),
			Text:      string(textBytes),
			CreatedAt: timestamppb.New(n.CreatedAt),
		}
		if n.SentToPatientAt.Valid {
			decryptedNote.SentToPatientAt = timestamppb.New(n.SentToPatientAt.Time)
		}
		if n.SentToEmail != nil {
			decryptedNote.SentToEmail = *n.SentToEmail
		}
		decryptedNotes = append(decryptedNotes, decryptedNote)
	}

	// 3. Fetch and decrypt sessions, transcripts, and reports
	sessions, err := s.queries.GetSessionsForExport(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "fetch sessions: %v", err)
	}

	var decryptedSessions []*clinicalv1.DecryptedSession
	for _, sess := range sessions {
		decryptedSess := &clinicalv1.DecryptedSession{
			Id:            sess.ID.String(),
			Name:          derefString(sess.Name),
			SessionDate:   sess.SessionDate.Time.Format("2006-01-02"),
			SessionNumber: sess.SessionNumber,
			Status:        string(sess.Status),
			CreatedAt:     timestamppb.New(sess.CreatedAt),
		}
		if sess.DurationSeconds != nil {
			decryptedSess.DurationSeconds = *sess.DurationSeconds
		}

		// 3a. Fetch and decrypt transcript
		transcript, err := s.queries.GetTranscriptBySession(ctx, sess.ID)
		if err == nil {
			var segs []*clinicalv1.TranscriptSegment
			if loadedSegs, ok := tryCanonicalBlobSegments(ctx, s.crypto, transcript); ok {
				segs = loadedSegs
			} else {
				segs, err = loadSegmentsViaPerSegmentLoop(ctx, s.queries, s.crypto, transcript.ID, sess.ID.String())
				if err != nil {
					slog.WarnContext(ctx, "failed to decrypt segments for session", "session_id", sess.ID, "error", err)
				}
			}

			if len(segs) > 0 {
				protoTranscript := &clinicalv1.DecryptedSessionTranscript{
					Id: transcript.ID.String(),
				}
				for _, seg := range segs {
					protoTranscript.Segments = append(protoTranscript.Segments, &clinicalv1.DecryptedSessionSegment{
						SpeakerTag:    seg.SpeakerTag,
						SpeakerLabel:  seg.SpeakerLabel,
						StartOffsetMs: seg.StartOffsetMs,
						EndOffsetMs:   seg.EndOffsetMs,
						Text:          seg.Text,
						Confidence:    seg.Confidence,
					})
				}
				// Group turns
				turns := grouping.GroupSegmentsIntoTurns(segs)
				for _, turn := range turns {
					protoTranscript.Turns = append(protoTranscript.Turns, &clinicalv1.DecryptedSessionTurn{
						SpeakerTag:    turn.SpeakerTag,
						SpeakerLabel:  turn.SpeakerLabel,
						StartOffsetMs: turn.StartOffsetMs,
						EndOffsetMs:   turn.EndOffsetMs,
						Text:          turn.Text,
						SegmentCount:  turn.SegmentCount,
						ConfidenceAvg: turn.ConfidenceAvg,
					})
				}
				decryptedSess.Transcript = protoTranscript
			}
		}

		// 3b. Fetch and decrypt reports
		reports, err := s.queries.ListReportsBySession(ctx, sess.ID)
		if err == nil {
			for _, rep := range reports {
				contentBytes, err := s.crypto.Decrypt(ctx, rep.ReportCiphertext, rep.ReportEncryptedDek)
				if err != nil {
					slog.ErrorContext(ctx, "decrypt report failed during DSAR export", "session_id", sess.ID, "report_id", rep.ID, "error", err)
					continue
				}

				decryptedSess.Reports = append(decryptedSess.Reports, &clinicalv1.DecryptedReport{
					Id:             rep.ID.String(),
					Title:          derefString(rep.Title),
					SummaryShort:   derefString(rep.SummaryShort),
					Content:        string(contentBytes),
					SentimentLabel: derefString(rep.SentimentLabel),
					RiskLevel:      derefString(rep.RiskLevel),
					CreatedAt:      timestamppb.New(rep.CreatedAt),
				})
			}
		}

		decryptedSessions = append(decryptedSessions, decryptedSess)
	}

	return &clinicalv1.ExportPatientDataResponse{
		PatientFile: protoPF,
		Notes:       decryptedNotes,
		Sessions:    decryptedSessions,
	}, nil
}

// DeletePatientData performs a cascaded soft-delete of all patient data.
func (s *Server) DeletePatientData(ctx context.Context, req *clinicalv1.DeletePatientDataRequest) (*emptypb.Empty, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}

	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	// Fetch file to verify ownership
	pf, err := s.queries.GetPatientFile(ctx, pfID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "patient file not found")
		}
		return nil, status.Errorf(codes.Internal, "get patient file: %v", err)
	}

	if pf.TherapistID != therapistID {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	// Pre-fetch session IDs for Pub/Sub deletion events
	sessionIDs, err := s.queries.ListSessionIDsForPatientFile(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list sessions: %v", err)
	}

	// Transaction to perform cascade soft-delete
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "begin transaction: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := tx.Queries()

	// 1. Soft-delete sessions
	if err := qtx.SoftDeleteSessionsForDSAR(ctx, pfID); err != nil {
		return nil, status.Errorf(codes.Internal, "soft delete sessions: %v", err)
	}

	// 2. Soft-delete patient notes
	if err := qtx.SoftDeletePatientNotesForDSAR(ctx, pfID); err != nil {
		return nil, status.Errorf(codes.Internal, "soft delete notes: %v", err)
	}

	// 3. Soft-delete patient file itself
	rows, err := qtx.SoftDeletePatientFileForDSAR(ctx, db.SoftDeletePatientFileForDSARParams{
		ID:          pfID,
		TherapistID: therapistID,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "soft delete patient file: %v", err)
	}
	if rows == 0 {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	// 4. Soft-delete paired patient user if exists
	if pf.PatientID.Valid {
		patientUserID := uuid.UUID(pf.PatientID.Bytes)
		_, err := qtx.SoftDeletePatientUserForDSAR(ctx, patientUserID)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "soft delete patient user: %v", err)
		}
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit transaction: %v", err)
	}

	// Write audit log event
	auditMeta, _ := json.Marshal(map[string]any{
		"patient_file_id": pfID.String(),
		"sessions_count":  len(sessionIDs),
	})
	_ = s.queries.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		ActorUserID:  pgtype.UUID{Bytes: therapistID, Valid: true},
		Action:       "patient_file.soft_delete",
		ResourceType: "patient_file",
		ResourceID:   pgtype.UUID{Bytes: pfID, Valid: true},
		Metadata:     auditMeta,
	})

	// Fan out Pub/Sub deleted events
	if s.pubsub != nil {
		for _, sid := range sessionIDs {
			if err := s.pubsub.PublishSessionDeleted(ctx, sid.String(), therapistID.String()); err != nil {
				slog.WarnContext(ctx, "publish session.deleted failed during DSAR delete",
					"session_id", sid, "error", err)
			}
		}
	}

	slog.InfoContext(ctx, "completed patient data soft-delete",
		"patient_file_id", pfID.String(),
		"therapist_id", therapistID.String(),
		"sessions_deleted", len(sessionIDs),
	)

	return &emptypb.Empty{}, nil
}

func derefString(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}
