// billing-svc Phase 3 entrypoint.
//
// Jeden HTTP/2 listener na PORT (default :8080) obsługujący:
//   - gRPC requests (Content-Type: application/grpc) → BillingService
//   - HTTP/1.1 + HTTP/2 plaintext → admin cron endpoints + Stripe stub
//
// Cloud Run akceptuje jeden port per service, więc nie można rozdzielić
// na dwa listenery (jak w sample architekturze gdzie wszystko ma osobne
// rejestrowane SAs). Używamy h2c muxa: handler dispatcher patrzy na
// Content-Type i routuje do grpcServer.ServeHTTP albo zwykłego HTTP muxa.
//
// Pattern (oficjalny gRPC docs / Cloud Run docs): kompatybilny zarówno z
// `gcloud run deploy --use-http2` jak i z Cloud Scheduler OIDC POSTami.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	nethttp "net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
	httpadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/http"
	psadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/pubsub"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/outboxpoller"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := getEnv("PORT", "8080")
	version := getEnv("VERSION", "phase3-v1")

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		dbUser := os.Getenv("DB_USER")
		dbPass := os.Getenv("DB_PASSWORD")
		dbHost := os.Getenv("DB_HOST")
		dbName := os.Getenv("DB_NAME")
		if dbUser != "" && dbPass != "" && dbHost != "" && dbName != "" {
			dbDSN = fmt.Sprintf("postgres://%s:%s@%s:5432/%s?sslmode=disable",
				dbUser, dbPass, dbHost, dbName)
		}
	}
	if dbDSN == "" {
		slog.Error("DATABASE_URL (or DB_USER/PASS/HOST/NAME) required")
		os.Exit(1)
	}

	rootCtx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	// Bounded pool — billing-svc gets 2 because it runs both the gRPC
	// handlers AND an in-process outbox poller goroutine that selects
	// from outbox_events. Single-conn would starve one or the other.
	// See docs/17 §11 for the cross-service budget table.
	poolCfg, err := pgxpool.ParseConfig(dbDSN)
	if err != nil {
		slog.Error("parse db dsn", "error", err)
		os.Exit(1)
	}
	poolCfg.MaxConns = 2
	poolCfg.MinConns = 0
	poolCfg.MaxConnIdleTime = 30 * time.Second
	pool, err := pgxpool.NewWithConfig(rootCtx, poolCfg)
	if err != nil {
		slog.Error("db connect failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	// Pub/Sub publisher (opcjonalnie — bez GCP_PROJECT_ID outbox poller
	// jest wyłączony, useful dla local dev).
	var pubPublisher *psadapter.Publisher
	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID != "" {
		pubPublisher, err = psadapter.NewPublisher(rootCtx, projectID)
		if err != nil {
			slog.Error("pubsub publisher init failed", "error", err)
			os.Exit(1)
		}
		defer func() { _ = pubPublisher.Close() }()
	} else {
		slog.Warn("GCP_PROJECT_ID unset — outbox poller disabled (local dev mode)")
	}

	billingServer := grpcadapter.NewServer(pool, version)
	if w := getEnvInt32("BILLING_WARN_REMAINING", 0); w > 0 {
		c := getEnvInt32("BILLING_CRITICAL_REMAINING", 1)
		billingServer.WithThresholds(w, c)
		slog.Info("custom thresholds set", "warn", w, "critical", c)
	}

	// gRPC server (in-process — handler reused via ServeHTTP).
	gs := grpc.NewServer()
	billingv1.RegisterBillingServiceServer(gs, billingServer)
	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	// HTTP mux (admin crons + Stripe stub + /healthz).
	httpMux := nethttp.NewServeMux()
	httpadapter.NewAdminHandler(pool, logger).RegisterRoutes(httpMux)
	httpadapter.NewStripeStubHandler(pool, logger).RegisterRoutes(httpMux)
	httpMux.HandleFunc("GET /healthz", func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// Mixed handler: gRPC requests trafiają do grpc.Server, reszta do http mux.
	// Content-Type "application/grpc" jest deterministic indicator gRPC traffic
	// (gRPC wire format + HTTP/2 wymagane).
	mixedHandler := nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.ProtoMajor == 2 && strings.HasPrefix(r.Header.Get("Content-Type"), "application/grpc") {
			gs.ServeHTTP(w, r)
			return
		}
		httpMux.ServeHTTP(w, r)
	})

	// h2c (HTTP/2 cleartext) — Cloud Run terminuje TLS przed kontenerem,
	// więc po naszej stronie ruch jest HTTP/2 plaintext.
	h2s := &http2.Server{}
	httpSrv := &nethttp.Server{
		Addr:              ":" + port,
		Handler:           h2c.NewHandler(mixedHandler, h2s),
		ReadHeaderTimeout: 10 * time.Second,
	}

	var wg sync.WaitGroup

	// Mixed listener goroutine.
	wg.Add(1)
	go func() {
		defer wg.Done()
		slog.Info("billing-svc starting (gRPC + HTTP mixed)",
			"port", port, "version", version)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, nethttp.ErrServerClosed) {
			slog.Error("serve failed", "error", err)
		}
	}()

	// Outbox poller goroutine (jeśli Pub/Sub jest włączony).
	if pubPublisher != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			pollInterval := time.Duration(getEnvInt32("OUTBOX_POLL_INTERVAL_SEC", 5)) * time.Second
			batchSize := getEnvInt32("OUTBOX_BATCH_SIZE", 100)
			poller := outboxpoller.New(pool, pubPublisher, outboxpoller.Config{
				PollInterval: pollInterval,
				BatchSize:    batchSize,
			}, logger)
			poller.Run(rootCtx)
		}()
	}

	<-rootCtx.Done()
	slog.Info("shutdown signal received")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	gs.GracefulStop()
	_ = httpSrv.Shutdown(shutdownCtx)

	wg.Wait()
	slog.Info("billing-svc stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt32(key string, fallback int32) int32 {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.ParseInt(v, 10, 32)
	if err != nil {
		slog.Warn("invalid env var", "key", key, "value", v, "fallback", fallback)
		return fallback
	}
	return int32(n)
}
