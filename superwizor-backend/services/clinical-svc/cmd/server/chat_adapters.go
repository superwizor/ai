package main

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/pkg/appconfig"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/chat"

	grpcadapter "github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/grpc"
)

// The chat and appconfig packages declare their own narrow database
// interfaces so they can be unit-tested without pgx. These adapters are
// the only place pgxpool meets them.
//
// The interfaces are deliberately not identical — appconfig only reads,
// the chat also writes — because widening either to a shared "database"
// interface would hand each package capabilities it has no business
// having. A config reader that can Exec is a config reader that can
// eventually delete something.

type appconfigPool struct{ pool *pgxpool.Pool }

func (a appconfigPool) Query(ctx context.Context, sql string, args ...any) (appconfig.Rows, error) {
	rows, err := a.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	return rows, nil
}

type chatPool struct{ pool *pgxpool.Pool }

func (c chatPool) Query(ctx context.Context, sql string, args ...any) (chat.Rows, error) {
	rows, err := c.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	return rows, nil
}

func (c chatPool) QueryRow(ctx context.Context, sql string, args ...any) chat.RowScanner {
	return c.pool.QueryRow(ctx, sql, args...)
}

func (c chatPool) Exec(ctx context.Context, sql string, args ...any) (int64, error) {
	tag, err := c.pool.Exec(ctx, sql, args...)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// ontologyPool adaptuje pgxpool do waskiego interfejsu Ontology Studio.
//
// Osobny adapter, a nie rozszerzenie chatPool: Studio i czat maja rozne
// powody do zmian, a wspolny typ zmusilby jeden do noszenia metod
// drugiego.
type ontologyPool struct{ pool *pgxpool.Pool }

func (o ontologyPool) Exec(ctx context.Context, sql string, args ...any) (int64, error) {
	tag, err := o.pool.Exec(ctx, sql, args...)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

func (o ontologyPool) Query(ctx context.Context, sql string, args ...any) (grpcadapter.OntologyRows, error) {
	rows, err := o.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	return rows, nil
}

func (o ontologyPool) QueryRow(ctx context.Context, sql string, args ...any) grpcadapter.OntologyRow {
	return o.pool.QueryRow(ctx, sql, args...)
}

// chatTracker forwards chat telemetry into the analytics collector.
//
// Properties are passed through as-is. That is safe only because
// telemetryFor builds them from bounded codes and counts — see
// TestTelemetryCarriesNoConversationContent, which is the test that keeps
// it true.
type chatTracker struct{ collector *analytics.Collector }

func (t chatTracker) Track(ctx context.Context, e chat.TelemetryEvent) {
	if t.collector == nil {
		return
	}
	t.collector.Track(ctx, analytics.Event{
		Name:       e.Name,
		Properties: e.Properties,
		Source:     "server",
		OccurredAt: time.Now(),
	})
}
