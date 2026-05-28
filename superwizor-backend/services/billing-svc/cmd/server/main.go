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
	billingv1connect "github.com/superwizor-ai/backend/gen/go/billing/v1/billingv1connect"
	"connectrpc.com/connect"

	"github.com/superwizor-ai/backend/pkg/connectmd"
	"github.com/superwizor-ai/backend/pkg/cors"
	grpcadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
	httpadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/http"
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

	// Phase C of feat/billing-svc-refactor removed the outbox poller +
	// Pub/Sub publisher + edge-threshold WithThresholds wiring. The
	// client-cache model (clinical-svc.GetMyBillingState + state_after
	// on Reservation/UsageCommit) is the only way state propagates now.

	billingServer := grpcadapter.NewServer(pool, version)

	// gRPC server (in-process — handler reused via ServeHTTP).
	gs := grpc.NewServer()
	billingv1.RegisterBillingServiceServer(gs, billingServer)
	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	// HTTP mux (admin crons + Stripe stub + /healthz + Connect-RPC).
	httpMux := nethttp.NewServeMux()
	httpadapter.NewAdminHandler(pool, logger).RegisterRoutes(httpMux)
	httpadapter.NewStripeStubHandler(pool, logger).RegisterRoutes(httpMux)
	// Connect-RPC surface — browser callers reach the same business
	// logic as the gRPC path via the ConnectAdapter. The connectmd
	// interceptor copies HTTP request headers into the ctx as gRPC
	// IncomingMetadata so auth helpers that read metadata.FromIncomingContext
	// see the Authorization Bearer header. Without it Connect requests
	// land at metadata-checking handlers with `code = Unauthenticated
	// desc = no gRPC metadata`. See pkg/connectmd for the writeup.
	connectPath, connectHandler := billingv1connect.NewBillingServiceHandler(
		grpcadapter.NewConnectAdapter(billingServer),
		connect.WithInterceptors(connectmd.HeadersToGRPCMetadata()),
	)
	httpMux.Handle(connectPath, connectHandler)
	httpMux.HandleFunc("GET /healthz", func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// Mixed handler dispatches by Content-Type:
	//   application/grpc           -> native gRPC server (server-to-server, iOS)
	//   application/grpc-web[+...] -> Connect handler (Flutter web speaks gRPC-Web)
	//   application/{json,connect+} -> Connect handler (marketing-site browser)
	//
	// The Connect handler is a 3-protocol multiplexer; routing gRPC-Web
	// to it gives Flutter web a working RPC channel without spinning up
	// a separate gRPC-Web proxy. Pre-fix Flutter web got 415 from the
	// plain gRPC server (see PROGRESS.md 2026-05-28).
	mixedHandler := nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		ct := r.Header.Get("Content-Type")
		if r.ProtoMajor == 2 && strings.HasPrefix(ct, "application/grpc") {
			if strings.HasPrefix(ct, "application/grpc-web") {
				httpMux.ServeHTTP(w, r)
				return
			}
			gs.ServeHTTP(w, r)
			return
		}
		httpMux.ServeHTTP(w, r)
	})

	// CORS middleware for browser-facing Connect-RPC + admin HTTP routes.
	// Origins come from CORS_ALLOWED_ORIGINS env (set by terraform on
	// staging to superwizor.ai + app.superwizor.ai + localhost dev).
	// Server-to-server callers (Cloud Scheduler OIDC) don't carry an
	// Origin header and pass through untouched. See docs/18 §5 / R2.
	corsOrigins := getEnv("CORS_ALLOWED_ORIGINS",
		"https://superwizor.ai,https://app.superwizor.ai,http://localhost:3000,http://localhost:8080")
	corsMW := cors.New(cors.FromEnv(corsOrigins))

	// h2c (HTTP/2 cleartext) — Cloud Run terminuje TLS przed kontenerem,
	// więc po naszej stronie ruch jest HTTP/2 plaintext.
	h2s := &http2.Server{}
	httpSrv := &nethttp.Server{
		Addr:              ":" + port,
		Handler:           h2c.NewHandler(corsMW(mixedHandler), h2s),
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
