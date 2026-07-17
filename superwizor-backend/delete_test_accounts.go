package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"github.com/jackc/pgx/v5"
	"google.golang.org/api/iterator"
)

func main() {
	ctx := context.Background()

	// 1. Setup Postgres
	conn, err := pgx.Connect(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(ctx)

	// 2. Setup Firebase Auth
	app, err := firebase.NewApp(ctx, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error initializing app: %v\n", err)
		os.Exit(1)
	}
	client, err := app.Auth(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error getting Auth client: %v\n", err)
		os.Exit(1)
	}

	// 3. Find and delete in Firebase Auth
	iter := client.Users(ctx, "")
	for {
		user, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "error iterating users: %v\n", err)
			break
		}

		if strings.HasPrefix(user.Email, "kolodzmaciej+") && strings.HasSuffix(user.Email, "@gmail.com") {
			fmt.Printf("Deleting from Firebase: %s (UID: %s)\n", user.Email, user.UID)
			err := client.DeleteUser(ctx, user.UID)
			if err != nil {
				fmt.Printf("Failed to delete %s: %v\n", user.UID, err)
			}
		}
	}

	// 4. Delete from Postgres
	tag, err := conn.Exec(ctx, "DELETE FROM users WHERE email LIKE 'kolodzmaciej+%%@gmail.com'")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Postgres delete failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Successfully deleted %d rows from Postgres.\n", tag.RowsAffected())
}
