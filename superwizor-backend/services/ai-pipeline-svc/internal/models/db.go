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

func (db *DB) SaveTranscript(ctx context.Context, patientFileID uuid.UUID, gcsURI string, transcriptText string) (uuid.UUID, error) {
	var id uuid.UUID
	err := db.pool.QueryRow(ctx, `
		INSERT INTO transcripts (patient_file_id, audio_gcs_uri, transcript_ciphertext)
		VALUES ($1, $2, $3)
		RETURNING id
	`, patientFileID, gcsURI, transcriptText).Scan(&id)
	return id, err
}

func (db *DB) SaveReport(ctx context.Context, patientFileID uuid.UUID, transcriptID uuid.UUID, reportText string) (uuid.UUID, error) {
	var id uuid.UUID
	// default inference for now empty JSON {}
	err := db.pool.QueryRow(ctx, `
		INSERT INTO reports (patient_file_id, transcript_id, content_ciphertext, speaker_role_inference, status, created_at)
		VALUES ($1, $2, $3, '{}', 'COMPLETED', $4)
		RETURNING id
	`, patientFileID, transcriptID, reportText, time.Now()).Scan(&id)
	return id, err
}
