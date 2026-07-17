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

	// Fetch duplicates
	rows, err := conn.Query(ctx, "SELECT id, email, phone_number, created_at, deleted_at FROM users WHERE phone_number = '+48 510-417-781'")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Query failed: %v\n", err)
		os.Exit(1)
	}
	defer rows.Close()

	for rows.Next() {
		var id, email, phone string
		var created, deleted interface{}
		err = rows.Scan(&id, &email, &phone, &created, &deleted)
		if err != nil {
			fmt.Printf("Error scanning row: %v\n", err)
			continue
		}
		fmt.Printf("Found Duplicate: id=%s, email=%s, phone=%s, created_at=%v, deleted_at=%v\n", id, email, phone, created, deleted)
	}
}
