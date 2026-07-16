package sttworker

// finalize.go — ProcessTranscriptObject Cloud Function entry point.
//
// Triggered by Eventarc OBJECT_FINALIZE on the transcripts-raw GCS
// bucket. Chirp BatchRecognize (submitted by ProcessAudio in
// main.go) writes its result there async; this is where we pick it
// up, merge across chunks if there are multiple, and finish the
// transcript-persist work that the old in-line stt-worker used to
// do at the tail of ProcessAudio.
//
// See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md.

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/speech/apiv2/speechpb"
	gcs "cloud.google.com/go/storage"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/api/iterator"
	"google.golang.org/protobuf/encoding/protojson"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/sttgcs"
)

// StorageObjectData is the subset of the Cloud Storage OBJECT_FINALIZE
// CloudEvent payload we care about. Mirrors the GCP Storage
// `StorageObjectData` schema but kept minimal so we don't pull in a
// proto dependency for one field.
type StorageObjectData struct {
	Bucket string `json:"bucket"`
	Name   string `json:"name"`
}

func init() {
	// Register the finalize entry alongside ProcessAudio (registered in
	// main.go::init). Same Cloud Functions Gen2 zip; the deployed
	// resource picks one entry via build_config.entry_point.
	functions.CloudEvent("ProcessTranscriptObject", ProcessTranscriptObject)
}

// ProcessTranscriptObject handles a single OBJECT_FINALIZE event on
// the transcripts-raw bucket. Idempotent on Pub/Sub redelivery and
// on multi-chunk fan-in (only the last chunk to finalize runs the
// merge work).
func ProcessTranscriptObject(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "stt-finalize")

	var obj StorageObjectData
	if err := e.DataAs(&obj); err != nil {
		logger.Warn("malformed storage event; acking", "error", err)
		return nil
	}

	parsed, ok := sttgcs.ParseOutputObjectPath(obj.Name)
	if !ok {
		// Sidecar metadata file, manual upload, or some other GCS
		// activity we don't care about. Ack and move on.
		logger.Info("skipping non-transcript object", "name", obj.Name)
		return nil
	}
	sessionID := parsed.SessionID
	chunkIndex := parsed.ChunkIndex
	logger = logger.With(
		"session_id", sessionID.String(),
		"chunk_index", chunkIndex,
		"object", obj.Name,
	)

	// Step 1. Idempotent finalized_at flip. The `finalized_at IS NULL`
	// guard makes the second OBJECT_FINALIZE event for the same chunk
	// (Pub/Sub at-least-once during retries) a 0-row no-op.
	affected, err := markChunkFinalized(ctx, sessionID, chunkIndex)
	if err != nil {
		// Transient DB; Pub/Sub will retry.
		logger.Error("markChunkFinalized failed", "error", err)
		return err
	}
	if affected == 0 {
		logger.Info("chunk already finalized; ack")
		return nil
	}

	// Step 2. Are we the merger? finalizeIfReady acquires the merge
	// lock by flipping sessions.status TRANSCRIBING → MERGING under
	// SELECT FOR UPDATE. Only one invocation wins.
	return finalizeIfReady(ctx, logger, sessionID, obj.Bucket)
}

// finalizeIfReady checks whether all chunks for this session have
// landed; if so, attempts to acquire the merge lock and drives
// mergeAndPersist. Otherwise returns nil (the last-to-arrive chunk
// will do the work).
func finalizeIfReady(ctx context.Context, logger *slog.Logger, sessionID uuid.UUID, bucket string) error {
	pending, err := countPendingChunks(ctx, sessionID)
	if err != nil {
		return err
	}
	if pending > 0 {
		logger.Info("waiting on sibling chunks", "pending", pending)
		return nil
	}

	// Acquire the merge lock under FOR UPDATE on sessions row.
	// Multiple finalize invocations may race here when N chunks
	// land simultaneously; FOR UPDATE serializes them; only the one
	// that observes status=TRANSCRIBING does work.
	acquired, err := acquireMergeLock(ctx, sessionID)
	if err != nil {
		return err
	}
	if !acquired {
		logger.Info("merge lock not acquired; another invocation handling it")
		return nil
	}

	return mergeAndPersist(ctx, logger, sessionID, bucket)
}

