package chat

import (
	"context"
	"os"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Every other test in this package mocks the pool. That is right for the
// routing and grounding logic — it makes the decision table testable
// without a database — but it means NOTHING checked that the SQL matches
// the schema.
//
// On 2026-08-20 that gap shipped to production. The retrieval queries
// referenced sessions.scheduled_at, sessions.duration_minutes and status
// 'CANCELLED'. The real columns are session_date and duration_seconds,
// and the cancelled statuses are 'CANCELED' (one L) and
// 'CANCELLED_BY_USER'. Every unit test passed. A therapist got
// "chat turn failed".
//
// This test PREPAREs each query against a real database. Preparing is
// enough: Postgres resolves every table and column name and reports the
// result types, without executing anything or touching a row. It needs no
// fixtures and cannot mutate data.
//
// Run it with:
//
//	TEST_DATABASE_URL=postgres://... go test ./internal/chat/ -run Schema
//
// Skipped without that variable, so `go test ./...` stays green offline.
func TestQueriesMatchLiveSchema(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set — schema check skipped")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer pool.Close()

	conn, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatalf("acquire: %v", err)
	}
	defer conn.Release()

	// Every query the package sends, with the argument count each takes.
	// Adding a query here is not optional: a query absent from this list
	// is a query nothing validates.
	queries := []struct {
		name string
		sql  string
	}{
		{"sqlRecentSessions", sqlRecentSessions},
		{"sqlSegmentIndex", sqlSegmentIndex},
		{"sqlStats", sqlStats},
		{"sqlLongestGap", sqlLongestGap},
		{"sqlReportDigests", sqlReportDigests},
		{"sqlRAGPool", sqlRAGPool},
		{"sqlEnsureCounter", sqlEnsureCounter},
		{"sqlReserve", sqlReserve},
		{"sqlInsertReservation", sqlInsertReservation},
		{"sqlCommit", sqlCommit},
		{"sqlMarkWarned", sqlMarkWarned},
		{"sqlInsertDecision", sqlInsertDecision},
		{"sqlLoadHistory", sqlLoadHistory},
		{"sqlInsertInteraction", sqlInsertInteraction},
	}

	for _, q := range queries {
		t.Run(q.name, func(t *testing.T) {
			// A unique name per prepare; reusing one would mask a later
			// failure behind the cached first success.
			stmt := "chatcheck_" + strings.ToLower(q.name) + "_" + uuid.NewString()[:8]
			if _, err := conn.Conn().Prepare(ctx, stmt, q.sql); err != nil {
				t.Errorf("%s does not match the schema: %v", q.name, err)
			}
		})
	}
}

// The cancelled-status list must match the enum exactly. A value that
// does not exist makes the filter silently match nothing, so cancelled
// sessions would count as attended — wrong numbers rather than an error,
// which is the worse failure.
func TestCancelledStatusesExistInEnum(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer pool.Close()

	rows, err := pool.Query(ctx,
		`SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
		  WHERE t.typname = 'session_status'`)
	if err != nil {
		t.Fatalf("read enum: %v", err)
	}
	defer rows.Close()

	live := map[string]bool{}
	for rows.Next() {
		var label string
		if err := rows.Scan(&label); err != nil {
			t.Fatalf("scan: %v", err)
		}
		live[label] = true
	}

	for _, want := range []string{"CANCELED", "CANCELLED_BY_USER"} {
		if !live[want] {
			t.Errorf("cancelledStatuses names %q, which is not in the session_status enum", want)
		}
	}
	// And the reverse: an enum value that means "cancelled" but is
	// missing from the list would be counted as an attended session.
	for label := range live {
		if strings.Contains(strings.ToUpper(label), "CANCEL") &&
			!strings.Contains(cancelledStatuses, "'"+label+"'") {
			t.Errorf("enum has %q, which looks cancelled but is absent from cancelledStatuses", label)
		}
	}
}
