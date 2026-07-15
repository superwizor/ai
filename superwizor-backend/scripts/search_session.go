package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
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

	// 1. Search for user matching Magdalena Janta
	fmt.Println("=== Searching for User 'Magdalena Janta' ===")
	rows, err := dbPool.Query(ctx, "SELECT id, email, first_name, last_name, firebase_uid, created_at FROM users WHERE first_name ILIKE '%Magdalena%' OR last_name ILIKE '%Janta%'")
	if err != nil {
		log.Fatalf("Failed to query users: %v", err)
	}
	defer rows.Close()

	var therapistIDs []string
	for rows.Next() {
		var id, email, firstName, lastName, firebaseUID string
		var createdAt time.Time
		if err := rows.Scan(&id, &email, &firstName, &lastName, &firebaseUID, &createdAt); err != nil {
			log.Fatalf("Failed to scan user row: %v", err)
		}
		fmt.Printf("Therapist ID: %s | Email: %s | Name: %s %s | Firebase UID: %s | Created: %s\n", id, email, firstName, lastName, firebaseUID, createdAt.Format(time.RFC3339))
		therapistIDs = append(therapistIDs, id)
	}

	if len(therapistIDs) == 0 {
		fmt.Println("No matching users found.")
		return
	}

	// 2. Query sessions and audio uploads for each therapist ID
	for _, therapistID := range therapistIDs {
		fmt.Printf("\n=== Sessions for Therapist %s (Last 3 Days) ===\n", therapistID)
		
		sessionRows, err := dbPool.Query(ctx, `
			SELECT s.id, s.patient_file_id, s.audio_upload_id, s.session_date, s.session_number, s.duration_seconds, s.status, COALESCE(s.error_message, ''), s.created_at, pf.working_alias
			FROM sessions s
			LEFT JOIN patient_files pf ON s.patient_file_id = pf.id
			WHERE s.therapist_id = $1 AND s.id = '5b69c912-bb68-41f5-9eab-9a6c1e024809'
			ORDER BY s.created_at DESC`, therapistID)
		if err != nil {
			log.Fatalf("Failed to query sessions: %v", err)
		}
		
		for sessionRows.Next() {
			var id, patientFileID string
			var audioUploadID *string
			var sessionDate time.Time
			var sessionNumber int
			var durationSeconds *int
			var status, errorMsg string
			var createdAt time.Time
			var pfAlias *string
			
			if err := sessionRows.Scan(&id, &patientFileID, &audioUploadID, &sessionDate, &sessionNumber, &durationSeconds, &status, &errorMsg, &createdAt, &pfAlias); err != nil {
				sessionRows.Close()
				log.Fatalf("Failed to scan session row: %v", err)
			}
			
			durStr := "NULL"
			if durationSeconds != nil {
				durStr = fmt.Sprintf("%d s", *durationSeconds)
			}
			audUpIDStr := "NULL"
			if audioUploadID != nil {
				audUpIDStr = *audioUploadID
			}
			pfName := "Unknown"
			if pfAlias != nil {
				pfName = *pfAlias
			}
			
			fmt.Printf("Session ID: %s | Patient: %s | Date: %s | Num: %d | Duration: %s | Status: %s | Error: %s | Created: %s | AudioUploadID: %s\n",
				id, pfName, sessionDate.Format("2006-01-02"), sessionNumber, durStr, status, errorMsg, createdAt.Format(time.RFC3339), audUpIDStr)

			// Query stt_operations for this session
			opRows, err := dbPool.Query(ctx, `
				SELECT chunk_index, chunk_count, start_offset_ms, operation_id, gcs_output_uri, language_code, used_native_diarization, COALESCE(finalize_error, ''), submitted_at, finalized_at
				FROM stt_operations
				WHERE session_id = $1
				ORDER BY chunk_index ASC`, id)
			if err != nil {
				log.Fatalf("Failed to query stt_operations: %v", err)
			}
			for opRows.Next() {
				var chunkIndex, chunkCount int
				var startOffsetMS int64
				var operationID, gcsOutputURI, languageCode string
				var usedNativeDiarization bool
				var finalizeError string
				var submittedAt time.Time
				var finalizedAt *time.Time

				if err := opRows.Scan(&chunkIndex, &chunkCount, &startOffsetMS, &operationID, &gcsOutputURI, &languageCode, &usedNativeDiarization, &finalizeError, &submittedAt, &finalizedAt); err != nil {
					opRows.Close()
					log.Fatalf("Failed to scan stt_operation: %v", err)
				}
				finAtStr := "NULL"
				if finalizedAt != nil {
					finAtStr = (*finalizedAt).Format(time.RFC3339)
				}
				fmt.Printf("   -> STT Op: Chunk %d/%d | Offset: %d ms | OpID: %s | Output: %s | Lang: %s | Diar: %v | Err: %s | Submitted: %s | Finalized: %s\n",
					chunkIndex, chunkCount, startOffsetMS, operationID, gcsOutputURI, languageCode, usedNativeDiarization, finalizeError, submittedAt.Format(time.RFC3339), finAtStr)
			}
			opRows.Close()
		}
		sessionRows.Close()

		fmt.Printf("\n=== Audio Uploads for Therapist %s (Last 3 Days) ===\n", therapistID)
		uploadRows, err := dbPool.Query(ctx, `
			SELECT id, session_id, bucket_name, object_path, content_type, file_size_bytes, duration_seconds, status, COALESCE(error_message, ''), created_at, expires_at
			FROM audio_uploads
			WHERE therapist_id = $1 AND created_at >= NOW() - INTERVAL '3 days'
			ORDER BY created_at DESC`, therapistID)
		if err != nil {
			log.Fatalf("Failed to query audio uploads: %v", err)
		}
		
		for uploadRows.Next() {
			var id string
			var sessionID *string
			var bucketName, objectPath, contentType string
			var fileSizeBytes, durationSeconds *int64
			var status, errorMsg string
			var createdAt, expiresAt time.Time
			
			if err := uploadRows.Scan(&id, &sessionID, &bucketName, &objectPath, &contentType, &fileSizeBytes, &durationSeconds, &status, &errorMsg, &createdAt, &expiresAt); err != nil {
				uploadRows.Close()
				log.Fatalf("Failed to scan upload row: %v", err)
			}
			
			sessIDStr := "NULL"
			if sessionID != nil {
				sessIDStr = *sessionID
			}
			szStr := "NULL"
			if fileSizeBytes != nil {
				szStr = fmt.Sprintf("%d bytes", *fileSizeBytes)
			}
			durStr := "NULL"
			if durationSeconds != nil {
				durStr = fmt.Sprintf("%d s", *durationSeconds)
			}
			
			fmt.Printf("Upload ID: %s | SessID: %s | GCS: gs://%s/%s | Status: %s | Size: %s | Dur: %s | Error: %s | Created: %s | Expires: %s\n",
				id, sessIDStr, bucketName, objectPath, status, szStr, durStr, errorMsg, createdAt.Format(time.RFC3339), expiresAt.Format(time.RFC3339))
		}
		uploadRows.Close()
	}
}
