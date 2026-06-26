package http

import (
	"context"
	"database/sql"
	"encoding/json"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

func TestStripeSubscriptionUnmarshal(t *testing.T) {
	// This is a diagnostic test that connects to a real database.
	// Skip in CI where no database is available.
	if testing.Short() {
		t.Skip("skipping integration test in short mode")
	}

	ctx := context.Background()
	url := "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5432/superwizor?sslmode=disable"
	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		url = "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5433/superwizor?sslmode=disable"
		conn, err = pgx.Connect(ctx, url)
		if err != nil {
			t.Fatalf("connect error: %v", err)
		}
	}
	defer func() { _ = conn.Close(ctx) }()

	var rawPayload []byte
	err = conn.QueryRow(ctx, "SELECT raw_payload FROM payment_events WHERE provider_event_id = 'evt_1TibseE5jzWcAIgefIIwMLdw'").Scan(&rawPayload)
	if err != nil {
		t.Fatalf("query raw_payload error: %v", err)
	}

	var event stripeEvent
	if err := json.Unmarshal(rawPayload, &event); err != nil {
		t.Fatalf("unmarshal event error: %v", err)
	}

	var sub stripeSubscription
	if err := json.Unmarshal(event.Data.Object, &sub); err != nil {
		t.Fatalf("unmarshal subscription error: %v", err)
	}

	t.Logf("Sub ID: %s", sub.ID)
	t.Logf("Sub Status: %s", sub.Status)
	t.Logf("Sub CurrentPeriodStart: %d", sub.CurrentPeriodStart)
	t.Logf("Sub CurrentPeriodEnd: %d", sub.CurrentPeriodEnd)
	t.Logf("Sub Items Data Length: %d", len(sub.Items.Data))
	if len(sub.Items.Data) > 0 {
		t.Logf("  Item 0 Price ID: %s", sub.Items.Data[0].Price.ID)
		t.Logf("  Item 0 CurrentPeriodStart: %d", sub.Items.Data[0].CurrentPeriodStart)
		t.Logf("  Item 0 CurrentPeriodEnd: %d", sub.Items.Data[0].CurrentPeriodEnd)
	}

	periodStartUnix := sub.CurrentPeriodStart
	periodEndUnix := sub.CurrentPeriodEnd

	if periodStartUnix == 0 && len(sub.Items.Data) > 0 {
		periodStartUnix = sub.Items.Data[0].CurrentPeriodStart
	}
	if periodEndUnix == 0 && len(sub.Items.Data) > 0 {
		periodEndUnix = sub.Items.Data[0].CurrentPeriodEnd
	}

	periodStart := time.Unix(periodStartUnix, 0).UTC()
	periodEnd := time.Unix(periodEndUnix, 0).UTC()

	t.Logf("periodStart: %v", periodStart)
	t.Logf("periodEnd: %v", periodEnd)

	if periodEnd.Before(periodStart) || periodEnd.Equal(periodStart) {
		t.Errorf("periodEnd %v is not after periodStart %v", periodEnd, periodStart)
	}
}

// Dummy type to satisfy sql reference if needed
var _ sql.NullString
