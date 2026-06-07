package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	slog.Info("Starting GDPR purger run")

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		dbUser := os.Getenv("DB_USER")
		dbPass := os.Getenv("DB_PASSWORD")
		dbHost := os.Getenv("DB_HOST")
		dbName := os.Getenv("DB_NAME")
		if dbUser != "" && dbPass != "" && dbHost != "" && dbName != "" {
			dbDSN = fmt.Sprintf("postgres://%s:%s@%s:5432/%s?sslmode=disable", dbUser, dbPass, dbHost, dbName)
		}
	}

	if dbDSN == "" {
		slog.Error("DATABASE_URL (or DB_USER/PASS/HOST/NAME) is required")
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	poolCfg, err := pgxpool.ParseConfig(dbDSN)
	if err != nil {
		slog.Error("Failed to parse database DSN", "error", err)
		os.Exit(1)
	}
	poolCfg.MaxConns = 2
	poolCfg.MinConns = 1

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		slog.Error("Failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := runPurge(ctx, pool); err != nil {
		slog.Error("Purger execution failed", "error", err)
		os.Exit(1)
	}

	slog.Info("GDPR purger run completed successfully")
}

func runPurge(ctx context.Context, pool *pgxpool.Pool) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	qtx := db.New(tx)

	// 1. Get all expired users, files, sessions, and notes
	expiredUsers, err := qtx.GetExpiredPatientUsers(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch expired users: %w", err)
	}

	expiredFiles, err := qtx.GetExpiredPatientFiles(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch expired patient files: %w", err)
	}

	expiredSessions, err := qtx.GetExpiredSessions(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch expired sessions: %w", err)
	}

	expiredNotes, err := qtx.GetExpiredPatientNotes(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch expired notes: %w", err)
	}

	slog.Info("Expired records found",
		"users_count", len(expiredUsers),
		"files_count", len(expiredFiles),
		"sessions_count", len(expiredSessions),
		"notes_count", len(expiredNotes),
	)

	var (
		usersPurged    int64
		filesPurged    int64
		sessionsPurged int64
		notesPurged    int64
	)

	// 2. Purge patient users
	// This will cascade delete their associated patient files, sessions, notes, etc.
	for _, userID := range expiredUsers {
		rows, err := qtx.PurgePatientUser(ctx, userID)
		if err != nil {
			return fmt.Errorf("failed to purge patient user %s: %w", userID, err)
		}
		usersPurged += rows
	}

	// 3. Purge patient files (e.g. pseudonymous files that don't have a user,
	// or those that weren't cascade-deleted for some reason)
	for _, file := range expiredFiles {
		// If the file has a linked patient_id user, we already purged (or should have purged) the user.
		// If it's a patient file without a user, we purge it here.
		rows, err := qtx.PurgePatientFile(ctx, file.ID)
		if err != nil {
			return fmt.Errorf("failed to purge patient file %s: %w", file.ID, err)
		}
		filesPurged += rows
	}

	// 4. Purge sessions that were soft-deleted individually
	for _, sessID := range expiredSessions {
		rows, err := qtx.PurgeSession(ctx, sessID)
		if err != nil {
			return fmt.Errorf("failed to purge session %s: %w", sessID, err)
		}
		sessionsPurged += rows
	}

	// 5. Purge notes that were soft-deleted individually
	for _, noteID := range expiredNotes {
		rows, err := qtx.PurgePatientNote(ctx, noteID)
		if err != nil {
			return fmt.Errorf("failed to purge note %s: %w", noteID, err)
		}
		notesPurged += rows
	}

	// 6. Purge old analytics events (older than 90 days)
	analyticsPurged, err := qtx.PurgeOldAnalyticsEvents(ctx)
	if err != nil {
		return fmt.Errorf("failed to purge old analytics events: %w", err)
	}

	// 7. Write one aggregate audit event
	metadataMap := map[string]any{
		"purged_patient_users":    usersPurged,
		"purged_patient_files":    filesPurged,
		"purged_sessions":         sessionsPurged,
		"purged_patient_notes":    notesPurged,
		"purged_analytics_events": analyticsPurged,
	}
	metadataJSON, err := json.Marshal(metadataMap)
	if err != nil {
		return fmt.Errorf("failed to marshal audit metadata: %w", err)
	}

	err = qtx.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		ActorUserID:    pgtype.UUID{Valid: false},
		OrganizationID: pgtype.UUID{Valid: false},
		Action:         "purger.run",
		ResourceType:   "system",
		ResourceID:     pgtype.UUID{Valid: false},
		Metadata:       metadataJSON,
	})
	if err != nil {
		return fmt.Errorf("failed to create audit event: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	slog.Info("Successfully purged expired records",
		"users_purged", usersPurged,
		"files_purged", filesPurged,
		"sessions_purged", sessionsPurged,
		"notes_purged", notesPurged,
		"analytics_purged", analyticsPurged,
	)

	return nil
}
