package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/jackc/pgx/v5/pgxpool"
)

func fetchDBPassword() string {
	cmd := exec.Command("gcloud", "secrets", "versions", "access", "latest", "--secret=postgres-database-url", "--project=superwizor-ai-25ecd")
	out, err := cmd.Output()
	if err != nil {
		log.Printf("Warning: Failed to fetch DB password from Secret Manager: %v", err)
		return "superwizor_password"
	}
	dbURL := strings.TrimSpace(string(out))
	parts := strings.Split(dbURL, "@")
	if len(parts) < 2 {
		return "superwizor_password"
	}
	prefix := parts[0]
	subParts := strings.Split(prefix, ":")
	if len(subParts) < 3 {
		return "superwizor_password"
	}
	return subParts[2]
}

func main() {
	ctx := context.Background()
	email := "dar1@gmail.com"
	password := "SuperwizorAI1"
	projectID := "superwizor-ai-25ecd"

	// 1. Firebase Auth Step
	config := &firebase.Config{
		ProjectID: projectID,
	}
	app, err := firebase.NewApp(ctx, config)
	if err != nil {
		log.Fatalf("Failed to initialize Firebase App: %v", err)
	}
	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("Failed to get Firebase Auth client: %v", err)
	}

	fmt.Printf("Firebase: Checking user %s\n", email)
	fbUser, err := authClient.GetUserByEmail(ctx, email)
	var fbUID string
	if err != nil {
		// Create in Firebase
		fmt.Printf("Firebase: User not found. Creating...\n")
		params := (&auth.UserToCreate{}).
			Email(email).
			EmailVerified(true).
			Password(password)
		uCreated, errCreate := authClient.CreateUser(ctx, params)
		if errCreate != nil {
			log.Fatalf("Firebase: Failed to create user: %v", errCreate)
		}
		fbUID = uCreated.UID
		fmt.Printf("Firebase: Successfully created user: %s (UID: %s)\n", uCreated.Email, fbUID)
	} else {
		fbUID = fbUser.UID
		fmt.Printf("Firebase: User exists (UID: %s). Updating password to %s...\n", fbUID, password)
		params := (&auth.UserToUpdate{}).
			Password(password).
			EmailVerified(true)
		_, errUpdate := authClient.UpdateUser(ctx, fbUID, params)
		if errUpdate != nil {
			log.Fatalf("Firebase: Failed to update password: %v", errUpdate)
		}
		fmt.Printf("Firebase: Password updated successfully\n")
	}

	// 2. Postgres Step
	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		pass := fetchDBPassword()
		dbDSN = fmt.Sprintf("postgres://superwizor_app:%s@127.0.0.1:5432/superwizor?sslmode=disable", pass)
	}
	fmt.Printf("DB: Connecting to database...\n")
	dbPool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		log.Fatalf("DB: Failed to connect: %v", err)
	}
	defer dbPool.Close()

	// Restore all users soft-deleted in the last 20 minutes
	fmt.Printf("DB: Restoring all users soft-deleted in the last 20 minutes...\n")
	tag2, err := dbPool.Exec(ctx, `
		UPDATE users
		SET deleted_at = NULL
		WHERE deleted_at >= now() - interval '20 minutes'
	`)
	if err != nil {
		log.Fatalf("DB: Failed to restore users: %v", err)
	}
	fmt.Printf("DB: Successfully restored %d users deleted in the last 20 minutes!\n", tag2.RowsAffected())

	// Check if user exists in DB
	var dbUserID string
	err = dbPool.QueryRow(ctx, "SELECT id FROM users WHERE email = $1", email).Scan(&dbUserID)
	if err != nil {
		// User does not exist in Postgres, we should insert them!
		fmt.Printf("DB: User %s not found in database. Let's insert as a new SUPERWIZOR_ADMIN...\n", email)
		_, err = dbPool.Exec(ctx, `
			INSERT INTO users (role, firebase_uid, email, first_name, last_name, is_email_verified)
			VALUES ('SUPERWIZOR_ADMIN', $1, $2, 'Admin', 'Dar', true)
		`, fbUID, email)
		if err != nil {
			log.Fatalf("DB: Failed to insert new SUPERWIZOR_ADMIN: %v", err)
		}
		fmt.Printf("DB: Successfully created new SUPERWIZOR_ADMIN in database.\n")
	} else {
		// User exists in Postgres! Set deleted_at = NULL, role = 'SUPERWIZOR_ADMIN', firebase_uid = fbUID
		fmt.Printf("DB: User found (ID: %s). Restoring deleted_at and setting role to SUPERWIZOR_ADMIN...\n", dbUserID)
		_, err = dbPool.Exec(ctx, `
			UPDATE users
			SET deleted_at = NULL,
				role = 'SUPERWIZOR_ADMIN',
				firebase_uid = $1
			WHERE id = $2
		`, fbUID, dbUserID)
		if err != nil {
			log.Fatalf("DB: Failed to update user: %v", err)
		}
		fmt.Printf("DB: Successfully updated user in database.\n")
	}

	fmt.Println("🎉 Restore and promotion successfully completed!")
}
