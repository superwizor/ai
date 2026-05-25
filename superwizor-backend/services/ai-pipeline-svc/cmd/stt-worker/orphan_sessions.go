package sttworker

// orphan_sessions.go — periodic cleanup of orphan PENDING_UPLOAD
// session rows. Option E (2026-05-25), see
// docs/14_INGESTION_EARLY_SESSION_CREATION.md.
//
// Failure mode this addresses: ingestion-svc.CreateAudioUpload now
// creates a sessions row in PENDING_UPLOAD status immediately, so
// the patient kartoteka can render it. If the upload then dies
// before CompleteAudioUpload (Flutter app force-killed mid-upload
// AND Hive box lost — uninstall, device wipe), the session row
// stays in PENDING_UPLOAD forever. The therapist sees a phantom
// "Oczekiwanie na audio…" entry that never advances.
//
// Cleanup criteria — ALL must be true:
//   - sessions.status = 'PENDING_UPLOAD'
//   - sessions.created_at < now() - 1 hour (debounce — Flutter's
//     queue is given a full hour to recover before we touch this)
//   - sessions has no linked transcript (transcripts.session_id
//     IS NULL for this id)
//   - the linked audio_uploads row's upload_completed_at IS NULL
//     (no PUT confirmed yet — anything that PUT successfully has
//     transitioned out of PENDING_UPLOAD via CompleteAudioUpload
//     or will via the recovery path)
//
// The cleanup CASCADE-deletes BOTH the sessions row and its
// audio_uploads row (mirrors the user's design-doc recommendation
// to avoid orphan references). The transcripts FK uses ON DELETE
// SET NULL so historical transcripts (none in this case) wouldn't
// be affected.

import (
	"context"
	"log/slog"
)

// runOrphanSessionCleanup is invoked from ProcessWatchdog alongside
// the existing stt_operations rescue scan. Same HTTP handler, same
// Cloud Scheduler tick (every 15 min), same SA — no new Terraform
// needed.
//
// Always returns nil — errors are logged but don't fail the HTTP
// response; the next tick will retry the scan.
func runOrphanSessionCleanup(ctx context.Context, logger *slog.Logger) error {
	if dbPool == nil {
		logger.Warn("orphan_session_cleanup: dbPool nil (mock mode); skipping")
		return nil
	}

	// One CTE deletes both rows in a single round-trip and reports
	// the IDs so we can log a count. ON DELETE SET NULL on
	// sessions.audio_upload_id means deleting the audio_uploads row
	// first would null the column; we delete the session first so
	// the audio_uploads row is identifiable via the same WHERE
	// clause. Subquery yields the audio_upload_id we need to clean
	// up alongside.
	tag, err := dbPool.Exec(ctx, `
		WITH targets AS (
			SELECT s.id AS session_id, s.audio_upload_id
			FROM sessions s
			LEFT JOIN audio_uploads au ON au.id = s.audio_upload_id
			LEFT JOIN transcripts t   ON t.session_id = s.id
			WHERE s.status = 'PENDING_UPLOAD'
			  AND s.created_at < now() - interval '1 hour'
			  AND s.deleted_at IS NULL
			  AND t.id IS NULL
			  AND (au.id IS NULL OR au.upload_completed_at IS NULL)
		),
		del_sessions AS (
			DELETE FROM sessions
			WHERE id IN (SELECT session_id FROM targets)
		)
		DELETE FROM audio_uploads
		WHERE id IN (SELECT audio_upload_id FROM targets WHERE audio_upload_id IS NOT NULL)
	`)
	if err != nil {
		logger.Error("orphan_session_cleanup failed", "error", err)
		return err
	}
	if affected := tag.RowsAffected(); affected > 0 {
		logger.Info("orphan_session_cleanup: removed orphan audio_uploads",
			"audio_uploads_deleted", affected)
	}
	return nil
}
