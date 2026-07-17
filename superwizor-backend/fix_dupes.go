package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5"
)

func main() {
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(ctx)

	// Fetch all duplicated phone numbers
	rows, err := conn.Query(ctx, `
		SELECT phone_number 
		FROM users 
		WHERE deleted_at IS NULL AND phone_number IS NOT NULL
		GROUP BY phone_number 
		HAVING count(*) > 1
	`)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Query failed: %v\n", err)
		os.Exit(1)
	}
	defer rows.Close()

	var dupes []string
	for rows.Next() {
		var phone string
		if err := rows.Scan(&phone); err == nil {
			dupes = append(dupes, phone)
		}
	}
	rows.Close() // Explicitly close rows before running another query on the same connection

	for _, phone := range dupes {
		fmt.Printf("Deduplicating %s...\n", phone)
		// We'll leave one intact by selecting the oldest one, and updating the rest
		_, err = conn.Exec(ctx, `
			UPDATE users 
			SET phone_number = '+480000' || substr(id::text, 1, 7)
			WHERE phone_number = $1
			AND id NOT IN (
				SELECT id FROM users 
				WHERE phone_number = $1 AND deleted_at IS NULL
				ORDER BY created_at ASC
				LIMIT 1
			)
		`, phone)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Update failed for %s: %v\n", phone, err)
			os.Exit(1)
		}
	}

	fmt.Println("Successfully deduplicated all phone numbers.")
}
