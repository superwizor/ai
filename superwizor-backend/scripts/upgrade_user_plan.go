package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

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
	// Extract password from: postgres://user:password@host:port/dbname
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
	email := "kolodzmaciej+testy+ustawnia@gmail.com"
	if len(os.Args) > 1 {
		email = os.Args[1]
	}

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		pass := fetchDBPassword()
		dbDSN = fmt.Sprintf("postgres://superwizor_app:%s@127.0.0.1:5432/superwizor?sslmode=disable", pass)
	}

	ctx := context.Background()
	dbPool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()

	fmt.Printf("🔍 Looking up user with email: %s\n", email)
	var userID, orgIDStr string
	err = dbPool.QueryRow(ctx, "SELECT id, organization_id FROM users WHERE email = $1", email).Scan(&userID, &orgIDStr)
	if err != nil {
		log.Fatalf("Error finding user: %v", err)
	}
	if orgIDStr == "" {
		log.Fatalf("User has no organization associated")
	}

	fmt.Printf("   User ID: %s\n   Org ID:  %s\n", userID, orgIDStr)

	// Get the PRO monthly plan
	var planID string
	var planName string
	var planLimit int32
	err = dbPool.QueryRow(ctx, "SELECT id, display_name, tokens_per_period FROM subscription_plans WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = true LIMIT 1").
		Scan(&planID, &planName, &planLimit)
	if err != nil {
		log.Fatalf("Error finding PRO monthly plan: %v", err)
	}

	fmt.Printf("📋 Found active PRO monthly plan:\n   Plan ID:   %s\n   Name:      %s\n   Limit:     %d sessions/month\n", planID, planName, planLimit)

	// Start a transaction
	tx, err := dbPool.Begin(ctx)
	if err != nil {
		log.Fatalf("Failed to start tx: %v", err)
	}
	defer tx.Rollback(ctx)

	// Check if a subscription already exists for this organization
	var subID string
	err = tx.QueryRow(ctx, "SELECT id FROM subscriptions WHERE organization_id = $1 LIMIT 1", orgIDStr).Scan(&subID)
	
	now := time.Now()
	periodStart := now.Truncate(24 * time.Hour)
	periodEnd := periodStart.AddDate(0, 1, 0)

	if err != nil {
		// No subscription, insert one
		subID = "99000000-0000-0000-0000-" + orgIDStr[24:]
		fmt.Printf("➕ Inserting new subscription: %s\n", subID)
		_, err = tx.Exec(ctx, `
			INSERT INTO subscriptions (id, organization_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
			VALUES ($1, $2, $3, 'MANUAL', $4, 'ACTIVE', $5, $6)`,
			subID, orgIDStr, planID, "manual-upgrade-"+time.Now().Format("20060102150405"), periodStart, periodEnd)
		if err != nil {
			log.Fatalf("Failed to insert subscription: %v", err)
		}
	} else {
		// Update subscription
		fmt.Printf("✏️  Updating existing subscription: %s\n", subID)
		_, err = tx.Exec(ctx, `
			UPDATE subscriptions 
			SET plan_id = $1, status = 'ACTIVE', current_period_start = $2, current_period_end = $3
			WHERE id = $4`,
			planID, periodStart, periodEnd, subID)
		if err != nil {
			log.Fatalf("Failed to update subscription: %v", err)
		}
	}

	// Update or insert usage_counter
	var counterID string
	err = tx.QueryRow(ctx, "SELECT id FROM usage_counters WHERE subscription_id = $1 AND period_start <= $2 AND period_end > $2", subID, now).Scan(&counterID)
	if err != nil {
		// Insert usage counter
		counterID = "88000000-0000-0000-0000-" + subID[24:]
		fmt.Printf("➕ Inserting new usage counter: %s with limit %d\n", counterID, planLimit)
		_, err = tx.Exec(ctx, `
			INSERT INTO usage_counters (id, subscription_id, period_start, period_end, tokens_used, tokens_reserved, tokens_limit)
			VALUES ($1, $2, $3, $4, 0, 0, $5)`,
			counterID, subID, periodStart, periodEnd, planLimit)
		if err != nil {
			log.Fatalf("Failed to insert usage counter: %v", err)
		}
	} else {
		// Update usage counter
		fmt.Printf("✏️  Updating existing usage counter: %s to limit %d\n", counterID, planLimit)
		_, err = tx.Exec(ctx, `
			UPDATE usage_counters
			SET tokens_limit = $1, tokens_used = 0, tokens_reserved = 0, period_start = $2, period_end = $3
			WHERE id = $4`,
			planLimit, periodStart, periodEnd, counterID)
		if err != nil {
			log.Fatalf("Failed to update usage counter: %v", err)
		}
	}

	err = tx.Commit(ctx)
	if err != nil {
		log.Fatalf("Failed to commit tx: %v", err)
	}

	fmt.Println("🚀 Upgrade successfully completed!")
}
