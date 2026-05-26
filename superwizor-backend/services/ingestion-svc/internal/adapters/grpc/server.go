package grpc

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
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

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	"github.com/superwizor-ai/backend/pkg/i18n/lang"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

// Server is the IngestionService gRPC server.
//
// Option F (feat/refactor-stt-architecture, 2026-05-25): the
// service now exposes only two RPCs — CreateAudioUpload (issue
// signed URL + create PENDING_UPLOAD session row) and
// GetAudioUploadStatus (debug helper). The legacy
// CompleteAudioUpload + ConvertAudio RPCs were deleted in this
// branch; the equivalent work is driven asynchronously by the
// in-process Pub/Sub subscriber in
// services/ingestion-svc/internal/adapters/pubsub/subscriber.go.
// See docs/15_HYBRID_EVENTARC_FINALIZATION.md.
//
// The `converter` field is still owned here (and accepted by
// NewServer) so the same constructor signature can be re-used by
// the subscriber wiring in cmd/server/main.go — keeping a single
// "service handle" struct around the queries + signer + converter
// + publisher quartet avoids duplicating wiring boilerplate.
// Server-side RPC methods no longer touch it.
type Server struct {
	ingestionv1.UnimplementedIngestionServiceServer
	queries    *db.Queries
	pool       *pgxpool.Pool // raw pool for advisory locks + ad-hoc tx
	signer     *storage.Signer
	converter  *storage.Converter // unused by RPCs post-Option F; kept for wiring symmetry
	bucketName string
	pubsub     PubsubPublisher // interface — concrete impl w main
	billing    billingv1.BillingServiceClient // optional, nil = skip reservation step
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

// WithBilling injects the billing-svc client; nil disables the reservation
// hook (server runs as if quota didn't exist — useful for local dev or for
// environments where billing-svc isn't reachable).
func (s *Server) WithBilling(b billingv1.BillingServiceClient) *Server {
	s.billing = b
	return s
}

// pgxBegin is a thin wrapper around s.pool.Begin used by
// CreateAudioUpload's session + audio_uploads INSERT tx. Kept as a
// method so test wiring (which may pass pool=nil) gets a clear
// error rather than a nil deref.
func (s *Server) pgxBegin(ctx context.Context) (pgx.Tx, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("pgxBegin: server has no pool (test wiring?)")
	}
	return s.pool.Begin(ctx)
}

