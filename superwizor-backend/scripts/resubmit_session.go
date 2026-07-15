package main

import (
	"context"
	"fmt"
	"log"
	"os"

	speech "cloud.google.com/go/speech/apiv2"
	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/option"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run scripts/resubmit_session.go <session_id>")
	}
	sessionIDStr := os.Args[1]
	sessionUUID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		log.Fatalf("Invalid session UUID: %v", err)
	}

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		log.Fatal("DATABASE_URL env var is required")
	}

	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID == "" {
		projectID = "superwizor-ai-25ecd"
	}
	transcriptsRawBkt := os.Getenv("TRANSCRIPTS_RAW_BUCKET")
	if transcriptsRawBkt == "" {
		transcriptsRawBkt = "superwizor-ai-25ecd-transcripts-raw"
	}

	ctx := context.Background()
	dbPool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()

	// 1. Get session details, particularly language_code and audio_upload details
	fmt.Printf("🔍 Loading session and audio upload info for %s...\n", sessionUUID)
	var languageCode string
	var status string
	var audioUploadID uuid.UUID
	err = dbPool.QueryRow(ctx, "SELECT status, audio_upload_id, COALESCE(language_code, 'pl-PL') FROM sessions WHERE id = $1", sessionUUID).
		Scan(&status, &audioUploadID, &languageCode)
	if err != nil {
		log.Fatalf("Failed to get session: %v", err)
	}
	fmt.Printf("Session status: %s | Language: %s | Upload ID: %s\n", status, languageCode, audioUploadID)

	var bucketName, objectPath string
	err = dbPool.QueryRow(ctx, "SELECT bucket_name, object_path FROM audio_uploads WHERE id = $1", audioUploadID).
		Scan(&bucketName, &objectPath)
	if err != nil {
		log.Fatalf("Failed to get audio upload: %v", err)
	}
	gcsURI := fmt.Sprintf("gs://%s/%s", bucketName, objectPath)
	fmt.Printf("Audio GCS URI: %s\n", gcsURI)

	// 2. Initialize Speech Client with EU endpoint
	fmt.Println("🚀 Connecting to Speech-to-Text API (EU Endpoint)...")
	speechClient, err := speech.NewClient(ctx, option.WithEndpoint("eu-speech.googleapis.com:443"))
	if err != nil {
		log.Fatalf("Failed to create speech client: %v", err)
	}
	defer speechClient.Close()

	// 3. Submit BatchRecognize request
	outputPrefix := fmt.Sprintf("gs://%s/%s/chunk_0/", transcriptsRawBkt, sessionUUID.String())
	fmt.Printf("Submitting Speech-to-Text BatchRecognize job...\nOutput GCS Prefix: %s\n", outputPrefix)

	// We use standard batching to bypass any 20-minute limitations on DYNAMIC_BATCHING
	req := &speechpb.BatchRecognizeRequest{
		Recognizer: fmt.Sprintf("projects/%s/locations/eu/recognizers/_", projectID),
		ProcessingStrategy: speechpb.BatchRecognizeRequest_PROCESSING_STRATEGY_UNSPECIFIED, // Standard tier
		Config: &speechpb.RecognitionConfig{
			DecodingConfig: &speechpb.RecognitionConfig_AutoDecodingConfig{
				AutoDecodingConfig: &speechpb.AutoDetectDecodingConfig{},
			},
			Model:         "chirp_3",
			LanguageCodes: []string{languageCode},
			Features: &speechpb.RecognitionFeatures{
				EnableAutomaticPunctuation: true,
				EnableWordTimeOffsets:      true,
			},
		},
		Files: []*speechpb.BatchRecognizeFileMetadata{
			{AudioSource: &speechpb.BatchRecognizeFileMetadata_Uri{Uri: gcsURI}},
		},
		RecognitionOutputConfig: &speechpb.RecognitionOutputConfig{
			Output: &speechpb.RecognitionOutputConfig_GcsOutputConfig{
				GcsOutputConfig: &speechpb.GcsOutputConfig{
					Uri: outputPrefix,
				},
			},
		},
	}

	op, err := speechClient.BatchRecognize(ctx, req)
	if err != nil {
		log.Fatalf("BatchRecognize call failed: %v", err)
	}
	opName := op.Name()
	fmt.Printf("STT Operation started: %s\n", opName)

	// 4. Update database (in a single transaction)
	tx, err := dbPool.Begin(ctx)
	if err != nil {
		log.Fatalf("Failed to start transaction: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Delete existing stt_operations rows for this session
	fmt.Println("Deleting old stt_operations rows...")
	_, err = tx.Exec(ctx, "DELETE FROM stt_operations WHERE session_id = $1", sessionUUID)
	if err != nil {
		log.Fatalf("Failed to delete old stt_operations: %v", err)
	}

	// Insert new stt_operation row
	fmt.Println("Inserting new stt_operations row...")
	_, err = tx.Exec(ctx, `
		INSERT INTO stt_operations (
			session_id, chunk_index, chunk_count, start_offset_ms,
			operation_id, gcs_output_uri,
			language_code, used_native_diarization, source_audio_uri
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		sessionUUID, 0, 1, 0,
		opName, outputPrefix,
		languageCode, false, gcsURI,
	)
	if err != nil {
		log.Fatalf("Failed to insert stt_operation: %v", err)
	}

	// Reset session status to TRANSCRIBING
	fmt.Println("Resetting session status to TRANSCRIBING...")
	_, err = tx.Exec(ctx, "UPDATE sessions SET status = 'TRANSCRIBING', error_message = NULL, status_updated_at = NOW() WHERE id = $1", sessionUUID)
	if err != nil {
		log.Fatalf("Failed to reset session status: %v", err)
	}

	err = tx.Commit(ctx)
	if err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}

	fmt.Println("🎉 Database updated successfully!")
	fmt.Println("Wait for GCP to finish transcription. Eventarc should trigger stt-finalize automatically when output lands on GCS.")
}
