package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type SignUpResponse struct {
	LocalId string `json:"localId"`
	Email   string `json:"email"`
}

func main() {
	ctx := context.Background()
	email := "demo@superwizor.ai"
	password := "SuperwizorDemo123!"

	// 1. Create/Ensure User in Firebase Auth Emulator
	fmt.Println("🔄 Creating user in Firebase Auth Emulator...")
	signUpURL := "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=mock-api-key"
	signUpBody, _ := json.Marshal(map[string]interface{}{
		"email":             email,
		"password":          password,
		"returnSecureToken": true,
	})

	resp, err := http.Post(signUpURL, "application/json", bytes.NewBuffer(signUpBody))
	var firebaseUID string
	if err != nil {
		log.Fatalf("failed to call firebase emulator: %v", err)
	}
	defer resp.Body.Close()

	respData, _ := io.ReadAll(resp.Body)
	if resp.StatusCode == http.StatusOK {
		var signUpResp SignUpResponse
		if err := json.Unmarshal(respData, &signUpResp); err != nil {
			log.Fatalf("failed to parse signup response: %v", err)
		}
		firebaseUID = signUpResp.LocalId
		fmt.Printf("✅ Firebase user created successfully. UID: %s\n", firebaseUID)
	} else {
		// Maybe user already exists, let's try to get user by email or sign in to get UID
		signInURL := "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=mock-api-key"
		signInBody, _ := json.Marshal(map[string]interface{}{
			"email":             email,
			"password":          password,
			"returnSecureToken": true,
		})
		resp2, err2 := http.Post(signInURL, "application/json", bytes.NewBuffer(signInBody))
		if err2 != nil {
			log.Fatalf("failed to call firebase signin: %v", err2)
		}
		defer resp2.Body.Close()
		respData2, _ := io.ReadAll(resp2.Body)
		if resp2.StatusCode == http.StatusOK {
			var signInResp SignUpResponse
			if err := json.Unmarshal(respData2, &signInResp); err != nil {
				log.Fatalf("failed to parse signin response: %v", err)
			}
			firebaseUID = signInResp.LocalId
			fmt.Printf("✅ Existing Firebase user found. UID: %s\n", firebaseUID)
		} else {
			log.Fatalf("failed to create or sign in Firebase user: %s", string(respData))
		}
	}

	// 2. Connect to local PostgreSQL
	fmt.Println("🔄 Connecting to database...")
	url := "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5432/superwizor?sslmode=disable"
	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		fmt.Printf("Retrying on 5433... ")
		url = "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5433/superwizor?sslmode=disable"
		conn, err = pgx.Connect(ctx, url)
		if err != nil {
			log.Fatalf("connect error: %v", err)
		}
	}
	defer conn.Close(ctx)

	// Start database tx
	tx, err := conn.Begin(ctx)
	if err != nil {
		log.Fatalf("failed to start tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Fetch a valid modality ID
	var defaultModalityID pgtype.UUID
	err = tx.QueryRow(ctx, "SELECT id FROM modalities LIMIT 1").Scan(&defaultModalityID)
	if err != nil {
		fmt.Printf("Warning: no modality found in database, defaultModalityID will be NULL: %v\n", err)
	} else {
		fmt.Printf("Found valid modality ID: %x\n", defaultModalityID.Bytes)
	}

	// Generate UUIDs
	var orgID, userID, subID, addressID string
	err = tx.QueryRow(ctx, "SELECT id FROM users WHERE email = $1", email).Scan(&userID)
	if err == pgx.ErrNoRows {
		// Create new
		err = tx.QueryRow(ctx, "SELECT gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()").Scan(&userID, &orgID, &subID, &addressID)
		if err != nil {
			log.Fatalf("uuid generation failed: %v", err)
		}

		fmt.Println("🔄 Inserting new addresses, organization, user, subscription...")
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
			log.Fatalf("failed to update primary admin: %v", err)
		}

		// E. Insert Subscription (TRIAL)
		_, err = tx.Exec(ctx, `
			INSERT INTO subscriptions (id, organization_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
			SELECT $1, $2, p.id, 'MANUAL', 'manual-demo-sub', 'TRIALING', date_trunc('month', now()), date_trunc('month', now()) + interval '1 month'
			FROM subscription_plans p
			WHERE p.tier = 'TRIAL' AND p.cycle = 'MONTHLY' AND p.is_active = TRUE
			LIMIT 1`,
			subID, orgID,
		)
		if err != nil {
			log.Fatalf("failed to insert subscription: %v", err)
		}

		// F. Insert Counter (TRIAL - 5 tokens limit)
		_, err = tx.Exec(ctx, `
			INSERT INTO usage_counters (id, subscription_id, period_start, period_end, tokens_used, tokens_reserved, tokens_limit)
			VALUES (gen_random_uuid(), $1, date_trunc('month', now()), date_trunc('month', now()) + interval '1 month', 0, 0, 5)`,
			subID,
		)
		if err != nil {
			log.Fatalf("failed to insert usage_counter: %v", err)
		}
	} else if err != nil {
		log.Fatalf("query user failed: %v", err)
	} else {
		// Existing user
		fmt.Printf("✅ User already exists in database. UserID: %s\n", userID)
		err = tx.QueryRow(ctx, "SELECT organization_id FROM users WHERE id = $1", userID).Scan(&orgID)
		if err != nil {
			log.Fatalf("failed to query org ID: %v", err)
		}
		// Let's get subscription ID
		err = tx.QueryRow(ctx, "SELECT id FROM subscriptions WHERE organization_id = $1 LIMIT 1", orgID).Scan(&subID)
		if err != nil {
			log.Fatalf("failed to query sub ID: %v", err)
		}
		// Update user's firebase UID and default modality in database
		_, err = tx.Exec(ctx, "UPDATE users SET firebase_uid = $1, default_modality_id = $2 WHERE id = $3", firebaseUID, defaultModalityID, userID)
		if err != nil {
			log.Fatalf("failed to update user fields: %v", err)
		}

		// Update sub plan to TRIAL (if not already)
		var trialPlanID string
		err = tx.QueryRow(ctx, "SELECT id FROM subscription_plans WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE LIMIT 1").Scan(&trialPlanID)
		if err == nil {
			_, _ = tx.Exec(ctx, "UPDATE subscriptions SET plan_id = $1, status = 'TRIALING' WHERE id = $2", trialPlanID, subID)
		}

		// Update usage counter limit to 5
		_, _ = tx.Exec(ctx, "UPDATE usage_counters SET tokens_limit = 5 WHERE subscription_id = $1", subID)
	}

	// 3. Clear and insert 3 invoices for this organization
	fmt.Println("🔄 Seeding 3 mock invoices...")
	_, _ = tx.Exec(ctx, "DELETE FROM invoices WHERE organization_id = $1", orgID)

	mockInvoices := []struct {
		stripeInvoiceID string
		amount          string
		currency        string
		pdf             string
		hostedUrl       string
		createdAt       time.Time
	}{
		{
			stripeInvoiceID: "in_demo_1",
			amount:          "199.00",
			currency:        "PLN",
			pdf:             "https://pay.stripe.com/invoice/acct_demo/inv_demo_1/pdf",
			hostedUrl:       "https://invoice.stripe.com/i/acct_demo/inv_demo_1",
			createdAt:       time.Now().AddDate(0, -2, 0),
		},
		{
			stripeInvoiceID: "in_demo_2",
			amount:          "199.00",
			currency:        "PLN",
			pdf:             "https://pay.stripe.com/invoice/acct_demo/inv_demo_2/pdf",
			hostedUrl:       "https://invoice.stripe.com/i/acct_demo/inv_demo_2",
			createdAt:       time.Now().AddDate(0, -1, 0),
		},
		{
			stripeInvoiceID: "in_demo_3",
			amount:          "299.00",
			currency:        "PLN",
			pdf:             "https://pay.stripe.com/invoice/acct_demo/inv_demo_3/pdf",
			hostedUrl:       "https://invoice.stripe.com/i/acct_demo/inv_demo_3",
			createdAt:       time.Now(),
		},
	}

	for _, inv := range mockInvoices {
		_, err = tx.Exec(ctx, `
			INSERT INTO invoices (
				id, organization_id, subscription_id, stripe_invoice_id, amount_paid, currency, invoice_pdf, hosted_invoice_url, period_start, period_end, created_at
			) VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			orgID, subID, inv.stripeInvoiceID, inv.amount, inv.currency, inv.pdf, inv.hostedUrl, inv.createdAt, inv.createdAt.AddDate(0, 1, 0), inv.createdAt,
		)
		if err != nil {
			log.Fatalf("failed to insert invoice: %v", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		log.Fatalf("failed to commit transaction: %v", err)
	}

	fmt.Println("🎉 Database seeded successfully with default modality!")
	fmt.Printf("Email: %s\n", email)
	fmt.Printf("Password: %s\n", password)
}
