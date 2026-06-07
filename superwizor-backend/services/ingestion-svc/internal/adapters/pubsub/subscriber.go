package pubsub

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"cloud.google.com/go/pubsub/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

// StorageObjectData represents the minimal payload of a GCS notification event.
type StorageObjectData struct {
	Bucket string `json:"bucket"`
	Name   string `json:"name"`
}

// AudioPublisher defines the event-publishing capability needed by the subscriber.
type AudioPublisher interface {
	PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error
}

type Subscriber struct {
	client     *pubsub.Client
	subID      string
	queries    *db.Queries
	pool       *pgxpool.Pool
	signer     *storage.Signer
	converter  *storage.Converter
	bucketName string
	publisher  AudioPublisher
	collector  *analytics.Collector
}

func NewSubscriber(
	ctx context.Context,
	projectID string,
	subID string,
	queries *db.Queries,
	pool *pgxpool.Pool,
	signer *storage.Signer,
	converter *storage.Converter,
	bucketName string,
	publisher AudioPublisher,
	collector *analytics.Collector,
) (*Subscriber, error) {
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("pubsub client: %w", err)
	}

	return &Subscriber{
		client:     client,
		subID:      subID,
		queries:    queries,
		pool:       pool,
		signer:     signer,
		converter:  converter,
		bucketName: bucketName,
		publisher:  publisher,
		collector:  collector,
	}, nil
}

func (s *Subscriber) Start(ctx context.Context) {
	slog.Info("subscriber: starting background pull subscriber", "subscription", s.subID)

	sub := s.client.Subscriber(s.subID)
	for {
		select {
		case <-ctx.Done():
			slog.Info("subscriber: stopping background pull subscriber", "reason", ctx.Err())
			return
		default:
			// Pull messages
			err := sub.Receive(ctx, func(receiveCtx context.Context, msg *pubsub.Message) {
				s.handleMessage(receiveCtx, msg)
			})
			if err != nil {
				if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
					return
				}
				slog.Error("subscriber: receive error, retrying in 5 seconds", "error", err)
				time.Sleep(5 * time.Second)
			}
		}
	}
}

