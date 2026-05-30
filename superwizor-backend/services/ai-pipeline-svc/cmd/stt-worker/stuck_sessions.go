// stuck_sessions.go — the time-based give-up backstop (docs/21 §3.6,
// WS2B). Complements the DLQ give-up reaper: it catches a session whose
// pipeline Pub/Sub message was lost ENTIRELY (never published, never
// DLQ'd — so the DLQ reaper never sees it) and would otherwise leave the
// user on an infinite spinner forever.
//
// Invoked from ProcessWatchdog alongside runOrphanSessionCleanup.

package sttworker

import (
	"context"
	"log/slog"
	"os"
	"strconv"
)

// defaultStuckSessionDeadlineHours sits safely BEYOND the ~24h
// transient-retry window (objectFinalized.sub / Eventarc subs: 100
// attempts ≈ 24h) so this backstop never force-fails a session that is
// still legitimately retrying. Tunable via STUCK_SESSION_DEADLINE_HOURS.
const defaultStuckSessionDeadlineHours = 26

func stuckSessionDeadlineHours() int {
	if v := os.Getenv("STUCK_SESSION_DEADLINE_HOURS"); v != "" {
		if h, err := strconv.Atoi(v); err == nil && h > 0 {
			return h
		}
	}
	return defaultStuckSessionDeadlineHours
}

// reapStuckSessions force-fails sessions wedged in a non-terminal
// post-upload state past the deadline, mirroring "failed" so the Flutter
// app shows the failure sheet instead of spinning. PENDING_UPLOAD is NOT
// included here — that's the orphan reaper's job (sessions that never got
// audio). We only touch states that imply the upload succeeded and the
// pipeline then stalled: CREATED / TRANSCRIBING / MERGING / ANALYZING.
//
// Idempotent: a session already terminal won't match the WHERE clause.
// Token release is handled by the reservation TTL + the DLQ give-up path
// (docs/21 WS0E/WS2A); this function only resolves the user-facing hang.
func reapStuckSessions(ctx context.Context, logger *slog.Logger) error {
	if dbPool == nil {
		logger.Warn("reap_stuck_sessions: dbPool nil (mock mode); skipping")
		return nil
	}

	hours := stuckSessionDeadlineHours()
	rows, err := dbPool.Query(ctx, `
		SELECT id::text
		FROM sessions
		WHERE status IN ('CREATED', 'TRANSCRIBING', 'MERGING', 'ANALYZING')
		  AND deleted_at IS NULL
		  AND status_updated_at < now() - make_interval(hours => $1)
	`, hours)
	if err != nil {
		logger.Error("reap_stuck_sessions: query failed", "error", err)
		return err
	}

	var ids []string
	for rows.Next() {
		var id string
		if scanErr := rows.Scan(&id); scanErr != nil {
			rows.Close()
			logger.Error("reap_stuck_sessions: scan failed", "error", scanErr)
			return scanErr
		}
		ids = append(ids, id)
	}
	rows.Close()
	if rerr := rows.Err(); rerr != nil {
		return rerr
	}

	for _, id := range ids {
		if uerr := updateSessionStatus(ctx, id, "FAILED"); uerr != nil {
			logger.Error("reap_stuck_sessions: mark FAILED failed", "session_id", id, "error", uerr)
			continue
		}
		if perr := publishSessionStatusChanged(ctx, id, "failed"); perr != nil {
			logger.Warn("reap_stuck_sessions: publish session.status_changed(failed) failed",
				"session_id", id, "error", perr)
		}
		logger.Warn("reap_stuck_sessions: session stuck past deadline → FAILED",
			"session_id", id, "deadline_hours", hours)
	}

	if len(ids) > 0 {
		logger.Info("reap_stuck_sessions: reaped stuck sessions", "count", len(ids))
	}
	return nil
}
