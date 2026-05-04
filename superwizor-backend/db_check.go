package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dbDSN := os.Getenv("DATABASE_URL")
	ctx := context.Background()
	dbPool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		log.Fatalf("db error: %v", err)
	}
	defer dbPool.Close()

	rows, err := dbPool.Query(ctx, "SELECT id, system_code FROM modalities;")
	if err != nil {
		log.Fatalf("query error: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var id, code string
		if err := rows.Scan(&id, &code); err != nil {
			log.Fatalf("scan error: %v", err)
		}
		fmt.Printf("Modality: %s - %s\n", id, code)
	}

	if err := rows.Err(); err != nil {
		log.Fatalf("rows error: %v", err)
	}
	fmt.Println("Done.")
}
