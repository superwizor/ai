package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
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

		// 2. Resolve segments.
		//
		// Fast path: read the canonical transcript_ciphertext blob (one
		// KMS decrypt for the whole transcript) when it carries
		// speaker roles. llm-worker.rebuildBlobWithRoles writes that
		// post-role-assignment shape; labels.go::UpdateSpeakerLabels
		// (therapist relabel) also writes it. The earlier attempt to
		// always read the blob broke diarization for pre-LLM-rebuild
		// transcripts (stt-worker writes the blob with null speaker_*
		// fields for the Polish / no-native-diarization path), so the
		// fast path is gated on tryCanonicalBlobSegments returning a
		// "blob has roles" success.
		//
		// Slow fallback: per-segment loop reads transcript_segments,
		// which is authoritatively post-LLM with roles populated.
		// Costs N KMS decrypts and will exceed the 30s gRPC deadline
		// for long sessions (~600+ chunks at ~80ms KMS RTT). Sessions
		// in that range need their blob backfilled (one-off) so the
		// fast path kicks in.
		if segs, ok := tryCanonicalBlobSegments(ctx, s.crypto, transcript); ok {
			protoTranscript.Segments = segs
			protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
		} else {
			segs, fatalErr := loadSegmentsViaPerSegmentLoop(ctx, s.queries, s.crypto, transcript.ID, req.SessionId)
			if fatalErr != nil {
				return nil, fatalErr
			}
			protoTranscript.Segments = segs
			protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
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

	// report_viewed_at (migration 000059): nullable timestamp. When the
	// therapist first opened the report. Drives the "nowy raport" badge
	// in Flutter — empty = unviewed.
	if s.ReportViewedAt.Valid {
		resp.ReportViewedAt = timestamppb.New(s.ReportViewedAt.Time)
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
		// Log it — a silent Internal here is what made "Tak, usuń do
		// nothing" undiagnosable. Most likely cause if it ever fires: a
		// new table referencing sessions(id) without ON DELETE CASCADE.
		slog.ErrorContext(ctx, "DeleteSession: hard delete failed",
			"session_id", sessionID, "therapist_id", therapistID, "error", err)
		return nil, status.Errorf(codes.Internal, "delete session: %v", err)
	}
	if rows == 0 {
		// Either the session never existed or belongs to another
		// therapist. Same 404 to avoid enumeration.
		slog.WarnContext(ctx, "DeleteSession: no row deleted (not found or not owned)",
			"session_id", sessionID, "therapist_id", therapistID)
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

// CancelSession marks an in-progress session as CANCELLED_BY_USER and
// releases any held billing reservation. The therapist triggers this
// from the "Wgrywanie" or "Bezpieczna analiza w toku" screens — e.g.
// when an upload is parked because the org ran out of tokens
// (QUOTA_EXHAUSTED) or they simply changed their mind.
//
// Semantics:
//   - Only non-terminal, pre-completion sessions are cancellable
//     (PENDING_UPLOAD … ANALYZING). A COMPLETED session is rejected with
//     FailedPrecondition — the therapist should DeleteSession instead.
//     A session already CANCELLED_BY_USER returns OK (idempotent — safe
//     to retry or double-tap the bin button).
//   - The held token reservation is released best-effort via
//     billing-svc.ReleaseCredit(reason=USER_CANCELED). A release failure
//     is logged but does NOT fail the cancel: the status flip is the
//     user-visible contract, and the reservation TTL-expires within ~4h
//     as a backstop.
//   - The row is KEPT (status=CANCELLED_BY_USER) for audit but hidden
//     from the kartoteka session list (see ListSessions). Distinct from
//     a hard DeleteSession (RODO erasure).
func (s *Server) CancelSession(ctx context.Context, req *clinicalv1.CancelSessionRequest) (*emptypb.Empty, error) {
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

	sess, err := s.queries.GetSession(ctx, sessionID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "session not found")
		}
		return nil, status.Errorf(codes.Internal, "load session: %v", err)
	}
	// Authz: same 404 whether the session is missing or owned by another
	// therapist, to avoid id enumeration.
	if sess.TherapistID != therapistID {
		return nil, status.Error(codes.NotFound, "session not found")
	}

	switch sess.Status {
	case db.SessionStatusCANCELLEDBYUSER:
		// Idempotent: already cancelled (and already released). No-op.
		return &emptypb.Empty{}, nil
	case db.SessionStatusCOMPLETED:
		return nil, status.Error(codes.FailedPrecondition,
			"session already completed; delete it instead of cancelling")
	}

	// Flip the status. UpdateSessionStatus is keyed by id; ownership was
	// verified above.
	if err := s.queries.UpdateSessionStatus(ctx, db.UpdateSessionStatusParams{
		ID:     sessionID,
		Status: db.SessionStatusCANCELLEDBYUSER,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "cancel session: %v", err)
	}

	// Mirror the cancellation to Firestore via session.status_changed
	// (docs/21) so a session_status_screen still watching this session
	// reflects the terminal state. Best-effort.
	if s.pubsub != nil {
		if perr := s.pubsub.PublishSessionStatusChanged(ctx, sessionID.String(), "cancelled"); perr != nil {
			slog.Warn("cancel session: publish session.status_changed(cancelled) failed",
				"session_id", sessionID, "error", perr)
		}
	}

	// Best-effort release of the held token reservation. Logged on
	// failure; never unwinds the cancel (the status flip is the
	// contract, and the reservation TTL-expires as a backstop).
	if s.billing != nil {
		orgID, oerr := s.queries.GetUserOrganizationID(ctx, therapistID)
		if oerr != nil || !orgID.Valid {
			slog.Warn("cancel session: resolve org for credit release failed",
				"session_id", sessionID, "error", oerr)
		} else {
			orgStr := uuid.UUID(orgID.Bytes).String()
			if _, rerr := s.billing.ReleaseCredit(ctx, &billingv1.ReleaseCreditRequest{
				SessionId:      sessionID.String(),
				OrganizationId: orgStr,
				Reason:         "USER_CANCELED",
			}); rerr != nil {
				slog.Warn("cancel session: release credit failed",
					"session_id", sessionID, "org_id", orgStr, "error", rerr)
			}
		}
	}

	slog.Info("session cancelled by user",
		"session_id", sessionID, "therapist_id", therapistID,
		"prior_status", string(sess.Status))
	return &emptypb.Empty{}, nil
}