// acquireMergeLock atomically checks-and-flips sessions.status from
// TRANSCRIBING to MERGING. Returns true when this invocation owns
// the merge work; false when status was anything else (already
// merged / failed / never started).
func acquireMergeLock(ctx context.Context, sessionID uuid.UUID) (bool, error) {
	if dbPool == nil {
		return true, nil // test/local: skip the lock
	}
	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var status string
	err = tx.QueryRow(ctx,
		"SELECT status FROM sessions WHERE id = $1 FOR UPDATE",
		sessionID).Scan(&status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil // session deleted between submit and finalize
		}
		return false, err
	}
	if status != "TRANSCRIBING" {
		return false, nil
	}
	if _, err := tx.Exec(ctx,
		"UPDATE sessions SET status = 'MERGING' WHERE id = $1",
		sessionID); err != nil {
		return false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return false, err
	}
	return true, nil
}

// mergeAndPersist does the actual work the old in-line stt-worker
// did after Chirp returned: parse each chunk's response, run the
// chunker, persist the transcript blob, publish transcript.completed.
//
// Wrapped in a deferred terminal/transient handler that:
//   - on terminal errors (Chirp file-level errors etc.): marks
//     session FAILED so future redeliveries hit the poison guard.
//   - on transient errors (DB / KMS / GCS 5xx): reverts status to
//     TRANSCRIBING so Pub/Sub-driven retries can re-enter through
//     acquireMergeLock again. Without the revert, the session
//     would stay in MERGING forever.
func mergeAndPersist(ctx context.Context, logger *slog.Logger, sessionID uuid.UUID, bucket string) (rerr error) {
	startTime := time.Now()
	defer func() {
		if rerr == nil {
			return
		}
		if isTerminalSTTError(rerr) {
			_ = updateSessionStatus(ctx, sessionID.String(), "FAILED")
			logger.Error("merge: terminal failure", "error", rerr)
		} else {
			_ = updateSessionStatus(ctx, sessionID.String(), "TRANSCRIBING")
			logger.Error("merge: transient failure — released lock", "error", rerr)
		}
	}()

	ops, err := loadOperationsForSession(ctx, sessionID)
	if err != nil {
		return fmt.Errorf("loadOperationsForSession: %w", err)
	}
	if len(ops) == 0 {
		// Nothing to merge — session went into MERGING but no
		// stt_operations rows exist. Shouldn't happen in practice
		// (the acquire-lock path only fires after a chunk finalized);
		// log loudly and FAIL so it doesn't block future work.
		return fmt.Errorf("mergeAndPersist: no stt_operations rows for session %s", sessionID)
	}

	parts, err := loadChunkResults(ctx, logger, ops, bucket, sessionID)
	if err != nil {
		return err
	}

	// Speaker-label fill (ADR-IMPL-007a sparse-label recovery). Each
	// chunk individually got Chirp's diarization tags; the fill propagates
	// adjacent labels into unlabeled words within each chunk. Bounded
	// by the chunker's pause threshold.
	if parts[0].UsedNativeDiarization {
		cfg := chunker.DefaultConfig()
		for i := range parts {
			fillSpeakerLabels(parts[i].Words, int64(cfg.PauseThresholdMS))
		}
	}

	merged, summary, stats := sttgcs.MergeChirpResults(parts)
	if stats.FallbackCount > 0 {
		// Stage 1 should never hit this (single chunk → no alignment
		// → no fallback path). Surface loudly if it does, plus the
		// metric for Stage 2 dashboards.
		logger.Warn("stt_cross_chunk_alignment_fallback",
			"fallback_count", stats.FallbackCount,
			"chunk_count", len(parts))
	}

	// Ghost-speaker collapse (added 2026-05-24 after the Janek
	// Johny session e7a1031c-…). Cross-chunk alignment in
	// internal/sttgcs/alignment.go can offset a borderline-ambiguous
	// label into a fresh integer (label "3" for a 2-speaker
	// session) when the majority-fraction threshold isn't met. The
	// llm-worker reattach from commit fa9ee48 only catches the
	// case where the LLM correctly counts 2 speakers; when the LLM
	// is shown 3 numbered turn-groups it dutifully reports 3
	// speakers, the reattach branch doesn't fire, and the ghost
	// passes through to the report. Collapsing here — before
	// chunker.ChunkByPauses and before the LLM ever sees the
	// stream — eliminates the artifact at the source.
	//
	// No-op for 1- or 2-speaker sessions (the common case) and
	// for genuinely 3+-speaker sessions where every label clears
	// the absolute / fractional thresholds. See collapse.go for
	// the heuristic + threshold rationale.
	if parts[0].UsedNativeDiarization {
		collapseStats := sttgcs.CollapseGhostSpeakers(merged)
		if len(collapseStats.RemovedLabels) > 0 {
			logger.Info("stt_ghost_speaker_collapse",
				"initial_speakers", collapseStats.InitialSpeakers,
				"final_speakers", collapseStats.FinalSpeakers,
				"removed_labels", collapseStats.RemovedLabels,
				"removed_word_counts", collapseStats.RemovedWordCounts)
			// Update the summary's SpeakerCount so the
			// downstream log line + the persisted record
			// reflect the post-collapse reality.
			summary.SpeakerCount = collapseStats.FinalSpeakers
		}
	}

	tr := &TranscriptResult{
		Words:                merged,
		LanguageCode:         summary.LanguageCode,
		WordCount:            summary.WordCount,
		ConfidenceAvg:        summary.ConfidenceAvg,
		HasNativeDiarization: summary.HasNativeDiarization,
		SpeakerCount:         summary.SpeakerCount,
	}

	logger.Info("merged transcript",
		"language", summary.LanguageCode,
		"raw_word_count", summary.WordCount,
		"speaker_count", summary.SpeakerCount,
		"native_diarization", summary.HasNativeDiarization,
		"merge_chunks", len(parts))

	return completeTranscript(ctx, logger, sessionID, tr, "chirp_3", startTime)
}

