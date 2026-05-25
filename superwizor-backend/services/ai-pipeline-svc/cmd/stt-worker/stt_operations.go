package sttworker

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5/pgconn"
)

// sttOpRow is the read-side projection of a stt_operations row,
// optionally enriched with the matching audio_chunks columns
// (seam_offset_ms, end_offset_ms, overlap_ms) when loaded for the
// merger. Single-chunk Stage 1 sessions have all three at zero.
type sttOpRow struct {
	ID                    uuid.UUID
	SessionID             uuid.UUID
	ChunkIndex            int
	ChunkCount            int
	StartOffsetMS         int64
	SeamOffsetMS          int64 // Stage 2 only; 0 when no audio_chunks row
	EndOffsetMS           int64 // Stage 2 only; 0 when no audio_chunks row
	OverlapMS             int   // Stage 2 only; 0 for chunk 0 OR Stage 1
	OperationID           string
	GCSOutputURI          string
	LanguageCode          string
	UsedNativeDiarization bool
	// FinalizedAt is nil when the row is still pending.
	FinalizedAt   any // *time.Time on the wire; finalize only reads NULL/NOT-NULL state
	FinalizeError *string
}

// insertSTTOpParams is the write payload for a new stt_operations row.
type insertSTTOpParams struct {
	SessionID             uuid.UUID
	ChunkIndex            int
	ChunkCount            int
	StartOffsetMS         int64
	OperationID           string
	GCSOutputURI          string
	LanguageCode          string
	UsedNativeDiarization bool
}

// insertSTTOperation persists the submit record. Returns a unique-
// violation sentinel when (session_id, chunk_index) is already present
// — the caller treats that as "another worker won the submit race"
// and silently continues.
func insertSTTOperation(ctx context.Context, p insertSTTOpParams) error {
	if dbPool == nil {
		return nil
	}
	_, err := dbPool.Exec(ctx, `
		INSERT INTO stt_operations (
			session_id, chunk_index, chunk_count, start_offset_ms,
			operation_id, gcs_output_uri,
			language_code, used_native_diarization
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		p.SessionID, p.ChunkIndex, p.ChunkCount, p.StartOffsetMS,
		p.OperationID, p.GCSOutputURI,
		p.LanguageCode, p.UsedNativeDiarization,
	)
	return err
}

// loadSubmittedChunks returns the chunk_index set for which a row
// already exists for this session. Lets ProcessAudio skip chunks
// that an earlier (now-redelivered) Pub/Sub event already submitted.
func loadSubmittedChunks(ctx context.Context, sessionID uuid.UUID) (map[int]bool, error) {
	out := map[int]bool{}
	if dbPool == nil {
		return out, nil
	}
	rows, err := dbPool.Query(ctx, `
		SELECT chunk_index FROM stt_operations WHERE session_id = $1`,
		sessionID)
	if err != nil {
		return nil, fmt.Errorf("loadSubmittedChunks: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var idx int
		if err := rows.Scan(&idx); err != nil {
			return nil, err
		}
		out[idx] = true
	}
	return out, rows.Err()
}

// markChunkFinalized flips finalized_at = now() for a single chunk
// row, returning the affected row count. Used by stt-finalize at
// OBJECT_FINALIZE entry — the `finalized_at IS NULL` guard makes
// re-deliveries no-ops (returns 0).
func markChunkFinalized(ctx context.Context, sessionID uuid.UUID, chunkIndex int) (int64, error) {
	if dbPool == nil {
		return 0, nil
	}
	tag, err := dbPool.Exec(ctx, `
		UPDATE stt_operations
		SET finalized_at = now()
		WHERE session_id = $1 AND chunk_index = $2 AND finalized_at IS NULL`,
		sessionID, chunkIndex)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// countPendingChunks returns how many chunks for the session still
// have finalized_at IS NULL. stt-finalize's merger waits until this
// is zero before acquiring the merge lock.
func countPendingChunks(ctx context.Context, sessionID uuid.UUID) (int, error) {
	if dbPool == nil {
		return 0, nil
	}
	var n int
	err := dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM stt_operations
		WHERE session_id = $1 AND finalized_at IS NULL`,
		sessionID).Scan(&n)
	return n, err
}

