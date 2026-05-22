package grpc

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	"github.com/superwizor-ai/backend/pkg/i18n/lang"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

type Server struct {
	ingestionv1.UnimplementedIngestionServiceServer
	queries    *db.Queries
	pool       *pgxpool.Pool // raw pool for advisory locks + ad-hoc tx
	signer     *storage.Signer
	converter  *storage.Converter // shells out to ffmpeg; used by ConvertAudio
	bucketName string
	pubsub     PubsubPublisher // interface — concrete impl w main
}

type PubsubPublisher interface {
	PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error
}

func NewServer(
	queries *db.Queries,
	pool *pgxpool.Pool,
	signer *storage.Signer,
	converter *storage.Converter,
	bucketName string,
	pubsub PubsubPublisher,
) *Server {
	return &Server{
		queries:    queries,
		pool:       pool,
		signer:     signer,
		converter:  converter,
		bucketName: bucketName,
		pubsub:     pubsub,
	}
}

// pgxBegin is the bridge between Stage 1's `s.queries` (sqlc-bound)
// and Stage 2's need for ad-hoc transactional work (pg_advisory_xact_lock
// + multi-row INSERT). Returns a pgx.Tx the caller wraps with
// s.queries.WithTx(tx) for sqlc-flavored statements.
func (s *Server) pgxBegin(ctx context.Context) (pgx.Tx, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("pgxBegin: server has no pool (test wiring?)")
	}
	return s.pool.Begin(ctx)
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

	// Idempotency pre-check (migration 000018 added the right scope).
	// On hit: short-circuit and return the cached row with a fresh
	// signed URL. The cache-miss path below is wrapped with a
	// unique-violation catch to handle the race between this lookup
	// and the INSERT.
	existing, err := s.queries.GetAudioUploadByIdempotency(ctx, db.GetAudioUploadByIdempotencyParams{
		IdempotencyKey: &req.IdempotencyKey,
		TherapistID:    therapistIDPg,
	})
	if err == nil {
		return s.cachedAudioUploadResponse(ctx, existing)
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
		// Race window: two concurrent requests with the same
		// idempotency_key both passed the pre-check (lines 56–82) and
		// reached this INSERT. Migration 000018 added
		// ux_audio_uploads_idempotency partial unique index on
		// (therapist_id, idempotency_key); the loser of the race hits
		// this branch. Re-fetch by key + return the winner's row, same
		// shape as the cache-hit response above.
		if cname := uniqueViolationConstraint(err); cname == "ux_audio_uploads_idempotency" {
			existing, gerr := s.queries.GetAudioUploadByIdempotency(ctx, db.GetAudioUploadByIdempotencyParams{
				IdempotencyKey: &req.IdempotencyKey,
				TherapistID:    therapistIDPg,
			})
			if gerr != nil {
				return nil, status.Errorf(codes.Internal, "idempotency race refetch: %v", gerr)
			}
			return s.cachedAudioUploadResponse(ctx, existing)
		}
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

// cachedAudioUploadResponse rebuilds the gRPC response for an
// already-existing audio_uploads row — used by both the cache-hit
// path (pre-check) and the cache-miss race path (post-INSERT unique
// violation). Same signed-URL regeneration: GCS signing is
// stateless, so the URL is fresh but the object_path is the cached
// one from the original create.
func (s *Server) cachedAudioUploadResponse(ctx context.Context, existing db.AudioUpload) (*ingestionv1.CreateAudioUploadResponse, error) {
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

// uniqueViolationConstraint returns the violated constraint's name
// for SQLSTATE 23505, or "" if err isn't a unique violation. Used by
// CreateAudioUpload to distinguish a (therapist_id, idempotency_key)
// race from any other unique-index trip (e.g. object_path).
func uniqueViolationConstraint(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
		return pgErr.ConstraintName
	}
	return ""
}

func (s *Server) CompleteAudioUpload(ctx context.Context, req *ingestionv1.CompleteAudioUploadRequest) (*ingestionv1.CompleteAudioUploadResponse, error) {
	uploadID, err := uuid.Parse(req.UploadId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid upload_id")
	}

	uploadIDPg := pgtype.UUID{Bytes: uploadID, Valid: true}

	// Codec gate (added 2026-05-20). Fetch the row first so we can
	// reject M4A / AAC / MP3 / WMA / any non-Chirp-supported codec
	// BEFORE flipping status to UPLOADED. Without this gate, an
	// M4A upload whose client forgot to call ConvertAudio would
	// propagate to stt-worker, where Chirp would reject it and
	// the Pub/Sub retry policy would burn 6× cold starts before
	// the DLQ catches it.
	//
	// Failure mode this guards against: client uploads M4A, network
	// hiccups between PUT and ConvertAudio, client retries from
	// CompleteAudioUpload and skips the convert step. The server
	// catches it synchronously and tells the client what to do.
	//
	// Why FailedPrecondition (and not InvalidArgument): the request
	// itself is fine — the problem is the server-side state of
	// the audio_uploads row (codec not yet converted). gRPC code
	// FailedPrecondition matches that semantic exactly.
	preCheck, err := s.queries.GetAudioUpload(ctx, uploadIDPg)
	if err != nil {
		return nil, status.Error(codes.NotFound, "audio upload not found")
	}
	if !storage.IsChirpSupported(preCheck.ContentType) {
		return nil, status.Errorf(codes.FailedPrecondition,
			"audio_uploads.content_type=%q is not Chirp-supported; "+
				"call IngestionService.ConvertAudio with audio_upload_id=%s "+
				"before CompleteAudioUpload",
			preCheck.ContentType, req.UploadId)
	}

	upload, err := s.queries.CompleteAudioUpload(ctx, db.CompleteAudioUploadParams{
		ID:              uploadIDPg,
		DurationSeconds: &req.ActualDurationSeconds,
		FileSizeBytes:   &req.ActualSizeBytes,
		ChunkCount:      req.ChunkCount,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// Stage 2 of feat/stt-long_audio_support: when the duration
	// exceeds Chirp 3's word-timestamp limit, internally invoke
	// ConvertAudio with chunk_for_chirp=true to split the FLAC
	// into ≤ 19-min segments. stt-submit will fan out
	// BatchRecognize per chunk.
	//
	// We call the handler through s.ConvertAudio (same code path,
	// in-process) rather than the client SDK — no network hop,
	// shares the same SA + DB pool.
	const longAudioThresholdSec = 1140
	if req.ActualDurationSeconds > longAudioThresholdSec && s.converter != nil {
		slog.Info("complete_audio_upload: triggering chunking",
			"upload_id", req.UploadId,
			"duration_sec", req.ActualDurationSeconds)
		if _, err := s.ConvertAudio(ctx, &ingestionv1.ConvertAudioRequest{
			AudioUploadId:         req.UploadId,
			ChunkForChirp:         true,
			MaxChunkSeconds:       longAudioThresholdSec,
			SourceDurationSeconds: req.ActualDurationSeconds,
		}); err != nil {
			// Chunking failed — fail the whole CompleteAudioUpload
			// rather than ship a session that stt-worker can't process.
			// The client sees a clean failure; the audio_uploads row
			// is already marked UPLOADED (the CompleteAudioUpload SQL
			// above committed) so they can retry CompleteAudioUpload
			// and trigger a fresh chunking attempt.
			slog.Error("complete_audio_upload: chunking failed",
				"upload_id", req.UploadId, "error", err)
			return nil, err
		}
	}

	// Auto-create session
	nextNumber, err := s.queries.GetNextSessionNumber(ctx, upload.PatientFileID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
    
	nextNum := nextNumber

    t := time.Now()
	datePg := pgtype.Date{Time: t, Valid: true}

	// Single round-trip: pull the modality display_name (for the
	// default session.name) AND the patient_user's ui_language (for
	// session.language_code that stt-worker reads, AND the
	// report_language fallback below). Both columns degrade to ""
	// on join misses; the InsertSession SQL NULLIFs each so a
	// missing modality or orphan patient_files row stores NULL and
	// downstream falls back appropriately.
	defaults, lookupErr := s.queries.GetSessionDefaultsForPatientFile(ctx, upload.PatientFileID)
	var defaultName string
	if lookupErr == nil && defaults.DisplayName != "" {
		defaultName = fmt.Sprintf("%s %d", defaults.DisplayName, nextNum)
	}
	// BCP47-ize the patient's ui_language for STT (Chirp wants pl-PL,
	// not pl). Empty → BCP47ize returns "" → SQL NULLIF stores NULL →
	// stt-worker falls back to its multi-language auto-detect list.
	audioLang := ""
	if lookupErr == nil {
		audioLang = lang.BCP47ize(defaults.PatientLanguage)
	}
	// report_language resolution — three-tier fallback so an English
	// patient's report doesn't silently come out in Polish (the bug
	// surfaced 2026-05-15 on session 7da68e6c):
	//   1. explicit req.ReportLanguage (Flutter passes it for sessions
	//      where therapist wants a different output language than the
	//      patient speaks)
	//   2. patient_user.ui_language from the JOIN above (mirrors the
	//      STT side — if patient's audio is en-US, default the report
	//      to English unless overridden)
	//   3. "pl" hardcoded fallback for orphan rows / pre-feat sessions
	//      where neither source is available
	reportLang := req.ReportLanguage
	if reportLang == "" && lookupErr == nil {
		reportLang = defaults.PatientLanguage
	}
	if reportLang == "" {
		reportLang = "pl"
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
		LanguageCode:    audioLang,
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

// ConvertAudio transcodes the GCS object backing an audio_uploads row
// to a Chirp 3-supported codec (FLAC 16 kHz mono by default). Fallback
// path for clients that can't transcode on-device — iPhone Voice
// Memos delivered via the file-picker land here when AVAudioFile's
// client-side conversion path can't decode the source.
//
// Idempotency: re-callable. When audio_uploads.content_type is already
// in a Chirp-supported codec we return OK with converted=false and
// don't touch the GCS object. The caller (Flutter app) is expected to
// hit this RPC at most once per upload — but a network retry won't
// break anything.
//
// Status transitions: this RPC NEVER advances the upload's status.
// Conversion runs in the PENDING window between PUT-to-signed-URL and
// CompleteAudioUpload. If CompleteAudioUpload races ahead (it
// shouldn't — the Flutter client awaits the ConvertAudio response
// first), the converted object_path is still consistent because the
// row is updated atomically here.
func (s *Server) ConvertAudio(ctx context.Context, req *ingestionv1.ConvertAudioRequest) (*ingestionv1.ConvertAudioResponse, error) {
	if s.converter == nil {
		// Defensive: in tests / local dev we may wire the server
		// without a converter. Surface as Unimplemented so the
		// Flutter app can degrade gracefully (the M4A upload will
		// fail downstream at Chirp, but the error is recognizable).
		return nil, status.Error(codes.Unimplemented, "audio conversion not configured")
	}

	uploadID, err := uuid.Parse(req.AudioUploadId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid audio_upload_id")
	}
	uploadIDPg := pgtype.UUID{Bytes: uploadID, Valid: true}

	upload, err := s.queries.GetAudioUpload(ctx, uploadIDPg)
	if err != nil {
		// Don't distinguish 404 vs internal here — the audio_uploads
		// pkey is UUID, no soft-delete column, so any error here is
		// effectively "not found" from the caller's POV.
		return nil, status.Error(codes.NotFound, "audio upload not found")
	}

	// Idempotent no-op for the codec normalization step when the
	// source is already Chirp-supported. We still fall through to
	// the chunking branch below if the caller asked for it — long
	// FLAC uploads need chunking even though no transcode is needed.
	skipTranscode := storage.IsChirpSupported(upload.ContentType)
	if skipTranscode && !req.ChunkForChirp {
		return &ingestionv1.ConvertAudioResponse{
			ContentType: upload.ContentType,
			ObjectPath:  upload.ObjectPath,
			Converted:   false,
		}, nil
	}

	target := req.TargetContentType
	if target == "" {
		target = "audio/flac"
	}
	target = strings.ToLower(target)
	if !storage.IsValidTargetFormat(target) {
		return nil, status.Errorf(codes.InvalidArgument,
			"unsupported target_content_type: %s", target)
	}

	// Transcode path. Only runs when the source codec needs
	// normalization (M4A / AAC / etc.). FLAC sources skip directly
	// to the chunking branch with `updated` synthesized below.
	var updated db.AudioUpload
	if skipTranscode {
		// Source is already Chirp-supported (typically FLAC).
		// `updated` is the existing audio_uploads row — no DB write
		// needed, but we still need its fields for the chunking
		// branch downstream.
		updated = upload
		slog.Info("convert_audio: skipping transcode (codec already supported)",
			"upload_id", req.AudioUploadId,
			"content_type", upload.ContentType,
		)
	} else {
		// Transcode on disk. Bound by the gRPC deadline — Cloud Run's
		// per-request timeout must be ≥ 300s. The converter streams
		// into ffmpeg, so RSS stays bounded at ~150 MB.
		slog.Info("convert_audio: starting",
			"upload_id", req.AudioUploadId,
			"src_object", upload.ObjectPath,
			"src_content_type", upload.ContentType,
			"target", target,
		)
		t0 := time.Now()
		result, err := s.converter.Convert(
			ctx,
			upload.BucketName,
			upload.ObjectPath,
			upload.ContentType,
			target,
		)
		if err != nil {
			slog.Error("convert_audio: ffmpeg failed",
				"upload_id", req.AudioUploadId,
				"error", err,
			)
			return nil, status.Errorf(codes.InvalidArgument,
				"transcode failed: %v", err)
		}
		slog.Info("convert_audio: ffmpeg done",
			"upload_id", req.AudioUploadId,
			"new_object", result.ObjectPath,
			"new_content_type", result.ContentType,
			"duration_ms", time.Since(t0).Milliseconds(),
		)

		updated, err = s.queries.UpdateAudioUploadAfterConversion(
			ctx,
			db.UpdateAudioUploadAfterConversionParams{
				ID:          uploadIDPg,
				ObjectPath:  result.ObjectPath,
				ContentType: result.ContentType,
				BucketName:  result.BucketName,
			},
		)
		if err != nil {
			slog.Error("convert_audio: db update failed after gcs success",
				"upload_id", req.AudioUploadId,
				"new_object", result.ObjectPath,
				"error", err,
			)
			return nil, status.Errorf(codes.Internal,
				"db update after conversion: %v", err)
		}

		slog.Info("convert_audio: done",
			"upload_id", req.AudioUploadId,
			"src_ext", filepath.Ext(upload.ObjectPath),
			"dst_ext", filepath.Ext(updated.ObjectPath),
			"src_content_type", upload.ContentType,
			"dst_content_type", updated.ContentType,
		)
	}

	// Stage 2 chunking branch (feat/stt-long_audio_support). When the
	// caller asked for chunking AND the source exceeds the
	// max_chunk_seconds threshold, run ffmpeg silencedetect, split the
	// (now-converted) FLAC into N pieces, write one audio_chunks row
	// per piece. stt-submit will fan out N BatchRecognize calls.
	chunkCount, err := s.maybeChunkForChirp(ctx, req, updated, uploadIDPg)
	if err != nil {
		return nil, err
	}

	return &ingestionv1.ConvertAudioResponse{
		ContentType: updated.ContentType,
		ObjectPath:  updated.ObjectPath,
		Converted:   !skipTranscode,
		ChunkCount:  int32(chunkCount),
	}, nil
}

// maybeChunkForChirp is the Stage 2 chunking branch of ConvertAudio.
// Called after the codec normalization step has settled. Short-
// circuits when:
//   - req.ChunkForChirp = false (Stage 1 single-output path)
//   - source duration ≤ max_chunk_seconds (no chunking needed)
//   - audio_chunks already exist for this upload AND the count
//     matches the expected fan-out (idempotent retry — earlier
//     attempt landed all chunks; caller is just re-querying)
//
// Otherwise:
//   1. Acquire pg_advisory_xact_lock on audio_upload_id to
//      serialize concurrent ConvertAudio calls.
//   2. Re-check audio_chunks state inside the lock (avoid double-
//      work).
//   3. If partial state exists, delete and start fresh — GCS
//      objects from the partial attempt are left to OLM 48h.
//   4. Call converter.ChunkForChirp.
//   5. INSERT one row per chunk.
//
// Returns the number of audio_chunks rows produced (0 when no
// chunking was needed).
func (s *Server) maybeChunkForChirp(
	ctx context.Context,
	req *ingestionv1.ConvertAudioRequest,
	upload db.AudioUpload,
	uploadIDPg pgtype.UUID,
) (int, error) {
	if !req.ChunkForChirp {
		return 0, nil
	}
	if req.SourceDurationSeconds <= 0 {
		return 0, status.Error(codes.InvalidArgument,
			"chunk_for_chirp=true requires source_duration_seconds > 0")
	}

	maxSec := int(req.MaxChunkSeconds)
	// 19 min default (with safety margin under Chirp 3's 20-min word-
	// timestamp limit). ChunkForChirp clamps to its own hard cap.
	if maxSec <= 0 {
		maxSec = 1140
	}

	// Short audio — skip without touching the DB.
	if int(req.SourceDurationSeconds) <= maxSec {
		return 0, nil
	}

	// Serialize concurrent ConvertAudio calls for this upload. The
	// hash of audio_upload_id is a non-blocking integer key for
	// pg_advisory_xact_lock. Lock auto-releases at transaction end
	// — we wrap the whole chunking + INSERT in one tx.
	tx, err := s.pgxBegin(ctx)
	if err != nil {
		return 0, status.Errorf(codes.Internal, "begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	uploadIDStr := uuid.UUID(uploadIDPg.Bytes).String()
	if _, err := tx.Exec(ctx,
		`SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`,
		uploadIDStr,
	); err != nil {
		return 0, status.Errorf(codes.Internal, "advisory lock: %v", err)
	}

	// Inside the lock: re-check current audio_chunks state.
	txq := s.queries.WithTx(tx)
	existing, err := txq.CountAudioChunksByUpload(ctx, uploadIDPg)
	if err != nil {
		return 0, status.Errorf(codes.Internal, "count chunks: %v", err)
	}
	if existing > 0 {
		// Idempotency: earlier attempt either fully or partially
		// landed chunks. We can't cheaply verify GCS object presence
		// here. Safe choice: trust the row count. If a partial set
		// exists, delete and redo — better to spend ffmpeg cycles
		// than to ship a split with missing chunks.
		//
		// But: if the existing count is exactly the expected one for
		// this source duration, the previous attempt completed and
		// this is a benign retry. Recompute expected count and
		// compare.
		expectedN := int64((int(req.SourceDurationSeconds) + maxSec - 1) / maxSec)
		if existing == expectedN {
			if err := tx.Commit(ctx); err != nil {
				return 0, status.Errorf(codes.Internal, "commit (idempotent path): %v", err)
			}
			return int(existing), nil
		}
		// Partial state — wipe and redo.
		if err := txq.DeleteAudioChunksByUpload(ctx, uploadIDPg); err != nil {
			return 0, status.Errorf(codes.Internal, "delete partial chunks: %v", err)
		}
	}

	chunks, err := s.converter.ChunkForChirp(
		ctx,
		upload.BucketName,
		upload.ObjectPath,
		int(req.SourceDurationSeconds),
		maxSec,
	)
	if err != nil {
		// ffmpeg or upload failure. The caller (CompleteAudioUpload)
		// will see this and fail the session before publishing
		// audio.uploaded — no orphan audio_uploads.status flip.
		slog.Error("convert_audio: chunking failed",
			"upload_id", req.AudioUploadId, "error", err)
		return 0, status.Errorf(codes.Internal, "chunk_for_chirp: %v", err)
	}

	for _, ch := range chunks {
		if err := txq.CreateAudioChunk(ctx, db.CreateAudioChunkParams{
			AudioUploadID: uploadIDPg,
			ChunkIndex:    int32(ch.ChunkIndex),
			BucketName:    ch.BucketName,
			ObjectPath:    ch.ObjectPath,
			StartOffsetMs: ch.StartOffsetMS,
			SeamOffsetMs:  ch.SeamOffsetMS,
			EndOffsetMs:   ch.EndOffsetMS,
			OverlapMs:     int32(ch.OverlapMS),
			CutOnSilence:  ch.CutOnSilence,
		}); err != nil {
			return 0, status.Errorf(codes.Internal, "insert chunk row: %v", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, status.Errorf(codes.Internal, "commit chunks: %v", err)
	}

	slog.Info("convert_audio: chunked",
		"upload_id", req.AudioUploadId,
		"chunk_count", len(chunks),
		"source_duration_sec", req.SourceDurationSeconds,
		"max_chunk_sec", maxSec,
	)
	return len(chunks), nil
}