// completeTranscript is the provider-agnostic tail of the STT pipeline:
// pause-chunk the word stream, persist the encrypted blob + segments,
// flip the session to ANALYZING, bill, publish transcript.completed and
// delete the source audio. Shared by the Chirp merge path
// (mergeAndPersist) and the synchronous Deepgram path (docs/39 D5) —
// everything downstream of this function cannot tell providers apart.
//
// Error contract matches mergeAndPersist's expectations: the returned
// error is classified by the caller (terminal → FAILED, transient →
// retry); nil means the point of no return was passed.
func completeTranscript(ctx context.Context, logger *slog.Logger, sessionID uuid.UUID, tr *TranscriptResult, sttModel string, startTime time.Time) error {
	chunkerCfg := chunker.DefaultConfig()
	chunks := chunker.ChunkByPauses(tr.Words, chunkerCfg)

	// DEV MODE ONLY: log plaintext transcript before encryption.
	// PHI exposure — never set in production. See main.go comment on
	// logPlaintextTranscript for the full warning.
	if os.Getenv("DEV_LOG_PLAINTEXT_TRANSCRIPT") == "true" {
		logPlaintextTranscript(logger, sessionID.String(), tr, chunks)
	}

	transcriptID, err := persistTranscript(ctx, sessionID.String(), tr, chunks, time.Since(startTime), sttModel)
	if err != nil {
		// UNIQUE on transcripts(session_id) (migration 000021) — if
		// a prior finalize attempt committed transcripts but crashed
		// before publishing, the retry hits 23505 here. Recover by
		// fetching the existing row's id and continuing to publish.
		if isUniqueViolation(err) {
			logger.Warn("transcripts row already exists; reusing existing id",
				"session_id", sessionID.String())
			existingID, fetchErr := fetchTranscriptIDForSession(ctx, sessionID)
			if fetchErr != nil {
				return fmt.Errorf("fetchTranscriptIDForSession after 23505: %w", fetchErr)
			}
			transcriptID = existingID
		} else {
			return fmt.Errorf("persistTranscript: %w", err)
		}
	}

	// language_code write guard (preserved from the in-line worker).
	// Only overwrite when the session row didn't already carry a
	// non-empty language. ingestion-svc populates this at session
	// creation; we never want to overwrite it.
	sessLang, _ := loadSessionLanguage(ctx, sessionID.String())
	if sessLang == "" && tr.LanguageCode != "" {
		_ = updateSessionLanguage(ctx, sessionID.String(), tr.LanguageCode)
	}

	if err := updateSessionStatus(ctx, sessionID.String(), "ANALYZING"); err != nil {
		// Status update is best-effort here; the transcript is
		// already persisted. Log + continue to publish.
		logger.Warn("status ANALYZING update failed", "error", err)
	}

	// Billing hook (fail-soft): post-STT, with duration_seconds known
	// authoritatively (set by ingestion-svc finalize via ffprobe), bill
	// the org via billing-svc.CommitUsage. Idempotent po session_id
	// (UNIQUE constraint na usage_events), więc Pub/Sub redelivery safe.
	// Errors logged + swallowed — billing failure nie blokuje pipeline.
	go commitBillingUsageAsync(sessionID.String())

	if err := publishTranscriptCompleted(ctx, sessionID.String(), transcriptID); err != nil {
		return fmt.Errorf("publishTranscriptCompleted: %w", err)
	}

	// Point of no return reached: the transcript is durably persisted AND
	// transcript.completed is published, so STT will never need the source
	// audio again. Delete the audio now to shrink PHI exposure from the
	// 48 h GCS lifecycle down to seconds after transcription. Fail-soft:
	// the lifecycle rule remains the backstop.
	deleteSessionAudio(ctx, logger, sessionID)

	logger.Info("transcript complete",
		"transcript_id", transcriptID,
		"stt_model", sttModel,
		"duration_ms", time.Since(startTime).Milliseconds(),
		"chunks", len(chunks))
	return nil
}

