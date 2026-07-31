package sttworker

// watchdog.go — ProcessWatchdog Cloud Function entry point (HTTP-
// triggered, invoked by Cloud Scheduler every 15 minutes).
//
// Belt-and-suspenders for the GCS-callback flow. Most invocations are
// no-ops (no stuck rows). When the OBJECT_FINALIZE event for a chunk
// is dropped by Eventarc (rare but possible), the watchdog reconstructs
// the Chirp Operation handle from `stt_operations.operation_id`, polls
// its status, and either drives finalize manually (DONE) or marks the
// session FAILED (ERROR).
//
// See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md "Watchdog" section.

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	longrunningpb "cloud.google.com/go/longrunning/autogen/longrunningpb"
	speech "cloud.google.com/go/speech/apiv2"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"google.golang.org/grpc/codes"
)

// maxChunkRetries bounds how many times the watchdog re-submits a
// single chunk after a transient Chirp failure (per-file error OR a
// hung-pending op) before giving up and marking the session FAILED.
// Each retry is a fresh (billed) BatchRecognize, so the cap keeps a
// permanently-flaky chunk from re-billing forever. Both re-submit
// triggers share this one budget.
//
// Default 24 (raised from 3 on 2026-06-29). Rationale: Chirp degradation
// windows can run for hours — session 4d18caee only recovered on its 3rd
// retry, i.e. right at the old cap. Terminal inputs (bad codec, etc.)
// still FAIL immediately via isTerminalStatusCode and are never retried,
// so this budget only ever burns on genuine transients. Paired with the
// 1h hung-pending give-up, 24 spans ~24h of retrying — aligned with the
// 26h reapStuckSessions backstop. Env-tunable without redeploy.
const defaultMaxChunkRetries = 24