func (s *Subscriber) handleMessage(ctx context.Context, msg *pubsub.Message) {
	// 1. Guard against non-OBJECT_FINALIZE events
	eventType := msg.Attributes["eventType"]
	if eventType == "" {
		eventType = msg.Attributes["event_type"]
	}
	// Note: GCS direct notification usually sends OBJECT_FINALIZE.
	// If Eventarc is routing it, the attribute might also be eventType.
	// We'll also check if the event type is empty or OBJECT_FINALIZE.
	if eventType != "" && eventType != "OBJECT_FINALIZE" {
		slog.Debug("subscriber: skipping non-finalize event", "eventType", eventType)
		msg.Ack()
		return
	}

	var data StorageObjectData
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		slog.Warn("subscriber: malformed payload, acking", "error", err)
		msg.Ack()
		return
	}

	if data.Name == "" || data.Bucket == "" {
		slog.Debug("subscriber: skipping empty notification payload")
		msg.Ack()
		return
	}

	// 2. Parse session ID from GCS path
	sessionID, err := parseSessionIDFromObjectPath(data.Name)
	if err != nil {
		slog.Debug("subscriber: skipping unrelated object path", "path", data.Name, "error", err)
		msg.Ack()
		return
	}

	slog.Info("subscriber: processing upload event", "session_id", sessionID, "path", data.Name)

	// 3. Acquire transaction-based advisory lock on session
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		slog.Error("subscriber: begin transaction failed", "session_id", sessionID, "error", err)
		msg.Nack()
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()

	_, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, sessionID.String())
	if err != nil {
		slog.Error("subscriber: acquire advisory lock failed", "session_id", sessionID, "error", err)
		msg.Nack()
		return
	}

	txq := s.queries.WithTx(tx)

	// 4. Query session and join upload to verify status
	var sessionStatus string
	var upload db.AudioUpload
	err = tx.QueryRow(ctx, `
		SELECT s.status, u.id, u.therapist_id, u.patient_file_id, u.session_id, u.bucket_name, u.object_path, u.content_type, u.status
		FROM sessions s
		JOIN audio_uploads u ON u.id = s.audio_upload_id
		WHERE s.id = $1 AND s.deleted_at IS NULL
	`, pgtype.UUID{Bytes: sessionID, Valid: true}).Scan(
		&sessionStatus,
		&upload.ID,
		&upload.TherapistID,
		&upload.PatientFileID,
		&upload.SessionID,
		&upload.BucketName,
		&upload.ObjectPath,
		&upload.ContentType,
		&upload.Status,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			slog.Warn("subscriber: session or linked upload not found, acking", "session_id", sessionID)
			msg.Ack()
			return
		}
		slog.Error("subscriber: query session/upload failed", "session_id", sessionID, "error", err)
		msg.Nack()
		return
	}

	var uploadIDStr string
	if upload.ID.Valid {
		uploadIDStr = uuid.UUID(upload.ID.Bytes).String()
	}

	// 5. Idempotency Check: if already CREATED or past it
	if sessionStatus != "PENDING_UPLOAD" {
		if sessionStatus == "CREATED" {
			slog.Info("subscriber: session is CREATED; republishing event", "session_id", sessionID)
			if pubErr := s.publisher.PublishAudioUploaded(ctx, sessionID.String(), uploadIDStr, upload.ObjectPath); pubErr != nil {
				slog.Error("subscriber: republish event failed", "session_id", sessionID, "error", pubErr)
				msg.Nack()
				return
			}
		}
		slog.Info("subscriber: session already processed, acking", "session_id", sessionID, "status", sessionStatus)
		msg.Ack()
		return
	}

	// 6. Autoritative Duration Probe via ffprobe
	durationSec, probeErr := s.converter.ProbeDuration(ctx, upload.BucketName, upload.ObjectPath)
	if probeErr != nil {
		slog.Warn("subscriber: ffprobe failed; using default/claimed duration", "session_id", sessionID, "error", probeErr)
		if upload.DurationSeconds != nil {
			durationSec = int(*upload.DurationSeconds)
		}
	} else {
		slog.Info("subscriber: probed duration successfully", "session_id", sessionID, "duration_sec", durationSec)
	}

	// 7. Codec Normalization (Transcode to FLAC if not Chirp-supported)
	skipTranscode := storage.IsChirpSupported(upload.ContentType)
	finalObjectPath := upload.ObjectPath

	if !skipTranscode {
		slog.Info("subscriber: transcoding non-FLAC audio source to FLAC", "session_id", sessionID, "src", upload.ObjectPath, "contentType", upload.ContentType)
		t0 := time.Now()
		result, convErr := s.converter.Convert(ctx, upload.BucketName, upload.ObjectPath, upload.ContentType, "audio/flac")
		if convErr != nil {
			slog.Error("subscriber: audio transcode failed with terminal error", "session_id", sessionID, "error", convErr)
			_ = txq.MarkAudioUploadFailed(ctx, db.MarkAudioUploadFailedParams{
				ID:           upload.ID,
				ErrorMessage: ptr(convErr.Error()),
			})
			_ = txq.UpdateSessionStatus(ctx, db.UpdateSessionStatusParams{
				ID:     pgtype.UUID{Bytes: sessionID, Valid: true},
				Status: "FAILED",
			})
			s.trackUploadFailed(ctx, upload, "transcode_error")
			if commitErr := tx.Commit(ctx); commitErr != nil {
				slog.Error("subscriber: commit failed on failure path", "session_id", sessionID, "error", commitErr)
			}
			msg.Ack() // Terminal error, ack it
			return
		}
		slog.Info("subscriber: audio transcode completed successfully", "session_id", sessionID, "dst", result.ObjectPath, "duration_ms", time.Since(t0).Milliseconds())

		updatedUpload, updateErr := txq.UpdateAudioUploadAfterConversion(ctx, db.UpdateAudioUploadAfterConversionParams{
			ID:          upload.ID,
			ObjectPath:  result.ObjectPath,
			ContentType: result.ContentType,
			BucketName:  result.BucketName,
		})
		if updateErr != nil {
			slog.Error("subscriber: UpdateAudioUploadAfterConversion failed", "session_id", sessionID, "error", updateErr)
			msg.Nack()
			return
		}
		finalObjectPath = updatedUpload.ObjectPath
	}

	// 8. Chunking Support (splits > 19-min FLAC audio into chunks)
	const longAudioThresholdSec = 1140
	chunkCount := 0
	if durationSec > longAudioThresholdSec {
		slog.Info("subscriber: audio exceeds threshold; triggering ffmpeg chunking", "session_id", sessionID, "duration_sec", durationSec)

		existingChunks, countErr := txq.CountAudioChunksByUpload(ctx, upload.ID)
		if countErr != nil {
			slog.Error("subscriber: CountAudioChunksByUpload failed", "session_id", sessionID, "error", countErr)
			msg.Nack()
			return
		}

		maxSec := longAudioThresholdSec
		expectedN := int64((durationSec + maxSec - 1) / maxSec)

		if existingChunks > 0 && existingChunks == expectedN {
			slog.Info("subscriber: expected chunks already exist in DB", "session_id", sessionID)
			chunkCount = int(existingChunks)
		} else {
			if existingChunks > 0 {
				if delErr := txq.DeleteAudioChunksByUpload(ctx, upload.ID); delErr != nil {
					slog.Error("subscriber: DeleteAudioChunksByUpload failed", "session_id", sessionID, "error", delErr)
					msg.Nack()
					return
				}
			}

			chunks, chunkErr := s.converter.ChunkForChirp(ctx, upload.BucketName, finalObjectPath, durationSec, maxSec)
			if chunkErr != nil {
				slog.Error("subscriber: ChunkForChirp failed with terminal error", "session_id", sessionID, "error", chunkErr)
				_ = txq.MarkAudioUploadFailed(ctx, db.MarkAudioUploadFailedParams{
					ID:           upload.ID,
					ErrorMessage: ptr(chunkErr.Error()),
				})
				_ = txq.UpdateSessionStatus(ctx, db.UpdateSessionStatusParams{
					ID:     pgtype.UUID{Bytes: sessionID, Valid: true},
					Status: "FAILED",
				})
				s.trackUploadFailed(ctx, upload, "chunking_error")
				if commitErr := tx.Commit(ctx); commitErr != nil {
					slog.Error("subscriber: commit failed on failure path", "session_id", sessionID, "error", commitErr)
				}
				msg.Ack()
				return
			}

			for _, ch := range chunks {
				if insertErr := txq.CreateAudioChunk(ctx, db.CreateAudioChunkParams{
					AudioUploadID: upload.ID,
					ChunkIndex:    int32(ch.ChunkIndex),
					BucketName:    ch.BucketName,
					ObjectPath:    ch.ObjectPath,
					StartOffsetMs: ch.StartOffsetMS,
					SeamOffsetMs:  ch.SeamOffsetMS,
					EndOffsetMs:   ch.EndOffsetMS,
					OverlapMs:     int32(ch.OverlapMS),
					CutOnSilence:  ch.CutOnSilence,
				}); insertErr != nil {
					slog.Error("subscriber: CreateAudioChunk failed", "session_id", sessionID, "error", insertErr)
					msg.Nack()
					return
				}
			}
			chunkCount = len(chunks)
		}
	}

	// 9. Finalize audio upload and session database records
	_, completeErr := txq.CompleteAudioUpload(ctx, db.CompleteAudioUploadParams{
		ID:              upload.ID,
		DurationSeconds: ptr(int32(durationSec)),
		FileSizeBytes:   upload.FileSizeBytes,
		ChunkCount:      int32(chunkCount),
	})
	if completeErr != nil {
		slog.Error("subscriber: CompleteAudioUpload failed", "session_id", sessionID, "error", completeErr)
		msg.Nack()
		return
	}

	if _, durErr := txq.UpdateSessionDuration(ctx, db.UpdateSessionDurationParams{
		ID:              pgtype.UUID{Bytes: sessionID, Valid: true},
		DurationSeconds: ptr(int32(durationSec)),
	}); durErr != nil {
		slog.Warn("subscriber: UpdateSessionDuration failed", "session_id", sessionID, "error", durErr)
	}

	if statusErr := txq.UpdateSessionStatus(ctx, db.UpdateSessionStatusParams{
		ID:     pgtype.UUID{Bytes: sessionID, Valid: true},
		Status: "CREATED",
	}); statusErr != nil {
		slog.Error("subscriber: UpdateSessionStatus failed", "session_id", sessionID, "error", statusErr)
		msg.Nack()
		return
	}

	// 10. Commit transaction
	if commitErr := tx.Commit(ctx); commitErr != nil {
		slog.Error("subscriber: commit tx failed", "session_id", sessionID, "error", commitErr)
		msg.Nack()
		return
	}

	s.trackUploadFinalized(ctx, upload, durationSec, !skipTranscode, chunkCount)

	slog.Info("subscriber: successfully processed upload, publishing STT kickoff event", "session_id", sessionID)

	// 11. Kickoff down-stream STT fanning out
	if pubErr := s.publisher.PublishAudioUploaded(ctx, sessionID.String(), uploadIDStr, finalObjectPath); pubErr != nil {
		slog.Error("subscriber: PublishAudioUploaded failed", "session_id", sessionID, "error", pubErr)
		// We nack the message so the subscriber retries later. Idempotency guard at step 5
		// will detect the CREATED status, republish the event, and ack safely!
		msg.Nack()
		return
	}

	msg.Ack()
}

