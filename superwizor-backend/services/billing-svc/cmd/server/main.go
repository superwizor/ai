package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	nethttp "net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	httpadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/http"
	grpcadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
	psadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/pubsub"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/outboxpoller"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := getEnv("PORT", "8080")
	httpPort := getEnv("HTTP_PORT", "8081")
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

	pool, err := pgxpool.New(rootCtx, dbDSN)
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

	srv := grpcadapter.NewServer(pool, version)
	if w := getEnvInt32("BILLING_WARN_REMAINING", 0); w > 0 {
		c := getEnvInt32("BILLING_CRITICAL_REMAINING", 1)
		srv.WithThresholds(w, c)
		slog.Info("custom thresholds set", "warn", w, "critical", c)
	}

	// gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("grpc listen failed", "error", err)
		os.Exit(1)
	}

	gs := grpc.NewServer()
	billingv1.RegisterBillingServiceServer(gs, srv)
	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	// HTTP server (admin crons + Stripe stub).
	mux := nethttp.NewServeMux()
	httpadapter.NewAdminHandler(pool, logger).RegisterRoutes(mux)
	httpadapter.NewStripeStubHandler(pool, logger).RegisterRoutes(mux)
	mux.HandleFunc("GET /healthz", func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	httpSrv := &nethttp.Server{
		Addr:              ":" + httpPort,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Coordinated shutdown.
	var wg sync.WaitGroup

	// gRPC server goroutine.
	wg.Add(1)
	go func() {
		defer wg.Done()
		slog.Info("billing-svc gRPC starting", "port", port, "version", version)
		if err := gs.Serve(lis); err != nil {
			slog.Error("grpc serve failed", "error", err)
		}
	}()

	// HTTP server goroutine.
	wg.Add(1)
	go func() {
		defer wg.Done()
		slog.Info("billing-svc HTTP starting", "port", httpPort)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, nethttp.ErrServerClosed) {
			slog.Error("http serve failed", "error", err)
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

	// Graceful shutdown.
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