func maxChunkRetries() int {
	if v := os.Getenv("STT_MAX_CHUNK_RETRIES"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return defaultMaxChunkRetries
}

// Stuck-PENDING give-up (docs follow-up to the 12c76823 incident).
//
// A Chirp op can hang PENDING indefinitely (done=false, no error code
// to classify) — a distinct transient mode from the DONE-with-error
// case the per-file path handles. reapStuckSessions only FAILs such a
// session at 26h; instead we cancel + re-submit a hung op, bounded by
// maxChunkRetries.
//
// The trigger requires TWO signals, not just wall-clock age:
//  1. age (now - submitted_at) past the give-up window, AND
//  2. the op's server-side metadata.update_time is stale.
//
// Why both: dynamic-batching has no latency SLA, so a legitimately
// queued op can be old. But a *progressing* op keeps advancing
// update_time, while a genuinely hung one freezes it (exactly what we
// saw on 12c76823: update_time frozen 1.5h while sibling ops kept
// finishing in ~2min). Gating on staleness distinguishes "one op hung"
// from "whole queue slow" and prevents a cancel-and-resubmit storm
// during a Chirp-wide slowdown.
const (
	defaultPendingGiveUpHours  = 3
	defaultPendingStaleMinutes = 45
)

func pendingGiveUpHours() int {
	if v := os.Getenv("STT_PENDING_GIVEUP_HOURS"); v != "" {
		if h, err := strconv.Atoi(v); err == nil && h > 0 {
			return h
		}
	}
	return defaultPendingGiveUpHours
}

func pendingStaleMinutes() int {
	if v := os.Getenv("STT_PENDING_STALE_MINUTES"); v != "" {
		if m, err := strconv.Atoi(v); err == nil && m > 0 {
			return m
		}
	}
	return defaultPendingStaleMinutes
}

// shouldGiveUpOnPendingOp is the pure decision behind the hung-op
// re-submit. Extracted so it can be unit-tested without a live Chirp
// operation. Returns true only when the op is BOTH past the give-up
// window AND its server-side progress timestamp is stale. When the op
// carries no update_time signal at all (hasUpdateTime=false) we refuse
// to cancel — better to wait (the 26h reaper backstops) than to kill an
// op we can't prove is hung.
func shouldGiveUpOnPendingOp(age time.Duration, hasUpdateTime bool, updateStaleness, giveUp, staleLimit time.Duration) bool {
	if age < giveUp {
		return false
	}
	if !hasUpdateTime {
		return false
	}
	return updateStaleness >= staleLimit
}

// watchdogStuckThresholdSeconds is the lower bound on
// (now - submitted_at) before a row is considered "stuck". Set high
// enough that legitimate slow Chirp jobs don't trigger us:
//
//   - Typical Chirp BatchRecognize for a 60-min session: 1-3 min.
//   - Outage-day Chirp can extend to 10-15 min.
//   - 30 min gives ample buffer over the worst observed normal latency.
const watchdogStuckThresholdSeconds = 30 * 60

func init() {
	functions.HTTP("ProcessWatchdog", ProcessWatchdog)
}

// ProcessWatchdog is the HTTP handler invoked by Cloud Scheduler.
// Always returns 200 — Cloud Scheduler interprets non-2xx as failure
// and retries with its own backoff, which would double the watchdog
// load. We log per-row outcomes and let the next 15-min tick pick up
// anything still pending.
func ProcessWatchdog(w http.ResponseWriter, r *http.Request) {
	// Cloud Scheduler doesn't carry a body of interest; drain it.
	_, _ = io.Copy(io.Discard, r.Body)
	_ = r.Body.Close()

	ctx := r.Context()
	logger := slog.With("function", "stt-watchdog")

	rows, err := loadPendingOperations(ctx, watchdogStuckThresholdSeconds)
	if err != nil {
		logger.Error("loadPendingOperations failed", "error", err)
		// Return 200 anyway — we'll try again next tick.
		w.WriteHeader(http.StatusOK)
		_, _ = fmt.Fprintln(w, "watchdog: db error logged")
		return
	}

	// Stuck-merge rescue runs every tick, independent of pending Chirp
	// operations: a session can have ALL chunks finalized yet no
	// transcript (a transient mergeAndPersist failure reverted status to
	// TRANSCRIBING without re-triggering). loadPendingOperations won't
	// surface those (their finalized_at is set), so handle them here —
	// before the no-pending-ops early return below.
	rescueStuckMerges(ctx, logger)

	if len(rows) == 0 {
		w.WriteHeader(http.StatusOK)
		_, _ = fmt.Fprintln(w, "watchdog: 0 stuck operations")
		return
	}

	logger.Info("found stuck operations", "count", len(rows))

	for _, op := range rows {
		opLogger := logger.With(
			"session_id", op.SessionID.String(),
			"chunk_index", op.ChunkIndex,
			"operation_id", op.OperationID,
		)
		if op.Provider == providerDeepgram || op.Provider == providerElevenLabs {
			// Synchronous providers have no long-running operation to
			// poll — a pending row past the stuck threshold means the
			// attempts (and their Pub/Sub redeliveries) dried up. One-shot
			// fallback to Chirp (docs/59 §4); the transcript-exists guard
			// inside handles the persisted-but-unmarked edge.
			//
			// For ElevenLabs this is also where a session lands after the
			// coverage guard rejected every attempt: the transcript was
			// never persisted, the row stayed pending, and Chirp gets a
			// turn at audio that Scribe could not read to the end.
			if err := rescueSyncOperation(ctx, opLogger, op); err != nil {
				opLogger.Warn("sync provider rescue failed; will retry next tick",
					"provider", op.Provider, "error", err)
			}
			continue
		}
		if err := rescueOperation(ctx, opLogger, op); err != nil {
			opLogger.Warn("rescue failed; will retry next tick", "error", err)
			// Don't fail the HTTP response — each row is independent;
			// failing one shouldn't block the others. The next
			// scheduler tick re-runs the whole scan.
		}
	}

	// Second responsibility (Option E, 2026-05-25): clean up orphan
	// PENDING_UPLOAD session rows whose upload never completed.
	// Runs after the stt_operations rescue so a transient DB error
	// here doesn't block the more time-sensitive Chirp poll. Errors
	// logged and ignored — next tick will retry.
	_ = runOrphanSessionCleanup(ctx, logger)

	// docs/21 WS2B: time-based give-up backstop for sessions whose
	// pipeline message was lost entirely (the DLQ reaper never sees
	// them). Deadline sits beyond the 24h retry window.
	_ = reapStuckSessions(ctx, logger)

	w.WriteHeader(http.StatusOK)
	_, _ = fmt.Fprintf(w, "watchdog: processed %d stuck operations\n", len(rows))
}

// rescueStuckMerges re-drives finalize for sessions whose chunks all
// finalized but never produced a transcript — e.g. a transient
// mergeAndPersist failure (a DB blip, or the now-fixed garbage-offset
// int4 overflow) that reverted status to TRANSCRIBING without
// re-triggering the merge. Without this the session hangs forever.
// Idempotent: finalizeIfReady re-acquires the merge lock under
// FOR UPDATE and the UNIQUE on transcripts(session_id) guards a double
// write. Errors are logged and swallowed — the next tick retries.
func rescueStuckMerges(ctx context.Context, logger *slog.Logger) {
	stuck, err := loadStuckMerges(ctx, watchdogStuckThresholdSeconds)
	if err != nil {
		logger.Error("loadStuckMerges failed", "error", err)
		return
	}
	for _, m := range stuck {
		mLogger := logger.With("session_id", m.SessionID.String())
		mLogger.Warn("re-driving stuck merge (all chunks finalized, no transcript)")
		if err := finalizeIfReady(ctx, mLogger, m.SessionID, bucketFromGCSURI(m.GCSOutputURI)); err != nil {
			mLogger.Warn("stuck-merge re-drive failed; will retry next tick", "error", err)
		}
	}
}

// rescueOperation polls the Operations API for a single stuck row
// and either drives finalize (when Chirp is actually done) or marks
// the session FAILED (when Chirp says the operation errored).
func rescueOperation(ctx context.Context, logger *slog.Logger, op sttOpRow) error {
	if speechClient == nil {
		return fmt.Errorf("speechClient not initialized")
	}

	// Reconstruct the Operation handle from its name.
	chirpOp := speechClient.BatchRecognizeOperation(op.OperationID)

	// Poll. When the op is still pending: nil resp + nil err. When
	// done (success): non-nil resp. When done (error): non-nil err.
	resp, pollErr := chirpOp.Poll(ctx)

	if pollErr != nil {
		// Poll returns an error for two very different reasons: (a) the
		// Chirp *operation* genuinely errored (bad file → terminal), or
		// (b) the Operations API was transiently unavailable
		// (Unavailable / DeadlineExceeded / Internal). Failing the
		// session on (b) would permanently kill a recoverable session
		// mid-outage (docs/21 §3.1 WS0D). Only a terminal-classified
		// error fails the session; transient → re-check next tick.
		if !isTerminalSTTError(pollErr) {
			logger.Warn("Chirp Poll transient error; leaving session in-progress, re-check next tick",
				"error_truncated", truncateOpError(pollErr.Error()))
			return nil
		}
		// Genuine terminal operation error.
		msg := truncateOpError(pollErr.Error())
		recordFinalizeError(ctx, op.SessionID, op.ChunkIndex, msg)
		_ = updateSessionStatus(ctx, op.SessionID.String(), "FAILED")
		if perr := publishSessionStatusChanged(ctx, op.SessionID.String(), "failed"); perr != nil {
			logger.Warn("publish session.status_changed(failed) failed", "error", perr)
		}
		releaseBillingCredit(ctx, op.SessionID.String(), "STT_FAILED")
		_, _ = markChunkFinalized(ctx, op.SessionID, op.ChunkIndex)
		logger.Error("Chirp operation completed with terminal ERROR; session FAILED",
			"error_truncated", msg)
		return nil
	}

	if !chirpOp.Done() {
		// Most pending ops are just slow — wait. But an op that has been
		// pending past the give-up window AND whose server-side progress
		// has gone stale is hung (12c76823 follow-up): cancel it and
		// re-submit a fresh one, sharing the maxChunkRetries budget.
		if hung, age, staleness := isHungPendingOp(op, chirpOp); hung {
			logger.Warn("Chirp op hung PENDING (past give-up window, progress stale); cancelling + re-submitting",
				"pending_seconds", int(age.Seconds()),
				"update_stale_seconds", int(staleness.Seconds()))
			if cerr := cancelChirpOp(ctx, op.OperationID); cerr != nil {
				// Best-effort: a failed cancel just risks the dead op
				// writing a late duplicate to the (reused) prefix, which
				// findTranscriptObject tolerates. Re-submit regardless.
				logger.Warn("cancel hung op failed; re-submitting anyway", "error", cerr)
			}
			resubmitted, rerr := resubmitChunk(ctx, logger, op, "pending-giveup",
				fmt.Sprintf("op pending %ds, update_time stale %ds",
					int(age.Seconds()), int(staleness.Seconds())))
			if rerr != nil {
				logger.Warn("hung-op re-submit failed; will retry next tick", "error", rerr)
				return nil
			}
			if !resubmitted {
				// Budget exhausted / no source URI: leave the row for the
				// 26h reapStuckSessions backstop rather than spinning.
				logger.Warn("hung op but re-submit unavailable (budget/source); leaving for give-up reaper")
			}
			return nil
		}
		logger.Info("Chirp operation still PENDING; will check next tick")
		return nil
	}

	// Per-file error inspection (added 2026-05-22 after the
	// 3f656c04 incident).
	//
	// Chirp's BatchRecognize can complete the *operation*
	// successfully while one or more files inside that operation
	// failed (e.g. "file is too long", codec rejected). The
	// failure surfaces inline in resp.Results[fileURI].Error —
	// NOT in the operation's top-level error AND NOT as a GCS
	// output file. If we skip this check and try to drive finalize
	// manually, findTranscriptObject will loop forever on
	// "no transcript file at prefix" because Chirp never wrote one.
	//
	// Per-file error classification (fixed 2026-06-26 after the
	// 12c76823 incident — chunk_2 lost to a transient code=13 INTERNAL).
	//
	// Chirp attaches a google.rpc.Status to the failing file in
	// resp.Results[uri].Error; its .Code is a bare gRPC status code.
	// We must split it the same way isTerminalSTTError splits operation-
	// level errors:
	//
	//   - Terminal (InvalidArgument/OutOfRange/NotFound/...): the input
	//     is bad and every retry returns the same answer → FAILED.
	//   - Transient (INTERNAL/UNAVAILABLE/DEADLINE_EXCEEDED/...): a
	//     Google-side fault. The operation is DONE-with-error and wrote
	//     NO transcript object, so re-polling THIS operation returns the
	//     same error forever — recovery requires a brand-new
	//     BatchRecognize. resubmitChunk does that, bounded by
	//     maxChunkRetries. Only when re-submit is impossible (budget
	//     exhausted, source audio GC'd, or a pre-000060 row with no
	//     source_audio_uri) do we fall through to FAILED.
	if resp != nil {
		for fileURI, fr := range resp.Results {
			if fr == nil || fr.Error == nil || fr.Error.Code == 0 {
				continue
			}
			code := codes.Code(fr.Error.Code)
			if !isTerminalStatusCode(code) {
				resubmitted, rerr := resubmitChunk(ctx, logger, op, "per-file-transient",
					fmt.Sprintf("code=%d %s", int(code), fr.Error.Message))
				if rerr != nil {
					// Transient *re-submit* failure (Operations API blip,
					// DB blip). Leave the row pending; next tick retries.
					logger.Warn("chunk re-submit failed transiently; will retry next tick",
						"error", rerr)
					return nil
				}
				if resubmitted {
					return nil
				}
				// resubmitted == false → unrecoverable (retries exhausted
				// or source audio gone): fall through to terminal FAILED.
			}
			msg := fmt.Sprintf(
				"chirp 3 returned per-file error: code=%d %s (file=%s)",
				fr.Error.Code, fr.Error.Message, fileURI,
			)
			recordFinalizeError(ctx, op.SessionID, op.ChunkIndex, truncateOpError(msg))
			_ = updateSessionStatus(ctx, op.SessionID.String(), "FAILED")
			if perr := publishSessionStatusChanged(ctx, op.SessionID.String(), "failed"); perr != nil {
				logger.Warn("publish session.status_changed(failed) failed", "error", perr)
			}
			releaseBillingCredit(ctx, op.SessionID.String(), "STT_FAILED")
			_, _ = markChunkFinalized(ctx, op.SessionID, op.ChunkIndex)
			logger.Error("Chirp per-file error; session FAILED",
				"error_code", fr.Error.Code,
				"error_message", fr.Error.Message)
			return nil
		}
	}

	// Success — Chirp wrote the transcript to GCS. Either
	// OBJECT_FINALIZE will fire (or already fired and we'd have
	// finalized_at set — but if we're here, that didn't happen).
	// Drive finalize manually.
	logger.Info("Chirp DONE; driving finalize manually")
	bucket := bucketFromGCSURI(op.GCSOutputURI)
	// markChunkFinalized's IS NULL guard makes this idempotent against
	// an eventual OBJECT_FINALIZE racing us — one of the two attempts
	// will see 0 rows affected and ack.
	if affected, err := markChunkFinalized(ctx, op.SessionID, op.ChunkIndex); err != nil {
		return fmt.Errorf("markChunkFinalized: %w", err)
	} else if affected == 0 {
		return nil
	}
	return finalizeIfReady(ctx, logger, op.SessionID, bucket)
}

// resubmitChunk fires a fresh BatchRecognize for a single chunk after
// a transient per-file Chirp error and repoints the stt_operations row
// at the new operation. Returns (resubmitted, error):
//
//   - (true, nil)   — a new operation was submitted and the row updated;
//     the next watchdog tick polls the new operation.
//   - (false, nil)  — re-submit is impossible (retry budget exhausted,
//     no source_audio_uri, or the source audio is gone):
//     the caller treats this chunk as terminal → FAILED.
//   - (false, err)  — a transient failure during re-submit (Operations
//     API / DB blip): the caller leaves the row pending
//     and retries on the next tick.
//
// The original errored operation wrote NO transcript object (a per-file
// error suppresses output), so we reuse the original output prefix:
// it's empty, and the new operation's OBJECT_FINALIZE round-trips
// cleanly through ParseOutputObjectPath (which demands the exact
// {uuid}/chunk_{n}/{leaf} 3-segment shape — an extra retry_N segment
// would break finalize's session/chunk mapping).
//
// reason is a short stable tag for the trigger ("per-file-transient" or
// "pending-giveup"); detail is a human-readable elaboration. Both feed
// logging/analytics so the two re-submit triggers stay distinguishable.
func resubmitChunk(ctx context.Context, logger *slog.Logger, op sttOpRow, reason, detail string) (bool, error) {
	if op.SourceAudioURI == "" {
		// Row predates the 000060 migration (or was never backfilled):
		// we have no input URI to re-submit. Can't auto-recover.
		logger.Warn("re-submit needed but row has no source_audio_uri; cannot re-submit",
			"reason", reason, "detail", detail)
		return false, nil
	}
	if op.RetryCount >= maxChunkRetries() {
		logger.Warn("re-submit needed but retry budget exhausted; giving up",
			"reason", reason,
			"detail", detail,
			"retry_count", op.RetryCount,
			"max_retries", maxChunkRetries())
		return false, nil
	}
	if speechClient == nil {
		return false, fmt.Errorf("speechClient not initialized")
	}

	outputPrefix := op.GCSOutputURI
	newOp, err := submitBatchRecognize(
		ctx, op.SourceAudioURI, outputPrefix, op.LanguageCode, op.UsedNativeDiarization)
	if err != nil {
		// Submit-call error. A terminal one (e.g. NotFound: source audio
		// GC'd by OLM 48h) means recovery is genuinely impossible → let
		// the caller FAIL. Transient → retry next tick.
		if isTerminalSTTError(err) {
			logger.Error("chunk re-submit hit terminal error (source audio gone?); session will FAIL",
				"error_truncated", truncateOpError(err.Error()))
			return false, nil
		}
		return false, fmt.Errorf("re-submit BatchRecognize: %w", err)
	}

	newRetry := op.RetryCount + 1
	if err := markChunkResubmitted(ctx, op.ID, newOp, outputPrefix, newRetry); err != nil {
		return false, fmt.Errorf("markChunkResubmitted: %w", err)
	}

	slog.InfoContext(ctx, "analytics",
		"ae", "stt.chunk_resubmitted",
		"session_id", op.SessionID.String(),
		"chunk_index", op.ChunkIndex,
		"retry_count", newRetry,
		"reason", reason,
	)
	logger.Warn("re-submitted chunk with fresh operation",
		"reason", reason,
		"detail", detail,
		"new_operation_id", newOp,
		"retry_count", newRetry,
		"max_retries", maxChunkRetries())
	return true, nil
}

// isHungPendingOp reports whether a still-PENDING op should be given up
// on (cancelled + re-submitted). It wires the live op's timing into the
// pure shouldGiveUpOnPendingOp decision: age from our submitted_at
// (per-attempt clock) and staleness from Chirp's metadata.update_time.
func isHungPendingOp(op sttOpRow, chirpOp *speech.BatchRecognizeOperation) (hung bool, age, staleness time.Duration) {
	age = time.Since(op.SubmittedAt)
	giveUp := time.Duration(pendingGiveUpHours()) * time.Hour
	staleLimit := time.Duration(pendingStaleMinutes()) * time.Minute

	hasUpdate := false
	if meta, err := chirpOp.Metadata(); err == nil && meta != nil && meta.GetUpdateTime() != nil {
		hasUpdate = true
		staleness = time.Since(meta.GetUpdateTime().AsTime())
	}
	return shouldGiveUpOnPendingOp(age, hasUpdate, staleness, giveUp, staleLimit), age, staleness
}

// cancelChirpOp asks the Speech API to cancel a long-running operation.
// Best-effort: Chirp cancellation isn't guaranteed instant, so the
// caller treats failure as non-fatal and re-submits regardless.
func cancelChirpOp(ctx context.Context, opName string) error {
	if speechClient == nil {
		return fmt.Errorf("speechClient not initialized")
	}
	return speechClient.CancelOperation(ctx, &longrunningpb.CancelOperationRequest{Name: opName})
}

// bucketFromGCSURI strips the "gs://" scheme and returns just the
// bucket portion of a GCS URI. Used to feed finalizeIfReady the
// bucket name when we drive it from a stored stt_operations.gcs_output_uri.
//
// Input:  "gs://my-bucket/path/chunk_0/"
// Output: "my-bucket"
func bucketFromGCSURI(uri string) string {
	const scheme = "gs://"
	if !strings.HasPrefix(uri, scheme) {
		return ""
	}
	rest := uri[len(scheme):]
	if i := strings.IndexByte(rest, '/'); i >= 0 {
		return rest[:i]
	}
	return rest
}

// truncateOpError caps the error message we stash in
// stt_operations.finalize_error. Chirp can dump multi-KB
// status messages; keep DB rows readable.
func truncateOpError(msg string) string {
	const cap = 1024
	if len(msg) > cap {
		return msg[:cap] + "...(truncated)"
	}
	return msg
}

// rescueSyncOperation handles a stuck row belonging to a synchronous
// provider (deepgram or elevenlabs). By the time the watchdog sees one
// (pending > 30 min), the redelivery-driven takeover in the provider
// branch has stopped making progress — fail the session over to Chirp
// exactly once. fallback_attempted rows should not exist here (the
// fallback rewrites provider to 'chirp'), but guard anyway so a partial
// failover can't loop.
func rescueSyncOperation(ctx context.Context, logger *slog.Logger, op sttOpRow) error {
	if op.FallbackAttempted {
		logger.Warn("row already failed over but still pending; leaving for give-up reaper",
			"provider", op.Provider)
		return nil
	}
	if op.SourceAudioURI == "" {
		logger.Warn("row has no source_audio_uri; cannot fall back — leaving for give-up reaper",
			"provider", op.Provider)
		return nil
	}
	return fallbackToChirp(ctx, logger, op.SessionID, op.SourceAudioURI, op.LanguageCode)
}
