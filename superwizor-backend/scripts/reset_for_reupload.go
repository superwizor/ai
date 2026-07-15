package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	sessionIDStr := "5b69c912-bb68-41f5-9eab-9a6c1e024809"
	sessionUUID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		log.Fatalf("Invalid session UUID: %v", err)
	}

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		log.Fatal("DATABASE_URL env var is required")
	}

	ctx := context.Background()
	dbPool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()

	// 1. Get audio upload ID
	var audioUploadID uuid.UUID
	err = dbPool.QueryRow(ctx, "SELECT audio_upload_id FROM sessions WHERE id = $1", sessionUUID).Scan(&audioUploadID)
	if err != nil {
		log.Fatalf("Failed to get audio_upload_id: %v", err)
	}

	fmt.Printf("Resetting database for Session: %s, Upload: %s...\n", sessionUUID, audioUploadID)

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		log.Fatalf("Failed to start transaction: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Delete from stt_operations
	fmt.Println("Deleting old stt_operations...")
	_, err = tx.Exec(ctx, "DELETE FROM stt_operations WHERE session_id = $1", sessionUUID)
	if err != nil {
		log.Fatalf("Failed to delete stt_operations: %v", err)
	}

	// Delete from audio_chunks
	fmt.Println("Deleting old audio_chunks...")
	_, err = tx.Exec(ctx, "DELETE FROM audio_chunks WHERE audio_upload_id = $1", audioUploadID)
	if err != nil {
		log.Fatalf("Failed to delete audio_chunks: %v", err)
	}

	// Reset audio_uploads
	fmt.Println("Resetting audio_uploads row to PENDING...")
	_, err = tx.Exec(ctx, `
		UPDATE audio_uploads 
		SET status = 'PENDING', 
		    duration_seconds = NULL, 
		    file_size_bytes = NULL, 
		    error_message = NULL,
		    upload_completed_at = NULL
		WHERE id = $1`, audioUploadID)
	if err != nil {
		log.Fatalf("Failed to reset audio_uploads: %v", err)
	}

	// Reset sessions
	fmt.Println("Resetting sessions row to PENDING_UPLOAD...")
	_, err = tx.Exec(ctx, `
		UPDATE sessions 
		SET status = 'PENDING_UPLOAD', 
		    duration_seconds = NULL, 
		    error_message = NULL,
		    status_updated_at = NOW()
		WHERE id = $1`, sessionUUID)
	if err != nil {
		log.Fatalf("Failed to reset sessions: %v", err)
	}

	err = tx.Commit(ctx)
	if err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}

	fmt.Println("🎉 Database reset completed successfully!")
}