func parseSessionIDFromObjectPath(path string) (uuid.UUID, error) {
	parts := strings.Split(path, "/")
	if len(parts) < 3 {
		return uuid.Nil, fmt.Errorf("invalid path format, expected at least 3 parts: %s", path)
	}
	// The GCS path format is: {therapist_id}/{session_id}/{timestamp}.{ext}
	_, err := uuid.Parse(parts[0])
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid therapist ID UUID: %w", err)
	}
	sessionID, err := uuid.Parse(parts[1])
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid session ID UUID: %w", err)
	}
	return sessionID, nil
}

func ptr[T any](v T) *T {
	return &v
}

func (s *Subscriber) trackUploadFailed(ctx context.Context, upload db.AudioUpload, category string) {
	if s.collector == nil {
		return
	}
	var thID *uuid.UUID
	if upload.TherapistID.Valid {
		id := uuid.UUID(upload.TherapistID.Bytes)
		thID = &id
	}
	var patFileID *uuid.UUID
	if upload.PatientFileID.Valid {
		id := uuid.UUID(upload.PatientFileID.Bytes)
		patFileID = &id
	}
	var sessID *uuid.UUID
	if upload.SessionID.Valid {
		id := uuid.UUID(upload.SessionID.Bytes)
		sessID = &id
	}
	var orgIDPtr *uuid.UUID
	if upload.TherapistID.Valid {
		orgIDPg, errOrg := s.queries.GetUserOrganizationID(ctx, upload.TherapistID)
		if errOrg == nil && orgIDPg.Valid {
			id := uuid.UUID(orgIDPg.Bytes)
			orgIDPtr = &id
		}
	}

	s.collector.Track(ctx, analytics.Event{
		Name:           "upload.failed",
		TherapistID:    thID,
		OrganizationID: orgIDPtr,
		SessionID:      sessID,
		PatientFileID:  patFileID,
		Properties: map[string]any{
			"error_category": category,
		},
		Source: "server",
	})
}

