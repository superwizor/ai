package grpc

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

type Server struct {
	ingestionv1.UnimplementedIngestionServiceServer
	queries    *db.Queries
	signer     *storage.Signer
	bucketName string
	pubsub     PubsubPublisher  // interface — concrete impl w main
}

type PubsubPublisher interface {
	PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error
}

func NewServer(queries *db.Queries, signer *storage.Signer, bucketName string, pubsub PubsubPublisher) *Server {
	return &Server{queries: queries, signer: signer, bucketName: bucketName, pubsub: pubsub}
}

func (s *Server) CreateAudioUpload(ctx context.Context, req *ingestionv1.CreateAudioUploadRequest) (*ingestionv1.CreateAudioUploadResponse, error) {
	fmt.Printf("Received CreateAudioUpload request\n")
	therapistID, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}
	patientFileID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	if req.IdempotencyKey == "" {
		return nil, status.Error(codes.InvalidArgument, "idempotency_key required")
	}

	therapistIDPg := pgtype.UUID{Bytes: therapistID, Valid: true}
	patientFileIDPg := pgtype.UUID{Bytes: patientFileID, Valid: true}

	// Idempotency check
	existing, err := s.queries.GetAudioUploadByIdempotency(ctx, db.GetAudioUploadByIdempotencyParams{
		IdempotencyKey: &req.IdempotencyKey,
		TherapistID:    therapistIDPg,
	})
	if err == nil {
		// Already exists — regenerate signed URL
		signedURL, expires, err := s.signer.GenerateUploadURL(ctx, existing.ObjectPath, existing.ContentType)
		if err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
		
		var existingID uuid.UUID
		if existing.ID.Valid {
			existingID = existing.ID.Bytes
		}

		return &ingestionv1.CreateAudioUploadResponse{
			UploadId:           existingID.String(),
			SignedUrl:          signedURL,
			SignedUrlExpiresAt: timestamppb.New(expires),
			ObjectPath:         existing.ObjectPath,
			RequiredHeaders: map[string]string{
				"x-goog-meta-source": "superwizor-mobile",
			},
		}, nil
	}

	ext := ".flac"
	switch req.ContentType {
	case "audio/flac":
		ext = ".flac"
	case "audio/wav":
		ext = ".wav"
	case "audio/mpeg":
		ext = ".mp3"
	case "audio/ogg", "audio/opus":
		ext = ".ogg"
	case "audio/webm":
		ext = ".webm"
	case "audio/mp4", "audio/m4a":
		ext = ".m4a"
	case "audio/aac":
		ext = ".aac"
	case "audio/amr":
		ext = ".amr"
	case "audio/x-ms-wma":
		ext = ".wma"
	}

	objectPath := fmt.Sprintf("%s/%s/%d%s",
		therapistID.String(),
		patientFileID.String(),
		time.Now().Unix(),
		ext,
	)

	upload, err := s.queries.CreateAudioUpload(ctx, db.CreateAudioUploadParams{
		TherapistID:       therapistIDPg,
		PatientFileID:     patientFileIDPg,
		BucketName:        s.bucketName,
		ObjectPath:        objectPath,
		ContentType:       req.ContentType,
		IdempotencyKey:    &req.IdempotencyKey,
		ClientAppVersion:  &req.ClientAppVersion,
		ClientPlatform:    &req.ClientPlatform,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	signedURL, expires, err := s.signer.GenerateUploadURL(ctx, objectPath, req.ContentType)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	var uploadIDStr string
	if upload.ID.Valid {
		uploadIDStr = uuid.UUID(upload.ID.Bytes).String()
	}

	return &ingestionv1.CreateAudioUploadResponse{
		UploadId:           uploadIDStr,
		SignedUrl:          signedURL,
		SignedUrlExpiresAt: timestamppb.New(expires),
		ObjectPath:         objectPath,
		RequiredHeaders: map[string]string{
			"x-goog-meta-source": "superwizor-mobile",
		},
	}, nil
}

func (s *Server) CompleteAudioUpload(ctx context.Context, req *ingestionv1.CompleteAudioUploadRequest) (*ingestionv1.CompleteAudioUploadResponse, error) {
	uploadID, err := uuid.Parse(req.UploadId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid upload_id")
	}

	uploadIDPg := pgtype.UUID{Bytes: uploadID, Valid: true}

	upload, err := s.queries.CompleteAudioUpload(ctx, db.CompleteAudioUploadParams{
		ID:              uploadIDPg,
		DurationSeconds: &req.ActualDurationSeconds,
		FileSizeBytes:   &req.ActualSizeBytes,
		ChunkCount:      req.ChunkCount,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// Auto-create session
	nextNumber, err := s.queries.GetNextSessionNumber(ctx, upload.PatientFileID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
    
	nextNum := nextNumber

    t := time.Now()
	datePg := pgtype.Date{Time: t, Valid: true}

	reportLang := req.ReportLanguage
	if reportLang == "" {
		reportLang = "pl"
	}

	// Compute the default session.name now while we have the
	// patient_file_id handy. Formula matches migration 000011's
	// backfill: "<modality display_name> <session_number>". Empty
	// modality lookup → empty NameDefault → DB stores NULL → the
	// proto mapper emits "" and Flutter falls back to its own
	// rendering. That degradation path is benign.
	modalityDisplay, lookupErr := s.queries.GetModalityDisplayNameForPatientFile(ctx, upload.PatientFileID)
	var defaultName string
	if lookupErr == nil && modalityDisplay != "" {
		defaultName = fmt.Sprintf("%s %d", modalityDisplay, nextNum)
	}

	session, err := s.queries.CreateSession(ctx, db.CreateSessionParams{
		TherapistID:     upload.TherapistID,
		PatientFileID:   upload.PatientFileID,
		AudioUploadID:   upload.ID,
		SessionDate:     datePg,
		SessionNumber:   nextNum,
		DurationSeconds: &req.ActualDurationSeconds,
		ContactForm:     "OFFICE",
		ReportLanguage:  reportLang,
		NameDefault:     defaultName,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	var sessionIDStr string
	if session.ID.Valid {
		sessionIDStr = uuid.UUID(session.ID.Bytes).String()
	}

	// Publish do Pub/Sub → trigger STT worker
	if err := s.pubsub.PublishAudioUploaded(ctx, sessionIDStr, req.UploadId, upload.ObjectPath); err != nil {
		// Log warning ale nie failuj request — workflow można retry'ować
		slog.Warn("failed to publish audio.uploaded", "error", err, "session_id", sessionIDStr)
	}

	return &ingestionv1.CompleteAudioUploadResponse{
		UploadId:          req.UploadId,
		SessionId:         sessionIDStr,
		ProcessingStarted: true,
	}, nil
}

func (s *Server) GetAudioUploadStatus(ctx context.Context, req *ingestionv1.GetAudioUploadStatusRequest) (*ingestionv1.AudioUploadStatus, error) {
	id, err := uuid.Parse(req.UploadId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid upload_id")
	}

	idPg := pgtype.UUID{Bytes: id, Valid: true}

	upload, err := s.queries.GetAudioUpload(ctx, idPg)
	if err != nil {
		if errors.Is(err, errNoRows()) {
			return nil, status.Error(codes.NotFound, "upload not found")
		}
		return nil, status.Error(codes.Internal, err.Error())
	}

	var createdTime, expiresTime time.Time
	if upload.CreatedAt.Valid {
		createdTime = upload.CreatedAt.Time
	}
	if upload.ExpiresAt.Valid {
		expiresTime = upload.ExpiresAt.Time
	}

	resp := &ingestionv1.AudioUploadStatus{
		UploadId:  req.UploadId,
		Status:    string(upload.Status),
		CreatedAt: timestamppb.New(createdTime),
		ExpiresAt: timestamppb.New(expiresTime),
	}
	if upload.ErrorMessage != nil {
		resp.ErrorMessage = *upload.ErrorMessage
	}
	return resp, nil
}

func errNoRows() error {
	// pgx.ErrNoRows alias for testability
	return fmt.Errorf("no rows")
}
