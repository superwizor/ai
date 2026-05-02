package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5"
)

func main() {
	url := "postgresql://postgres:%7B%3DjDj%3D%3AG6Q%5DehAvs4mpet%2A0K%2B%5DP%26Ks%7B8@10.158.0.3:5432/superwizor"
	conn, err := pgx.Connect(context.Background(), url)
	if err != nil {
		fmt.Printf("Connect error: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(context.Background())

	var user string
	err = conn.QueryRow(context.Background(), "SELECT current_user").Scan(&user)
	if err != nil {
		fmt.Printf("Query error: %v\n", err)
	} else {
		fmt.Printf("Current user: %s\n", user)
	}

	_, err = conn.Exec(context.Background(), "SELECT * FROM modalities LIMIT 1")
	if err != nil {
		fmt.Printf("Select modalities error: %v\n", err)
	} else {
		fmt.Printf("Select modalities OK\n")
	}
}