func (s *Server) CreateAudioUpload(ctx context.Context, req *ingestionv1.CreateAudioUploadRequest) (*ingestionv1.CreateAudioUploadResponse, error) {
	// Option E (2026-05-25, see docs/14_INGESTION_EARLY_SESSION_CREATION.md):
	// session row is created at THIS RPC. Under the old flow the sessions
	// table didn't get a row until after ffprobe + chunking finished — 3-10
	// min for long audio. Therapists returned to the kartoteka before that
	// and saw an empty session list. Now the session exists from the moment
	// Flutter gets the signed URL, in PENDING_UPLOAD status.
	//
	// Option F (2026-05-25, feat/refactor-stt-architecture): the
	// PENDING_UPLOAD → CREATED flip is no longer driven by a follow-up
	// CompleteAudioUpload RPC. ingestion-svc's in-process subscriber
	// (subscriber.go) consumes the bucket's OBJECT_FINALIZE event and
	// finalizes the upload (probe duration, fallback transcode, chunk
	// if > 19 min, flip status, publish audio.uploaded). Flutter
	// terminates at phase=completed the moment its HTTP PUT returns 2xx.
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

	// Option E: session-defaults lookup + session creation now happen
	// here. Wrapped in a tx with the audio_uploads INSERT so a crash
	// between the two never leaves a half-created state.
	tx, err := s.pgxBegin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txq := s.queries.WithTx(tx)

	// Session number + modality display name + audio language.
	nextNumber, err := txq.GetNextSessionNumber(ctx, patientFileIDPg)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	defaults, lookupErr := txq.GetSessionDefaultsForPatientFile(ctx, patientFileIDPg)
	var defaultName string
	if lookupErr == nil && defaults.DisplayName != "" {
		defaultName = fmt.Sprintf("%s %d", defaults.DisplayName, nextNumber)
	}
	audioLang := ""
	if lookupErr == nil {
		audioLang = lang.BCP47ize(defaults.PatientLanguage)
	}
	reportLang := req.ReportLanguage
	if reportLang == "" && lookupErr == nil {
		reportLang = defaults.PatientLanguage
	}
	if reportLang == "" {
		reportLang = "pl"
	}
	t := time.Now()
	datePg := pgtype.Date{Time: t, Valid: true}
	// duration_seconds is not yet known — pass nil; the subscriber
	// will overwrite once ffprobe has run on the uploaded object.
	session, err := txq.CreateSessionPendingUpload(ctx, db.CreateSessionPendingUploadParams{
		TherapistID:     therapistIDPg,
		PatientFileID:   patientFileIDPg,
		SessionDate:     datePg,
		SessionNumber:   nextNumber,
		DurationSeconds: nil,
		ContactForm:     "OFFICE",
		ReportLanguage:  reportLang,
		NameDefault:     defaultName,
		LanguageCode:    audioLang,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "CreateSessionPendingUpload: %v", err)
	}

	// Object path uses session_id (Option E). subscriber.go parses
	// this path back into a session_id to drive finalize.
	sessionUUID := uuid.UUID(session.ID.Bytes)
	objectPath := fmt.Sprintf("%s/%s/%d%s",
		therapistID.String(),
		sessionUUID.String(),
		time.Now().Unix(),
		ext,
	)

	upload, err := txq.CreateAudioUpload(ctx, db.CreateAudioUploadParams{
		TherapistID:      therapistIDPg,
		PatientFileID:    patientFileIDPg,
		SessionID:        session.ID,
		BucketName:       s.bucketName,
		ObjectPath:       objectPath,
		ContentType:      req.ContentType,
		IdempotencyKey:   &req.IdempotencyKey,
		ClientAppVersion: &req.ClientAppVersion,
		ClientPlatform:   &req.ClientPlatform,
	})
	if err != nil {
		if cname := uniqueViolationConstraint(err); cname == "ux_audio_uploads_idempotency" {
			// Roll back the session INSERT — race winner already
			// owns one. Re-fetch and respond from the winner's row.
			_ = tx.Rollback(ctx)
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

	// Close the circular link sessions.audio_upload_id →
	// audio_uploads.id now that the audio_uploads row exists. The
	// partial UNIQUE INDEX from migration 000024 (added by Fix 1)
	// enforces 1:1 on the session side.
	if err := txq.SetSessionAudioUploadID(ctx, db.SetSessionAudioUploadIDParams{
		ID:            session.ID,
		AudioUploadID: upload.ID,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "SetSessionAudioUploadID: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit CreateAudioUpload tx: %v", err)
	}

	// Billing hook (synchronous): reserve 1 token on billing-svc.
	//
	// Hard-block on QUOTA_EXHAUSTED — propagate the ResourceExhausted code
	// to the Flutter client so it shows QuotaExhaustedDialog and stops the
	// upload. Other errors (transient billing-svc network blip, missing
	// org, subscription past-due) stay fail-soft so a billing flake doesn't
	// reject legitimate uploads. See the function comment for the precise
	// error taxonomy.
	//
	// Note: at this point the session + audio_upload rows are already
	// committed in our tx (above). On QUOTA_EXHAUSTED the client never
	// PUTs the audio object to GCS, so the upload row sits empty and
	// expires via audio_uploads.expires_at TTL. Cheaper than an extra
	// CheckQuota upfront and tolerates the race where another concurrent
	// upload consumes the last token between check and reserve.
	if s.billing != nil {
		if err := s.reserveCreditOrBlock(ctx, sessionUUID, therapistIDPg); err != nil {
			return nil, err
		}
	}

	signedURL, expires, err := s.signer.GenerateUploadURL(
		ctx, objectPath, req.ContentType, req.EstimatedSizeBytes,
	)
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
		SessionId: sessionUUID.String(),
	}, nil
}

// cachedAudioUploadResponse rebuilds the gRPC response for an
// already-existing audio_uploads row — used by both the cache-hit
// path (pre-check) and the cache-miss race path (post-INSERT unique
// violation). Same signed-URL regeneration: GCS signing is
// stateless, so the URL is fresh but the object_path is the cached
// one from the original create.
func (s *Server) cachedAudioUploadResponse(ctx context.Context, existing db.AudioUpload) (*ingestionv1.CreateAudioUploadResponse, error) {
	// On idempotent retry we don't have the request's
	// estimated_size_bytes anymore — use the audio_uploads row's
	// actual file_size_bytes if known (post-PUT retry), else 0
	// which falls back to the default 30 min TTL.
	var estSize int64
	if existing.FileSizeBytes != nil {
		estSize = *existing.FileSizeBytes
	}
	signedURL, expires, err := s.signer.GenerateUploadURL(
		ctx, existing.ObjectPath, existing.ContentType, estSize,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	var existingID uuid.UUID
	if existing.ID.Valid {
		existingID = existing.ID.Bytes
	}
	var sessionIDStr string
	if existing.SessionID.Valid {
		sessionIDStr = uuid.UUID(existing.SessionID.Bytes).String()
	}
	return &ingestionv1.CreateAudioUploadResponse{
		UploadId:           existingID.String(),
		SignedUrl:          signedURL,
		SignedUrlExpiresAt: timestamppb.New(expires),
		ObjectPath:         existing.ObjectPath,
		RequiredHeaders: map[string]string{
			"x-goog-meta-source": "superwizor-mobile",
		},
		SessionId: sessionIDStr,
	}, nil
}

// uniqueViolationConstraint returns the violated constraint's name
// for SQLSTATE 23505, or "" if err isn't a unique violation.
func uniqueViolationConstraint(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
		return pgErr.ConstraintName
	}
	return ""
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

// reserveCreditOrBlock — synchronous billing reservation called inline by
// CreateAudioUpload. Returns:
//
//   - nil on success (1 token reserved, normal path) — caller proceeds.
//   - nil on a non-fatal billing error (lookup failure, missing org,
//     transient billing-svc unavailability, etc.) — fail-soft preserved
//     so a billing flake doesn't reject legitimate uploads.
//   - codes.ResourceExhausted on QUOTA_EXHAUSTED — caller MUST propagate
//     this to the Flutter client. Flutter renders QuotaExhaustedDialog
//     and aborts the upload; the orphan sessions+audio_uploads rows
//     created in the tx above expire on their own (audio_uploads
//     expires_at, default 30 min). No GCS object is uploaded.
//
// Other billing-side errors that should also be hard-blocks (in theory):
// FailedPrecondition for SUBSCRIPTION_PAST_DUE or SUBSCRIPTION_INACTIVE
// — both indicate the org cannot record sessions. We propagate those too
// since the Flutter UI already handles them via the same dialog path.
//
// session_id is the idempotency_key so a retried CreateAudioUpload (same
// idempotency_key on our side → cached response path) won't double-reserve.
func (s *Server) reserveCreditOrBlock(ctx context.Context, sessionUUID uuid.UUID, therapistIDPg pgtype.UUID) error {
	// Independent timeout so a slow billing-svc doesn't compound any
	// upstream deadline pressure on the caller's ctx.
	rctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	orgIDPg, err := s.queries.GetUserOrganizationID(rctx, therapistIDPg)
	if err != nil {
		slog.WarnContext(rctx, "billing reserve: lookup org failed (fail-soft)",
			"session_id", sessionUUID, "therapist_id", therapistIDPg, "error", err)
		return nil
	}
	if !orgIDPg.Valid {
		slog.InfoContext(rctx, "billing reserve: user has no org (skipping)",
			"session_id", sessionUUID, "therapist_id", therapistIDPg)
		return nil
	}

	therapistIDStr := ""
	if therapistIDPg.Valid {
		therapistIDStr = uuid.UUID(therapistIDPg.Bytes).String()
	}
	orgIDStr := uuid.UUID(orgIDPg.Bytes).String()

	_, err = s.billing.ReserveCredit(rctx, &billingv1.ReserveCreditRequest{
		SessionId:       sessionUUID.String(),
		OrganizationId:  orgIDStr,
		TherapistId:     therapistIDStr,
		EstimatedTokens: 1,
		IdempotencyKey:  "ingestion-reserve-" + sessionUUID.String(),
	})
	if err != nil {
		code := status.Code(err)
		switch code {
		case codes.ResourceExhausted:
			// QUOTA_EXHAUSTED. Hard-block. The Flutter client surfaces
			// this via QuotaExhaustedDialog (existing UI).
			slog.WarnContext(rctx, "billing reserve: QUOTA_EXHAUSTED — blocking upload",
				"session_id", sessionUUID, "organization_id", orgIDStr)
			return status.Error(codes.ResourceExhausted, "QUOTA_EXHAUSTED")
		case codes.FailedPrecondition:
			// SUBSCRIPTION_PAST_DUE / SUBSCRIPTION_INACTIVE / QUOTA_COUNTER_MISSING.
			// Same UX as quota exhausted from Flutter's POV — propagate.
			slog.WarnContext(rctx, "billing reserve: subscription precondition failed — blocking upload",
				"session_id", sessionUUID, "organization_id", orgIDStr, "error", err)
			return status.Error(codes.FailedPrecondition, err.Error())
		default:
			// Network blip, billing-svc timeout, internal error. Fail-soft
			// so transient billing problems don't reject uploads. The
			// session goes through; stt-finalize will attempt CommitUsage
			// at the end of the pipeline and a follow-up commit can
			// reconcile.
			slog.WarnContext(rctx, "billing reserve: ReserveCredit failed (fail-soft, non-quota)",
				"session_id", sessionUUID, "organization_id", orgIDStr, "error", err, "code", code.String())
			return nil
		}
	}
	slog.InfoContext(rctx, "billing reserve: 1 token reserved",
		"session_id", sessionUUID, "organization_id", orgIDStr)
	return nil
}
