package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

func main() {
	ctx := context.Background()
	projectID := "superwizor-ai-25ecd"
	email := "demo@superwizor.ai"
	password := "SuperwizorDemo123!"

	// Find key file
	wd, err := os.Getwd()
	if err != nil {
		log.Fatalf("Failed to get working directory: %v", err)
	}
	keyPath := filepath.Join(wd, "sa-key.json")
	if _, err := os.Stat(keyPath); os.IsNotExist(err) {
		// Try parent directory if we are inside scripts/ or superwizor-backend/
		keyPath = filepath.Join(wd, "..", "sa-key.json")
		if _, err := os.Stat(keyPath); os.IsNotExist(err) {
			keyPath = filepath.Join(wd, "../..", "sa-key.json")
		}
	}

	config := &firebase.Config{
		ProjectID: projectID,
	}

	var opt option.ClientOption
	if stat, err := os.Stat(keyPath); err == nil && stat.Size() > 0 {
		fmt.Printf("Using credentials key: %s\n", keyPath)
		opt = option.WithCredentialsFile(keyPath)
	} else {
		fmt.Println("No valid sa-key.json found. Falling back to Application Default Credentials (ADC)...")
	}

	var app *firebase.App
	if opt != nil {
		app, err = firebase.NewApp(ctx, config, opt)
	} else {
		app, err = firebase.NewApp(ctx, config)
	}
	if err != nil {
		log.Fatalf("Failed to initialize Firebase App: %v", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("Failed to get Firebase Auth client: %v", err)
	}

	fmt.Printf("Checking Firebase user: %s\n", email)
	u, err := authClient.GetUserByEmail(ctx, email)
	if err != nil {
		// If user doesn't exist, create them
		fmt.Printf("User %s not found. Creating...\n", email)
		params := (&auth.UserToCreate{}).
			Email(email).
			EmailVerified(true).
			Password(password)
		uCreated, errCreate := authClient.CreateUser(ctx, params)
		if errCreate != nil {
			log.Fatalf("Failed to create Firebase user: %v", errCreate)
		}
		fmt.Printf("Successfully created user: %s (UID: %s, EmailVerified: %t)\n", uCreated.Email, uCreated.UID, uCreated.EmailVerified)
	} else {
		fmt.Printf("User found: %s (UID: %s, EmailVerified: %t)\n", u.Email, u.UID, u.EmailVerified)
		if !u.EmailVerified {
			fmt.Println("Updating EmailVerified to true...")
			params := (&auth.UserToUpdate{}).
				EmailVerified(true)
			uUpdated, errUpdate := authClient.UpdateUser(ctx, u.UID, params)
			if errUpdate != nil {
				log.Fatalf("Failed to update Firebase user: %v", errUpdate)
			}
			fmt.Printf("Successfully updated user: %s (EmailVerified: %t)\n", uUpdated.Email, uUpdated.EmailVerified)
		} else {
			fmt.Println("User already has EmailVerified = true. Nothing to do!")
		}
	}
}
