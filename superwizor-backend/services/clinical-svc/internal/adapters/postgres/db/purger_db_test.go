package db

import (
	"context"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIntegration_PurgerQueries(t *testing.T) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("Skipping DB integration test: DATABASE_URL is not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	require.NoError(t, err)
	defer pool.Close()

	// Begin a transaction to ensure zero-pollution and isolated runs
	tx, err := pool.Begin(ctx)
	require.NoError(t, err)
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	q := New(tx)

	// Create a mock therapist user
	therapistID := uuid.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO users (id, role, first_name, last_name, ui_language, timezone, has_accepted_tos, firebase_uid, email)
		VALUES ($1, 'THERAPIST', 'Therapist', 'PurgerTest', 'pl', 'Europe/Warsaw', true, $2, $3)
	`, therapistID, "purger_therapist_uid_"+uuid.New().String()[:8], "purger_therapist_"+uuid.New().String()[:8]+"@example.com")
	require.NoError(t, err)

	// Create a mock modality
	modalityID := uuid.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO modalities (id, system_code, display_name, therapist_ai_general_prompt, therapist_ai_section_prompts, patient_ai_general_prompt, patient_ai_section_prompts, is_supported, modality_type)
		VALUES ($1, $2, 'CBT Test', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, true, 'therapy')
	`, modalityID, "CBT_PURGE_"+uuid.New().String()[:8])
	require.NoError(t, err)

	// --- Setup Expired and Non-Expired Patient Users ---
	expiredUserID := uuid.New()
	nonExpiredUserID := uuid.New()
	activeUserID := uuid.New()

	// Expired user (deleted 31 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO users (id, role, first_name, last_name, ui_language, deleted_at)
		VALUES ($1, 'PATIENT', 'Expired', 'User', 'pl', NOW() - INTERVAL '31 days')
	`, expiredUserID)
	require.NoError(t, err)

	// Non-expired user (deleted 10 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO users (id, role, first_name, last_name, ui_language, deleted_at)
		VALUES ($1, 'PATIENT', 'NonExpired', 'User', 'pl', NOW() - INTERVAL '10 days')
	`, nonExpiredUserID)
	require.NoError(t, err)

	// Active patient user (not deleted)
	_, err = tx.Exec(ctx, `
		INSERT INTO users (id, role, first_name, last_name, ui_language)
		VALUES ($1, 'PATIENT', 'Active', 'User', 'pl')
	`, activeUserID)
	require.NoError(t, err)

	// --- Setup Expired and Non-Expired Patient Files ---
	expiredFileID := uuid.New()
	nonExpiredFileID := uuid.New()
	activeFileID := uuid.New()

	// Expired patient file (linked to expired user, soft deleted 31 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO patient_files (id, therapist_id, patient_id, working_alias, modality_id, process_type, deleted_at)
		VALUES ($1, $2, $3, 'ExpiredFile', $4, 'INDIVIDUAL', NOW() - INTERVAL '31 days')
	`, expiredFileID, therapistID, expiredUserID, modalityID)
	require.NoError(t, err)

	// Non-expired patient file (linked to non-expired user, soft deleted 10 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO patient_files (id, therapist_id, patient_id, working_alias, modality_id, process_type, deleted_at)
		VALUES ($1, $2, $3, 'NonExpiredFile', $4, 'INDIVIDUAL', NOW() - INTERVAL '10 days')
	`, nonExpiredFileID, therapistID, nonExpiredUserID, modalityID)
	require.NoError(t, err)

	// Active patient file (linked to active user, not deleted)
	_, err = tx.Exec(ctx, `
		INSERT INTO patient_files (id, therapist_id, patient_id, working_alias, modality_id, process_type)
		VALUES ($1, $2, $3, 'ActiveFile', $4, 'INDIVIDUAL')
	`, activeFileID, therapistID, activeUserID, modalityID)
	require.NoError(t, err)

	// --- Setup Expired and Non-Expired Sessions ---
	expiredSessID := uuid.New()
	nonExpiredSessID := uuid.New()
	activeSessID := uuid.New()

	// Expired session (under active file, soft deleted 31 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO sessions (id, patient_file_id, therapist_id, name, session_date, session_number, status, deleted_at)
		VALUES ($1, $2, $3, 'Expired Session', NOW(), 1, 'COMPLETED', NOW() - INTERVAL '31 days')
	`, expiredSessID, activeFileID, therapistID)
	require.NoError(t, err)

	// Non-expired session (under active file, soft deleted 10 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO sessions (id, patient_file_id, therapist_id, name, session_date, session_number, status, deleted_at)
		VALUES ($1, $2, $3, 'NonExpired Session', NOW(), 2, 'COMPLETED', NOW() - INTERVAL '10 days')
	`, nonExpiredSessID, activeFileID, therapistID)
	require.NoError(t, err)

	// Active session (under active file, not deleted)
	_, err = tx.Exec(ctx, `
		INSERT INTO sessions (id, patient_file_id, therapist_id, name, session_date, session_number, status)
		VALUES ($1, $2, $3, 'Active Session', NOW(), 3, 'COMPLETED')
	`, activeSessID, activeFileID, therapistID)
	require.NoError(t, err)

	// --- Setup Expired and Non-Expired Patient Notes ---
	expiredNoteID := uuid.New()
	nonExpiredNoteID := uuid.New()
	activeNoteID := uuid.New()

	// Expired patient note (under active file, soft deleted 31 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO patient_notes (id, patient_file_id, therapist_id, kind, title_ciphertext, title_encrypted_dek, text_ciphertext, text_encrypted_dek, deleted_at)
		VALUES ($1, $2, $3, 'FREE_NOTE', '\x01', '\x02', '\x03', '\x04', NOW() - INTERVAL '31 days')
	`, expiredNoteID, activeFileID, therapistID)
	require.NoError(t, err)

	// Non-expired patient note (under active file, soft deleted 10 days ago)
	_, err = tx.Exec(ctx, `
		INSERT INTO patient_notes (id, patient_file_id, therapist_id, kind, title_ciphertext, title_encrypted_dek, text_ciphertext, text_encrypted_dek, deleted_at)
		VALUES ($1, $2, $3, 'FREE_NOTE', '\x01', '\x02', '\x03', '\x04', NOW() - INTERVAL '10 days')
	`, nonExpiredNoteID, activeFileID, therapistID)
	require.NoError(t, err)

	// Active patient note (under active file, not deleted)
	_, err = tx.Exec(ctx, `
		INSERT INTO patient_notes (id, patient_file_id, therapist_id, kind, title_ciphertext, title_encrypted_dek, text_ciphertext, text_encrypted_dek)
		VALUES ($1, $2, $3, 'FREE_NOTE', '\x01', '\x02', '\x03', '\x04')
	`, activeNoteID, activeFileID, therapistID)
	require.NoError(t, err)

	// --- Setup Expired and Active Analytics Events ---
	expiredEventID := uuid.New()
	activeEventID := uuid.New()

	_, err = tx.Exec(ctx, `
		INSERT INTO analytics_events (id, event_name, occurred_at)
		VALUES ($1, 'test.expired_event', NOW() - INTERVAL '95 days')
	`, expiredEventID)
	require.NoError(t, err)

	_, err = tx.Exec(ctx, `
		INSERT INTO analytics_events (id, event_name, occurred_at)
		VALUES ($1, 'test.active_event', NOW() - INTERVAL '10 days')
	`, activeEventID)
	require.NoError(t, err)

	// --- 1. Test query list of expired users/files/sessions/notes ---
	t.Run("Retrieve expired users", func(t *testing.T) {
		users, err := q.GetExpiredPatientUsers(ctx)
		require.NoError(t, err)
		assert.Contains(t, users, expiredUserID)
		assert.NotContains(t, users, nonExpiredUserID)
		assert.NotContains(t, users, activeUserID)
	})

	t.Run("Retrieve expired patient files", func(t *testing.T) {
		files, err := q.GetExpiredPatientFiles(ctx)
		require.NoError(t, err)

		var ids []uuid.UUID
		for _, f := range files {
			ids = append(ids, f.ID)
		}
		assert.Contains(t, ids, expiredFileID)
		assert.NotContains(t, ids, nonExpiredFileID)
		assert.NotContains(t, ids, activeFileID)
	})

	t.Run("Retrieve expired sessions", func(t *testing.T) {
		sessions, err := q.GetExpiredSessions(ctx)
		require.NoError(t, err)
		assert.Contains(t, sessions, expiredSessID)
		assert.NotContains(t, sessions, nonExpiredSessID)
		assert.NotContains(t, sessions, activeSessID)
	})

	t.Run("Retrieve expired patient notes", func(t *testing.T) {
		notes, err := q.GetExpiredPatientNotes(ctx)
		require.NoError(t, err)
		assert.Contains(t, notes, expiredNoteID)
		assert.NotContains(t, notes, nonExpiredNoteID)
		assert.NotContains(t, notes, activeNoteID)
	})

	// --- 2. Test hard deleting expired records and cascading ---
	t.Run("Purge records successfully", func(t *testing.T) {
		// Purge the expired user, which should cascade delete the expired file
		rows, err := q.PurgePatientUser(ctx, expiredUserID)
		require.NoError(t, err)
		assert.Equal(t, int64(1), rows)

		// Check that the expired patient file is gone via cascade
		var count int64
		err = tx.QueryRow(ctx, "SELECT COUNT(*) FROM patient_files WHERE id = $1", expiredFileID).Scan(&count)
		require.NoError(t, err)
		assert.Equal(t, int64(0), count)

		// Purge individual expired session
		rows, err = q.PurgeSession(ctx, expiredSessID)
		require.NoError(t, err)
		assert.Equal(t, int64(1), rows)

		// Purge individual expired note
		rows, err = q.PurgePatientNote(ctx, expiredNoteID)
		require.NoError(t, err)
		assert.Equal(t, int64(1), rows)

		// Purge old analytics events
		analyticsPurged, err := q.PurgeOldAnalyticsEvents(ctx)
		require.NoError(t, err)
		assert.Equal(t, int64(1), analyticsPurged)

		// Check that expired event is gone
		var eventCount int64
		err = tx.QueryRow(ctx, "SELECT COUNT(*) FROM analytics_events WHERE id = $1", expiredEventID).Scan(&eventCount)
		require.NoError(t, err)
		assert.Equal(t, int64(0), eventCount)

		// Check that active event is still there
		err = tx.QueryRow(ctx, "SELECT COUNT(*) FROM analytics_events WHERE id = $1", activeEventID).Scan(&eventCount)
		require.NoError(t, err)
		assert.Equal(t, int64(1), eventCount)

		// Write a dummy audit event using pgtype.UUID
		err = q.CreateAuditEvent(ctx, CreateAuditEventParams{
			ActorUserID:    pgtype.UUID{Valid: false},
			OrganizationID: pgtype.UUID{Valid: false},
			Action:         "purger.run",
			ResourceType:   "system",
			ResourceID:     pgtype.UUID{Valid: false},
			Metadata:       []byte(`{"purged_patient_files": 1}`),
		})
		assert.NoError(t, err)
	})
}