// loadChunkResults downloads + parses Chirp output for every chunk
// of the session in chunk_index order. Returns []ChunkResult ready
// to feed sttgcs.MergeChirpResults.
func loadChunkResults(
	ctx context.Context,
	logger *slog.Logger,
	ops []sttOpRow,
	bucket string,
	sessionID uuid.UUID,
) ([]sttgcs.ChunkResult, error) {
	parts := make([]sttgcs.ChunkResult, 0, len(ops))
	for _, op := range ops {
		objectName, err := findTranscriptObject(ctx, bucket, op)
		if err != nil {
			return nil, fmt.Errorf("findTranscriptObject chunk %d: %w", op.ChunkIndex, err)
		}
		blob, err := downloadGCSObject(ctx, bucket, objectName)
		if err != nil {
			return nil, fmt.Errorf("downloadGCSObject chunk %d (%s): %w", op.ChunkIndex, objectName, err)
		}

		// Chirp's GCS output is a serialized `BatchRecognizeResults`
		// (the per-file payload), NOT a `BatchRecognizeResponse` (the
		// outer wrapper used by the inline-output path). Captured
		// 2026-05-22 from real staging output: the JSON top-level is
		// `{"results":[...], "metadata":{...}}` — equivalent to
		// `BatchRecognizeFileResult.InlineResult.Transcript`.
		//
		// We unmarshal into BatchRecognizeResults directly and then
		// synthesize a BatchRecognizeResponse so ParseChirp3Results
		// works unchanged. Trade-off: the synthetic file key "_" is
		// arbitrary — ParseChirp3Results iterates the map and
		// doesn't key on URI.
		var results speechpb.BatchRecognizeResults
		if err := protojson.Unmarshal(blob, &results); err != nil {
			return nil, fmt.Errorf("protojson.Unmarshal chunk %d: %w", op.ChunkIndex, err)
		}

		synthetic := &speechpb.BatchRecognizeResponse{
			Results: map[string]*speechpb.BatchRecognizeFileResult{
				"_": {
					Result: &speechpb.BatchRecognizeFileResult_InlineResult{
						InlineResult: &speechpb.InlineResult{
							Transcript: &results,
						},
					},
				},
			},
		}

		tr, err := ParseChirp3Results(synthetic, op.UsedNativeDiarization, op.LanguageCode)
		if err != nil {
			// File-level error from Chirp lands here (codec rejected,
			// "is too long", etc.). isTerminalSTTError will classify
			// the wrapped error via the "chirp 3 returned" prefix.
			recordFinalizeError(ctx, sessionID, op.ChunkIndex, err.Error())
			return nil, err
		}

		parts = append(parts, sttgcs.ChunkResult{
			ChunkIndex:            op.ChunkIndex,
			StartOffsetMS:         op.StartOffsetMS,
			SeamOffsetMS:          op.SeamOffsetMS,
			EndOffsetMS:           op.EndOffsetMS,
			OverlapMS:             op.OverlapMS,
			UsedNativeDiarization: op.UsedNativeDiarization,
			LanguageCode:          tr.LanguageCode,
			Words:                 tr.Words,
		})
	}

	logger.Info("loaded chunk results", "chunk_count", len(parts))
	return parts, nil
}

// findTranscriptObject lists the chunk's GCS output prefix and
// returns the single `transcript_*.json` file Chirp wrote. Chirp
// picks the file's hash suffix on its end; we can't predict it.
//
// If Chirp ever writes multiple files to the same prefix (sidecar
// metadata, schema changes), we pick the first matching the
// `transcript_*.json` convention; the rest get OLM-cleaned at 7d.
func findTranscriptObject(ctx context.Context, bucket string, op sttOpRow) (string, error) {
	prefix := sttgcs.OutputPrefixFor(op.SessionID, op.ChunkIndex)
	it := gcsClient.Bucket(bucket).Objects(ctx, &gcs.Query{Prefix: prefix})
	for {
		attrs, err := it.Next()
		if err != nil {
			if errors.Is(err, iterator.Done) {
				return "", fmt.Errorf("no transcript file at prefix %s", prefix)
			}
			return "", err
		}
		leaf := stripPrefix(attrs.Name, prefix)
		// Chirp's actual leaf filename is e.g.
		// `1779458535_transcript_{op_hash}.json` — a unix-timestamp
		// prefix the SDK doesn't document. Match by Contains so a
		// future Chirp tweak that adds/removes that prefix doesn't
		// silently break us.
		if strings.Contains(leaf, "transcript_") && strings.HasSuffix(leaf, ".json") {
			return attrs.Name, nil
		}
	}
}

