// Package outboxpoller implementuje background goroutine wewnątrz billing-svc
// która co N sekund fetch-uje unprocessed outbox_events i publikuje je
// do Pub/Sub topic billing.outbox.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §3.8.
//
// Pattern: poll-and-publish, NIE LISTEN/NOTIFY. Powód: prosty, deterministic,
// łatwy do reasoning'u przy multiple replicas (FOR UPDATE SKIP LOCKED w query
// gwarantuje że dwie repliki nie pobiorą tego samego row).
//
// Tradeoffs:
//   - latency: 0 do PollInterval (default 5s), akceptowalne dla quota warnings.
//   - load: 1 query per N sekund per replika, niski.
//   - durability: row pozostaje w outbox_events do attempts < 10; potem
//     "stuck" (DLQ-equivalent). Manualne wznowienie via SQL UPDATE attempts=0.
package outboxpoller

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Publisher to interfejs dla testów — produkcyjnie implementowany przez
// internal/adapters/pubsub.Publisher.
type Publisher interface {
	PublishOutboxEvent(
		ctx context.Context,
		eventType, aggregateType, organizationID, idempotencyKey string,
		payload []byte,
	) error
}

// Config — runtime parameters dla pollera.
type Config struct {
	PollInterval time.Duration // default 5s
	BatchSize    int32         // default 100
}

func (c Config) withDefaults() Config {
	if c.PollInterval == 0 {
		c.PollInterval = 5 * time.Second
	}
	if c.BatchSize == 0 {
		c.BatchSize = 100
	}
	return c
}

type Poller struct {
	pool   *pgxpool.Pool
	pub    Publisher
	cfg    Config
	logger *slog.Logger
}

func New(pool *pgxpool.Pool, pub Publisher, cfg Config, logger *slog.Logger) *Poller {
	if logger == nil {
		logger = slog.Default()
	}
	return &Poller{
		pool:   pool,
		pub:    pub,
		cfg:    cfg.withDefaults(),
		logger: logger,
	}
}

// Run blokuje aż do ctx.Done(). Pierwsze fetchowanie odbywa się natychmiast,
// kolejne wg PollInterval. Loop kończy się czysto po cancelacji contextu
// (nie czeka na zakończenie aktywnego batcha — to OK, bo FOR UPDATE SKIP
// LOCKED zwalnia loki przy rollbacku, kolejna replika je weźmie).
func (p *Poller) Run(ctx context.Context) {
	p.logger.Info("outbox poller starting",
		"interval", p.cfg.PollInterval,
		"batch_size", p.cfg.BatchSize)

	// Pierwsze przebicie od razu — żeby przy starcie nie czekać na pierwsze
	// tick'a jeśli są zaległe eventy.
	if err := p.processBatch(ctx); err != nil && !errors.Is(err, context.Canceled) {
		p.logger.Error("outbox initial batch failed", "error", err)
	}

	ticker := time.NewTicker(p.cfg.PollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			p.logger.Info("outbox poller stopping")
			return
		case <-ticker.C:
			if err := p.processBatch(ctx); err != nil && !errors.Is(err, context.Canceled) {
				p.logger.Error("outbox batch failed", "error", err)
			}
		}
	}
}

// processBatch — jedna iteracja: BEGIN tx, FETCH FOR UPDATE SKIP LOCKED,
// publish do Pub/Sub każdego row, MarkPublished lub MarkFailed, COMMIT.
//
// Tx jest trzymana przez czas publishu — to wydłuża lock, ale gwarantuje
// że inna replika nie wjedzie i nie zrobi double-publishu (gdyby my publish'i
// a potem failowali w MarkPublished, druga replika by zauważyła processed=false
// i opublikowała ponownie — at-least-once jest OK dla idempotentnych konsumentów,
// ale niepotrzebnie zwiększałoby duplikaty).
func (p *Poller) processBatch(ctx context.Context) error {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("tx begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	q := db.New(tx)
	batch, err := q.FetchUnpublishedOutboxBatch(ctx, p.cfg.BatchSize)
	if err != nil {
		return fmt.Errorf("fetch batch: %w", err)
	}
	if len(batch) == 0 {
		return nil
	}

	p.logger.Debug("outbox batch fetched", "count", len(batch))

	publishedCount := 0
	for _, ev := range batch {
		idempKey := buildIdempotencyKey(ev.AggregateType, ev.EventType, ev.AggregateID.String(), ev.CreatedAt)
		err := p.pub.PublishOutboxEvent(
			ctx,
			ev.EventType,
			ev.AggregateType,
			ev.OrganizationID.String(),
			idempKey,
			ev.Payload,
		)
		if err != nil {
			errStr := err.Error()
			if mErr := q.MarkOutboxEventFailed(ctx, db.MarkOutboxEventFailedParams{
				ID:        ev.ID,
				LastError: &errStr,
			}); mErr != nil {
				p.logger.Error("mark failed update failed",
					"event_id", ev.ID,
					"publish_error", err,
					"db_error", mErr)
			}
			p.logger.Warn("outbox publish failed",
				"event_id", ev.ID,
				"event_type", ev.EventType,
				"attempts", ev.Attempts+1,
				"error", err)
			continue
		}
		if err := q.MarkOutboxEventPublished(ctx, ev.ID); err != nil {
			p.logger.Error("mark published failed (event already in pubsub)",
				"event_id", ev.ID,
				"error", err)
			continue
		}
		publishedCount++
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("tx commit: %w", err)
	}

	if publishedCount > 0 {
		p.logger.Info("outbox batch published",
			"published", publishedCount,
			"total", len(batch))
	}
	return nil
}

// buildIdempotencyKey — deterministic per-event ID. Konsument używa tego
// żeby deduplikować nawet jeśli Pub/Sub dostarczy message 2x (at-least-once).
func buildIdempotencyKey(aggregateType, eventType, aggregateID string, createdAt time.Time) string {
	return fmt.Sprintf("%s:%s:%s:%d", aggregateType, eventType, aggregateID, createdAt.UnixNano())
}

// Ensure pgx.Tx satisfies db.DBTX so q := db.New(tx) compiles.
var _ db.DBTX = (pgx.Tx)(nil)
