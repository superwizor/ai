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
	"strings"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

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

	w.WriteHeader(http.StatusOK)
	_, _ = fmt.Fprintf(w, "watchdog: processed %d stuck operations\n", len(rows))
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
		_, _ = markChunkFinalized(ctx, op.SessionID, op.ChunkIndex)
		logger.Error("Chirp operation completed with terminal ERROR; session FAILED",
			"error_truncated", msg)
		return nil
	}

	if !chirpOp.Done() {
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
	// Match: any per-file Error with non-zero code → mark FAILED.
	// Same classification as isTerminalSTTError (file-level Chirp
	// rejections are always terminal).
	if resp != nil {
		for fileURI, fr := range resp.Results {
			if fr == nil || fr.Error == nil || fr.Error.Code == 0 {
				continue
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
