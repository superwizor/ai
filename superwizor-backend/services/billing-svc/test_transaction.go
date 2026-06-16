package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

func main() {
	ctx := context.Background()
	url := "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5432/superwizor?sslmode=disable"
	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		url = "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5433/superwizor?sslmode=disable"
		conn, err = pgx.Connect(ctx, url)
		if err != nil {
			log.Fatalf("connect error: %v", err)
		}
	}
	defer conn.Close(ctx)

	orgID, _ := uuid.Parse("73f93e7c-8843-4592-b43c-7d06c9350482")
	planID, _ := uuid.Parse("72628d0b-34d9-4988-a33a-0eba0e3a384a")
	subID := "sub_1TibsdE5jzWcAIge5y2y5vFf"
	status := db.SubscriptionStatusACTIVE
	periodStart := time.Unix(1781535168, 0).UTC()
	periodEnd := time.Unix(1784127168, 0).UTC()

	tx, err := conn.Begin(ctx)
	if err != nil {
		log.Fatalf("begin error: %v", err)
	}
	defer tx.Rollback(ctx)

	qTx := db.New(tx)

	fmt.Println("1. Running DeactivateOtherActiveSubscriptions...")
	err = qTx.DeactivateOtherActiveSubscriptions(ctx, db.DeactivateOtherActiveSubscriptionsParams{
		OrganizationID:         orgID,
		ProviderSubscriptionID: subID,
	})
	if err != nil {
		fmt.Printf("DeactivateOtherActiveSubscriptions failed: %v\n", err)
		return
	}
	fmt.Println("Success.")

	fmt.Println("2. Running UpsertStripeSubscription...")
	dbSub, err := qTx.UpsertStripeSubscription(ctx, db.UpsertStripeSubscriptionParams{
		OrganizationID:         orgID,
		PlanID:                 planID,
		ProviderSubscriptionID: subID,
		Status:                 status,
		CurrentPeriodStart:     periodStart,
		CurrentPeriodEnd:       periodEnd,
		CancelAtPeriodEnd:      false,
		TrialEndAt:             pgtype.Timestamptz{Valid: false},
	})
	if err != nil {
		fmt.Printf("UpsertStripeSubscription failed: %v\n", err)
		return
	}
	fmt.Printf("Success. ID: %s, PlanID: %s, Status: %s\n", dbSub.ID, dbSub.PlanID, dbSub.Status)

	fmt.Println("3. Running CreateUsageCounter...")
	_, counterErr := qTx.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
		SubscriptionID: dbSub.ID,
		PeriodStart:    periodStart,
		PeriodEnd:      periodEnd,
		TokensLimit:    30, // plan tokens
	})
	if counterErr != nil {
		fmt.Printf("CreateUsageCounter failed: %v\n", counterErr)
		// Note: we don't return here because webhook logs it and continues to commit
	} else {
		fmt.Println("Success.")
	}

	fmt.Println("4. Committing transaction...")
	err = tx.Commit(ctx)
	if err != nil {
		fmt.Printf("Commit failed: %v\n", err)
		return
	}
	fmt.Println("Transaction committed successfully!")
}
