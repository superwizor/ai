package sttworker

// deepgram_path.go — the Deepgram Nova-3 provider branch of ProcessAudio
// (docs/39_DEEPGRAM_STT_MIGRATION.md, Faza 1).
//
// Unlike the Chirp path (submit → GCS callback → stt-finalize), Deepgram's
// pre-recorded API is synchronous and stores nothing server-side: the HTTP
// response IS the transcript. So this branch claims the work, mints a
// short-lived signed GET URL for the audio, calls /v1/listen, and finishes
// the transcript inline via the same completeTranscript tail the Chirp
// merger uses. No MERGING status, no Eventarc, no transcripts-raw bucket.
//
// Failure semantics follow docs/21 exactly:
//   - Terminal (bad input/config): session FAILED, billing released, ack.
//   - Auth (key rotated/revoked): NACK + loud log; NEVER the session's
//     fault, so never FAILED.
//   - Transient: NACK → Pub/Sub retries; the claim-takeover guard below
//     dedupes concurrent attempts, and after dgMaxAttempts the session
//     fails over to the Chirp path (once) so a Deepgram outage degrades
//     to today's behavior instead of losing the recording.

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	gcs "cloud.google.com/go/storage"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/superwizor-ai/backend/pkg/i18n/lang"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/deepgram"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/sttgcs"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/transcriptfmt"
)

const (
	// sttModelDeepgram is stamped into transcripts.stt_model.
	sttModelDeepgram = "deepgram-nova-3"

	// dgInFlightTTL is how long a claimed-but-unfinished row blocks other
	// invocations. Must exceed the worst-case synchronous call (330 s
	// client timeout × 2 attempts ≈ 11 min) so a live attempt is never
	// hijacked mid-flight.
	dgInFlightTTL = 15 * time.Minute

	// dgMaxAttempts bounds Deepgram tries per session (initial + takeover
	// re-tries). The claim that would start attempt dgMaxAttempts+1
	// triggers the one-shot Chirp fallback instead.
	dgMaxAttempts = 3
)

// errDeepgramInFlight signals a redelivery raced a live attempt: NACK
// and let Pub/Sub redeliver after the in-flight TTL.
var errDeepgramInFlight = errors.New("deepgram attempt in flight; retry later")

// resolveSTTProvider picks the STT engine for a session (docs/39 §4):
//
//	STT_PROVIDER=deepgram            → deepgram for everyone (post-canary)
//	STT_PROVIDER unset/chirp +
//	  STT_PROVIDER_ALLOWLIST=<uuids> → deepgram when the session's
//	                                   therapist or org is listed (canary)
//	otherwise                        → chirp
//
// Any resolution failure falls back to chirp — the provider flag must
// never be the reason a session doesn't transcribe.
func resolveSTTProvider(ctx context.Context, sessionID string) string {
	if dgClient == nil {
		return "chirp" // no API key wired — flag is irrelevant
	}
	switch strings.ToLower(os.Getenv("STT_PROVIDER")) {
	case "deepgram":
		return "deepgram"
	case "", "chirp":
		// fall through to the allowlist canary
	default:
		slog.Warn("unknown STT_PROVIDER value; defaulting to chirp",
			"value", os.Getenv("STT_PROVIDER"))
		return "chirp"
	}

	allow := strings.TrimSpace(os.Getenv("STT_PROVIDER_ALLOWLIST"))
	if allow == "" || dbPool == nil {
		return "chirp"
	}
	listed := map[string]bool{}
	for _, id := range strings.Split(allow, ",") {
		if id = strings.TrimSpace(strings.ToLower(id)); id != "" {
			listed[id] = true
		}
	}

	var therapistID, orgID string
	err := dbPool.QueryRow(ctx, `
		SELECT s.therapist_id::text, COALESCE(u.organization_id::text, '')
		FROM sessions s JOIN users u ON u.id = s.therapist_id
		WHERE s.id = $1`, sessionID).Scan(&therapistID, &orgID)
	if err != nil {
		slog.Warn("provider allowlist lookup failed; defaulting to chirp",
			"session_id", sessionID, "error", err)
		return "chirp"
	}
	if listed[strings.ToLower(therapistID)] || (orgID != "" && listed[strings.ToLower(orgID)]) {
		return "deepgram"
	}
	return "chirp"
}