// transcriptBlobLine matches the on-disk JSON shape stt-worker writes to
// transcripts.transcript_ciphertext (services/ai-pipeline-svc/cmd/
// stt-worker/main.go::BlobLine) and the shape llm-worker rewrites in
// rebuildBlobWithRoles after speaker-label assignment. SpeakerTag /
// SpeakerLabel are pointers so we can tell "no role assigned to this
// chunk" (nil) from "explicit zero / empty" (which doesn't happen in
// practice but stays unambiguous).
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

// cryptoBoxIface is the narrow surface of cryptobox.CryptoBox the
// transcript reader uses; matches the existing s.crypto interface
// without pulling its import here.
type cryptoBoxIface interface {
	Decrypt(ctx context.Context, ciphertext, encryptedDEK []byte) ([]byte, error)
}

// tryCanonicalBlobSegments returns (segments, true) only when the blob
// is a "post-roles" snapshot — at least one line carries a populated
// speaker_label. That's the marker llm-worker.rebuildBlobWithRoles (and
// labels.go::UpdateSpeakerLabels) leave behind once roles have been
// assigned; the raw stt-worker write leaves speaker_label nil/empty for
// pl-PL sessions and we DO NOT want to use the blob in that case (it
// would strip diarization).
//
// Returns (nil, false) on any decrypt / parse error, on empty blob, or
// when no line carries a role — caller falls back to the per-segment
// loop. Errors are logged but not surfaced as gRPC errors because the
// fallback is correct.
//
// Cost: 1 KMS decrypt + 1 JSON unmarshal, independent of session length.
func tryCanonicalBlobSegments(ctx context.Context, crypto cryptoBoxIface, transcript db.Transcript) ([]*clinicalv1.TranscriptSegment, bool) {
	if len(transcript.TranscriptCiphertext) == 0 {
		return nil, false
	}
	blobJSON, err := crypto.Decrypt(ctx, transcript.TranscriptCiphertext, transcript.TranscriptEncryptedDek)
	if err != nil {
		slog.Warn("canonical blob decrypt failed; falling back to per-segment",
			"transcript_id", transcript.ID.String(), "error", err)
		return nil, false
	}
	var lines []transcriptBlobLine
	if err := json.Unmarshal(blobJSON, &lines); err != nil {
		slog.Warn("canonical blob unmarshal failed; falling back to per-segment",
			"transcript_id", transcript.ID.String(), "error", err)
		return nil, false
	}

	// Strict marker: at least one line must carry a non-empty speaker
	// label. Pre-llm-worker blobs have all speaker_* fields nil for
	// pl-PL sessions, and we must not pretend they have diarization.
	hasRoles := false
	for _, l := range lines {
		if l.SpeakerLabel != nil && *l.SpeakerLabel != "" {
			hasRoles = true
			break
		}
	}
	if !hasRoles {
		return nil, false
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
	return out, true
}

// loadSegmentsViaPerSegmentLoop is the historical slow path — reads
// transcript_segments and KMS-decrypts each text. Costs N KMS calls
// (~80-200ms each), so long sessions will exceed the gRPC deadline.
// Returns a non-nil fatal error only when the transcript has segments
// but every single decrypt failed (almost certainly a KMS misconfig);
// otherwise returns whatever it could decrypt + nil.
func loadSegmentsViaPerSegmentLoop(ctx context.Context, queries db.Querier, crypto cryptoBoxIface, transcriptID uuid.UUID, sessionIDStr string) ([]*clinicalv1.TranscriptSegment, error) {
	segments, err := queries.ListTranscriptSegments(ctx, transcriptID)
	if err != nil {
		return nil, nil
	}
	var segDecryptErrs int
	out := make([]*clinicalv1.TranscriptSegment, 0, len(segments))
	for _, seg := range segments {
		textBytes, derr := crypto.Decrypt(ctx, seg.TextCiphertext, seg.TextEncryptedDek)
		if derr != nil {
			segDecryptErrs++
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
		out = append(out, &clinicalv1.TranscriptSegment{
			SpeakerTag:    seg.SpeakerTag,
			SpeakerLabel:  seg.SpeakerLabel,
			StartOffsetMs: seg.StartOffsetMs,
			EndOffsetMs:   seg.EndOffsetMs,
			Text:          string(textBytes),
			Confidence:    conf,
		})
	}
	if len(segments) > 0 && len(out) == 0 {
		slog.Error("all transcript segments failed to decrypt — likely KMS misconfig",
			"session_id", sessionIDStr,
			"transcript_id", transcriptID.String(),
			"segment_count", len(segments),
			"decrypt_errors", segDecryptErrs)
		return nil, status.Error(codes.Internal,
			"transcript present but no segments could be decrypted; check clinical-svc KMS config")
	}
	return out, nil
}

// MarkReportViewed sets report_viewed_at on a COMPLETED session.
// Idempotent — re-calling on an already-viewed session is a no-op
// (COALESCE in the SQL preserves the first-view timestamp). The status
// filter means calling on a non-completed session silently does nothing.
//
// Authz: therapist_id from JWT context must own the session (SQL filter).
func (s *Server) MarkReportViewed(ctx context.Context, req *clinicalv1.MarkReportViewedRequest) (*emptypb.Empty, error) {
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

	if err := s.queries.MarkReportViewed(ctx, db.MarkReportViewedParams{
		ID:          sessionID,
		TherapistID: therapistID,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "mark report viewed: %v", err)
	}

	return &emptypb.Empty{}, nil
}

// SetAvatarConfig sets or clears the avatar customization (label + color)
// on a patient file. Empty avatar_config clears to defaults.
//
// Authz: therapist_id from JWT context must own the patient file (SQL filter).
func (s *Server) SetAvatarConfig(ctx context.Context, req *clinicalv1.SetAvatarConfigRequest) (*emptypb.Empty, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}

	patientFileID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	if err := s.queries.SetAvatarConfig(ctx, db.SetAvatarConfigParams{
		AvatarConfig: req.AvatarConfig,
		ID:           patientFileID,
		TherapistID:  therapistID,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "set avatar config: %v", err)
	}

	return &emptypb.Empty{}, nil
}

