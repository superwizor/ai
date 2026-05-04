package models

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	pool *pgxpool.Pool
}

func NewDB(ctx context.Context, databaseURL string) (*DB, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to database: %v", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("database ping failed: %v", err)
	}

	return &DB{pool: pool}, nil
}

func (db *DB) Close() {
	db.pool.Close()
}

func (db *DB) SaveTranscript(ctx context.Context, sessionID uuid.UUID, languageCode string, sttModel string, transcriptCiphertext []byte, transcriptEncryptedDEK []byte) (uuid.UUID, error) {
	var id uuid.UUID
	err := db.pool.QueryRow(ctx, `
		INSERT INTO transcripts (session_id, language_code, stt_model, transcript_ciphertext, transcript_encrypted_dek)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, sessionID, languageCode, sttModel, transcriptCiphertext, transcriptEncryptedDEK).Scan(&id)
	return id, err
}

func (db *DB) SaveReport(ctx context.Context, sessionID uuid.UUID, transcriptID uuid.UUID, modalityID uuid.UUID, reportCiphertext []byte, reportEncryptedDEK []byte, llmModel string) (uuid.UUID, error) {
	var id uuid.UUID
	err := db.pool.QueryRow(ctx, `
		INSERT INTO reports (session_id, transcript_id, modality_id, report_ciphertext, report_encrypted_dek, llm_model, speaker_role_inference, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, '{}', $7)
		RETURNING id
	`, sessionID, transcriptID, modalityID, reportCiphertext, reportEncryptedDEK, llmModel, time.Now()).Scan(&id)
	return id, err
}

func (db *DB) GetSessionContext(ctx context.Context, sessionID uuid.UUID) (patientFileID uuid.UUID, modalityID uuid.UUID, err error) {
	err = db.pool.QueryRow(ctx, `
		SELECT s.patient_file_id, pf.modality_id
		FROM sessions s
		JOIN patient_files pf ON pf.id = s.patient_file_id
		WHERE s.id = $1
	`, sessionID).Scan(&patientFileID, &modalityID)
	return
}

func (db *DB) GetModalityPrompt(ctx context.Context, modalityID uuid.UUID) (string, error) {
	var promptJSON []byte
	err := db.pool.QueryRow(ctx, `
		SELECT therapist_ai_general_prompt
		FROM modalities
		WHERE id = $1
	`, modalityID).Scan(&promptJSON)
	if err != nil {
		return "", err
	}
	return string(promptJSON), nil
}
