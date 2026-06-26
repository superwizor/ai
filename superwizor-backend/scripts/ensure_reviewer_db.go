package main

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

func fetchDBPassword() string {
	cmd := exec.Command("gcloud", "secrets", "versions", "access", "latest", "--secret=postgres-database-url", "--project=superwizor-ai-25ecd")
	out, err := cmd.Output()
	if err != nil {
		log.Fatalf("Failed to fetch DB password from Secret Manager: %v", err)
	}
	dbURL := strings.TrimSpace(string(out))
	// Extract password from: postgres://user:password@host:port/dbname
	parts := strings.Split(dbURL, "@")
	if len(parts) < 2 {
		log.Fatalf("Invalid DB URL format")
	}
	prefix := parts[0]
	subParts := strings.Split(prefix, ":")
	if len(subParts) < 3 {
		log.Fatalf("Invalid DB URL prefix format")
	}
	return subParts[2]
}

func main() {
	ctx := context.Background()
	email := "demo@superwizor.ai"
	firebaseUID := "UCDUoFyfvzQs5oRMtHP8KATMssf1" // UID we just created

	pass := fetchDBPassword()

	// Start cloud-sql-proxy in the background
	fmt.Println("🚀 Starting Cloud SQL Proxy...")
	proxyCmd := exec.Command("../cloud-sql-proxy", "superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de")
	err := proxyCmd.Start()
	if err != nil {
		log.Fatalf("Failed to start Cloud SQL Proxy: %v", err)
	}
	defer func() {
		fmt.Println("🧹 Stopping Cloud SQL Proxy...")
		_ = proxyCmd.Process.Kill()
	}()

	// Wait for proxy to listen
	time.Sleep(3 * time.Second)

	dbDSN := fmt.Sprintf("postgres://superwizor_app:%s@127.0.0.1:5432/superwizor?sslmode=disable", pass)
	fmt.Println("🔄 Connecting to production database...")
	conn, err := pgx.Connect(ctx, dbDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer conn.Close(ctx)

	var userID string
	err = conn.QueryRow(ctx, "SELECT id FROM users WHERE email = $1", email).Scan(&userID)
	if err == pgx.ErrNoRows {
		fmt.Printf("User %s not found in DB. Registering in DB...\n", email)

		tx, err := conn.Begin(ctx)
		if err != nil {
			log.Fatalf("Failed to start tx: %v", err)
		}
		defer func() { _ = tx.Rollback(ctx) }()

		// Fetch a valid modality ID
		var defaultModalityID pgtype.UUID
		err = tx.QueryRow(ctx, "SELECT id FROM modalities LIMIT 1").Scan(&defaultModalityID)
		if err != nil {
			fmt.Printf("Warning: no modality found in database: %v\n", err)
		}

		// Generate UUIDs
		var orgID, subID, addressID string
		err = tx.QueryRow(ctx, "SELECT gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()").Scan(&userID, &orgID, &subID, &addressID)
		if err != nil {
			log.Fatalf("uuid generation failed: %v", err)
		}

		// A. Insert Address
		_, err = tx.Exec(ctx, `
			INSERT INTO addresses (id, country_code, region, city, postal_code, street_line, building_number)
			VALUES ($1, 'PL', 'mazowieckie', 'Warszawa', '00-001', 'Demo Street', '1')`,
			addressID,
		)
		if err != nil {
			log.Fatalf("failed to insert address: %v", err)
		}

		// B. Insert Organization
		_, err = tx.Exec(ctx, `
			INSERT INTO organizations (id, legal_name, headquarters_address_id, type)
			VALUES ($1, 'Demo Sp. z o.o.', $2, 'SOLO')`,
			orgID, addressID,
		)
		if err != nil {
			log.Fatalf("failed to insert org: %v", err)
		}

		// C. Insert User
		_, err = tx.Exec(ctx, `
			INSERT INTO users (id, role, organization_id, firebase_uid, email, first_name, last_name, ui_language, timezone, has_accepted_tos, default_modality_id)
			VALUES ($1, 'THERAPIST', $2, $3, $4, 'Demo', 'User', 'pl', 'Europe/Warsaw', true, $5)`,
			userID, orgID, firebaseUID, email, defaultModalityID,
		)
		if err != nil {
			log.Fatalf("failed to insert user: %v", err)
		}

		// D. Update Primary Admin User
		_, err = tx.Exec(ctx, `
			UPDATE organizations SET primary_admin_user_id = $1 WHERE id = $2`,
			userID, orgID,
		)
		if err != nil {
			log.Fatalf("failed to update org admin: %v", err)
		}

		// E. Fetch PRO Plan
		var planID string
		err = tx.QueryRow(ctx, "SELECT id FROM subscription_plans WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = true LIMIT 1").Scan(&planID)
		if err != nil {
			log.Fatalf("Failed to find PRO plan: %v", err)
		}

		// F. Insert Subscription
		now := time.Now()
		periodStart := now.Truncate(24 * time.Hour)
		periodEnd := periodStart.AddDate(0, 1, 0)
		_, err = tx.Exec(ctx, `
			INSERT INTO subscriptions (id, organization_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
			VALUES ($1, $2, $3, 'MANUAL', $4, 'ACTIVE', $5, $6)`,
			subID, orgID, planID, "manual-review-sub", periodStart, periodEnd,
		)
		if err != nil {
			log.Fatalf("Failed to insert subscription: %v", err)
		}

		err = tx.Commit(ctx)
		if err != nil {
			log.Fatalf("Failed to commit tx: %v", err)
		}
		fmt.Printf("✅ User %s successfully registered in production DB with active PRO plan!\n", email)
	} else {
		fmt.Printf("User %s already exists in production DB (UserID: %s). Updating Firebase UID and checking status...\n", email, userID)
		
		// Update Firebase UID to make sure they match
		_, err = conn.Exec(ctx, "UPDATE users SET firebase_uid = $1 WHERE id = $2", firebaseUID, userID)
		if err != nil {
			log.Fatalf("Failed to update firebase_uid in DB: %v", err)
		}
		
		// Let's check organization
		var orgID string
		err = conn.QueryRow(ctx, "SELECT organization_id FROM users WHERE id = $1", userID).Scan(&orgID)
		if err == nil && orgID != "" {
			// Ensure they have active subscription
			var subID string
			err = conn.QueryRow(ctx, "SELECT id FROM subscriptions WHERE organization_id = $1 LIMIT 1", orgID).Scan(&subID)
			if err == pgx.ErrNoRows {
				fmt.Println("User has no active subscription. Adding one...")
				// Fetch PRO Plan
				var planID string
				err = conn.QueryRow(ctx, "SELECT id FROM subscription_plans WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = true LIMIT 1").Scan(&planID)
				if err == nil {
					now := time.Now()
					periodStart := now.Truncate(24 * time.Hour)
					periodEnd := periodStart.AddDate(0, 1, 0)
					_, err = conn.Exec(ctx, `
						INSERT INTO subscriptions (id, organization_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
						VALUES (gen_random_uuid(), $1, $2, 'MANUAL', $3, 'ACTIVE', $4, $5)`,
						orgID, planID, "manual-review-sub", periodStart, periodEnd,
					)
					if err != nil {
						fmt.Printf("Failed to insert subscription: %v\n", err)
					} else {
						fmt.Println("✅ Added manual PRO subscription.")
					}
				}
			}
		}
		fmt.Println("✅ DB configuration is up to date!")
	}
}
