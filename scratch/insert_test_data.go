package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		panic("DATABASE_URL is required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		panic(err)
	}
	defer pool.Close()

	// Insert therapist (user)
	var therapistID string
	err = pool.QueryRow(ctx, `
		INSERT INTO users (role, firebase_uid, email, first_name, last_name, has_accepted_tos) 
		VALUES ('THERAPIST', 'test-firebase-uid-1', 'test@superwizor.ai', 'Test', 'Therapist', true) 
		ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email 
		RETURNING id;
	`).Scan(&therapistID)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Therapist ID: %s\n", therapistID)

	// Get a modality ID
	var modalityID string
	err = pool.QueryRow(ctx, `SELECT id FROM modalities LIMIT 1`).Scan(&modalityID)
	if err != nil {
		panic(err)
	}
    fmt.Printf("Modality ID: %s\n", modalityID)

	// Insert patient file
	var patientFileID string
	err = pool.QueryRow(ctx, `
		INSERT INTO patient_files (therapist_id, modality_id, working_alias) 
		VALUES ($1, $2, 'Pacjent Testowy') 
		RETURNING id;
	`, therapistID, modalityID).Scan(&patientFileID)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Patient File ID: %s\n", patientFileID)
}
