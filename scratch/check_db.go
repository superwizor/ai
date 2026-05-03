package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dbDSN := os.Getenv("DATABASE_URL")
	ctx := context.Background()
	pool, _ := pgxpool.New(ctx, dbDSN)
	defer pool.Close()

	var id, status, objectPath string
	err := pool.QueryRow(ctx, "SELECT id, status, object_path FROM audio_uploads ORDER BY created_at DESC LIMIT 1;").Scan(&id, &status, &objectPath)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	fmt.Printf("Upload ID: %s, Status: %s, Path: %s\n", id, status, objectPath)

    // Check sessions
    var sId, sStatus string
    err = pool.QueryRow(ctx, "SELECT id, status FROM sessions ORDER BY created_at DESC LIMIT 1;").Scan(&sId, &sStatus)
	if err == nil {
		fmt.Printf("Session ID: %s, Status: %s\n", sId, sStatus)
	}

    // Check transcripts
    var tId string
    err = pool.QueryRow(ctx, "SELECT id FROM transcripts WHERE audio_upload_id = $1 LIMIT 1;", id).Scan(&tId)
	if err == nil {
		fmt.Printf("Transcript ID: %s\n", tId)
	} else {
        fmt.Printf("Transcript not found for upload %s: %v\n", id, err)
    }
}