// deleteSessionAudio removes the session's audio from the
// audio-uploads bucket once the transcript is durably persisted and
// published (see the call site for why that ordering is safe). It
// deletes every object under the session's directory prefix
// `<therapist_id>/<session_id>/` — the original upload plus any
// `<ts>_chunk_N.flac` the chunker wrote (chunker.go:167, same dir).
//
// Best-effort by design: the 48 h GCS Object-Lifecycle rule
// (infra/modules/storage/main.tf) is the backstop, so every failure
// here is logged and swallowed — audio cleanup must never fail the
// pipeline or block ANALYZING. Idempotent (NotFound tolerated) so a
// Pub/Sub redelivery re-run is harmless.
func deleteSessionAudio(ctx context.Context, logger *slog.Logger, sessionID uuid.UUID) {
	if dbPool == nil || gcsClient == nil {
		return
	}
	var bucket, objectPath string
	err := dbPool.QueryRow(ctx,
		"SELECT bucket_name, object_path FROM audio_uploads WHERE session_id = $1",
		sessionID).Scan(&bucket, &objectPath)
	if err != nil {
		logger.Warn("audio cleanup: lookup failed; 48h lifecycle will reclaim",
			"session_id", sessionID.String(), "error", err)
		return
	}
	slash := strings.LastIndex(objectPath, "/")
	if bucket == "" || slash < 0 {
		logger.Warn("audio cleanup: missing bucket or non-nested object_path; skipping",
			"bucket", bucket, "object_path", objectPath)
		return
	}
	prefix := objectPath[:slash+1] // include the trailing '/'

	it := gcsClient.Bucket(bucket).Objects(ctx, &gcs.Query{Prefix: prefix})
	deleted := 0
	for {
		attrs, iterErr := it.Next()
		if errors.Is(iterErr, iterator.Done) {
			break
		}
		if iterErr != nil {
			logger.Warn("audio cleanup: list failed", "prefix", prefix, "error", iterErr)
			break
		}
		if delErr := gcsClient.Bucket(bucket).Object(attrs.Name).Delete(ctx); delErr != nil &&
			!errors.Is(delErr, gcs.ErrObjectNotExist) {
			logger.Warn("audio cleanup: delete failed", "object", attrs.Name, "error", delErr)
			continue
		}
		deleted++
	}
	logger.Info("audio cleanup: source audio deleted post-transcript",
		"bucket", bucket, "prefix", prefix, "objects_deleted", deleted)
}

// downloadGCSObject reads a GCS object into memory. Chirp's JSON
// outputs are typically a few hundred KB — well under the 1 GiB
// memory limit on the function.
func downloadGCSObject(ctx context.Context, bucket, object string) ([]byte, error) {
	r, err := gcsClient.Bucket(bucket).Object(object).NewReader(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = r.Close() }()
	return io.ReadAll(r)
}

// fetchTranscriptIDForSession is the post-23505 recovery query. It
// returns the existing transcripts.id for a session, used when
// persistTranscript hit the UNIQUE constraint because a prior
// finalize attempt committed transcripts but crashed before
// publishing transcript.completed.
func fetchTranscriptIDForSession(ctx context.Context, sessionID uuid.UUID) (string, error) {
	if dbPool == nil {
		return "", fmt.Errorf("dbPool nil; cannot recover transcript_id")
	}
	var id uuid.UUID
	err := dbPool.QueryRow(ctx,
		"SELECT id FROM transcripts WHERE session_id = $1",
		sessionID).Scan(&id)
	if err != nil {
		return "", err
	}
	return id.String(), nil
}

// updateSessionLanguage is exposed here as a wrapper around the
// shared helper in main.go. Kept inline so the language_code-write
// guard at the end of mergeAndPersist is self-contained.
//
// (Existing main.go::updateSessionLanguage signature is reused
// directly — this comment is just documentation.)
var _ = updateSessionLanguage

// stripPrefix removes leading prefix p from s; returns s unchanged
// when s doesn't start with p. Used to test the leaf-name portion of
// a GCS object key against the "transcript_" prefix.
func stripPrefix(s, p string) string {
	if strings.HasPrefix(s, p) {
		return s[len(p):]
	}
	return s
}
