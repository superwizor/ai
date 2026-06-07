package analytics

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Event reprezentuje pojedyncze zdarzenie analityczne zapisywane do PostgreSQL.
// Nie zawiera żadnych danych osobowych pacjentów (PHI) zgodnie z P1 i GDPR.
type Event struct {
	Name           string
	TherapistID    *uuid.UUID
	OrganizationID *uuid.UUID
	SessionID      *uuid.UUID
	PatientFileID  *uuid.UUID
	ReportID       *uuid.UUID
	Properties     map[string]any
	Source         string // "server" lub "client"
	ClientPlatform string
	ClientVersion  string
	OccurredAt     time.Time
}

// Collector zarządza buforowaniem i zapisem zdarzeń analitycznych w tle.
type Collector struct {
	db   *pgxpool.Pool
	ch   chan Event
	wg   sync.WaitGroup
	done chan struct{}
}

// NewCollector inicjalizuje kolektor i uruchamia proces przetwarzania w tle.
// Bufor kanału to 1000 zdarzeń. Jeśli się przepełni, nowe zdarzenia są odrzucane.
func NewCollector(db *pgxpool.Pool) *Collector {
	c := &Collector{
		db:   db,
		ch:   make(chan Event, 1000),
		done: make(chan struct{}),
	}

	c.wg.Add(1)
	go c.worker()

	return c
}

// Track dodaje zdarzenie do kolejki. Jest to operacja nieblokująca i bezpieczna współbieżnie.
// Jeśli kanał jest pełny, zdarzenie zostanie pominięte, a fakt ten zalogowany jako ostrzeżenie.
func (c *Collector) Track(ctx context.Context, e Event) {
	if e.OccurredAt.IsZero() {
		e.OccurredAt = time.Now()
	}
	if e.Source == "" {
		e.Source = "server"
	}
	if e.Properties == nil {
		e.Properties = make(map[string]any)
	}

	select {
	case c.ch <- e:
	default:
		slog.WarnContext(ctx, "analytics queue full, dropping event", "event_name", e.Name)
	}
}

// Shutdown bezpiecznie kończy działanie kolektora, zapisując wszystkie pozostałe zdarzenia.
func (c *Collector) Shutdown() {
	close(c.ch)
	c.wg.Wait()
}

func (c *Collector) worker() {
	defer c.wg.Done()

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	var batch []Event
	maxBatchSize := 100

	flush := func() {
		if len(batch) == 0 {
			return
		}
		c.flushEvents(batch)
		batch = nil
	}

	for {
		select {
		case ev, ok := <-c.ch:
			if !ok {
				// Kanał zamknięty (Shutdown)
				flush()
				return
			}
			batch = append(batch, ev)
			if len(batch) >= maxBatchSize {
				flush()
			}
		case <-ticker.C:
			flush()
		}
	}
}

func (c *Collector) flushEvents(events []Event) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Przygotowanie danych do szybkiego CopyFrom
	rows := make([][]any, len(events))
	for i, e := range events {
		propBytes, err := json.Marshal(e.Properties)
		if err != nil {
			slog.ErrorContext(ctx, "failed to marshal analytics properties", "error", err, "event_name", e.Name)
			propBytes = []byte("{}")
		}

		rows[i] = []any{
			e.Name,
			e.TherapistID,
			e.OrganizationID,
			e.SessionID,
			e.PatientFileID,
			e.ReportID,
			propBytes,
			e.Source,
			nullString(e.ClientPlatform),
			nullString(e.ClientVersion),
			e.OccurredAt,
		}
	}

	_, err := c.db.CopyFrom(
		ctx,
		pgx.Identifier{"analytics_events"},
		[]string{
			"event_name",
			"therapist_id",
			"organization_id",
			"session_id",
			"patient_file_id",
			"report_id",
			"properties",
			"source",
			"client_platform",
			"client_version",
			"occurred_at",
		},
		pgx.CopyFromRows(rows),
	)

	if err != nil {
		slog.ErrorContext(ctx, "failed to batch insert analytics events", "error", err, "count", len(events))
	}
}

func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}