func (s *Subscriber) trackUploadFinalized(ctx context.Context, upload db.AudioUpload, durationSec int, neededTranscode bool, chunkCount int) {
	if s.collector == nil {
		return
	}
	var thID *uuid.UUID
	if upload.TherapistID.Valid {
		id := uuid.UUID(upload.TherapistID.Bytes)
		thID = &id
	}
	var patFileID *uuid.UUID
	if upload.PatientFileID.Valid {
		id := uuid.UUID(upload.PatientFileID.Bytes)
		patFileID = &id
	}
	var sessID *uuid.UUID
	if upload.SessionID.Valid {
		id := uuid.UUID(upload.SessionID.Bytes)
		sessID = &id
	}
	var orgIDPtr *uuid.UUID
	if upload.TherapistID.Valid {
		orgIDPg, errOrg := s.queries.GetUserOrganizationID(ctx, upload.TherapistID)
		if errOrg == nil && orgIDPg.Valid {
			id := uuid.UUID(orgIDPg.Bytes)
			orgIDPtr = &id
		}
	}

	s.collector.Track(ctx, analytics.Event{
		Name:           "upload.finalized",
		TherapistID:    thID,
		OrganizationID: orgIDPtr,
		SessionID:      sessID,
		PatientFileID:  patFileID,
		Properties: map[string]any{
			"duration_seconds": durationSec,
			"needed_transcode": neededTranscode,
			"chunk_count":      chunkCount,
		},
		Source: "server",
	})
}