// loadOperationsForSession returns all stt_operations rows for the
// session in chunk_index order, enriched with the matching
// audio_chunks columns (seam/end/overlap) so the merger has all
// the offsets it needs to do cross-chunk alignment.
//
// The LEFT JOIN through sessions → audio_uploads → audio_chunks
// keeps Stage 1 sessions (no audio_chunks row) returning zeroed
// seam/end/overlap — the merger's len(parts)==1 branch then
// degenerates to the passthrough path.
func loadOperationsForSession(ctx context.Context, sessionID uuid.UUID) ([]sttOpRow, error) {
	if dbPool == nil {
		return nil, nil
	}
	rows, err := dbPool.Query(ctx, `
		SELECT op.id, op.chunk_index, op.chunk_count, op.start_offset_ms,
		       op.operation_id, op.gcs_output_uri,
		       op.language_code, op.used_native_diarization, op.finalize_error,
		       COALESCE(ch.seam_offset_ms, 0) AS seam_offset_ms,
		       COALESCE(ch.end_offset_ms, 0)  AS end_offset_ms,
		       COALESCE(ch.overlap_ms, 0)     AS overlap_ms
		FROM stt_operations op
		JOIN sessions s ON s.id = op.session_id
		LEFT JOIN audio_chunks ch
		       ON ch.audio_upload_id = s.audio_upload_id
		      AND ch.chunk_index    = op.chunk_index
		WHERE op.session_id = $1
		ORDER BY op.chunk_index`,
		sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []sttOpRow
	for rows.Next() {
		var r sttOpRow
		r.SessionID = sessionID
		if err := rows.Scan(
			&r.ID, &r.ChunkIndex, &r.ChunkCount, &r.StartOffsetMS,
			&r.OperationID, &r.GCSOutputURI,
			&r.LanguageCode, &r.UsedNativeDiarization, &r.FinalizeError,
			&r.SeamOffsetMS, &r.EndOffsetMS, &r.OverlapMS,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// recordFinalizeError stamps a chunk row with the terminal error
// string for ops inspection. Best-effort — failures don't block the
// session-status FAILED write.
func recordFinalizeError(ctx context.Context, sessionID uuid.UUID, chunkIndex int, msg string) {
	if dbPool == nil {
		return
	}
	_, _ = dbPool.Exec(ctx, `
		UPDATE stt_operations
		SET finalize_error = $3
		WHERE session_id = $1 AND chunk_index = $2`,
		sessionID, chunkIndex, msg)
}

// isUniqueViolation reports whether err is a Postgres unique-
// constraint violation (SQLSTATE 23505). Used to distinguish the
// concurrent-submit race (drop and continue) from other DB errors.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation
}

// loadPendingOperations returns stt_operations rows submitted >
// thresholdSeconds ago that still have finalized_at IS NULL. The
// watchdog consults this list to detect stuck operations.
func loadPendingOperations(ctx context.Context, thresholdSeconds int) ([]sttOpRow, error) {
	if dbPool == nil {
		return nil, nil
	}
	rows, err := dbPool.Query(ctx, `
		SELECT id, session_id, chunk_index, chunk_count, start_offset_ms,
		       operation_id, gcs_output_uri,
		       language_code, used_native_diarization, finalize_error
		FROM stt_operations
		WHERE finalized_at IS NULL
		  AND submitted_at < now() - make_interval(secs => $1)`,
		thresholdSeconds)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []sttOpRow
	for rows.Next() {
		var r sttOpRow
		if err := rows.Scan(
			&r.ID, &r.SessionID, &r.ChunkIndex, &r.ChunkCount, &r.StartOffsetMS,
			&r.OperationID, &r.GCSOutputURI,
			&r.LanguageCode, &r.UsedNativeDiarization, &r.FinalizeError,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