// deepgramLanguage maps the session's BCP47 tag onto Deepgram's short
// code ("pl-PL" → "pl"). Empty session language falls back to "pl" —
// the v1 product is Polish-only and Deepgram has no equivalent of
// Chirp's multi-language auto-detect list for this call shape.
func deepgramLanguage(bcp47 string) string {
	if bcp47 == "" {
		return "pl"
	}
	if i := strings.IndexByte(bcp47, '-'); i > 0 {
		return strings.ToLower(bcp47[:i])
	}
	return strings.ToLower(bcp47)
}

// processAudioDeepgram is the deepgram branch of ProcessAudio. The
// caller has already: validated the event, passed the poison guard,
// set sessions.status=TRANSCRIBING and resolved bcp47Lang.
func processAudioDeepgram(ctx context.Context, logger *slog.Logger, ev AudioUploadedEvent, sessionUUID uuid.UUID, bcp47Lang string) error {
	logger = logger.With("provider", "deepgram")
	sourceURI := fmt.Sprintf("gs://%s/%s", bucketName, ev.ObjectPath)

	claim, err := claimDeepgramOperation(ctx, sessionUUID, sourceURI, bcp47Lang)
	if err != nil {
		return err // transient DB → NACK
	}
	switch claim.state {
	case dgClaimAlreadyDone:
		logger.Info("deepgram row already finalized; ack")
		return nil
	case dgClaimForeignProvider:
		logger.Info("chunk rows owned by chirp; letting chirp machinery finish", "row_provider", claim.rowProvider)
		return nil
	case dgClaimInFlight:
		logger.Info("another deepgram attempt in flight; NACK for later redelivery")
		return errDeepgramInFlight
	case dgClaimExhausted:
		logger.Warn("deepgram attempts exhausted; failing over to chirp",
			"attempts", claim.attempt)
		return fallbackToChirp(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	}

	logger.Info("deepgram attempt claimed", "attempt", claim.attempt)

	signedURL, err := signAudioURL(ev.ObjectPath)
	if err != nil {
		// Signing is local/IAM — failures are transient (token blip) →
		// NACK. The claim row ages into takeover on the next delivery.
		logger.Error("signAudioURL failed", "error", err)
		return err
	}

	start := time.Now()
	res, err := dgClient.Transcribe(ctx, signedURL, deepgram.Params{
		Language: deepgramLanguage(bcp47Lang),
	})
	if err != nil {
		return handleDeepgramError(ctx, logger, sessionUUID, err)
	}
	_ = updateDeepgramRequestID(ctx, sessionUUID, res.RequestID)

	slog.InfoContext(ctx, "analytics",
		"ae", "stt.submitted",
		"session_id", sessionUUID.String(),
		"provider", "deepgram",
		"language_code", bcp47Lang,
		"native_diarization", res.SpeakerCount > 0,
		"chunk_count", 1,
		"dg_request_id", res.RequestID,
		"dg_transcribe_ms", time.Since(start).Milliseconds(),
	)
	if res.DroppedWords() > 0 {
		logger.Warn("dropped words with implausible timestamps",
			"dropped_words", res.DroppedWords(), "kept_words", res.WordCount)
	}
	logger.Info("deepgram transcription complete",
		"dg_request_id", res.RequestID,
		"word_count", res.WordCount,
		"speaker_count", res.SpeakerCount,
		"audio_duration_sec", res.AudioDurationSec,
		"transcribe_ms", time.Since(start).Milliseconds())

	tr := &TranscriptResult{
		Words:                res.Words,
		LanguageCode:         lang.BCP47ize(res.LanguageCode),
		WordCount:            res.WordCount,
		ConfidenceAvg:        res.ConfidenceAvg,
		HasNativeDiarization: res.SpeakerCount > 0,
		SpeakerCount:         res.SpeakerCount,
	}

	if err := completeTranscript(ctx, logger, sessionUUID, tr, sttModelDeepgram, start); err != nil {
		// completeTranscript failures are DB/KMS/pubsub — classify like
		// the merge path: terminal → FAILED+ack, transient → NACK (status
		// stays TRANSCRIBING; the claim row ages into takeover).
		if isTerminalSTTError(err) {
			return handleSTTError(ctx, logger, sessionUUID.String(), err)
		}
		logger.Error("completeTranscript transient failure; NACK", "error", err)
		return err
	}

	if _, err := markChunkFinalized(ctx, sessionUUID, 0); err != nil {
		// Transcript is durably persisted + published; only the ops row
		// stayed pending. fallbackToChirp's transcript-exists guard makes
		// the eventual watchdog touch a no-op, so just log.
		logger.Warn("markChunkFinalized failed post-persist (harmless; guarded downstream)", "error", err)
	}
	return nil
}

// handleDeepgramError applies the docs/21 failure semantics to a
// Transcribe error.
func handleDeepgramError(ctx context.Context, logger *slog.Logger, sessionUUID uuid.UUID, err error) error {
	switch deepgram.Classify(err) {
	case deepgram.Auth:
		// Credential rot — a platform incident, not a session failure.
		// Distinct log signature for alerting; NACK so the session waits
		// for the key fix (or the chirp fallback after dgMaxAttempts).
		logger.Error("deepgram_auth_error — API key rejected; session left in-progress",
			"error", err.Error())
		return err
	case deepgram.Terminal:
		recordFinalizeError(ctx, sessionUUID, 0, truncateOpError(err.Error()))
		_, _ = markChunkFinalized(ctx, sessionUUID, 0)
		return handleSTTError(ctx, logger, sessionUUID.String(), fmt.Errorf("deepgram: %w: %s", errTerminalSTT, err.Error()))
	default:
		logger.Warn("deepgram transient error; NACK for retry", "error", err.Error())
		return err
	}
}

// ── claim / takeover ────────────────────────────────────────────────

type dgClaimState int

const (
	dgClaimOwned dgClaimState = iota
	dgClaimInFlight
	dgClaimAlreadyDone
	dgClaimExhausted
	dgClaimForeignProvider
)

type dgClaim struct {
	state       dgClaimState
	attempt     int // 1-based attempt number when state == dgClaimOwned
	rowProvider string
}

// claimDeepgramOperation makes this invocation the exclusive owner of
// the session's Deepgram attempt, using the (session_id, chunk_index)
// UNIQUE row as the lock:
//
//	no row              → INSERT (attempt 1)
//	row finalized       → AlreadyDone
//	row owned by chirp  → ForeignProvider (mid-flight flag flip)
//	row fresh           → InFlight (live attempt elsewhere)
//	row stale           → takeover UPDATE (attempt N+1), unless the
//	                      budget is exhausted → Exhausted (fallback)
func claimDeepgramOperation(ctx context.Context, sessionUUID uuid.UUID, sourceURI, bcp47Lang string) (dgClaim, error) {
	if dbPool == nil {
		return dgClaim{state: dgClaimOwned, attempt: 1}, nil
	}

	tag, err := dbPool.Exec(ctx, `
		INSERT INTO stt_operations (
			session_id, chunk_index, chunk_count, start_offset_ms,
			operation_id, gcs_output_uri, language_code,
			used_native_diarization, source_audio_uri, provider
		) VALUES ($1, 0, 1, 0, 'deepgram:sync', '', $2, TRUE, $3, 'deepgram')
		ON CONFLICT (session_id, chunk_index) DO NOTHING`,
		sessionUUID, bcp47Lang, sourceURI)
	if err != nil {
		return dgClaim{}, fmt.Errorf("claim insert: %w", err)
	}
	if tag.RowsAffected() == 1 {
		return dgClaim{state: dgClaimOwned, attempt: 1}, nil
	}

	// Conflict — inspect the existing row.
	var (
		provider          string
		retryCount        int
		finalized         bool
		fallbackAttempted bool
		submittedAt       time.Time
	)
	err = dbPool.QueryRow(ctx, `
		SELECT provider, retry_count, finalized_at IS NOT NULL,
		       fallback_attempted, submitted_at
		FROM stt_operations
		WHERE session_id = $1 AND chunk_index = 0`,
		sessionUUID).Scan(&provider, &retryCount, &finalized, &fallbackAttempted, &submittedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Row vanished between INSERT-conflict and SELECT (session
			// deleted). Nothing to do.
			return dgClaim{state: dgClaimAlreadyDone}, nil
		}
		return dgClaim{}, fmt.Errorf("claim inspect: %w", err)
	}

	switch {
	case finalized:
		return dgClaim{state: dgClaimAlreadyDone}, nil
	case provider != "deepgram" || fallbackAttempted:
		return dgClaim{state: dgClaimForeignProvider, rowProvider: provider}, nil
	case time.Since(submittedAt) < dgInFlightTTL:
		return dgClaim{state: dgClaimInFlight}, nil
	case retryCount+1 >= dgMaxAttempts:
		return dgClaim{state: dgClaimExhausted, attempt: retryCount + 1}, nil
	}

	// Stale row — take it over. The WHERE re-checks staleness so two
	// concurrent takeovers can't both win.
	tag, err = dbPool.Exec(ctx, `
		UPDATE stt_operations
		SET submitted_at = now(), retry_count = retry_count + 1
		WHERE session_id = $1 AND chunk_index = 0
		  AND provider = 'deepgram' AND finalized_at IS NULL
		  AND submitted_at < now() - make_interval(secs => $2)`,
		sessionUUID, int(dgInFlightTTL.Seconds()))
	if err != nil {
		return dgClaim{}, fmt.Errorf("claim takeover: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return dgClaim{state: dgClaimInFlight}, nil // lost the takeover race
	}
	return dgClaim{state: dgClaimOwned, attempt: retryCount + 2}, nil
}

func updateDeepgramRequestID(ctx context.Context, sessionUUID uuid.UUID, requestID string) error {
	if dbPool == nil || requestID == "" {
		return nil
	}
	_, err := dbPool.Exec(ctx, `
		UPDATE stt_operations SET request_id = $2
		WHERE session_id = $1 AND chunk_index = 0 AND provider = 'deepgram'`,
		sessionUUID, requestID)
	return err
}

// signAudioURL mints a V4-signed GET URL for the session's audio object.
// TTL matches dgInFlightTTL: long enough for Deepgram to fetch + process,
// short enough to be useless if it ever leaked. The URL is never logged.
//
// Signing uses the ambient service account via the IAM Credentials
// SignBlob API — the stt-worker SA needs
// roles/iam.serviceAccountTokenCreator on itself (terraform).
func signAudioURL(objectPath string) (string, error) {
	if gcsClient == nil {
		return "", fmt.Errorf("gcs client not initialized")
	}
	return gcsClient.Bucket(bucketName).SignedURL(objectPath, &gcs.SignedURLOptions{
		Scheme:  gcs.SigningSchemeV4,
		Method:  "GET",
		Expires: time.Now().Add(dgInFlightTTL),
	})
}

// ── chirp fallback ──────────────────────────────────────────────────

// fallbackToChirp re-routes a session whose Deepgram attempts are
// exhausted onto the standard Chirp path, exactly once (docs/39 §4).
// It re-runs the Chirp submission fan-out (including the audio_chunks
// plan — a >19-min session must NOT go to Chirp as one file):
//
//	chunk 0   → the existing deepgram row is repointed in place
//	            (provider='chirp', fallback_attempted=TRUE)
//	chunk 1.. → fresh INSERTs, standard chirp rows
//
// From then on the ordinary OBJECT_FINALIZE / watchdog machinery owns
// the session. Callable from both the redelivery path and the watchdog.
func fallbackToChirp(ctx context.Context, logger *slog.Logger, sessionUUID uuid.UUID, sourceURI, bcp47Lang string) error {
	logger = logger.With("provider_fallback", "deepgram→chirp")

	// Transcript already exists → the prior attempt died between persist
	// and the ops-row update. Just close the row.
	if id, err := fetchTranscriptIDForSession(ctx, sessionUUID); err == nil && id != "" {
		logger.Info("transcript already persisted; closing ops row instead of fallback")
		_, _ = markChunkFinalized(ctx, sessionUUID, 0)
		return nil
	}

	operatorOptIn := os.Getenv("STT_NATIVE_DIARIZATION") == "on" || os.Getenv("USE_NATIVE_DIARIZATION") == "true"
	useNativeDiarization := operatorOptIn && transcriptfmt.NativeDiarizationSupported(bcp47Lang)

	// Rebuild the chunk plan by session (the audio.uploaded upload_id is
	// not available on the watchdog path).
	chunks, err := loadChunkPlanBySession(ctx, sessionUUID, sourceURI)
	if err != nil {
		logger.Warn("fallback: chunk plan lookup failed; using single chunk", "error", err)
		chunks = []ChunkPlan{{ChunkIndex: 0, GCSUri: sourceURI}}
	}

	for _, ch := range chunks {
		outputPrefix := fmt.Sprintf("gs://%s/%s",
			transcriptsRawBkt, sttgcs.OutputPrefixFor(sessionUUID, ch.ChunkIndex))

		opName, err := submitBatchRecognize(ctx, ch.GCSUri, outputPrefix, bcp47Lang, useNativeDiarization)
		if err != nil {
			// NotFound → audio GC'd; genuinely unrecoverable.
			return handleSTTError(ctx, logger, sessionUUID.String(), err)
		}

		if ch.ChunkIndex == 0 {
			if _, uerr := dbPool.Exec(ctx, `
				UPDATE stt_operations
				SET provider = 'chirp', operation_id = $2, gcs_output_uri = $3,
				    chunk_count = $4, used_native_diarization = $5,
				    fallback_attempted = TRUE, retry_count = 0,
				    submitted_at = now(),
				    finalize_error = 'deepgram fallback; prior request_id=' || COALESCE(request_id, 'n/a')
				WHERE session_id = $1 AND chunk_index = 0`,
				sessionUUID, opName, outputPrefix, len(chunks), useNativeDiarization); uerr != nil {
				return fmt.Errorf("fallback repoint chunk 0: %w", uerr)
			}
		} else {
			if ierr := insertSTTOperation(ctx, insertSTTOpParams{
				SessionID:             sessionUUID,
				ChunkIndex:            ch.ChunkIndex,
				ChunkCount:            len(chunks),
				StartOffsetMS:         ch.StartOffsetMS,
				OperationID:           opName,
				GCSOutputURI:          outputPrefix,
				LanguageCode:          bcp47Lang,
				UsedNativeDiarization: useNativeDiarization,
				SourceAudioURI:        ch.GCSUri,
				Provider:              "chirp",
			}); ierr != nil && !isUniqueViolation(ierr) {
				return fmt.Errorf("fallback insert chunk %d: %w", ch.ChunkIndex, ierr)
			}
		}
	}

	slog.InfoContext(ctx, "analytics",
		"ae", "stt.provider_fallback",
		"session_id", sessionUUID.String(),
		"from", "deepgram", "to", "chirp",
		"chunk_count", len(chunks))
	logger.Warn("session failed over to chirp", "chunk_count", len(chunks))
	return nil
}

// loadChunkPlanBySession is loadChunkPlan keyed by session instead of
// upload id — the watchdog path has no audio.uploaded payload in hand.
func loadChunkPlanBySession(ctx context.Context, sessionUUID uuid.UUID, fallbackSourceURI string) ([]ChunkPlan, error) {
	single := []ChunkPlan{{ChunkIndex: 0, GCSUri: fallbackSourceURI}}
	if dbPool == nil {
		return single, nil
	}
	rows, err := dbPool.Query(ctx, `
		SELECT ch.chunk_index, ch.bucket_name, ch.object_path,
		       ch.start_offset_ms, ch.seam_offset_ms, ch.end_offset_ms, ch.overlap_ms
		FROM audio_chunks ch
		JOIN sessions s ON s.audio_upload_id = ch.audio_upload_id
		WHERE s.id = $1
		ORDER BY ch.chunk_index`, sessionUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []ChunkPlan
	for rows.Next() {
		var (
			idx              int32
			bkt, obj         string
			start, seam, end int64
			overlap          int32
		)
		if err := rows.Scan(&idx, &bkt, &obj, &start, &seam, &end, &overlap); err != nil {
			return nil, err
		}
		out = append(out, ChunkPlan{
			ChunkIndex:    int(idx),
			GCSUri:        fmt.Sprintf("gs://%s/%s", bkt, obj),
			StartOffsetMS: start,
			SeamOffsetMS:  seam,
			EndOffsetMS:   end,
			OverlapMS:     int(overlap),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return single, nil
	}
	return out, nil
}
